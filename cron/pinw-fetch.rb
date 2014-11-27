require 'sys/filesystem'
require 'active_record'
require 'yaml'
require 'fileutils'
require 'open-uri'

# Models:
require_relative '../models/base'

# TODO: gene_name_soon flags return hints check processing limits

class PinWFetch
	class DiskFullError < RuntimeError; end
	class BadFASTAHeaderError < RuntimeError; end	
	class UserFilesizeLimitError < RuntimeError; end
	class InvalidJobStateError < RuntimeError; end

	def initialize db_settings, debug: false, force: false
		@db_settings = db_settings
		@debug = debug
		@force = force

		if debug
			ActiveRecord::Base.logger = Logger.new(STDERR)
		end

		ActiveRecord::Base.establish_connection @db_settings
	end

	#########
	def run_main_loop
		# As the function name states,
		cron_lock = check_and_acquire_cron_lock


		# Disk is full, signal the problem to the other processes:
		#ProcessingState.find('DISK_FULL').update value: true


		max_active_downloads = 50
		# Keep looping until all download slots are used or there are no more jobs to process:
		# TODO: trick to be able to use find_each?
		Job.where(awaiting_download: true).each do |job|
			break if max_active_downloads < ProcessingState.find('FETCH_ACTIVE_DOWNLOADS').value.to_i

			puts('got a job:', job.id) if @debug

			# Refresh cron lock:
			cron_lock.update value: Process.pid


			## MAIN OPERATIONS ##

			puts 'main operations' if @debug

			# Genomics (fetch if needed, validate, extract gene name):
			no_gene_name_soon = genomics job

			puts "genomics returned #{no_gene_name_soon}" if @debug

			# Fetch the required metadata from Ensembl:
			ensembl job unless no_gene_name_soon
				# To get the metadata from Ensembl we need a gene name.
				# We might either already have it or not.
				# The second case happens when the user provides his own 
				# FASTA file via URL download (ergo by not uploading it 
				# directly).
				# If the genomics process encountered problems we might
				# not have a gene name soon (retry timeouts, full disk, ...).
				# If this is not the case, the ensembl process will even try 
				# to wait a little more (sleep 5) before giving up, in case 
				# the FASTA file is being downloaded at the same time (the 
				# genomics process will try to extract the gene name from 
				# the file while it's downloading by checking the first 
				# frame of the HTTP response's body (also useful to prevent
				# unecessary downloads)). 

			reads job
		end

		# Free the cron lock:
		cron_lock.update value: nil

	end

	def genomics job, async: true
		# Returns a hint for the ensembl function:
		# true if problems have been encountered that 
		# will prevent the process from getting a gene 
		# name soon, false otherwise.

		puts 'genomics started' if @debug

		# Exit if there is nothing to do or a lock is still in place:
		return false if job.genomics_ok
		return (not job.gene_name) if job.genomics_failed or (job.genomics_pid and (Time.now < job.genomics_lock + 5 * 60))


		puts 'past first return wall' if @debug

		# Exit if we need to wait more before attempting again to download:
		return (not job.gene_name) unless waited_enough job.genomics_last_retry, job.genomics_retries

		puts 'past second' if @debug

		# # Also exit if there is no more free disk space:
		# free_space = Sys::Filesystem.stat("/").block_size * stat.blocks_available / 1024 / 1024 # MegaBytes
		# return (job.gene_name and true) unless free_space > 100
		# ^^ wrong some processing doesnt require disk space

		# Clear lock if needed:
		if job.genomics_pid
			Process.kill 9, job.genomics_pid
			puts 'killed old genomics' if @debug
		end

		puts 'done with genomics lock' if @debug

		# Close the DB connection (required when forking):
		ActiveRecord::Base.connection_pool.disconnect! if async

		puts 'forking' if @debug and async

		# The function that does the actual work:
		# (it will be either executed in a different process
		# or executed sequentially if `async` is set to false)
		processing_block = lambda {
			begin
				puts '[G] inside the process (or still in the same process is async is false :)' if @debug

				# Connect to the database:
				ActiveRecord::Base.establish_connection @db_settings if async

				# Update the db
				job.update({
					genomics_lock: Time.now,
					genomics_retries: job.genomics_retries + 1, # <- safe 
					genomics_last_retry: Time.now,
					genomics_pid: Process.pid
				})

				puts 'updated db' if @debug

				# There are 3 possible cases:

				# we have an URL -> download and check header if not downloading from ensembl
				if job.genomics_url
					puts "[G] URL fetch case for job #{job.id}" if @debug

					# Don't even try if there is no more disk space:
					raise_if_not_enough_space

					puts '[G] ok, enough disk space' if @debug

					FileUtils.mkpath "downloads/#{job.id}"

					puts '[G] dirs created' if @debug

					# TODO: encoding, compression, url safety checks
					open(job.genomics_url, 
						:content_length_proc => lambda {|bytes|
							return unless bytes
							filesize = bytes / 1024 / 1024 # MegaBytes 

							puts '[G] content length test' if @debug

							# Check disk and user limits:
							raise_if_not_enough_space filesize: filesize, user: job.user

							puts '[G] ok content length test' if @debug
						},

						:progress_proc => lambda {|bytes|
							transferred = bytes / 1024 / 1024 # MegaBytes
							# TODO: update some counter?
							# Check disk and user limits:
							raise_if_not_enough_space filesize: transferred, user: job.user

							# Keepalive:
							if Time.now > job.genomics_lock + 20 # Seconds
								job.update genomics_lock: Time.now
							end
						},
						:read_timeout=>10

					) do |transfer| 
						header = transfer.readline
						raise BadFASTAHeaderError unless header =~ /\A>(chr)?X|Y|x|y|\d+:\d+:\d+:\+|-|\+1|-1|1\z/
						
						File.open("downloads/#{job.id}/genomics.fasta", 'w') do |f| 
							f.write header
							f.write transfer.read 
						end
					end

					# TODO:      ^^ find better syntax, add separated exception hadnling?
					# TODO: check frame, extract gene_name asap
					

				# A FASTA file was provided by the user and we need to check its headers:
				elsif job.genomics_file
					puts '[G] checking uploaded file' if @debug

					header = File.open("downloads/#{job.id}/genomics.fasta", 'r').readline 
					
					puts "[G] header is: #{header}" if @debug

					raise BadFASTAHeaderError unless header =~ /\A>(chr)?X|Y|x|y|\d+:\d+:\d+:\+|-|\+1|-1|1\z/

					puts '[G] header ok' if @debug

				# We have a gene name and need to do the whole 
				elsif job.gene_name
					

					# TODO: ensebl
					puts '[G] got gene name, fetching data from ensembl' if @debug

					#

				else raise InvalidJobStateError
				end 

				job.update genomics_ok: true

				# Check if job is ready to be dispatched:
				job.update(awaiting_dispatch: true, downloads_completed_at: Time.now) if Job.find(job.id).all_reads_ok

			rescue InvalidJobStateError
				puts "[G] the job is in an invalid state!" if @debug
				job.update genomics_failed: true, genomics_last_error: "Bad job state."

			rescue Errno::ENOENT # File not found
				puts "[G] cant file the genomics file!" if @debug
				job.update genomics_failed: true, genomics_last_error: "Missing genomics file!"

			rescue BadFASTAHeaderError
				puts "[G] the genomics file has a bad header!" if @debug
				job.update genomics_failed: true, genomics_last_error: "Genomics file doesn't have the required header format."
			
			rescue DiskFullError
				puts "[G] the disk is full!" if @debug
				job.update genomics_retries: job.genomics_retries - 1, genomics_failed: true, genomics_last_error: "Disk full!"
				#          ^^^^^^^^^^^^^^^^ It shoudn't count as a failed retry. 

			rescue UserFilesizeLimitError
				puts "[G] this file exceedes the user limits!" if @debug
				job.update genomics_failed: true, genomics_last_error: "Filesize exceedes user limits."

			rescue URI::InvalidURIError => ex
				puts "[G] invalid url error!" if @debug
				job.update genomics_failed: true, genomics_last_error: "Invalid URL"

			rescue => ex
				puts "[G] unhandled error: #{ex.message}." if @debug
				job.update genomics_failed: true, genomics_last_error: "Unhandled error: #{ex.message}."

			ensure
				job.update genomics_pid: nil
				puts '[G] end of subprocess' if @debug
			end
		}

		if async
			# Start the process that will perform the processing:
			Process.detach Process.fork &processing_block
		else
			processing_block[]
		end


		# Back online:
		ActiveRecord::Base.establish_connection @db_settings if async

		return false
	end


	def ensembl job, async: true
		# Returns false when the ensembl fetch has already 
		# either failed or succeeded, returns true otherwise.

		puts 'started ensembl transcripts fetch procedure' if @debug

		# Exit if there is nothing to do:
		return false if job.ensembl_ok or job.ensembl_failed or (job.ensembl_pid and (Time.now < job.ensembl_lock + 5 * 60)) # 5 minutes

		puts "past first return wall" if @debug

		# Clear lock if needed:
		if job.ensembl_pid
			Process.kill 9, job.ensembl_pid
			puts 'ensembl killed'
		end

		puts 'ok lock ensembl' if @debug

		# Exit if we still need to wait before attempting again the download:
		return true unless waited_enough job.ensembl_last_retry, job.ensembl_retries

		# If we don't have a gene_name we wait a little 
		# and then exit if the situation hasn't changed.
		sleep(5) unless job.gene_name
		job = Job.find job.id
		return true unless job.gene_name


		puts "forking!" if @debug

		# Close the DB connection (required when forking):
		ActiveRecord::Base.connection_pool.disconnect! if async

		# The function that does the actual work:
		# (it will be either executed in a different process
		# or executed sequentially if `async` is set to false)
		processing_block = lambda { 
			begin
				puts '[E] starded subprocess (or still in the same process if async is false :)' if @debug

				# Connect to the database:
				ActiveRecord::Base.establish_connection @db_settings if async

				# Update the DB with our new pid:
				# job.update ensembl_pid: Process.pid

				job.update({
					ensembl_lock: Time.now,
					ensembl_retries: job.ensembl_retries + 1, # <- safe
					ensembl_last_retry: Time.now,
					ensembl_pid: Process.pid
				})

				# Fetch the data:
				# TODO: fetch operations	
				puts '[E] fetched the data!' if @debug

				job.update ensembl_ok: true

				puts '[E] updated db!' if @debug

			rescue => ex
				puts "[E] failed: #{ex.message}" if @debug

				if job.ensembl_retries > 5
					job.update ensembl_failed: true, ensembl_last_error: "Too many failed retries"
					puts "[E] failed too many times" if @debug
				else
					job.update ensembl_last_error: "Failed to fetch data, will retry (reason: #{ex.message})"
					puts "[E] will retry" if @debug
				end
			ensure
				job.update ensembl_pid: nil
				puts '[E] end of subprocess' if @debug
			end
		}

		# Detach from the child process:
		if async
			Process.detach Process.fork &processing_block
		else
			processing_block[]
		end

		# Restablish the database connection:
		ActiveRecord::Base.establish_connection @db_settings if async

		return true
	end


	def reads job, async: true
		puts 'reads started' if @debug

		# Exit if there is nothing to do:
		return false if job.all_reads_ok or job.some_reads_failed

		# Check state of downloadable URLs, if any:
		reads_list = JobRead.where(job_id: job.id, ok: false, failed: false)

		# Exit if there are no reads to download
		return false unless reads_list 

		reads_list.each do |reads|

			# Skip to the next loop if there is nothing to do:
			continue if reads.pid and Time.now < reads.lock + 5 * 60 # 5 minutes

			puts "past first return wall" if @debug

			# Clear lock if needed:
			if job.ensembl_pid
				Process.kill 9, job.ensembl_pid
				puts 'ensembl killed'
			end

			puts 'done with lock' if @debug

			# Skip to the next loop if we still need to wait before attempting again the download:
			continue unless waited_enough reads.last_retry, reads.retries
			

			puts "forking!" if @debug

			# Close the DB connection (required when forking):
			ActiveRecord::Base.connection_pool.disconnect! if async

			# The function that does the actual work:
			# (it will be either executed in a different process
			# or executed sequentially if `async` is set to false)
			processing_block = lambda {
				begin
					puts "[R##{reads.id}] starded subprocess (or still in the same process if async is false" if @debug

					# Connect to the database:
					ActiveRecord::Base.establish_connection @db_settings if async

					# Update the DB with our new pid:
					# job.update ensembl_pid: Process.pid

					read.update({
						lock: Time.now,
						retries: reads.retries + 1, # <- safe
						last_retry: Time.now,
						pid: Process.pid
					})

					# Fetch the data:
					# TODO: fetch operations	


					puts "[R##{reads.id}] fetching the data" if @debug

					# Don't even try if there is no more disk space:
					raise_if_not_enough_space

					puts "[R##{reads.id}] ok, enough disk space" if @debug

					FileUtils.mkpath "downloads/#{job.id}/"

					puts "[R##{reads.id}] dirs created" if @debug

					# TODO: encoding, compression, url safety checks
					open(reads.url, 
					  :content_length_proc => lambda {|bytes|
						return unless bytes
						filesize = bytes / 1024 / 1024 # MegaBytes 

						puts "[R##{reads.id}] content length test" if @debug

						# Check disk and user limits:
						raise_if_not_enough_space filesize: filesize, user: job.user

						puts "[R##{reads.id}] ok content length test" if @debug
					  },

					  :progress_proc => lambda {|bytes|
							transferred = bytes / 1024 / 1024 # MegaBytes
							# TODO: update some counter?
						   # Check disk and user limits:
							raise_if_not_enough_space filesize: filesize, user: job.user
						   
						   # Keepalive:
						   if Time.now > reads.lock + 20 # Seconds
							job.update genomics_lock: Time.now
						   end
					  },
					:read_timeout=>10) do |transfer| 
								header = transfer.readline
								raise BadFASTAHeaderError unless header =~ /\A>(chr)?X|Y|x|y|\d+:\d+:\d+:\+|-|\+1|-1|1\z/
								
								File.open("downloads/#{job.id}/reads-#{job.id}.fastq", 'w') do |f| 
									f.write header
									f.write transfer.read 
								end
							end

					reads.update ok: true

					# Check if all downloads are done and update the job:
					remaining_reads = JobRead.find_by(job_id: job.id).not(ok: true)
					job.update(all_reads_ok: true) if not remaining_reads

					# Check if job is ready to be dispatched:
					job.update(awaiting_dispatch: true, downloads_completed_at: Time.now) if Job.find(job.id).genomics_ok 

				rescue DiskFullError
					puts "[R##{reads.id}] the disk is full!" if @debug
					reads.update retries: reads.retries - 1, failed: true, genomics_last_error: "Disk full!"
					#          ^^^^^^^^^^^^^^^^ It shoudn't count as a failed retry. 
					job.update some_reads_failed: true, reads_last_error: "Disk full!"

				rescue UserFilesizeLimitError
					puts "[R##{reads.id}] this file exceedes the user limits!" if @debug
					reads.update failed: true, last_error: "Filesize exceedes user limits."
					job.update some_reads_failed: true, reads_last_error: "##{reads.id} exceedes user limits."

				rescue URI::InvalidURIError => ex
					puts "[R##{reads.id}] invalid url error!" if @debug
					reads.update failed: true, last_error: "Invalid URL"
					job.update some_reads_failed: true, reads_last_error: "##{reads.id} has and invalid URL."

				rescue => ex
					puts "[R##{reads.id}] unhandled error: #{ex.message}." if @debug
					reads.update failed: true, last_error: "Unhandled error: #{ex.message}."
					job.update some_reads_failed: true, reads_last_error: "##{reads.id} unhandled error: #{ex.message}."

				ensure
					reads.update pid: nil
					puts '[G] end of subprocess' if @debug
				end
			}

			if async 
				Process.detach Process.fork &processing_block
			else
				processing_block[]
			end
		end
		
		# Back online:
		ActiveRecord::Base.establish_connection @db_settings if async
		return reads_list.length > 0
	end




	def check_and_acquire_cron_lock
		cron_lock = ProcessingState.find 'FETCH_CRON_LOCK'

		# Check if another pinw-fetch is running (or is dead/hanging):
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
					puts "Warning: last pinw-fetch cronjob was terminated."
				rescue
					puts "Warning: last pinw-fetch cronjob died unexpectedly (or the system was just restarted)."
				end
			end
		end
		puts 'OK LOCK CRON' if @debug


		# Acquire lock:
		cron_lock.update value: Process.pid
		return cron_lock
	end



	def waited_enough last_retry, retries
		return true unless last_retry and retries
		return Time.now > last_retry + 15 * 4**retries
	end

	def raise_if_not_enough_space filesize: 0, user: nil
		stat = Sys::Filesystem.stat("/")
		free_space = stat.block_size * stat.blocks_available / 1024 / 1024 # MegaBytes

		raise DiskFullError if free_space < 100 #Megabytes
		raise UserFilesizeLimitError if user and user.max_fs < filesize
	end
end




if __FILE__ == $0
	settings = YAML.load(File.read('config/database.yml'))

	force = false
	if ARGV.length > 0 and (ARGV[0] == '-f' or ARGV[0] == '--force')
		force = true
	end

	PinWFetch.new({
		adapter: settings['test']['adapter'],
		database: settings['test']['database'],
		timeout: 30000,
	}, debug: true, force: force).run_main_loop
end

