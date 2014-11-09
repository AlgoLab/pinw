
ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'processing_status'
    create_table :processing_status do |table|
      table.column :key, :string
      table.column :value, :text
      table.column :name, :string
      table.column :description, :string
      table.column :type, :string
      table.timestamps
    end
    ActiveRecord::Base.connection.execute "INSERT INTO processing_status (key, value) VALUES (\"FETCH_CRON_LOCK\", NULL)"
    ActiveRecord::Base.connection.execute "INSERT INTO processing_status (key, value) VALUES (\"FETCH_ACTIVE_DOWNLOADS\", 0)"
  end
end

class ProcessingState < ActiveRecord::Base
  self.table_name = "processing_status"
  self.primary_key = 'key'
end