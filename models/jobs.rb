ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'jobs'
    create_table :jobs do |table|
      table.column :status,         :string, :default => 'QUEUED'
      table.column :last_err_cause, :string
      table.column :retries,        :integer, :default => 0
      table.column :started_at,     :datetime
      table.column :description,    :string
      table.column :ensembl,        :string
      table.column :genome,         :string
      table.column :readsURLs,      :string
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
    when 'QUEUED'
      "Queued"
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
end