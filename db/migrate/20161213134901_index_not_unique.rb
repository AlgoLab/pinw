class IndexNotUnique < ActiveRecord::Migration
  def change
    remove_index(:results, column: [:gene_name, :organism_id])
    add_index(:results, [:gene_name, :organism_id], unique: false)
  end
end
