
class Job < ActiveRecord::Base
  belongs_to :user, :class_name => 'User'
  belongs_to :server, :class_name => 'Server'
  def header_regex
    return /\A>(?:chr)?(?:[XYxy]|\d+):\d+:\d+:(?:1|-1|\+1|-|\+)\n\z/
  end



  def is_failure?
    ['TEMP_FAILURE', 'PARTIALLY_COMPLETED', 'FAILED'].include? self.status
  end


  
  def status_short
    case self.status
    when 'QUEUED_DOWNLOAD'
      "Waiting for download to begin"
    when 'DOWNLOADING'
      "Downloading required data"
    when 'QUEUED_PROCESSING'
      "Waiting for processing to begin"
    when 'PROCESSING'
      "Runnable"
    when 'TEMP_FAILURE'
      "Temporary failure"
    when 'FAILED'
      "Failed"
    when 'COMPLETED'
      "Completed"
    when 'PARTIALLY_COMPLETED'
      "Partially completed"
    else
      "Error!!"
    end
  end

  def get_queued
    return Job.where('state = "QUEUED"')
  end
end




class JobRead < ActiveRecord::Base
  self.table_name = "jobs_reads"
  belongs_to :job, class_name: 'Job'
end

