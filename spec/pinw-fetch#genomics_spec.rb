require 'fileutils'
require_relative '../cron/pinw-fetch'


settings = YAML.load(File.read(PROJECT_BASE_PATH + 'config/database.yml'))
myFetch = PinWFetch.new({
      adapter: settings['test']['adapter'],
      database: PROJECT_BASE_PATH + settings['test']['database'],
      timeout: 30000
}, debug: !!(ENV['PINW_RSPEC_VERBOSE']), force: false, download_path: PROJECT_BASE_PATH + 'test_temp/downloads/')


describe PinWFetch, "#genomics" do
    before(:all) {FileUtils.rm_rf(PROJECT_BASE_PATH + 'test_temp/downloads/')}
    after(:all) {FileUtils.rm_rf(PROJECT_BASE_PATH + 'test_temp/downloads/')}
    
    before(:each) {@job = Job.create}

    it "does not process jobs with genomics_ok: true (##{__LINE__})" do
        @job.update genomics_ok: true, gene_name: "test-update-from-line-#{__LINE__}"

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_lock).to eq Time.at(0)
    end

    it "does not process jobs with genomics_failed: true (##{__LINE__})" do
        @job.update genomics_ok: false, gene_name: "test-update-from-line-#{__LINE__}", genomics_failed: true 

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_lock).to eq Time.at(0)
    end


    it "does not process locked genomics jobs (##{__LINE__})" do
        spid = Process.fork {sleep 10}
        mylock = Time.now + 100 * 60
        @job.update({
            genomics_ok: false, 
            gene_name: "test-update-from-line-#{__LINE__}", 
            genomics_failed: false, 
            genomics_pid: spid, 
            genomics_lock: mylock
        })

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_lock).to eq mylock
    end

    it "does not process jobs still in retry cooldown (##{__LINE__})" do
        @job.update ({
            genomics_ok: false, 
            gene_name: "test-update-from-line-#{__LINE__}", 
            genomics_failed: false, 
            genomics_last_retry: Time.now - 8,
            genomics_retries: 3
        })

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_lock).to eq Time.at(0)
    end

    it "does process jobs for which has waited enough with name since last retry (##{__LINE__})" do
        @job.update ({
            genomics_ok: false, 
            gene_name: "test-update-from-line-#{__LINE__}", 
            genomics_failed: false, 
            genomics_last_retry: Time.now - 8000,
            genomics_retries: 1
        })

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_lock).not_to eq Time.at(0)
    end

    it "does process jobs for which the lock has expired (##{__LINE__})" do
        spid = Process.fork {sleep 100}
        mylock = Time.now - 100 * 60
        @job.update ({
            genomics_ok: false, 
            gene_name: "test-update-from-line-#{__LINE__}", 
            genomics_failed: false, 
            genomics_pid: spid, 
            genomics_lock: mylock
        })

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_pid).not_to eq spid
    end

  # fetch URL

    it "fails genomics for jobs with a bad URL (##{__LINE__})" do
        bad_url = 'ht?tp://www.sgrugolf..com/badfile.txt'
        @job.update genomics_ok: false, gene_name: "test-update-from-line-#{__LINE__}", genomics_url: bad_url

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_failed).to eq true
        expect(Job.find(@job.id).genomics_last_error).to eq "Invalid URL"
    end

    it "fails genomics for jobs with a 404 URL (##{__LINE__})" do
        url_404 = 'https://raw.githubusercontent.com/AlgoLab/PIntron/master/dist-docs/example/genomic_x.txt'
        @job.update genomics_ok: false, gene_name: "test-update-from-line-#{__LINE__}", genomics_url: url_404

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_failed).to eq true
        expect(Job.find(@job.id).genomics_last_error).to eq "HTTP Error 404 Not Found."
    end

    it "fails genomics for jobs with URL pointing to an unexisting host (##{__LINE__})" do
        @job.update genomics_ok: false, gene_name: "test-update-from-line-#{__LINE__}", genomics_url: 'http://notexists.notexists123123123.com'

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_failed).to eq true
        expect(Job.find(@job.id).genomics_last_error).not_to eq nil
    end

    it "fails genomics for jobs with an URL pointing to a file with a bad fasta header (##{__LINE__})" do
        bad_header_url = 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_badheader.fasta'
        @job.update genomics_ok: false, gene_name: "test-update-from-line-#{__LINE__}", genomics_url: bad_header_url

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_failed).to eq true
        expect(Job.find(@job.id).genomics_last_error).to eq "Genomics file doesn't have the required header format."
    end

    # it "fails genomics for jobs with an URL pointing to a file with a missing fasta body (##{__LINE__})" do
    #     bad_body_url = 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_headonly.fasta'
    #     @job.update genomics_ok: false, gene_name: "test-update-from-line-#{__LINE__}", genomics_url: bad_body_url

    #     result = myFetch.genomics @job, async: false
    #     expect(Job.find(@job.id).genomics_failed).to eq true
    #     expect(Job.find(@job.id).genomics_last_error).to eq "No file found"
    # end

    it "does process correctly a job with a valid genomics URL (##{__LINE__})" do
        ok_url = 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_ok.fasta'
        @job.update genomics_ok: false, gene_name: "test-update-from-line-#{__LINE__}", genomics_url: ok_url

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_ok).to eq true
    end

      # fetch file

    it "fails genomics for jobs with no valid genomics source (##{__LINE__})" do
        @job.update genomics_ok: false, gene_name: "test-update-from-line-#{__LINE__}"

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_failed).to eq true
        expect(Job.find(@job.id).genomics_last_error).to eq "Bad job state: nowhere to get the genomics data."
    end

    it "fails genomics for jobs with an directly uploaded file with a bad fasta header (##{__LINE__})" do
        @job.update genomics_ok: false, gene_name: "test-update-from-line-#{__LINE__}"
        FileUtils.mkpath PROJECT_BASE_PATH + "test_temp/downloads/#{@job.id}/"
        FileUtils.cp(PROJECT_BASE_PATH + 'spec/test_files/genomic_badheader.fasta', PROJECT_BASE_PATH + "test_temp/downloads/#{@job.id}/genomics.fasta")

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_failed).to eq true
        expect(Job.find(@job.id).genomics_last_error).to eq "Genomics file doesn't have the required header format."
    end

    # it "fails genomics for jobs with an directly uploaded file which is missing the body (##{__LINE__})" do
    #     @job.update genomics_ok: false, gene_name: "test-update-from-line-#{__LINE__}"
    #     FileUtils.mkpath PROJECT_BASE_PATH + "test_temp/downloads/#{@job.id}/"
    #     FileUtils.cp(PROJECT_BASE_PATH + 'spec/test_files/genomic_headonly.fasta', PROJECT_BASE_PATH + "test_temp/downloads/#{@job.id}/genomics.fasta")

    #     result = myFetch.genomics @job, async: false
    #     expect(Job.find(@job.id).genomics_failed).to eq true
    #     expect(Job.find(@job.id).genomics_last_error).to eq "No file found"
    # end

    it "does process correctly genomics for jobs for which the user has supplied a valid fasta file (##{__LINE__})" do
        @job.update genomics_ok: false, gene_name: "test-update-from-line-#{__LINE__}"
        FileUtils.mkpath PROJECT_BASE_PATH + "test_temp/downloads/#{@job.id}/"
        FileUtils.cp(PROJECT_BASE_PATH + 'spec/test_files/genomic_ok.fasta', PROJECT_BASE_PATH + "test_temp/downloads/#{@job.id}/genomics.fasta")

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_ok).to eq true
    end

    it "fails genomics for jobs that require a download bigger than the user-quota" do
        ok_url = 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_ok.fasta'
        @job.update gene_name: "test-update-from-line-#{__LINE__}", genomics_url: ok_url
        @job.user = User.new nickname: 'banana', max_fs: 0

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_failed).to eq true
        expect(Job.find(@job.id).genomics_last_error).to eq "Filesize exceedes user limits."
    end
    
    it "fails genomics for jobs that require a download but the disk is full" do
        begin 
            module Sys
                class Filesystem
                    @@original_method = Sys::Filesystem.method(:stat)
                    def self.stat(arg)
                        raise PinWFetch::DiskFullError
                    end
                end
            end

            ok_url = 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_ok.fasta'
            @job.update gene_name: "test-update-from-line-#{__LINE__}", genomics_url: ok_url
            @job.user = User.new nickname: 'banana', max_fs: 100000000

            result = myFetch.genomics @job, async: false
            expect(Job.find(@job.id).genomics_retries).to eq 3
            expect(Job.find(@job.id).genomics_last_error).to eq "Disk full!"
        ensure
            module Sys
                class Filesystem
                    def self.stat(arg)
                        @@original_method[arg]
                    end
                end
            end
        end
    end


    it "takes jobs out of the download queue when all preprocessing is done" do
        ok_url = 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_ok.fasta'
        @job.update gene_name: "test-update-from-line-#{__LINE__}", ensembl_ok: true, all_reads_ok: true, genomics_url: ok_url

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_ok).to eq true
        expect(Job.find(@job.id).awaiting_download).to eq false
    end

    it "moves jobs to the dispatch queue when the necessary downloads are complete" do
        ok_url = 'https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/genomic_ok.fasta'
        @job.update gene_name: "test-update-from-line-#{__LINE__}", all_reads_ok: true, genomics_url: ok_url

        result = myFetch.genomics @job, async: false
        expect(Job.find(@job.id).genomics_ok).to eq true
        expect(Job.find(@job.id).awaiting_dispatch).to eq true
    end
    # fetch ensembl

end