ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'jobs'
    create_table :jobs do |table|
      table.column :status,     :string, :default => 'QUEUED'
      table.column :started_at, :datetime
      table.references :servers
      table.references :users
      table.references :results, :index => true
      table.timestamps

      # table.index :results_id, :unique => true
    end
  end
end

class Job < ActiveRecord::Base

end