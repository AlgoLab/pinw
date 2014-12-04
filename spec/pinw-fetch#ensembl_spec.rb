require 'fileutils'
require_relative '../cron/pinw-fetch'


`rake db:reset`

settings = YAML.load(File.read(PROJECT_BASE_PATH + 'config/database.yml'))
myFetch = PinWFetch.new({
      adapter: settings['test']['adapter'],
      database: PROJECT_BASE_PATH + settings['test']['database'],
      timeout: 30000
}, debug: !!(ENV['PINW_RSPEC_VERBOSE']), force: false, download_path: PROJECT_BASE_PATH + 'test_temp/downloads/')


describe PinWFetch, "#ensembl" do
    before(:all) {FileUtils.rm_rf(PROJECT_BASE_PATH + 'test_temp/downloads/')}
    after(:all) {FileUtils.rm_rf(PROJECT_BASE_PATH + 'test_temp/downloads/')}
    
    before(:each) {@job = Job.create quality_threshold: 33}

    it "does not process jobs with ensembl_ok: true (##{__LINE__})" do
        @job.update ensembl_ok: true

        result = myFetch.ensembl @job, async: false
        expect(Job.find(@job.id).ensembl_lock).to eq Time.at(0)
    end

    it "does not process jobs with ensembl_failed: true (##{__LINE__})" do
        @job.update ensembl_ok: false, gene_name: "job-#{@job.id}", ensembl_failed: true 

        result = myFetch.ensembl @job, async: false
        expect(Job.find(@job.id).ensembl_lock).to eq Time.at(0)
    end

    it "does not process failed ensembl jobs (##{__LINE__})" do
        @job.update ensembl_ok: false, ensembl_failed: true 

        result = myFetch.ensembl @job, async: false
        expect(Job.find(@job.id).ensembl_lock).to eq Time.at(0)
    end

    it "does not process locked ensembl jobs (##{__LINE__})" do
        spid = Process.fork {sleep 10}
        mylock = Time.now + 100 * 60
        @job.update({
            ensembl_ok: false, 
            gene_name: "job-#{@job.id}", 
            ensembl_failed: false, 
            ensembl_pid: spid, 
            ensembl_lock: mylock
        })

        result = myFetch.ensembl @job, async: false
        expect(Job.find(@job.id).ensembl_lock).to eq mylock
    end

    it "does not process jobs which hasn't waited enough (##{__LINE__})" do
        @job.update ({
            ensembl_ok: false, 
            gene_name: "job-#{@job.id}", 
            ensembl_failed: false, 
            ensembl_last_retry: Time.now - 8,
            ensembl_retries: 1
        })

        result = myFetch.ensembl @job, async: false
        expect(Job.find(@job.id).ensembl_lock).to eq Time.at(0)
    end

    it "does not process jobs which has waited enough with spid (##{__LINE__})" do
        spid = Process.fork {sleep 10}
        @job.update ({
            ensembl_ok: false, 
            gene_name: "job-#{@job.id}", 
            ensembl_failed: false, 
            ensembl_pid: spid, 
            ensembl_last_retry: Time.now - 8000,
            ensembl_retries: 1
        })

        result = myFetch.ensembl @job, async: false
        expect(Job.find(@job.id).ensembl_lock).not_to eq Time.at(0)
        expect(Job.find(@job.id).ensembl_pid).not_to eq spid
    end

    it "does not process jobs which hasn't gene name (##{__LINE__})" do
        @job.update ({
            ensembl_ok: false, 
            organism_name: "human", 
            ensembl_failed: false
        })

        result = myFetch.ensembl @job, async: false
        expect(Job.find(@job.id).ensembl_failed).to eq true
        expect(Job.find(@job.id).ensembl_last_error).to eq "Missing gene name and/or organism name, which are required to fetch annotated transcripts from ensembl."
    end

    it "does not process jobs which hasn't organism name (##{__LINE__})" do
        @job.update ({
            ensembl_ok: false, 
            gene_name: "job-#{@job.id}",
            ensembl_failed: false
        })

        result = myFetch.ensembl @job, async: false
        expect(Job.find(@job.id).ensembl_failed).to eq true
        expect(Job.find(@job.id).ensembl_last_error).to eq "Missing gene name and/or organism name, which are required to fetch annotated transcripts from ensembl."
    end

    it "does not process jobs which hasn't neither gene name nor organism name (##{__LINE__})" do
        @job.update ({
            ensembl_ok: false, 
            ensembl_failed: false
        })

        result = myFetch.ensembl @job, async: false
        expect(Job.find(@job.id).ensembl_failed).to eq true
        expect(Job.find(@job.id).ensembl_last_error).to eq "Missing gene name and/or organism name, which are required to fetch annotated transcripts from ensembl."
    end

    it "does check for completed reads (##{__LINE__})" do
        @job.update ({
            ensembl_ok: false, 
            gene_name: "job-#{@job.id}",
            organism_name: "human", 
            ensembl_failed: false,
            genomics_ok: true,
            all_reads_ok: true
        })

        result = myFetch.ensembl @job, async: false
        expect(Job.find(@job.id).awaiting_download).to eq false
        expect(Job.find(@job.id).downloads_completed_at).not_to eq nil
    end

end
