class AddRequestIdToGtfs < ActiveRecord::Migration
  def change
    add_column :gtfs, :request_id, :integer
  end
end
