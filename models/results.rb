ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'results'
    create_table :results do |table|
      table.column :filename_o_qualcosaDLG,      :string
      table.column :working_dir,     :string
      table.references :users
      table.references :servers
      table.references :jobs
      table.timestamps
    end
  end
end
