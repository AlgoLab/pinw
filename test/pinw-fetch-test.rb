require 'fileutils'
require_relative '../cron/pinw-fetch'

ENV['RACK_ENV'] = 'test'

PROJECT_BASE_PATH ||= File.expand_path('../../', __FILE__) + '/'


class Time
  def Time.now
    Time.new.round(6)
  end
end

    settings = YAML.load(File.read(PROJECT_BASE_PATH + 'config/database.yml'))

    force = false
    myFetch = PinWFetch.new({
      adapter: settings['test']['adapter'],
      database: PROJECT_BASE_PATH + settings['test']['database'],
      timeout: 30000,
      download_path: PROJECT_BASE_PATH + 'test_temp/downloads/'
    }, debug: true, force: force, download_path: PROJECT_BASE_PATH + 'test_temp/downloads/')

FileUtils.rm_rf(PROJECT_BASE_PATH + 'test_temp/downloads/')

describe PinWFetch, "#genomics" do
  before(:all) {FileUtils.rm_rf(PROJECT_BASE_PATH + 'test_temp/downloads/')}


   before(:each) do
    @job = Job.new
 end 

  # prepare

  it "does not process sucessfully completed genomics jobs" do
    @job.genomics_ok = true
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false
    expect(Job.find(@job.id).genomics_lock).to eq Time.at(0)
  end

  it "does not process failed genomics jobs with gene name" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_failed = true
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_lock).to eq Time.at(0)
  end

  it "does not process failed genomics jobs without gene name" do
    @job.genomics_ok = false
    @job.genomics_failed = true
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq true 
    expect(Job.find(@job.id).genomics_lock).to eq Time.at(0)
  end

  it "does not process active genomics jobs with gene name" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_failed = false
    spid = Process.fork {sleep 100}
    @job.genomics_pid = spid
    mylock = Time.now + 100 * 60
    @job.genomics_lock = mylock
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_lock).to eq mylock
  end

  it "does not process active genomics jobs without gene name" do
    @job.genomics_ok = false
    @job.genomics_failed = false
    @job.genomics_pid = '1'
    mylock = Time.now + 100 * 60
    @job.genomics_lock = mylock
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq true 
    expect(Job.find(@job.id).genomics_lock).to eq mylock
  end

  it "does not process jobs which has waited enough with name" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_failed = false
    @job.genomics_last_retry = Time.now - 8
    @job.genomics_retries = 1
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_lock).to eq Time.at(0)
  end

  it "does not process jobs which has waited enough with name" do
    @job.genomics_ok = false
    @job.genomics_failed = false
    @job.genomics_last_retry = Time.now - 8
    @job.genomics_retries = 1
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq true 
    expect(Job.find(@job.id).genomics_lock).to eq Time.at(0)
  end

  it "does not process active genomics jobs with expired lock" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_failed = false
    spid = Process.fork {sleep 100}
    @job.genomics_pid = spid
    mylock = Time.now - 100 * 60
    @job.genomics_lock = mylock
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_pid).not_to eq spid
  end

  # fetch URL

  it "does not process genomics jobs with bad URL" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_url = 'ht?tp://www.sgrugolf..com/badfile.txt'
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_failed).to eq true
    expect(Job.find(@job.id).genomics_last_error).to eq "Invalid URL"
  end

  it "does not process genomics jobs with no file URL and 404" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_url = 'https://raw.githubusercontent.com/AlgoLab/PIntron/master/dist-docs/example/genomic_x.txt'
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_failed).to eq true
    expect(Job.find(@job.id).genomics_last_error).to eq "HTTP Error 404 Not Found."
  end

  it "does not process genomics jobs with no response from server" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_url = 'https://raw.gicontent.com/genomic_x.txt'
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_failed).to eq true
    expect(Job.find(@job.id).genomics_last_error).to eq "??? url farlocco"
  end

  it "does not process genomics jobs when file has bad fasta header" do
    @job.genomics_ok = false
    @job.gene_name = 'test132'
    @job.genomics_url = 'https://raw.githubusercontent.com/AlgoLab/pinw/master/test/test_files/genomic_badheader.fasta'
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_failed).to eq true
    expect(Job.find(@job.id).genomics_last_error).to eq "Genomics file doesn't have the required header format."
  end

  it "does not process genomics jobs when file hasn't a body" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_url = 'https://raw.githubusercontent.com/AlgoLab/pinw/master/test/test_files/genomic_headonly.fasta'
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_failed).to eq true
    expect(Job.find(@job.id).genomics_last_error).to eq "No file found"
  end

  it "does not process correct genomics jobs" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_url = 'https://raw.githubusercontent.com/AlgoLab/pinw/master/test/test_files/genomic_ok.fasta'
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_ok).to eq true
  end

  # fetch file

  it "does not process genomics jobs with no file on server" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_failed).to eq true
    expect(Job.find(@job.id).genomics_last_error).to eq "Bad job state: nowhere to get the genomics data."
  end

  it "does not process genomics jobs when file in folder has bad fasta header" do
    @job.genomics_ok = false
    @job.gene_name = 'fasta_header_gene_name'
    @job.save

    FileUtils.mkpath PROJECT_BASE_PATH + "test_temp/downloads/#{@job.id}/"
    FileUtils.cp(PROJECT_BASE_PATH + 'test/test_files/genomic_badheader.fasta', PROJECT_BASE_PATH + "test_temp/downloads/#{@job.id}/genomics.fasta")
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_failed).to eq true
    expect(Job.find(@job.id).genomics_last_error).to eq "Genomics file doesn't have the required header format."
  end

  it "does not process genomics jobs when file in folder hasn't a body" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_failed).to eq true
    expect(Job.find(@job.id).genomics_last_error).to eq "No file found"
  end

  it "does not process correct genomics jobs using file in download folder" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_file = true
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_ok).to eq true
  end

  # fetch ensembl

  after(:each) do
      # test the lock has been freed
      # job = Job.take
      expect(@job.ensembl_pid).to eq nil
      @job.destroy
      #reads
  end

  after(:all) {FileUtils.rm_rf(PROJECT_BASE_PATH + 'test_temp/downloads/')}
end