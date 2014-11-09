require 'sys/filesystem'
require 'active_record'
require 'yaml'
require 'fileutils'
require 'open-uri'

$debug = true

# Load settings:
settings = YAML.load(File.read('config.yml'))


# ActiveRecord::Base.logger = Logger.new(STDERR)
$db_settings = {
  :adapter => settings['database']['adapter'],
  :database => settings['database']['name'],
}

ActiveRecord::Base.establish_connection $db_settings


# Models:
require_relative '../models/users'
require_relative '../models/servers'
require_relative '../models/results'
require_relative '../models/jobs'
require_relative '../models/processing_status'




puts "starting"  if $debug


def main
	# As the function name states,
	cron_lock = check_and_acquire_cron_lock


	# Disk is full, signal the problem to the other processes:
	#ProcessingState.find('DISK_FULL').update value: true


	max_active_downloads = 50
	# Keep looping until all download slots are used or there are no more jobs to process:
	Job.where(awaiting_download: true).find_each do |job|
		break if max_active_downloads < ProcessingState.find('FETCH_ACTIVE_DOWNLOADS').value.to_i

		puts('got a job:', job.id) if $debug

		# Refresh cron lock:
		cron_lock.update value: Process.pid


		## MAIN OPERATIONS ##

		puts 'main operations' if $debug

		# Genomics (fetch if needed, validate, extract gene name):
		no_gene_name_soon = genomics job

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

		# reads job
	end

	# Free the cron lock:
	cron_lock.update value: nil

end

def genomics job
	# Returns a hint for the ensembl function:
	# true if problems have been encountered that 
	# will prevent the process from getting a gene 
	# name soon, false otherwise.

	puts 'genomics started' if $debug

	# Exit if there is nothing to do:
	return false if job.genomics_ok
    genomics_lock_expired = (not job.genomics_pid) or (Time.now > job.genomics_lock + 5 * 60) # 5 minutes
	return (job.gene_name and true) if job.genomics_failed or not genomics_lock_expired

	puts 'past first return wall' if $debug

	# Exit if we need to wait more before attempting again to download:
	return (job.gene_name and true) unless waited_enough job.genomics_last_retry, job.genomics_retries

	puts 'past second' if $debug

	# # Also exit if there is no more free disk space:
	# free_space = Sys::Filesystem.stat("/").block_size * stat.blocks_available / 1024 / 1024 # MegaBytes
	# return (job.gene_name and true) unless free_space > 100
	# ^^ wrong some processing doesnt require disk space

	# Clear lock if needed:
	if job.genomics_pid
		case clear_lock job.genomics_pid
		when :killed
			puts 'killed old genomics'
		when :no_process
			puts 'old genomics died'
		end
	end

	puts 'done with genomics lock' if $debug

	# Close the DB connection (required when forking):
	ActiveRecord::Base.connection.disconnect!

	puts 'forking' if $debug

	# Start the process that will perform the processing:
	spid = Process.fork do 
		puts '[G] inside the process' if $debug

		# Connect to the database:
		ActiveRecord::Base.establish_connection $db_settings


		# Update the db
		job.update({
			genomics_lock: Time.now,
			genomics_retries: job.genomics_retries + 1, # <- safe 
			genomics_last_retry: Time.now,
			genomics_pid: Process.pid
		})

		puts 'updated db' if $debug

		# There are 3 possible cases:

		# we have an URL -> download and check header if not downloading from ensembl
		if job.genomics_url
			puts "[G] URL fetch case for job #{job.id}" if $debug

			# Don't even try if there is no more disk space:
			stat = Sys::Filesystem.stat("/")
			free_space = stat.block_size * stat.blocks_available / 1024 / 1024 # MegaBytes
			
			if free_space < 100 #Megabytes
				# Nothing to do here, release the lock and exit:
				job.update genomics_pid: nil, genomics_retries: job.genomics_retries - 1 # It shoudn't count as a failed retry.		
				exit(0)
			end

			puts '[G] ok, enough disk space' if $debug

			FileUtils.mkpath "downloads/#{job.id}"

			puts '[G] dirs created' if $debug

			begin
				# TODO: encoding, compression, url safety checks
				open(job.genomics_url, 
				  :content_length_proc => lambda {|bytes|
				  	return unless bytes
				  	filesize = bytes / 1024 / 1024 # MegaBytes 

			    	puts '[G] content length test' if $debug

			    	# Check user limits:
			    	if job.user.max_fs < filesize / 1024 / 1024
			    		job.update genomics_failed: true, genomics_pid: nil, genomics_last_error: "File too big for the user."
			    		raise 'user limit'
			    	end

			    	puts '[G] user limit ok' if $debug

			    	# Check system limits:
			    	stat = Sys::Filesystem.stat("/")
					free_space = stat.block_size * stat.blocks_available / 1024 / 1024 # MegaBytes
			    	if free_space - filesize < 100
			    		job.update genomics_failed: true, genomics_pid: nil, genomics_last_error: "Not enough disk space, need #{filesize}MB of space!"
			    		# TODO: add some other type of mechanism
			    		raise 'disk full'
			    	end

			    	puts '[G] ok content length test' if $debug
				  },
				  :progress_proc => lambda {|bytes|
				  	transferred = bytes / 1024 / 1024 # MegaBytes
				   # TODO: update some counter?
					   # Check user limits:
					   if job.user.max_fs < transferred 
					   	job.update genomics_failed: true, genomics_last_error: "File too big for the user."
					   	raise 'user limit'
					   end

					   # Check system limits:
						stat = Sys::Filesystem.stat("/")
						free_space = stat.block_size * stat.blocks_available / 1024 / 1024 # MegaBytes
					   if free_space - transferred < 100
					   	job.update genomics_failed: true, genomics_last_error: "Not enough disk space!"
					   	# TODO: add some other type of mechanism
					   	raise 'disk full'
					   end


					   # Keepalive:
					   if Time.now > job.genomics_lock + 20 # Seconds
					   	job.update genomics_lock: Time.now
					   end
				  },
				  :read_timeout=>10) {|transfer| 

					File.open("downloads/#{job.id}/genomics", 'w') {|f| f.write transfer.read }


				}
						# TODO:      ^^ find better syntax, add separated exception hadnling?
						# TODO: check frame, extract gene_name asap
			rescue URI::InvalidURIError => ex
				puts "[G] invalid url exception"
				job.update genomics_last_error: "Invalid URL", genomics_failed: true, genomics_pid: nil
				job.pid
				exit(0)

			rescue => ex
				puts '[G] dunno exception:', ex.message
				exit(0)
			end

		# A FASTA file was provided by the user and we need to check its headers:
		elsif job.genomics_file
			# TODO: check header, extract gene_name
			puts '[G] checking uploaded file' if $debug



		# We have a gene name and need to do the whole 
		elsif job.gene_name
			# TODO: ensebl
			puts '[G] got gene name, fetching data from ensembl' if $debug

		else raise 'wtf'
		end 

		job.update genomics_ok: true, genomics_pid: nil

		puts '[G] end of subprocess' if $debug

	end
	Process.detach spid

	# Back online:
	ActiveRecord::Base.establish_connection $db_settings

	return false
