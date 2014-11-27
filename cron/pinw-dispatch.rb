require 'net/ssh'

# Models:
require_relative '../models/base'

# TODO: check timelock math
# TODO: --super-force option

class PinWDispatch

	def initialize db_settings, debug: false, force: false
		@db_settings = db_settings
		@debug = debug
		@force = force

		if debug
			ActiveRecord::Base.logger = Logger.new(STDERR)
		end

		ActiveRecord::Base.establish_connection @db_settings
	end

	def run_main_loop
		# Acquire lock:
		cron_lock = check_and_acquire_cron_lock

		# Process all servers:
		Server.order(:priority).each do |server| 
			check_server server

			# Refresh cron lock:
			cron_lock.update value: Process.pid
		end
		# (ordering by priority ensures servers with higher priority 
		#  are selected first to dispatch enqueued jobs)

		# Free the cron lock:
		cron_lock.update value: nil
	
	end

	def check_server server

		# Exit if there is a lock still in place:
		return if (not server.check_pid) or (Time.now < server.check_lock + 5 * 60) # 5 minutes

		# Exit if we already checked this server a moment ago:
		return if (not @force) and (Time.now < server.check_last_at + 30) # 30 seconds
		# (if callbacks are enabled the server might have aknowledged a finished job a moment ago
		#  and routine checks are really not necessary)

		# Clear lock if needed:
		if server.check_pid
			Process.kill 9, server.check_pid
			puts 'killed old check process'
		end


		# Close the DB connection (required when forking):
		ActiveRecord::Base.connection_pool.disconnect!

		puts 'forking' if @debug

		spid = Process.fork do
			begin
				puts '[D] inside the process' if @debug

				check_server server, dispatch: true

				# Connect to the database:
				ActiveRecord::Base.establish_connection @db_settings

				# Update the db
				server.update({
					check_lock: Time.now,
					check_last_at: Time.now,
					check_pid: Process.pid
				})

				puts '[D] updated db' if @debug

				Net::SSH.start('host', 'user', :password => "password") do |ssh|
					## CHECK SERVER ##
					ssh.exec!("pyton script")
					# get results

					completed_jobs = [1,2,3] # get from results
					free_slots

					channels = []
					completed_jobs.each do |cj|
						ssh.open_channel do |ch|
						# Channels are asynchronous!
							channels << ch

							# perform cleanup
							# register finished job
							channel.on_data do |ch, data|
						      puts "got stdout: #{data}"
						      channel.send_data "something for stdin\n"
							end

						    channel.on_extended_data do |ch, type, data|
						      puts "got stderr: #{data}"
						    end

						    channel.on_close do |ch|
						      puts "channel is closing!"
						    end
						end
					end

					

					# This nested block is only used to ensure that
					# channels don't get interrupted by errors that 
					# might happen during a job dispatch.
					# All error handling is still done in the main
					# begin/rescue block.
					begin 
						## DISPATCH NEW JOBS ##
						while free_slots > 0

							break if server.remote_network and ProcessingState.get('BLSBLA')

							Job.transaction do
								job = Job.find_by!(awaiting_dispatch: true,
												  # Job.arel_table[:processing_dispatch_lock].lt(Time.now - 5 * 60), # 5 minutes
												  processing_dispatch_lock: Time.at(0)..(Time.now - 5 * 60), # 5 minutes
												  server_id: [server.id, nil]).order(:server_id)
								

								if job.processing_dispatch_pid
									Process.kill 9, job.processing_dispatch_pid
									puts 'killed old dispatch'
								end


								job.update {
									processing_dispatch_lock: Time.now,
									processing_dispatch_pid: Process.pid
								}		
							end



							# transfer data
								# clear remote directory
								# copy #{job.id}/input (genomics, reads0, reads1, ...)
								# copy some script information in root?

							# launch job



							job.update {
								processing_dispatch_pid: nil,
								awaiting_dispatch: false,
								processing_dispatch_ok: true
							}

							free_slots -= 1
						end
					ensure
						# If channels took more time to complete than dispatch 
						# (or there was no dispatch), wait for them all to complete:
						channels.each {|ch| ch.wait}
					end
				end
			rescue ActiveRecord::RecordNotFound
				# Apparently we're out of jobs to dispatch, nice!

			rescue => ex
				puts ex.message

			ensure
				server.update check_pid: nil
				puts '[D] end of subprocess' if @debug
			end
		end
		Process.detach(spid)
		ActiveRecord::Base.establish_connection @db_settings
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
				begin
					Process.kill 9, cron_lock.value
					puts "Warning: last pinw-dispatch cronjob was terminated."
				rescue
					puts "Warning: last pinw-dispacth cronjob died unexpectedly (or the system was just restarted)."
				end
			end
		end
		puts 'OK LOCK CRON' if @debug


		# Acquire lock:
		cron_lock.update value: Process.pid
		return cron_lock
	end

end


if __FILE__ == $0
	settings = YAML.load(File.read('config/database.yml'))

	force = false
	if ARGV.length > 0 and (ARGV[0] == '-f' or ARGV[0] == '--force')
		force = true
	end

	PinWDispatch.new({
		adapter: settings['test']['adapter'],
		database: settings['test']['database'],
		timeout: 30000,
	}, debug: true, force: force).run_main_loop
end