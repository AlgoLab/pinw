class Reads < ActiveRecord::Base
  belongs_to :request, autosave: true
  mount_uploader :path, ReadsUploader
end
