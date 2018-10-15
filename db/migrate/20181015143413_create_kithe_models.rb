class CreateKitheModels < ActiveRecord::Migration[5.2]
  def change
    create_table :kithe_models, id: :uuid do |t|
      t.string :title, null: false

      # Rails STI
      t.string :type, null: false

      # position in membership when in a mmebership relation
      t.integer :position

      t.jsonb :json_attributes

      t.timestamps
    end

    # self-referential work children/members
    add_reference :kithe_models, :parent, type: :uuid, foreign_key: {to_table: :kithe_models}
  end
end
