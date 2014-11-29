require 'fileutils'
require_relative '../cron/pinw-fetch'


settings = YAML.load(File.read(PROJECT_BASE_PATH + 'config/database.yml'))
myFetch = PinWFetch.new({
      adapter: settings['test']['adapter'],
      database: PROJECT_BASE_PATH + settings['test']['database'],
      timeout: 30000
}, debug: !!(ENV['PINW_RSPEC_VERBOSE']), force: false, download_path: PROJECT_BASE_PATH + 'test_temp/downloads/')


describe PinWFetch, "#reads" do
    before(:all) {FileUtils.rm_rf(PROJECT_BASE_PATH + 'test_temp/downloads/')}
    after(:all) {FileUtils.rm_rf(PROJECT_BASE_PATH + 'test_temp/downloads/')}
    
    before(:each) {@job = Job.create}

    it "does not process jobs with all_reads_ok: true (##{__LINE__})" do
        @job.update all_reads_ok: true

        result = myFetch.reads @job, async: false
        expect(Job.find(@job.id).all_reads_ok).to eq true
    end

    it "does not process jobs with some_reads_failed: true (##{__LINE__})" do
        @job.update some_reads_failed: true

        result = myFetch.reads @job, async: false
        expect(Job.find(@job.id).some_reads_failed).to eq true
    end

    it "does not process jobs with all_reads_ok and some_reads_failed: true (##{__LINE__})" do
        @job.update all_reads_ok: true
        @job.update some_reads_failed: true

        result = myFetch.reads @job, async: false
        expect(Job.find(@job.id).all_reads_ok).to eq true
        expect(Job.find(@job.id).some_reads_failed).to eq true
    end

    it "does not process jobs with locked reads (##{__LINE__})" do
        now = Time.now
        spid1 = Process.fork {sleep 10}
        spid2 = Process.fork {sleep 10}
        reads1 = JobRead.create({
            job_id: @job.id,
            lock: now - 20, 
            pid: spid1,
            ok: false, 
            failed: false
        })
        reads2 = JobRead.create({
            job_id: @job.id,
            lock: now - 10,
            pid: spid2,
            ok: false, 
            failed: false
        })

        result = myFetch.reads @job, async: false
        expect(JobRead.find(reads1.id).lock).to eq now - 20
        expect(JobRead.find(reads1.id).ok).to eq false
        expect(JobRead.find(reads1.id).failed).to eq false
        expect(JobRead.find(reads2.id).lock).to eq now - 10
        expect(JobRead.find(reads2.id).ok).to eq false
        expect(JobRead.find(reads2.id).failed).to eq false
    end

    it "does not process jobs with not_waited_enough: true (##{__LINE__})" do
        now = Time.now
        spid1 = Process.fork {sleep 10}
        spid2 = Process.fork {sleep 10}
        reads1 = JobRead.create({
            job_id: @job.id,
            ok: false, 
            failed: false,
            last_retry: now,
            retries: 2,
            pid: spid1
        })
        reads2 = JobRead.create({
            job_id: @job.id,
            ok: false, 
            failed: false,
            last_retry: now,
            retries: 3,
            pid: spid2
        })

        result = myFetch.reads @job, async: false
        expect(JobRead.find(reads1.id).ok).to eq false
        expect(JobRead.find(reads1.id).pid).to eq spid1
        expect(JobRead.find(reads2.id).ok).to eq false
        expect(JobRead.find(reads2.id).pid).to eq spid2
    end

    it "does not process jobs with bad url (##{__LINE__})" do
        now = Time.now
        spid1 = Process.fork {sleep 10}
        spid2 = Process.fork {sleep 10}
        reads1 = JobRead.create({
            job_id: @job.id,
            ok: false, 
            failed: false,
            last_retry: now - 80,
            retries: 1,
            pid: spid1,
            url: "ht?tp://asfagtfasd..com/badurl.txt"
        })
        reads2 = JobRead.create({
            job_id: @job.id,
            ok: false, 
            failed: false,
            last_retry: now - 80,
            retries: 1,
            pid: spid2,
            url: "https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/ests.fastq"
        })

        result = myFetch.reads @job, async: false
        expect(JobRead.find(reads1.id).ok).to eq false
        expect(JobRead.find(reads1.id).pid).not_to eq spid1
        expect(JobRead.find(reads1.id).failed).to eq true
        expect(JobRead.find(reads1.id).last_error).to eq "Invalid URL"
        expect(JobRead.find(reads2.id).ok).to eq true
        expect(JobRead.find(reads2.id).pid).to eq nil
        expect(Job.find(@job.id).some_reads_failed).to eq true
        expect(Job.find(@job.id).reads_last_error).to eq "##{reads1.id} has an invalid URL."
    end

    it "does process all reads (##{__LINE__})" do
        now = Time.now
        spid1 = Process.fork {sleep 10}
        spid2 = Process.fork {sleep 10}
        reads1 = JobRead.create({
            job_id: @job.id,
            ok: false, 
            failed: false,
            last_retry: now - 80,
            retries: 1,
            pid: spid1,
            url: "https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/ests.fastq"
        })
        reads2 = JobRead.create({
            job_id: @job.id,
            ok: false, 
            failed: false,
            last_retry: now - 80,
            retries: 1,
            pid: spid2,
            url: "https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/ests.fastq"
        })

        result = myFetch.reads @job, async: false
        expect(JobRead.find(reads1.id).ok).to eq true
        expect(JobRead.find(reads1.id).pid).to eq nil
        expect(JobRead.find(reads2.id).ok).to eq true
        expect(JobRead.find(reads2.id).pid).to eq nil
        expect(Job.find(@job.id).all_reads_ok).to eq true
        expect(Job.find(@job.id).reads_last_error).to eq nil
    end

    it "does process all reads and dispatch (##{__LINE__})" do
        @job.update ({
            genomics_ok: true, 
        })
        now = Time.now
        spid1 = Process.fork {sleep 10}
        spid2 = Process.fork {sleep 10}
        reads1 = JobRead.create({
            job_id: @job.id,
            ok: false, 
            failed: false,
            last_retry: now - 80,
            retries: 1,
            pid: spid1,
            url: "https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/ests.fastq"
        })
        reads2 = JobRead.create({
            job_id: @job.id,
            ok: false, 
            failed: false,
            last_retry: now - 80,
            retries: 1,
            pid: spid2,
            url: "https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/ests.fastq"
        })

        result = myFetch.reads @job, async: false
        expect(JobRead.find(reads1.id).ok).to eq true
        expect(JobRead.find(reads1.id).pid).to eq nil
        expect(JobRead.find(reads2.id).ok).to eq true
        expect(JobRead.find(reads2.id).pid).to eq nil
        expect(Job.find(@job.id).all_reads_ok).to eq true
        expect(Job.find(@job.id).reads_last_error).to eq nil
        expect(Job.find(@job.id).awaiting_dispatch).to eq true
        expect(Job.find(@job.id).downloads_completed_at).to eq nil
    end

    it "does process all reads and dispatch (##{__LINE__})" do
        @job.update ({
            genomics_ok: true, 
            ensembl_ok: true
        })
        now = Time.now
        spid1 = Process.fork {sleep 10}
        spid2 = Process.fork {sleep 10}
        reads1 = JobRead.create({
            job_id: @job.id,
            ok: false, 
            failed: false,
            last_retry: now - 80,
            retries: 1,
            pid: spid1,
            url: "https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/ests.fastq"
        })
        reads2 = JobRead.create({
            job_id: @job.id,
            ok: false, 
            failed: false,
            last_retry: now - 80,
            retries: 1,
            pid: spid2,
            url: "https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/ests.fastq"
        })

        result = myFetch.reads @job, async: false
        expect(JobRead.find(reads1.id).ok).to eq true
        expect(JobRead.find(reads1.id).pid).to eq nil
        expect(JobRead.find(reads2.id).ok).to eq true
        expect(JobRead.find(reads2.id).pid).to eq nil
        expect(Job.find(@job.id).all_reads_ok).to eq true
        expect(Job.find(@job.id).reads_last_error).to eq nil
        expect(Job.find(@job.id).awaiting_dispatch).to eq true
        expect(Job.find(@job.id).awaiting_download).to eq false
        expect(Job.find(@job.id).downloads_completed_at).not_to eq nil
    end

    it "fails reads for jobs that require a download but the disk is full" do
        expect(Sys::Filesystem).to receive(:stat).and_raise(PinWFetch::DiskFullError)

        now = Time.now
        spid = Process.fork {sleep 10}
        reads = JobRead.create({
            job_id: @job.id,
            ok: false, 
            failed: false,
            last_retry: now - 80,
            retries: 1,
            pid: spid,
            url: "https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/ests.fastq"
        })

        result = myFetch.reads @job, async: false
        expect(JobRead.find(reads.id).ok).to eq false
        expect(JobRead.find(reads.id).pid).not_to eq spid
        expect(JobRead.find(reads.id).failed).to eq false
        expect(JobRead.find(reads.id).last_error).to eq "Disk full!"
    end

    it "fails reads for jobs that require a download but the file exceedes user limits" do
        now = Time.now
        spid = Process.fork {sleep 10}
        user = User.find(1)
        user.update max_fs: 0
        @job.user = user
        reads = JobRead.create({
            job_id: @job.id,
            ok: false, 
            failed: false,
            url: "https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/ests.fastq"
        })

        result = myFetch.reads @job, async: false
        expect(JobRead.find(reads.id).ok).to eq false
        expect(JobRead.find(reads.id).pid).not_to eq spid
        expect(JobRead.find(reads.id).failed).to eq true
        expect(JobRead.find(reads.id).last_error).to eq "Filesize exceedes user limits."
        expect(Job.find(@job.id).reads_last_error).to eq "##{reads.id} exceedes user limits."
    end

    it "handles correctly not specifically handled errors" do
        class BlarghError < RuntimeError; end
        expect(File).to receive(:open).and_raise(BlarghError)

        now = Time.now
        spid = Process.fork {sleep 10}
        reads = JobRead.create({
            job_id: @job.id,
            ok: false, 
            failed: false,
            last_retry: now - 80,
            retries: 1,
            pid: spid,
            url: "https://raw.githubusercontent.com/AlgoLab/pinw/master/spec/test_files/ests.fastq"
        })

        result = myFetch.reads @job, async: false
        expect(JobRead.find(reads.id).ok).to eq false
        expect(JobRead.find(reads.id).pid).not_to eq spid
        expect(JobRead.find(reads.id).failed).to eq true
        expect(JobRead.find(reads.id).last_error).not_to eq nil
    end



end
