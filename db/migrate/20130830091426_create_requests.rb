class CreateRequests < ActiveRecord::Migration
  def change
    create_table :requests do |t|
      t.string :hugo_name
      t.integer :status

      t.timestamps
    end
  end
end
