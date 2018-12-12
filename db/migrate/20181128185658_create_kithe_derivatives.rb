class CreateKitheDerivatives < ActiveRecord::Migration[5.2]
  def change
    create_table :kithe_derivatives do |t|
      t.string :key, null: false
      t.jsonb :file_data
      t.references :asset, foreign_key: {to_table: :kithe_models}, type: :uuid, index: true, null: false

      t.timestamps
    end

    add_index :kithe_derivatives, [:asset_id, :key], unique: true
  end
end
