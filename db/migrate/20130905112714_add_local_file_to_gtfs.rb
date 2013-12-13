class AddLocalFileToGtfs < ActiveRecord::Migration
  def change
    add_column :gtfs, :local_file, :string
  end
end
