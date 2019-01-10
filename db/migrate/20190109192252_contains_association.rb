class ContainsAssociation < ActiveRecord::Migration[5.2]
  def change
    create_table :kithe_model_contains, id: false do |t|
      t.references :containee, type: :uuid, foreign_key: {to_table: :kithe_models}
      t.references :container, type: :uuid, foreign_key: {to_table: :kithe_models}
    end
  end
end
