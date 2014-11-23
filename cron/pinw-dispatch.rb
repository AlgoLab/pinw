require 'net/ssh'

# Models:
require_relative '../models/base'

# TODO: check timelock math
# TODO: --super-force option

class PinWDispatch

	def initialize db_settings, debug: false, force:false
		@db_settings = db_settings
		@debug = debug
		@force = force

		if debug
			ActiveRecord::Base.logger = Logger.new(STDERR)
		end

		ActiveRecord::Base.establish_connection @db_settings

		# Models:
		require_relative '../models/users'
		require_relative '../models/servers'
		require_relative '../models/results'
		require_relative '../models/jobs'
		require_relative '../models/processing_status'
	end

	def run_main_loop
		# Acquire lock:
		cron_lock = check_and_acquire_cron_lock

		# Process all servers:
		Server.order(:priority).each {|server| check_server server}
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
			case clear_lock server.check_pid
			when :killed
				puts 'killed old check process'
			when :no_process
				puts 'old check process died'
			end
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

					## DISPATCH NEW JOBS ##
					# Job.find_by(awaiting_dispatch: true)
					job = get right job

					# locks
					# transfer data
					# launch job


					# If channels took more time to complete than dispatch 
					# (or there was no dispatch), wait for them all to complete:
					channels.each {|ch| ch.wait}
				end
			rescue

			ensure
				server.update check_pid: nil
				# job.update dispatch_pid: nil
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
			if (not @force) and cron_lock.updated_at > Time.now - 5 * 60 # 5 minutes
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


	def clear_lock pid
		begin
			Process.kill 9, pid
			return :killed
		rescue
			return :no_process
		end
	end	


end


if __FILE__ == $0
	settings = YAML.load(File.read('config.yml'))

	force = false
	if ARGV.length > 0 and (ARGV[0] == '-f' or ARGV[0] == '--force')
		force = true
	end

	PinWDispatch.new({
		adapter: settings['database']['adapter'],
		database: settings['database']['name'],
		timeout: 30000,
	}, debug: true, force: force).run_main_loop
end