end


def ensembl job
	# Returns false when the ensembl fetch has already 
	# either failed or succeeded, returns true otherwise.

	puts 'started ensembl transcripts fetch procedure' if $debug

	# Caching the value since it will be used twice:
    ensembl_lock_expired = (not job.ensembl_pid) or (Time.now > job.ensembl_lock + 5 * 60) # 5 minutes

    # Exit if there is nothing to do:
    return false if job.ensembl_ok or job.ensembl_failed or not ensembl_lock_expired

    puts "past first return wall" if $debug

    # Clear lock if needed:
   	if job.ensembl_pid
    	case clear_lock job.ensembl_pid
    	when :killed
    		puts 'ensembl killed'
    	when :no_process
    		puts 'ensembl process died badly'
    	end
    end

    puts 'ok lock ensembl' if $debug

    # Exit if we still need to wait before attempting again the download:
    return true unless waited_enough job.ensembl_last_retry, job.ensembl_retries

    # If we don't have a gene_name we wait a little 
    # and then exit if the situation hasn't changed.
    Process.sleep(5) unless job.gene_name
    job = Job.find job.id
    return true unless job.gene_name


	puts "forking!" if $debug

	# Close the DB connection (required when forking):
	ActiveRecord::Base.connection.disconnect!

	# Spawn the process that will perform the download:
	spid = Process.fork do 

		puts '[E] starded subprocess' if $debug

		# Connect to the database:
		ActiveRecord::Base.establish_connection $db_settings

		# Update the DB with our new pid:
		# job.update ensembl_pid: Process.pid

		job.update({
			ensembl_lock: Time.now,
			ensembl_retries: job.ensembl_retries + 1,
			ensembl_last_retry: Time.now,
			ensembl_pid: Process.pid
		})

		begin
			# Fetch the data:
			# open('http://google.com')		
			job.update ensembl_ok: true, ensembl_pid: nil
		rescue => ex
			puts "[E] failed: #{ex.message}" if $debug
			if job.retries > 5
				job.update ensembl_failed: true, ensembl_pid: nil, ensembl_last_error: "Too many failed retries"
				puts "[E] failed too many times" if $debug
			else
				job.update ensembl_pid: nil, ensembl_last_error: "Failed to fetch data, will retry (reason: #{ex.message})"
				puts "[E] will retry" if $debug
			end
			exit(0)
		end

		puts '[E] end of subprocess' if $debug
	end

	# Detach from the child process:
	Process.detach spid

	# Restablish the database connection:
	ActiveRecord::Base.establish_connection $db_settings

	return true
end


def check_and_acquire_cron_lock
	cron_lock = ProcessingState.find 'FETCH_CRON_LOCK'

	# Check if another pinw-fetch is running (or is dead/hanging):
	puts " Cron lock value: #{cron_lock.value}" if $debug
	if cron_lock.value # nil => last cron completed successfully 
		if cron_lock.updated_at > Time.now - 5 * 60 # 5 minutes
			# The other process is still alive
			puts "Warning: cron running wtf dude"
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
	puts 'OK LOCK CRON' if $debug


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


def waited_enough last_retry, retries
	return true unless last_retry and retries
	return Time.now > last_retry + 15 * 4**retries
end


# Run the main loop:
main

puts 'Script ended' if $debug