require_relative '../cron/pinw-fetch'


describe PinWFetch, "#ensembl" do

  before(:each) do
  	@job = Job.new
  end

  it "does not process sucessfully completed ensembl jobs" do
  	@job.ensembl_ok = true
  	result = PinWFetch.ensembl @job
  	expect(result).to eq false 
  end

  it "does not process failed ensembl jobs" do
  	@job.ensembl_failed = true
  	result = PinWFetch.ensembl @job
  	expect(result).to eq false 
  end

  it "returns true when there is no gene_name and doesnt count it as a failure" do
    @job.gene_name = nil
    @job.save
    result = PinWFetch.ensembl @job

    expect(result).to eq true
    expect(@job.ensembl).to eq nil
    expect(@job.ensembl_retries).to eq 0
  end

  it "downloads transcripts when there is a gene_name" do
  	@job.gene_name = 'tolo'
  	@job.save
  	result = PinWFetch.ensembl @job
  	expect(result).to eq true

  	sleep(3) # wait for the subprocess to complete
  	expect(Job.find(@job.id).ensembl_ok).to eq true
  end

  it "quits when a lock is in place" do

  end
  
  it "frees correctly stale PID locks" do

  end


  it "waits when a retry timetout has not occurred" do

  end

  after(:each) do
      # test the lock has been freed
      # job = Job.take
	  expect(@job.ensembl_pid).to eq nil
	  @job.destroy
      #reads
  end
end


describe PinWFetch, "#genomics" do

  before(:each) do
  	@job = Job.new
  end

  it "does not process sucessfully completed genomics jobs" do
  	@job.genomics_ok = true
  	result = PinWFetch.genomics @job
  	expect(result).to eq false
  end

  it "does not process failed genomics jobs" do
  	@job.genomics_failed = true
  	result = PinWFetch.genomics @job
  	expect(result).to eq false 
  end

  it "processes correctly case URL genomics" do
    @job.genomics_url = 'http://google.com'
    @job.save
    result = PinWFetch.genomics @job

    expect(result).to eq false

  	sleep(3) # wait for the subprocess to complete
    expect(@job.genomics_file).not_to eq nil
    expect(@job.genomics_ok).to eq true
  end

  it "processes correctly case GENE NAME" do
    @job.gene_name = 'yolo'
    @job.save
    result = PinWFetch.genomics @job

    expect(result).to eq false

  	sleep(3) # wait for the subprocess to complete
    expect(@job.genomics_file).not_to eq nil
    expect(@job.genomics_ok).to eq true
  end

  it "processes correctly case FILE genomics" do
    @job.genomics_file = true
    @job.save
    result = PinWFetch.genomics @job

    expect(result).to eq false

  	sleep(3) # wait for the subprocess to complete
    expect(@job.genomics_file).not_to eq nil
    expect(@job.genomics_ok).to eq true
  end

  it "sends a process to deployment when proper" do
  	@job.reads_ok = true


  end

  it "quits when a lock is in place" do
  	@job.genomics_pid = 999
  	@job.genomics_lock = Time.now

  	
  end
  
  it "frees correctly stale PID locks" do
  	spid = Process.fork {sleep while true}


  	Process.kill 9, spid


  end

  it "waits when a retry timetout has not occurred" do

  	@job.genomics_retries = 3
  	@job.last_retry = Time.now

  end

  after(:each) do
      # test the lock has been freed
	  expect(@job.genomics_pid).to eq nil
	  @job.destroy
  end



end