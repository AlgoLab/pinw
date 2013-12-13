class CreateReads < ActiveRecord::Migration
  def change
    create_table :reads do |t|
      t.string :path
      t.string :url
      t.boolean :stored
      t.string :type

      t.timestamps
    end
  end
end
