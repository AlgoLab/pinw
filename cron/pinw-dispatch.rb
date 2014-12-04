require 'active_record'
require 'net/ssh'
require "net/scp"

PROJECT_BASE_PATH ||= File.expand_path('../../', __FILE__) + '/'

# Models:
require PROJECT_BASE_PATH + '/models/base'

# TODO: check timelock math
# TODO: --super-force option


module DebugFunctionWrapper 
    # This module is used to wrap method calls:
    # all it does is add a tag into the deug_prefix list and
    # remove it after the method returns. 
    # This way we have less debug-related pollution inside the code.
    # Basically it's a poor man's function decorator.

    def check_server server, *args, **kwargs
        @debug_prefixes << "S:#{server.id}" if @debug
        begin
            return super server, *args, **kwargs
        ensure
            @debug_prefixes.pop if @debug
        end
    end
end

class PinWDispatch
    prepend DebugFunctionWrapper
    class ServerConfigurationError < RuntimeError; end
    class JobDispatchError < RuntimeError; end

    def initialize db_settings, debug: false, force: false, download_path: PROJECT_BASE_PATH + 'downloads/'
        # When the `:force` option is true the cron will   
        # forcefully terminate the fetch_cron_lock owner.

        @db_settings = db_settings
        @debug = debug
        @force = force
        @download_path = download_path
        @debug_prefixes = []

        @lock_timeout = 60 # seconds

        ActiveRecord::Base.logger = Logger.new(STDERR) if @debug
        ActiveRecord::Base.establish_connection @db_settings

        @max_remote_transfers = Settings.get_max_remote_transfers
    end

    def run_main_loop
        # Acquire lock:
        cron_lock = check_and_acquire_cron_lock

        debug 'LOCK OK'

        # Process all servers:
        Server.order(:priority).each do |server|
            @debug_prefixes << "S:#{server.id}" if @debug
            
            check_server server
            debug 'DONE CHECKING SERVER'

            # Refresh cron lock:
            cron_lock.update value: Process.pid

            @debug_prefixes.pop if @debug
        end
        # (ordering by priority ensures servers with higher priority 
        #  are selected first to dispatch enqueued jobs)

        # Free the cron lock:
        cron_lock.update value: nil
    
    end

    def check_server server, async: true

        # Exit if there is a lock still in place:
        return if server.check_pid and (Time.now < server.check_lock + @lock_timeout) # 60s

        # Exit if we already checked this server a moment ago:
        return if (not @force) and (Time.now < server.check_last_at + 30) # 30 seconds
        # (if callbacks are enabled the server might have aknowledged a finished job a moment ago
        #  and routine checks are really not necessary)

        # Clear lock if needed:        
        Process.kill 9, server.check_pid if server.check_pid
        debug 'killed old check process' if server.check_pid

        launch lambda {
            begin
                # Update the db
                server.update({
                    check_lock: Time.now,
                    check_last_at: Time.now,
                    check_pid: Process.pid
                })

                debug 'acquired server lock'

                options = {port: server.port || 22}
                if server.password
                    options[:password] = server.password
                elsif server.client_certificate
                    options[:key_data] = [server.client_certificate]
                    options[:passphrase] = server.passphrase
                else
                    raise ServerConfigurationError
                end

                debug "connecting to #{server.user}@#{server.host} with data: #{options}"

                Net::SSH.start(server.host, server.username, options) do |ssh|
                    debug 'connected!'

                    # Open SCP session:
                    scp = Net::SCP.new(ssh)

                    ## CHECK SERVER ##

                    ssh.exec!("pyton script")
                    debug 'check script executed'

                    # Get results:
                    results = scp.download! 'check_report.yml'
                    debug "gotten report:\n #{results}"

                    # Parse results:
                    # TODO: parse results

                    completed_jobs = [1,2,3] # get from results
                    free_slots = 3

                    # TODO: maybe change style to async for better troughput? (must understand how to correctly handle errors)

                    # ACK completed jobs:
                    completed_jobs.each do |job|


                    end


                    # This nested block is only used to ensure that
                    # channels don't get interrupted by errors that 
                    # might happen during a job dispatch (and to 
                    # convert the errors in JobDispatchErrors so that
                    # we know that the curlpit might not be the server
                    # but the job instance, and flag it accordingly).
                    # All error handling is still done in the main
                    # begin/rescue block.
                    
                    ## DISPATCH NEW JOBS ##
                    while free_slots > 0 and (not server.remote_network or ProcessingState.get_active_remote_transfers < @max_remote_transfers)
                        begin

                            # TODO: remove transaction by using a conditional UPDATE ... LIMIT 1 ?

                            dispatch_job = nil # TODO: scope!

                            Job.transaction do
                                dispatch_job = Job.find_by(awaiting_dispatch: true,
                                                  # Job.arel_table[:processing_dispatch_lock].lt(Time.now - 5 * 60), # 5 minutes
                                                  processing_dispatch_lock: Time.at(0)..(Time.now - 5 * 60), # 5 minutes
                                                  server_id: [server.id, nil]).order(:server_id)
                            
                                break unless dispatch_job

                                if dispatch_job.processing_dispatch_pid
                                    Process.kill 9, dispatch_job.processing_dispatch_pid
                                    puts 'killed old dispatch'
                                end


                                dispatch_job.update server_id: server.id, processing_dispatch_lock: Time.now, processing_dispatch_pid: Process.pid
                                    
                            end



                            # clear remote directory? no, fail
                            ProcessingState.add_remote_transfer server_id: server.id, job_id: dispatch_job.id
                            scp.download!('/filezz/', 'myfilezz/')
            

                            dispatch_job.update awaiting_dispatch: false, processing_dispatch_ok: true
                            free_slots -= 1

                        rescue => ex
                            raise JobDispatchError, ex.message

                        ensure
                            dispatch_job.update processing_dispatch_pid: nil

                            # If channels took more time to complete than dispatch 
                            # (or there was no dispatch), wait for them all to complete:
                            channels.each {|ch| ch.wait}
                        end
                    end
                end

            rescue ServerConfigurationError
                debug 'this server has an invalid configuration!'
                server.update last_check_error: "This server has an invalid configuration!"

            rescue JobDispatchError => ex
                debug "Job Dispatch Error: #{ex.message}"

            rescue Net::SSH::Exception => ex
                debug "SSH Error: #{ex.message} #{ex.inspect}"
                server.update last_check_error: "SSH error: #{ex.message}"

            rescue => ex
                debug "unhandled error: #{ex.message} #{ex.inspect}"
                server.update last_check_error: "unhandled error: #{ex.message}"

            ensure
                server.update check_pid: nil
                puts '[D] end of subprocess' if @debug
            end
        }, async: async
    end

    def launch(processing_block, async: true)
        if async
            debug 'async was true, disconnecting db and forking'
            
            # Close the DB connection (required when forking):
            ActiveRecord::Base.connection_pool.disconnect!
            Process.detach Process.fork do 
                # Connect to the database:
                ActiveRecord::Base.establish_connection @db_settings
                processing_block.call
            end

            # Restablish the database connection:
            ActiveRecord::Base.establish_connection @db_settings
        else
            debug 'async was false, proceeding sequentially'
            
            processing_block.call
            debug 'done processing!'
        end
    end

    def check_and_acquire_cron_lock
        cron_lock = ProcessingState.find 'DISPATCH_CRON_LOCK'

        # Check if another pinw-dispatch is running (or is dead/hanging):
        puts " Cron lock value: #{cron_lock.value}" if @debug
        if cron_lock.value # nil => last cron completed successfully 
            if (not @force) and Time.now < cron_lock.updated_at + 5 * 60 # 5 minutes
                # The other process is still alive
                puts "Warning: older cron insance still running, aborting current execution."
                Process.exit(0)
            else
                # The other instance is either hanging or dead
                Process.kill 9, cron_lock.value
                puts "Warning: last pinw-dispatch cronjob was terminated."
            end
        end
        puts 'OK LOCK CRON' if @debug


        # Acquire lock:
        cron_lock.update value: Process.pid
        return cron_lock
    end

    def debug string
        prefixes = ["P:#{Process.pid}"] + @debug_prefixes
        puts "[#{prefixes.join('|')}] #{string}" if @debug
    end

end


if __FILE__ == $0
    settings = YAML.load File.read PROJECT_BASE_PATH + 'config/database.yml'

    force = ARGV.include?('-f') or ARGV.include? '--force'
    debug = ARGV.include?('-d') or ARGV.include? '--debug'

    PinWDispatch.new({
        adapter: settings['test']['adapter'],
        database: PROJECT_BASE_PATH + settings['test']['database'],
        timeout: 30000,
    }, debug: debug, force: force).run_main_loop
end