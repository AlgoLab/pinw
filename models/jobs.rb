require 'open-uri'

class Job < ActiveRecord::Base
  validates :quality_threshold, numericality: { only_integer: true, greater_than: 33 - 1, less_than: 126 + 1 }
  validates :description, length: {maximum: 100000}, allow_nil: true # 100kB
  validate :validateGenomicsURL
  belongs_to :user, :class_name => 'User'
  belongs_to :server, :class_name => 'Server'
  belongs_to :organism
  validates :organism, presence: true, allow_nil: true

  def header_regex
    return /\A>(?:chr)?(?:[XYxy]|\d+):\d+:\d+:(?:1|-1|\+1|-|\+)\n\z/
  end

  def validateGenomicsURL
    return unless genomics_url
    unless genomics_url.start_with?('http', 'https', 'ftp') and genomics_url =~ /\A#{URI::regexp}\z/
        errors.add(:url, "Invalid URL")
    end
  end
end




class JobRead < ActiveRecord::Base
  self.table_name = "jobs_reads"

  validates :url, length: { maximum: 8000, minimum: 3}
  validate :validateURL

  belongs_to :job, class_name: 'Job'

  def validateURL
    unless url.start_with?('http', 'https', 'ftp') and url =~ /\A#{URI::regexp}\z/
        errors.add(:url, "Invalid URL")
    end
  end
end

