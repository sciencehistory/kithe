class AddRepresentativeRelations < ActiveRecord::Migration[5.2]
  def change
    add_reference :kithe_models, :representative, foreign_key: {to_table: :kithe_models}, type: :uuid, null: true
    add_reference :kithe_models, :leaf_representative, foreign_key: {to_table: :kithe_models}, type: :uuid, null: true
  end
end
