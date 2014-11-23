class ProcessingState < ActiveRecord::Base
  self.table_name = "processing_status"
  self.primary_key = 'key'
  serialize :value
end