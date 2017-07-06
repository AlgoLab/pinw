require 'active_record'
require 'net/ssh'
require "net/scp"
require 'yaml'
require 'json'
require 'fileutils'



PROJECT_BASE_PATH ||= File.expand_path('../../', __FILE__) + '/'

PROJECT_DATA_PATH ||= File.expand_path("..", PROJECT_BASE_PATH) + '/data/'


# Models:
require PROJECT_BASE_PATH + 'models/base'

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
    class CheckScriptTimeoutError < RuntimeError; end
    class GenericSSHProcedureError < RuntimeError; end


    def initialize db_settings, debug: false, force: false, download_path: PROJECT_DATA_PATH + 'downloads/'
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
        @min_read_length = Settings.get_min_read_length
        @max_job_runtime = Settings.get_max_job_runtime
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

        # Exit if the server is disabled:
        return unless server.enabled

        # Exit if there is a lock still in place:
        return if server.check_pid and (Time.now < server.check_lock + @lock_timeout) # 60s

        # Exit if we already checked this server a moment ago:
        return if (not @force) and (Time.now < server.check_last_at + 30) # 30 seconds
        # (if callbacks are enabled the server might have aknowledged a finished job a moment ago
        #  and routine checks are really not necessary)

        # Clear lock if needed:
        kill 9, server.check_pid if server.check_pid
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

                k = Settings.get_ssh_keys

                debug 'grabbed pinw ssh key'

                options = {port: server.port || 22}
                # if server.password.length > 0
                    options[:password] = server.password
                # elsif server.client_certificate.length > 0
                    options[:key_data] = [k[:private_key]]
                #     options[:passphrase] = server.passphrase
                # else
                #     raise ServerConfigurationError
                # end

                debug "connecting to #{server.username}@#{server.host} with data: #{options}"

                # Proxy Command support:
                if server.ssh_proxy_command.length > 0
                    debug "instantiating proxy command"
                    options[:proxy] = Net::SSH::Proxy::Command.new(server.ssh_proxy_command)
                end

                Net::SSH.start(server.host, server.username, options) do |ssh|
                    debug 'connected!'

                    ## CHECK SERVER ##

                    # Move to the pinw working dir:
                    if server.working_dir
                        ssh.exec!("mkdir -p #{server.working_dir}") do |ch, success|
                            raise GenericSSHProcedureError unless success
                        end
                    end

                    # Open SCP session:
                    scp = Net::SCP.new(ssh)

                    # Make sure jobs/ directory exists
                    ssh.exec!("mkdir -p #{server.working_dir}/jobs") do |ch, success|
                        raise GenericSSHProcedureError unless success
                    end

                    # Make sure results/ directory exists
                    ssh.exec!("mkdir -p #{server.working_dir}/results") do |ch, success|
                        raise GenericSSHProcedureError unless success
                    end

                    # Remove old report if present:
                    # (this prevents stale readings in case of wonky failures)
                    ssh.exec!("rm -f #{server.working_dir}/pinw-report.json") do |ch, success|
                        raise GenericSSHProcedureError unless success
                    end

                    # Generate a new report:
                    scp.upload!(PROJECT_BASE_PATH + 'cron/check_jobs.py', "#{server.working_dir}/check_jobs.py")
                    ssh.exec!("chmod +x #{server.working_dir}/check_jobs.py") do |ch, success|
                        raise GenericSSHProcedureError unless success
                    end

                    start_check = Time.now
                    ssh.exec!("cd #{server.working_dir} && ./check_jobs.py") do |ch, stream, data|
                        # Renew lock:
                        server.update check_lock: Time.now if Time.now - server.check_lock > 20 # seconds

                        # Die if hanging:
                        if Time.now - start_check > 60 # seconds
                            ch.close
                            raise CheckScriptTimeoutError
                        end
                    end
                    debug 'check script executed'

                    # Parse results:
                    results = JSON.parse scp.download! "#{server.working_dir}/pinw-report.json"
                    debug "gotten report:\n #{results}"


                    running_jobs = results['running']
                    dead_jobs = results['dead']
                    completed_jobs = results['completed']

                    free_slots = 3

                    ## ACK COMPLETED JOBS ##
                    completed_jobs.each do |j|
                        job = Job.find(j['id'])
                        result = j['result']

                        debug "Dentro completed_jobs.each, la variabile result vale: #{result}"

                        # Renew lock:
                        server.update check_lock: Time.now if Time.now - server.check_lock > 20 # seconds

                        # TODO: what should happen for failed jobs that have produced a json file?

                        begin
                          # Scarico il risultato di Pintron (output.txt) e lo salvo nella cartella public
                          scp.download!("#{server.working_dir}/jobs/job-#{job.id}/output.txt", "#{PROJECT_BASE_PATH}public/results/job-#{job.id}-result.json")
                          debug "Pintron output downloaded into job-#{job.id} directory"
                          
                            # LOCAL SAVE DB
                            result = Result.create_with({
                                user_id: job.user_id,
                                server_id: server.id,
                                organism_id: job.organism_id,
                                gene_name: job.gene_name,
                                description: job.description,
                                ref_sequence: result['ref-seqs'],
                                json: "job-#{job.id}-result.json"

                            }).find_or_create_by!(job_id: job.id)


                            # ACK REMOTE SERVER
                            ssh.exec!("echo '#{result.id}|#{job.id}|#{Time.now}' > #{server.working_dir}/jobs/job-#{job.id}/pinw-ack")
                            ssh.exec!("cp -rf #{server.working_dir}/jobs/job-#{job.id} #{server.working_dir}/results/result-#{result.id}")
                            ssh.exec!("rm -rf #{server.working_dir}/jobs/job-#{job.id}")

                            # Delete job from db:
                            job.destroy

                        rescue => ex
                            debug ex.message
                            job.update processing_error: "Unexpected error: #{ex.message}" # , processing_failed: true
                        end
                    end

                    ## DEAD JOBS ##
                    # Job.where(server_id: server.id).where.not(id: active_jobs + failed_jobs + completed_jobs).each do |job|
                    #     job.update processing_failed: true, processing_last_error: "Spurious job: the server has no knowledge of this job."
                    # end


                    ## DISPATCH NEW JOBS ##
                    while free_slots > 0 and (server.local_network or ProcessingState.get_active_remote_transfers < @max_remote_transfers)
                        # Renew lock:
                        server.update check_lock: Time.now if Time.now - server.check_lock > 20 # seconds

                        begin
                            # TODO: remove transaction by using a conditional UPDATE ... LIMIT 1 ?
                            dispatch_job = nil
                            old_pid = nil
                            Job.transaction do
                                dispatch_job = Job.order(:server_id).find_by(Job.arel_table[:processing_dispatch_lock].lt(Time.now - 5 * 60),
                                                  awaiting_dispatch: true, paused: false, server_id: [server.id, nil])

                                debug "dispatch jobs IMP: #{dispatch_job.to_yaml}"
                                # Exit if there are no more jobs to dispatch:
                                debug "No more job to dispatch" unless dispatch_job
                                break unless dispatch_job
                                debug "dispatching a job!"

                                # Save stale pid (no unecessary operations inside the transaction):
                                old_pid = dispatch_job.processing_dispatch_pid

                                # Lock job:
                                dispatch_job.update({
                                    server_id: server.id,
                                    processing_dispatch_lock: Time.now,
                                    processing_dispatch_pid: Process.pid
                                })
                            end #transaction

                            # Kill eventual stale pid:
                            if old_pid
                                kill 9, old_pid
                                debug "killed old dispatch for dispatch job: #{dispatch_job.id}"
                                #debug "killed old dispatch for dispatch job: #{dispatch_job.id}"
                            end


                            break unless dispatch_job


                            # Clear remote dir
                            ssh.exec!("rm -rf #{server.working_dir}/jobs/job-#{dispatch_job.id}")

                            # Write the config snippet (rewritten every dispatch in case of job restart)

                            File.write(@download_path + "job-#{dispatch_job.id}/job-params.json", JSON.generate({
                                pintron_path: server.pintron_path,
                                organism: dispatch_job.organism.name,
                                gene_name: dispatch_job.gene_name,
                                output: "job-#{dispatch_job.id}-output.json",
                                # Shortest read length considered by pintron:
                                min_read_length: @min_read_length,
                                # if the quality threshold is present the format is FASTQ  else the format is EST
                                quality_threshold: if dispatch_job.quality_threshold then dispatch_job.quality_threshold else nil end,
                                # Job processing timeout:
                                timeout: @max_job_runtime,
                                use_callback: true, #server.use_callback,
                                callback_url: "localhost" #server.callback_url

                            }))

                            # Write the execution script:
                            FileUtils.cp(PROJECT_BASE_PATH + "cron/launch.py", @download_path + "job-#{dispatch_job.id}/")

                            # Concatenate all sequence files into one file
                            system("cat #{@download_path}job-#{dispatch_job.id}/reads/* > #{@download_path}job-#{dispatch_job.id}/reads/reads-concat")

                            ProcessingState.add_remote_transfer "Server: #{server.id} | Job: #{dispatch_job.id}"
                            scp.upload!(@download_path + "job-#{dispatch_job.id}/", "#{server.working_dir}/jobs/job-#{dispatch_job.id}/", recursive: true) do |ch, name, sent, total|
                                # Renew server lock:
                                server.update check_lock: Time.now if Time.now - server.check_lock > 20 # seconds

                                # Renew job lock:
                                dispatch_job.update processing_dispatch_lock: Time.now if Time.now - server.check_lock > 20 # seconds
                            end
                            debug 'done uploading files!'

                            # Start the processing script
                            ssh.exec!("chmod +x #{server.working_dir}/jobs/job-#{dispatch_job.id}/launch.py")
                            ssh.exec!("cd #{server.working_dir}/jobs/job-#{dispatch_job.id} && ./launch.py &")
                            ssh.exec!('disown')

                            # Mark job as dispatched!
                            dispatch_job.update awaiting_dispatch: false, processing_dispatch_ok: true
                            free_slots -= 1

                        rescue => ex
                            raise JobDispatchError, ex.message

                        ensure
                            ProcessingState.remove_remote_transfer rescue nil
                            dispatch_job.update(processing_dispatch_pid: nil) rescue nil

                            # If channels took more time to complete than dispatch
                            # (or there was no dispatch), wait for them all to complete:
                        end #begin
                    end #while
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
            Process.detach(Process.fork do
                # Connect to the database:
                ActiveRecord::Base.establish_connection @db_settings
                processing_block.call
            end)

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
                kill 9, cron_lock.value
                puts "Warning: last pinw-dispatch cronjob was terminated."
            end
        end
        puts 'OK LOCK CRON' if @debug


        # Acquire lock:
        cron_lock.update value: Process.pid
        return cron_lock
    end

    def debug string
        prefixes = ["DISPATCH"] + ["P:#{Process.pid}"] + @debug_prefixes
        puts "[#{prefixes.join('|')}] #{string}" if @debug
    end

    def kill sig, pid
        Process.kill 9, pid rescue nil
    end


end


if __FILE__ == $0
    settings = YAML.load File.read PROJECT_BASE_PATH + 'config/database.yml'

    force = ARGV.include? '--force'
    debug = ARGV.include? '--debug'
    production = ARGV.include? '--production'

    env =  if production then 'production' else 'development' end

    x = PinWDispatch.new({
        adapter:  settings[env]['adapter'],
        database: PROJECT_DATA_PATH + settings[env]['database'],
        timeout: 30000,
    }, debug: debug, force: true)


    x.run_main_loop
end
