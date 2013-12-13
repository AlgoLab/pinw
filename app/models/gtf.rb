class Gtf < ActiveRecord::Base
  belongs_to :request, autosave: true
  mount_uploader :path, GtfUploader
end
