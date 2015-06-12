class Result < ActiveRecord::Base
	belongs_to :user, :class_name => 'User'
	belongs_to :server, :class_name => 'Server'
	belongs_to :job, :class_name => 'Job'
end