class AddLocalFileToReads < ActiveRecord::Migration
  def change
    add_column :reads, :local_file, :string
  end
end
