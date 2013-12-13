class CreateGtfs < ActiveRecord::Migration
  def change
    create_table :gtfs do |t|
      t.string :path
      t.string :url
      t.boolean :stored

      t.timestamps
    end
  end
end
