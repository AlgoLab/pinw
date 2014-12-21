require 'git'

require 'active_record'
require 'net/ssh'
require "net/scp"
require 'yaml'
require 'fileutils'

PROJECT_BASE_PATH ||= File.expand_path('../../', __FILE__) + '/'

# Models:
require PROJECT_BASE_PATH + '/models/base'


class PinWUpdate
    prepend DebugFunctionWrapper
    class DiskFullError < RuntimeError; end
    class BadFASTAHeaderError < RuntimeError; end    
    class UserFilesizeLimitError < RuntimeError; end
    class InvalidJobStateError < RuntimeError; end

    def initialize db_settings, debug: false, force: false, download_path: PROJECT_BASE_PATH + 'downloads/'
        # When the `:force` option is true the cron will   
        # forcefully terminate the fetch_cron_lock owner.

        @db_settings = db_settings
        @debug = debug
        @force = force
        @debug_prefixes = []

        @lock_timeout = 60 # seconds


        ActiveRecord::Base.logger = Logger.new(STDERR) if @debug
        ActiveRecord::Base.establish_connection @db_settings

    end

    def check_and_apply_updates
        # TODO: processing conflicts, open files, general panic
        begin

             # Get current tag version from the db:
            current_tag = ProcessingState.get_current_tag

            # Open local repository:
            git = Git.open PROJECT_BASE_PATH
            
            # Fetch updates:
            git.fetch

            # List all tags and keep only tags newer than the current one:
            updates_to_apply = git.tags().map{|t| t.name}.keep_if{|tname| tname > current_tag}.sort
            return false if updates_to_apply.length == 0

            # Some updates might require to block access to the site:
            nginx_was_stopped = false

            # If we do migrations, first we backup the db:
            db_backup_done = false
            
            FileUtils.mkpath PROJECT_BASE_PATH + "db/backups"
            db_update_filepath = PROJECT_BASE_PATH + "db/backups/pinw-#{Time.now.to_i}-#{current_tag}-to-#{updates_to_apply.last}.db"

            # Apply all updates:
            updates_to_apply.each do |tag|
                need_migration = false
                need_to_stop_ngninx = false

                git.gtree(current_tag).diff(tag).each do |diff|
                    need_migration = true if diff.path.start_with? "db/"
                    need_to_stop_ngninx = true if !(diff.path.starts_with? "public/" || diff.path.starts_with? "views/")

                    # Quick exit if we already know that we need to do both:
                    # NOTE: migrations imply nginx must be restarted.
                    break if need_migration and need_to_stop_ngninx
                end

                if need_to_stop_ngninx and not nginx_was_stopped
                    `nginx -s quit`
                    nginx_was_stopped = false
                end

                # Checkout the new tag:
                git.checkout tag

                if need_migration
                    # Backup the database if required:
                    unless db_backup_done
                        `gzip -c #{PROJECT_BASE_PATH}db/pinw.db > #{db_update_filepath}`
                        db_backup_done = true
                    end
                        
                    # NOTE: The migration script should restart all jobs/kill running processes as required.
                
                    # Run the migration:
                    `rake -f #{PROJECT_BASE_PATH}Rakefile db:migrate`
                end
            end

            # Update the db tag:
            ProcessingState.set_current_tag updates_to_apply.last
            

            # Restart nginx if it had been stopped:
            `nginx` if nginx_was_stopped

        rescue => ex
            # Something went wrong: roll back the update and whine about it.

            # We might have failed really early:
            db_update_filepath ||= false

            # Nothing to revert if the filepath wasn't set:
            return unless db_update_filepath

            # If we have a backup, restore it:
            `gizp -cd #{db_update_filepath} > #{PROJECT_BASE_PATH}db/pinw.db` if File.exist? db_update_filepath

            # Rollback to the correct commit:
            safe_tag = ProcessingState.get_current_tag
            git.checkout safe_tag

            # Whine about it:
            updates_to_apply ||= []
            target = "failed too early to know"
            taget = updates_to_apply.last if updates_to_apply.length > 0
            ProcessingState.set_last_update_error "From [#{safe_tag}] to [#{target}], error was #{ex.message}"
        ensure
            # Nginx must be restarted
            nginx_was_stopped ||= false

            `nginx` if nginx_was_stopped 
        end
    end
end


if __FILE__ == $0
    settings = YAML.load File.read PROJECT_BASE_PATH + 'config/database.yml'

    force = ARGV.include?('-f') or ARGV.include? '--force'
    debug = ARGV.include?('-d') or ARGV.include? '--debug'

    pinw_updater = PinWUpdate.new({
        adapter: settings['test']['adapter'],
        database: PROJECT_BASE_PATH + settings['development']['database'],
        timeout: 30000,
    }, debug: debug, force: force)

    pinw_updater.check_and_apply_updates
end

