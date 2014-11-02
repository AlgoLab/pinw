ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'jobs'
    create_table :jobs do |table|
      table.column :status,         :string, :default => 'QUEUED_DOWNLOAD'
     
      table.column :ensembl_transcripts, :string

      table.column :gene_name, :string
      table.column :genomics_url, :string
      table.column :genomics_file, :string
      table.column :genomics_retries, :string
      table.column :genomics_pid, :integer
      table.column :genomics_lock, :datetime
      table.column :genomics_last_error, :string
      table.column :genomics_ok, :boolean
      
      table.column :reads_to_download, :string
      table.column :reads_downloading, :string # also contains locks, pids and retries
      table.column :reads_downloaded, :string
      table.column :reads_files, :string
      table.column :reads_last_error, :string
      table.column :reads_ok, :boolean

      table.column :downloads_completed_at, :datetime


      table.column :processing_dispatch_pid, :integer
      table.column :processing_dispatch_lock, :datetime
      table.column :processing_dispatched_at,  :datetime
      table.column :processing_dispatch_error, :string 
      table.column :processing_dispatch_ok, :boolean

      table.column :processing_metrics,  :string
      table.column :processing_error, :string # pids are stored on the remote machine and polling is peformed by another script
      table.column :processing_ok, :boolean

      table.column :description,    :string
      
      table.references :server
      table.references :user
      table.references :result,    :index => true
      table.timestamps

      # table.index :results_id, :unique => true
    end
  end
end

class Job < ActiveRecord::Base
  belongs_to :user, :class_name => 'User'
  belongs_to :server, :class_name => 'Server'

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