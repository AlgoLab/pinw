require_relative '../cron/pinw-fetch'

ENV['RACK_ENV'] = 'test'


class Time
  def Time.now
    Time.new.round(6)
  end
end

    settings = YAML.load(File.read(File.expand_path('../../config/database.yml', __FILE__)))

    force = false
    myFetch = PinWFetch.new({
      adapter: settings['test']['adapter'],
      database: File.expand_path('../../' + settings['test']['database'], __FILE__),
      timeout: 30000,
    }, debug: false, force: force)



describe PinWFetch, "#genomics" do
   before(:each) do
  
    @job = Job.new
  end 

  # prepare

  it "does not process sucessfully completed genomics jobs (#1)" do
    @job.genomics_ok = true
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false
    expect(Job.find(@job.id).genomics_lock).to eq Time.at(0)
  end

  it "does not process failed genomics jobs with gene name (#2)" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_failed = true
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_lock).to eq Time.at(0)
  end

  it "does not process failed genomics jobs without gene name (#3)" do
    @job.genomics_ok = false
    @job.genomics_failed = true
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq true 
    expect(Job.find(@job.id).genomics_lock).to eq Time.at(0)
  end

  it "does not process active genomics jobs with gene name (#4)" do
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

  it "does not process active genomics jobs without gene name (#5)" do
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

  it "does not process jobs which has waited enough with name (#6)" do
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

  it "does not process jobs which has waited enough with name (#7)" do
    @job.genomics_ok = false
    @job.genomics_failed = false
    @job.genomics_last_retry = Time.now - 8
    @job.genomics_retries = 1
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq true 
    expect(Job.find(@job.id).genomics_lock).to eq Time.at(0)
  end

  it "does not process active genomics jobs with expired lock (#8)" do
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

  it "does not process active genomics jobs with bad file (#9)" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_failed = false
    spid = Process.fork {sleep 100}
    @job.genomics_pid = spid
    mylock = Time.now - 100 * 60
    @job.genomics_lock = mylock
    @job.genomics_url = 'ht?tp://www.sgrugolf..com/badfile.txt'
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_failed).to eq true
    expect(Job.find(@job.id).genomics_last_error).to eq "Invalid URL"
  end

  it "does not process active genomics jobs with no file URL and 404 (#10)" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_url = 'https://raw.githubusercontent.com/AlgoLab/PIntron/master/dist-docs/example/genomic_x.txt'
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_failed).to eq true
    expect(Job.find(@job.id).genomics_last_error).to eq "Unhandled error: 404 Not Found."
  end

  it "does not process active genomics jobs with no file URL and 404 (#11)" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_url = 'https://raw.gicontent.com/genomic_x.txt'
    @job.save
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_failed).to eq true
    expect(Job.find(@job.id).genomics_last_error).to eq "Unhandled error: 404 Not Found."
  end

  it "does not process active genomics jobs when file has bad fasta header (#12)" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_url = 'https://raw.githubusercontent.com/AlgoLab/PIntron/master/dist-docs/example/genomic_badh.txt'
    @job.save
    # file with bad fasta header needed somewhere!!!
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_failed).to eq true
    expect(Job.find(@job.id).genomics_last_error).to eq "Unhandled error: 404 Not Found."
  end

  it "does not process active genomics jobs when file hasn't a body (#13)" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_url = 'https://raw.githubusercontent.com/AlgoLab/PIntron/master/dist-docs/example/genomic_nob.txt'
    @job.save
    # file with fasta header but no body needed!!!
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_failed).to eq true
    expect(Job.find(@job.id).genomics_last_error).to eq "No file found"
  end

  it "does not process correct genomics jobs (#14)" do
    @job.genomics_ok = false
    @job.gene_name = 'banana'
    @job.genomics_url = 'https://raw.githubusercontent.com/AlgoLab/PIntron/master/dist-docs/example/genomic.txt'
    @job.save
    # file with fasta header but no body needed!!!
    result = myFetch.genomics @job, async: false
    expect(result).to eq false 
    expect(Job.find(@job.id).genomics_ok).to eq true
  end

  

  after(:each) do
      # test the lock has been freed
      # job = Job.take
	  expect(@job.ensembl_pid).to eq nil
	  @job.destroy
      #reads
  end
end