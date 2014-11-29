require 'active_record'
require 'yaml'
require 'sys/filesystem'
require 'fileutils'
require 'open-uri'

PROJECT_BASE_PATH ||= File.expand_path('../../', __FILE__) + '/'

# Models:
require PROJECT_BASE_PATH + '/models/base'

# TODO: gene_name_soon
# TODO: optimize writes

# The cron script is defined as a class, 
# which has the following structure:
#
# class PinWFetch
#   def init
#
#   def run_main_loop 
      # loops over jobs and launches `genomics`, 
      # `ensembl` and `reads` for each.
#
#   def genomics
      # either downloads the genomics file from 
      # (ensembl of an user-specified URL) or checks
      # the user-uploaded genomic datafile
#      
#   def ensembl
      # if enabled, downloads annotated transcripts 
      # relative to the job's gene if required
#
#   def reads
      # downloads reads from user-specified URLs
#
#   ... helper methods ...



module DebugFunctionWrapper 
    # This module is used to wrap method calls:
    # all it does is add a tag into the deug_prefix list and
    # remove it after the method returns. 
    # This way we have less debug-related pollution inside the code.
    # Basically it's a poor man's decorator.

    def genomics *args, **kwargs
        @debug_prefixes << "GENOMICS" if @debug
        begin
            return super *args, **kwargs
        ensure
            @debug_prefixes.pop if @debug
        end
    end
    def ensembl *args, **kwargs
        @debug_prefixes << "ENSEMBL" if @debug
        begin
            return super *args, **kwargs
        ensure
            @debug_prefixes.pop if @debug
        end
    end
    def reads *args, **kwargs
        @debug_prefixes << "READS" if @debug
        begin
            return super *args, **kwargs
        ensure
            @debug_prefixes.pop if @debug
        end
    end
end


