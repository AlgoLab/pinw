
ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'servers'
    create_table :servers do |table|
      table.column :name,         :string
      table.column :host,         :string
      table.column :ssh_port,     :string
      table.column :username,     :string
      table.column :password,     :string
      table.column :ssh_cert,     :string
      table.column :pintron_path, :string
      table.column :working_dir,	:string
      table.column :enabled, :boolean
      table.timestamps

      table.index :name, :unique => true
    end
  end
end

class Server < ActiveRecord::Base

end
