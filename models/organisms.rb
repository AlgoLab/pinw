class Organism < ActiveRecord::Base
	has_many :jobs, inverse_of: :organism
	validates :name, presence: true
	validates :ensembl_id, presence: true
end