class PinWFetch
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
        @download_path = download_path
        @debug_prefixes = []

        @lock_timeout = 60 # seconds


        ActiveRecord::Base.logger = Logger.new(STDERR) if @debug
        ActiveRecord::Base.establish_connection @db_settings

        @max_active_downloads = Settings.get_max_active_downloads

    end

    def run_main_loop
        debug 'BEGIN MAIN LOOP'

        # As the function name states,
        cron_lock = check_and_acquire_cron_lock
        debug 'CRON LOCK OK'


        # Loop over all jobs awaiting for download/preprocessing:
        Job.where(awaiting_download: true).each do |job|
        	@debug_prefixes << "J:#{job.id}" if @debug
	        # NOTE: trick to be able to use find_each?
          	debug 'BEGIN JOB LOOP'

            # Refresh cron lock:
            cron_lock.update value: Process.pid


            ## MAIN OPERATIONS ##

            # Genomics (fetch if needed, validate, extract gene name):
            no_gene_name_soon = genomics job
            debug "GENOMICS RETURNED #{no_gene_name_soon}"

            # Currently disabled because we don't have to fetch
            # anything from ensembl unless we have both organism
            # and gene_name defined.
            # When support for extracting similar informations
            # from the genomics file header, this approach will
            # prove useful.
            #
            # # Fetch the required metadata from Ensembl:
            # ensembl job unless no_gene_name_soon
            # debug 'DONE ENSEMBL' unless no_gene_name_soon
            #     # To get the metadata from Ensembl we need a gene name.
            #     # We might either already have it or not.
            #     # The second case happens when the user provides his own 
            #     # FASTA file via URL download (ergo by not uploading it 
            #     # directly).
            #     # If the genomics process encountered problems we might
            #     # not have a gene name soon (retry timeouts, full disk, ...).
            #     # If this is not the case, the ensembl process will even try 
            #     # to wait a little more (sleep 5) before giving up, in case 
            #     # the FASTA file is being downloaded at the same time (the 
            #     # genomics process will try to extract the gene name from 
            #     # the file while it's downloading by checking the first 
            #     # frame of the HTTP response's body (also useful to prevent
            #     # unecessary downloads)). 

            ensembl job 
            debug 'DONE ENSEMBL' 

            reads job
            debug 'DONE READS AND DONE PROCESSING JOB'

            @debug_prefixes.pop if @debug
        end

        # Free the cron lock:
        cron_lock.update value: nil
    end

    def genomics job, async: true
        # Returns a hint for the ensembl function:
        # true if problems have been encountered that 
        # will prevent the process from getting a gene 
        # name soon, false otherwise.
        debug 'genomics started'

        # Exit if there is nothing to do or a lock is still in place:
        return if job.genomics_ok or job.genomics_failed or (job.genomics_pid and (Time.now < job.genomics_lock + @lock_timeout))
        debug 'not `ok` not `failed`, not locked, proceeding'

        # Exit if we need to wait more before attempting again to download:
        return unless waited_enough job.genomics_last_retry, job.genomics_retries
        debug 'past second'

        # Clear lock if needed:
        Process.kill 9, job.genomics_pid if job.genomics_pid
        debug 'there was a stale pid, killed' if job.genomics_pid

        # The function that does the actual work:
        # (it is either executed either in a different process
        #  or sequentially if `async` is set to false)
        launch lambda {
            begin
                debug '###### GENOMICS MAIN WORK PROCESS ######'

                # Grab the lock:
                job.update({
                    genomics_lock: Time.now,
                    genomics_retries: job.genomics_retries + 1, # <- safe 
                    genomics_last_retry: Time.now,
                    genomics_pid: Process.pid
                })

                debug "GRABBED LOCK"


                genomics_filepath = @download_path + "#{job.id}/genomics.fasta"

                # There are 3 possible cases:

                # We must download the genomic data from Ensembl:
                if job.genomics_ensembl
                    debug "CASE: Fetch genomics from ensembl"

                    debug "TODO: perform the actual genomics download from ensembl"
                    raise NotImplementedError

                # We must download the genomic data from an URL -> download and check header
                elsif job.genomics_url
                    debug "CASE: Fetch genomics from URL"
                    
                    # Don't even try if there is no disk space:
                    raise_if_not_enough_space

                   
                    # Make sure the path exists:
                    FileUtils.mkpath @download_path + "#{job.id}"
                    debug "created path: #{genomics_filepath}"

                    # Test that the URL is valid and that is either http/ftp
                    # especially because it seems that open() can also take 
                    # interal path references, which is a security violation.
                    unless job.genomics_url.start_with?('http', 'https', 'ftp') and job.genomics_url =~ /\A#{URI::regexp}\z/
                        raise URI::InvalidURIError 
                    end


                    # TODO: encoding, compression, url safety checks
                    open(job.genomics_url, 
                    :content_length_proc => lambda {|bytes|
                        debug "called content length proc with value #{bytes} (bytes)"
                        return unless bytes
                        filesize = bytes / 1024.0 / 1024.0 # MegaBytes 

                        # Check disk and user limits:
                        raise_if_not_enough_space filesize: filesize, user: job.user
                        debug 'ok file content length'
                    },

                    :progress_proc => lambda {|bytes|
                        debug "called progress proc with value #{bytes} (bytes)"
                        transferred = bytes / 1024.0 / 1024.0 # MegaBytes
                        # TODO: update some counter?
                        # Check disk and user limits:
                        raise_if_not_enough_space filesize: transferred, user: job.user

                        # Keepalive:
                        if Time.now > job.genomics_lock + 30 # Seconds
                            job.update genomics_lock: Time.now
                        end
                    },

                    :read_timeout=>10) do |transfer|
                        header = transfer.readline
                        # TODO?: extract gene_name asap

                        raise BadFASTAHeaderError unless header =~ job.header_regex
                        debug 'header is ok'
                        
                        debug 'writing file'
                        File.open(genomics_filepath, 'w') do |f| 
                            f.write header
                            f.write transfer.read 
                        end
                        debug 'file written'
                    end

                # A FASTA file was provided by the user and we need to check its headers:
                else 
                    debug 'CASE: We have a genomics file and need to check it'

                    begin
                        header = File.open(genomics_filepath, 'r').readline 
                    rescue => ex
                        debug "error: #{ex.message} #{ex.inspect}"
                        raise InvalidJobStateError
                    end
                    debug "header is: #{header}"

                    raise BadFASTAHeaderError unless header =~ job.header_regex
                    debug 'header ok'
                end 

                job.update genomics_ok: true
                debug '### OK! ###'

                # Check if job is ready to be dispatched 
                # and/or taken out of the download queue:

                job = Job.find(job.id)


                if job.all_reads_ok
                    to_update = {awaiting_dispatch: true} 
                    # all updates must be "toggle-only"! (no rewrite to confirm)
                    debug '#### PUSHING THE JOB TO THE DISPATCH QUEUE #####'

                    if job.ensembl_ok
                        to_update[:awaiting_download] = false 
                        to_update[:downloads_completed_at] = Time.now
                        debug '#### REMOVING THE JOB FROM DOWNLOAD QUEUE #####'
                    end 

                    job.update **to_update
                end 

            rescue InvalidJobStateError
                debug "the job is missing the necessary genomic data info"
                job.update genomics_failed: true, genomics_last_error: "Bad job state: nowhere to get the genomics data."

            # rescue Errno::ENOENT # File not found
            #     debug 'cannot find the genomics file'
            #     job.update genomics_failed: true, genomics_last_error: "Missing genomics file!"

            rescue BadFASTAHeaderError
                debug 'the genomics file has a bad header!'
                job.update genomics_failed: true, genomics_last_error: "Genomics file doesn't have the required header format."
            
            rescue DiskFullError
                debug 'disk full!'
                job.update genomics_retries: 3, genomics_last_error: "Disk full!"
                #          ^^^^^^^^^^^^^^^^ Try again in ~15 minutes.

            rescue UserFilesizeLimitError
                debug 'this file exceedes the user filesize limits'
                job.update genomics_failed: true, genomics_last_error: "Filesize exceedes user limits."

            rescue URI::InvalidURIError
                debug 'invalid URL'
                job.update genomics_failed: true, genomics_last_error: "Invalid URL"

            rescue OpenURI::HTTPError => ex
                debug "HTTP Error: #{ex.message}"
                job.update genomics_failed: true, genomics_last_error: "HTTP Error #{ex.message}."

            rescue => ex
                debug "unhandled error: #{ex.message}"
                job.update genomics_failed: true, genomics_last_error: "Unhandled error #{ex.message}."

            ensure
                job.update genomics_pid: nil
                debug '###### END OF MAIN GENOMICS WORK ######'
            end
        }, async: async

    end


    def ensembl job, async: true
        # Returns false when the ensembl fetch has already 
        # either failed or succeeded, returns true otherwise.
        debug 'ensembl started'

        # Exit if there is nothing to do:
        return false if job.ensembl_ok or job.ensembl_failed or (job.ensembl_pid and (Time.now < job.ensembl_lock + @lock_timeout)) # 60s
        debug 'not `ok` not `failed`, not locked, proceeding'


        # Exit if we still need to wait before attempting again the download:
        return true unless waited_enough job.ensembl_last_retry, job.ensembl_retries
        debug 'waited enough since last failure, proceeding' if job.ensembl_retries > 0


            # # The following block is commented as that is a feature currently
            # # not implemented. Consult the related comment in PinWFetch.run_main_loop
            # # for more information.
            #     # If we don't have a gene_name we wait a little 
            #     # and then exit if the situation hasn't changed.
            #     sleep(5) unless job.gene_name
           
        
        
        # Clear lock if needed:
        if job.ensembl_pid
            Process.kill 9, job.ensembl_pid
            debug 'stale pid found, killed old process'
        end

        # The function that does the actual work:
        # (it will be either executed in a different process
        # or executed sequentially if `async` is set to false)
        launch lambda { 
            begin
                debug '###### ENSEMBL MAIN WORK PROCESS ######'

                # Update the DB with our new pid:
                job.update({
                    ensembl_lock: Time.now,
                    ensembl_retries: job.ensembl_retries + 1, # <- safe
                    ensembl_last_retry: Time.now,
                    ensembl_pid: Process.pid
                })

                raise InvalidJobStateError unless job.gene_name and job.organism_name

                # Fetch the data:

                # TODO: ENSEMBL API     

                job.update ensembl_ok: true
                debug '### OK ###'

                job = Job.find(job.id)

                # Remove from download queue if all downloads are complete:
                if job.all_reads_ok and job.genomics_ok
                    job.update awaiting_download: false, downloads_completed_at: Time.now
                    debug '#### REMOVING THE JOB FROM DOWNLOAD QUEUE #####'
                end

            rescue InvalidJobStateError
                debug 'must fetch ensembl but the required data is missing'
                job.update ensembl_failed: true, ensembl_last_error: "Missing gene name and/or organism name, which are required to fetch annotated transcripts from ensembl."

            rescue => ex
                debug "fetch failed: #{ex.message}"
                if job.ensembl_retries > 5
                    job.update ensembl_failed: true, ensembl_last_error: "Too many failed retries"
                    debug '### PERMANENT FAILURE (too many failures) ###'
                else
                    job.update ensembl_last_error: "Failed to fetch data, will retry (reason: #{ex.message})"
                    debug 'will retry'
                end
            ensure
                job.update ensembl_pid: nil
                debug '###### END OF MAIN ENSEMBL WORK ######'
            end
        }, async: async

        return true
    end


    def reads job, async: true
        debug 'reads started'

        # Exit if there is nothing to do:
        return false if job.all_reads_ok or job.some_reads_failed

        # Check state of downloadable URLs, if any:
        reads_list = JobRead.where(job_id: job.id, ok: false, failed: false)

        # Exit if there are no reads to download
        return false unless reads_list 

        debug 'past main return walls'

        reads_list.each do |reads|
            @debug_prefixes << "R:#{reads.id}"
            debug 'begin read management'

            # Skip to the next loop if there is nothing to do:
            next if reads.pid and Time.now < reads.lock + @lock_timeout # 60s
            debug 'read is not locked'

            # Exit if we have maxed-out download slots mid-cycle:
            break if @max_active_downloads < ProcessingState.get_active_downloads.count
            debug 'we have slots!'

            # Clear lock if needed:
            if job.ensembl_pid
                Process.kill 9, job.ensembl_pid
                debug 'stale pid found, killed'
            end

            # Skip to the next loop if we still need to wait before attempting again the download:
            next unless waited_enough reads.last_retry, reads.retries
            debug 'we do not have to wait, proceeding'
            

            # The function that does the actual work:
            # (it will be either executed in a different process
            # or executed sequentially if `async` is set to false)
            launch lambda {
                begin
                    debug '###### READS MAIN WORK PROCESS ######'

                    # Update the DB:
                    read.update({
                        lock: Time.now,
                        retries: reads.retries + 1, # <- safe
                        last_retry: Time.now,
                        pid: Process.pid
                    })
                    ProcessingState.add_active_download(reads.url)
                    debug "db updated!"


                    # Don't even try if there is no more disk space:
                    raise_if_not_enough_space
                    debug "we have enough disk space, proceed"

                    # Make sure the download path exists:
                    reads_path = PROJECT_BASE_PATH + "downloads/#{job.id}/reads/"
                    FileUtils.mkpath reads_path
                    debug "created reads download path: #{reads_path}"


                    # TODO: compression 

                    # Test that the URL is valid and that is either http/ftp
                    # especially because it seems that open() can also take 
                    # interal path references, which is a security violation.
                    unless reads.url.start_with?('http', 'https', 'ftp') and reads.url =~ /\A#{URI::regexp}\z/
                        raise URI::InvalidURIError 
                    end

                    # Fetch the data:
                    open(reads.url, 
                    :content_length_proc => lambda {|bytes|
                        debug "called content_length_proc with value: #{bytes}"

                        return unless bytes
                        filesize = bytes / 1024.0 / 1024.0 # MegaBytes 

                        # Check disk and user limits:
                        raise_if_not_enough_space filesize: filesize, user: job.user
                        debug 'pased space limit test'
                    },
                    :progress_proc => lambda {|bytes|
                        debug "called progress_proc with value: #{bytes}"

                        transferred = bytes / 1024.0 / 1024.0 # MegaBytes
                        
                        # TODO: update some counter?
                        # TODO: fix counting problems?

                        # Check disk and user limits:
                        raise_if_not_enough_space filesize: filesize, user: job.user
                        debug 'pased space limit test'
                       
                        # Keepalive:
                        job.update genomics_lock: Time.now if Time.now > reads.lock + 20 # Seconds
                    },
                    :read_timeout=>10) do |transfer| 
                        #first_char = transfer.getc
                        
                        File.open(reads_path + "reads-#{reads.id}", 'w') do |f| 
                            #f.write first_char
                            f.write transfer.read 
                        end
                    end   

                    reads.update ok: true
                    debug '### OK ###'

                    # Check if all downloads are done and update the job:
                    remaining_reads = JobRead.find_by(job_id: job.id).not(ok: true)
                    job.update(all_reads_ok: true) if not remaining_reads
                    debug 'all reads ok!' if not remaining_reads

                    job = Job.find(job.id)

                    # Move forward the job if necessary
                    if job.genomics_ok
                        to_update = {awaiting_dispatch: true}
                        debug '#### PUSHING THE JOB TO THE DISPATCH QUEUE #####'
                        if job.ensembl_ok
                            to_update[:awaiting_download] = false
                            to_update[:downloads_completed_at] = Time.now
                            debug '#### REMOVING THE JOB FROM DOWNLOAD QUEUE #####'
                        end
                        job.update **to_update
                    end

                rescue DiskFullError
                    debug 'disk is full'
                    reads.update retries: 3, genomics_last_error: "Disk full!"
                    #            ^^^^^^^^ Try again in ~15 minutes.
                    # job.update some_reads_failed: false, reads_last_error: "Disk full!"

                rescue UserFilesizeLimitError
                    debug 'file exceedes user limits'
                    reads.update failed: true, last_error: "Filesize exceedes user limits."
                    job.update some_reads_failed: true, reads_last_error: "##{reads.id} exceedes user limits."

                rescue URI::InvalidURIError
                    debug 'invalid uri'
                    reads.update failed: true, last_error: "Invalid URL"
                    job.update some_reads_failed: true, reads_last_error: "##{reads.id} has an invalid URL."

                rescue BadFASTAHeaderError
                    debug 'bad fasta header'
                    reads.update failed: true, last_error: "Bad FASTA header"
                    job.update some_reads_failed: true, reads_last_error: "##{reads.id} has an invalid FASTA header."

                rescue => ex
                    debug "unhandled error: #{ex.message}"
                    reads.update failed: true, last_error: "Unhandled error: #{ex.message}."
                    job.update some_reads_failed: true, reads_last_error: "##{reads.id} unhandled error: #{ex.message}."

                ensure
                    reads.update pid: nil
                    ProcessingState.remove_active_download(reads.url)
                    debug '###### END OF MAIN READS WORK ######'
                end
            }, async: async
        end
        return reads_list.length > 0
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
        cron_lock = ProcessingState.find 'FETCH_CRON_LOCK'

        # Check if another pinw-fetch is running (or is dead/hanging):
        debug " Cron lock value: #{cron_lock.value}"
        if cron_lock.value # nil => last cron completed successfully 
            if (not @force) and Time.now < cron_lock.updated_at + @lock_timeout # 60s
                # The other process is still alive
                debug "Warning: older cron insance still running, aborting current execution."
                Process.exit(0)
            else
                # The other instance is either hanging or dead
                Process.kill 9, cron_lock.value
                debug "Warning: last pinw-fetch cronjob was terminated."
            end
        end

        # Acquire lock:
        cron_lock.update value: Process.pid
        return cron_lock
    end



    def waited_enough last_retry, retries
        return true unless last_retry and retries
        return Time.now > last_retry + 15 * 4**retries
    end

    def raise_if_not_enough_space filesize: 0, user: nil
        debug "called disk space check with params: #{filesize} | #{user}"
        stat = Sys::Filesystem.stat("/")
        free_space = stat.block_size * stat.blocks_available / 1024.0 / 1024.0 # MegaBytes

        raise DiskFullError if free_space < 100 #Megabytes
        raise UserFilesizeLimitError if user and user.max_fs < filesize
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

    PinWFetch.new({
        adapter: settings['test']['adapter'],
        database: PROJECT_BASE_PATH + settings['test']['database'],
        timeout: 30000,
    }, debug: debug, force: force).run_main_loop
end

