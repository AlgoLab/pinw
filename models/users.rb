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
    ActiveRecord::Base.connection.execute "INSERT INTO users (nickname, password, admin) VALUES (\"admin\", \"admin\", \"t\")"
    ActiveRecord::Base.connection.execute "INSERT INTO users (nickname, password, enabled) VALUES (\"guest\", \"guest\", \"f\")"
  end
end


class User < ActiveRecord::Base
  validates_uniqueness_of :nickname
  validates :nickname, format: { with: /\A[A-Za-z0-9._\-\@]{3,50}\z/ }
  validates :password, length: { in: 5..50 }
  validates :email, format: { with: /\A([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})\z/i }

  has_many :user_changes_to_others, :class_name => 'UserHistory', :foreign_key => 'admin_id'
  has_many :user_changes_to_self, :class_name => 'UserHistory', :foreign_key => 'subject_id'

  has_many :jobs, :class_name => 'Job', :foreign_key => 'user_id'


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
