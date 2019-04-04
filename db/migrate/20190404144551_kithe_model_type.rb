class KitheModelType < ActiveRecord::Migration[5.2]
  def change
    reversible do |dir|
      dir.up do
        add_column :kithe_models, :kithe_model_type, :integer

        # Make sure all existing rows get value set
        Kithe::Model.find_each do |model|
          model.save!(validate: false)
        end

        # Make it non-nullable
        change_column :kithe_models, :kithe_model_type, :integer, null: false
      end
      dir.down do
        remove_column :kithe_models, :kithe_model_type
      end
    end
  end
end
