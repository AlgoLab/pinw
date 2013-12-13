class AddRequestIdToReads < ActiveRecord::Migration
  def change
    add_column :reads, :request_id, :integer
  end
end
