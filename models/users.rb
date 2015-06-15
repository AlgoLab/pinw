class User < ActiveRecord::Base
  validates_uniqueness_of :nickname
  validates :nickname, format: { with: /\A[A-Za-z0-9._\-\@]{3,50}\z/ }
  validates :password, length: { in: 5..50 }
  validates :email, format: { with: /\A([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})\z/i }

  has_many :user_changes_to_others, :class_name => 'UserHistory', :foreign_key => 'admin_id'
  has_many :user_changes_to_self, :class_name => 'UserHistory', :foreign_key => 'subject_id'

  has_many :jobs, :class_name => 'Job', :foreign_key => 'user_id'
  has_many :results, :class_name => 'Result', :foreign_key => 'user_id'


end

class UserHistory < ActiveRecord::Base
  self.table_name = "user_history"
  belongs_to :admin, :class_name => 'User'
  belongs_to :subject, :class_name => 'User'
end
