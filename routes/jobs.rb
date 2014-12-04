# encoding: utf-8
require "sinatra/json"
require 'fileutils'
require 'sys/filesystem'


class PinW < Sinatra::Application
	class TooManyJobsError < RuntimeError; end
	class GenomicsCombinationError < RuntimeError; end
	class GeneSourceTypeError < RuntimeError; end
	class JobValidationError < RuntimeError; end
	class ReadURLError < RuntimeError; end
	class DiskFullError < RuntimeError; end
	class DiskUserLimitError < RuntimeError; end
	class NoReadsError < RuntimeError; end
	class TooManyReads < RuntimeError; end
	class InvalidServerId < RuntimeError; end
	
    # Auth checks:
    before '/jobs/*' do
        halt "must be logged in to access the job panel" unless session[:user]
        current_user = User.find(session[:user].id) # blargh
        unless current_user.enabled
            session[:user] = nil
            halt "account disabled"
        end
        session[:user] = current_user
    end

    get '/jobs/active/?' do
        job_list = Job.all.to_a
        server_list = Server.all.to_a
        erb :'jobs/active', :locals => {:job_list => job_list, :server_list => server_list}
    end

    post '/jobs/new' do
    	begin 
    		all_went_ok = false
	        job = Job.new awaiting_download: true

    		unless session[:user].max_ql < 0
    			puts Job.where(user_id: session[:user].id).count
    			if Job.where(user_id: session[:user].id).count >= session[:user].max_ql
    				raise TooManyJobsError
    			end
    		end

	        job.user_id = session[:user].id
	        if session[:user].admin and params[:InputServer]
	            job.server_id = params[:InputServer]
	            begin
	            	Server.find(params[:InputServer])
	            rescue ActiveRecord::RecordNotFound
	            	raise InvalidServerId
	            end 
	        end
	        
	        job.organism_name = params[:InputOrganism] unless params[:InputOrganismUnknown]
	        job.gene_name = params[:InputGeneName] unless params[:InputGeneNameUnknown]

	        # If we don't have to fetch the ensembl data, we set the `ensembl_ok` flag to true.
	        job.ensembl_ok = !(params[:InputTranscripts] and params[:InputOrganism] and !params[:InputOrganismUnknown] and params[:InputGeneName] and !params[:InputGeneNameUnknown])


	        # 1 -> Fetch genomics from ensembl
	        # 2 -> Fetch genomics from URL
	        # 3 -> Genomics file uploaded by the user
	        case params[:type]
	        when '1'
	        	raise GenomicsCombinationError unless params[:InputOrganism] and !params[:InputOrganismUnknown] and params[:InputGeneName] and !params[:InputGeneNameUnknown]
	            job.genomics_ensembl = true
	        when '2'
	            job.genomics_url = params[:InputGeneURL]
	        when '3'
	            # File will be saved once the job is created
	        else 
	        	raise GeneSourceTypeError
	        end

	   		# Validated by the model:
	        job.quality_threshold = params[:InputQuality]
	        job.description = params[:InputDescription]

	        # Die unless the job is valid:
	        raise JobValidationError unless job.valid?

	        # Die if too many reads:
	        raise TooManyReads if params[:InputURLs] and params[:InputURLs].length > settings.max_reads_urls
	        raise TooManyReads if params[:InputFiles] and params[:InputFiles].length > settings.max_reads_uploads

	        # URL READS #
	        reads_urls = []
	        if params[:InputURLs]
	        	params[:InputURLs].each do |url|
	        		new_jobread = JobRead.new url: url
	       			raise ReadURLError unless new_jobread.valid?
	       			reads_urls << new_jobread
	        	end
	        end


	        # DISKSPACE LIMIT TESTS #
	        will_occupy = 0
	        will_occupy += params[:InputGeneFile].length if params[:type] == '3'
     		params[:InputFiles].each_with_index {|read_file| will_occupy += read_file.length} if params[:InputFiles]

     		if will_occupy > 0
		        stat = Sys::Filesystem.stat("/")
		        free_space = stat.block_size * stat.blocks_available / 1024.0 / 1024.0 # MegaBytes
		        raise DiskFullError if free_space - will_occupy < 100 #Megabytes
		        unless session[:user].max_fs < 0
		        	raise  DiskUserLimitError if session[:user].max_fs < will_occupy 
		        end
		    end

		    raise NoReadsError unless (params[:InputURLs] and params[:InputURLs].length > 0) or (params[:InputFiles] and params[:InputFiles].length > 0)

	        # SAVE FOR REAL #
	        Job.transaction do
	            job.save
	            reads_urls.each do |reads|
	            	reads.job_id = job.id
	            	reads.save
	            end

    	        # Pepare the folder structure
                FileUtils.mkpath settings.download_path + "#{job.id}/reads/"

            	# SAVE FILES #
            	if params[:type] == '3'
                    File.open(settings.download_path + "#{job.id}/genomics.fasta", 'w') {|f| f.write params[:InputGeneFile]}
                end

                if params[:InputFiles]
                	params[:InputFiles].each_with_index do |read_file, index|
        	            File.open(settings.download_path + "#{job.id}/reads/reads-upload-#{index}", 'w') {|f| f.write read_file}
                	end
                end
	        end

	        all_went_ok = true
	        redirect to '/jobs/active'

	    rescue TooManyJobsError 
	    	puts "Too many jobs!"
	    	redirect to '/jobs/active?err=1'

	    rescue GenomicsCombinationError 
	    	puts "Genomics combination error!"
	    	redirect to '/jobs/active?err=2'

	    rescue GeneSourceTypeError 
	    	puts "Genetics source type error!"
	    	redirect to '/jobs/active?err=3'

	    rescue JobValidationError 
	    	puts "Job failed to validate"
	    	redirect to '/jobs/active?err=4'

	    rescue ReadURLError 
	    	puts "A read has an invalid URL!"
	    	redirect to '/jobs/active?err=5'

	    rescue DiskFullError 
	    	puts "Disk Full!"
	    	redirect to '/jobs/active?err=6'

	    rescue DiskUserLimitError 
	    	puts "Filesize bigger than user limits!"
	    	redirect to '/jobs/active?err=7'

	    rescue NoReadsError 
	    	puts "There are no reads!"
	    	redirect to '/jobs/active?err=8'

	    rescue TooManyReads
	    	puts "Too many reads"
	    	redirect to '/jobs/active?err=9'

	    rescue InvalidServerId
	    	puts "Invalid Server"
	    	redirect to '/jobs/active?err=10'	    	

	    rescue => ex
	    	puts "Generic error! #{ex.message} #{ex.inspect} {{#{job.inspect}}} <<#{job.errors.messages}>>"

	        redirect to '/jobs/active?err=11'

	    ensure
	    	# Perform cleanup if failed:
	    	unless all_went_ok
	    		FileUtils.rm_rf settings.download_path + "#{job.id}" if job.id
	    	end
	    end
    end

    get '/jobs/complete/?' do

        erb :'jobs/complete'
    end

    get '/jobs/update' do
        jobs_state = []
        session[:user].jobs(true).each do |job|
            jobs_state << {
                id: job.id,

                gene_name: job.gene_name,
                description: job.description,

                ensembl_ok: job.ensembl_ok,
                ensembl_failed: job.ensembl_failed,
                ensembl_last_error: job.ensembl_last_error,

                genomics_ok: job.genomics_ok,
                genomics_failed: job.genomics_failed,
                genomics_last_error: job.genomics_last_error,

                all_reads_ok: job.all_reads_ok,
                some_reads_failed: job.some_reads_failed,
                reads_last_error: job.reads_last_error,

                reads_total: JobRead.where(job_id: job.id).count,
                reads_done: JobRead.where(job_id: job.id, ok: true).count,


                current_time: Time.now
            }
        end

        puts jobs_state

        json({success: true, jobs: jobs_state})
    end
end