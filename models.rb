require 'active_record'

##################
### DB PREPARE ###

ActiveRecord::Base.logger = Logger.new(STDERR)

ActiveRecord::Base.establish_connection(
  :adapter  => 'sqlite3',
  :database => 'pintron.db'
  )

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'users'
    create_table :users do |table|
      table.column :nickname, :string
      table.column :password, :string
      table.column :email,    :string
      table.column :admin,    :boolean, :default => false
      table.column :enabled,  :boolean, :default => true
      table.column :max_fs,   :integer, :default => 0
      table.column :max_cput, :integer, :default => 0
      table.column :max_ql,   :integer, :default => 0
      table.timestamps

      table.index :nickname, :unique => true
    end
  end
end


class User < ActiveRecord::Base
  validates_uniqueness_of :nickname
  has_many :user_changes_to_others, :class_name => 'UserHistory', :foreign_key => 'admin_id'
  has_many :user_changes_to_self, :class_name => 'UserHistory', :foreign_key => 'subject_id'
end

ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.tables.include? 'user_history'
    create_table :user_history do |table|
      table.references :admin
      table.references :subject
      table.column :message, :string
      table.timestamps
    end
  end
end

class UserHistory < ActiveRecord::Base
  self.table_name = "user_history"
  belongs_to :admin, :class_name => 'User'
  belongs_to :subject, :class_name => 'User'
end

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
      table.timestamps

      table.index :name, :unique => true
    end
  end
end


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
