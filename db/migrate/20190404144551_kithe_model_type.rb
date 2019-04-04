class KitheModelType < ActiveRecord::Migration[5.2]
  def change
    reversible do |dir|
      dir.up do
        add_column :kithe_models, :kithe_model_type, :integer

        # Make sure all existing rows get value set. This is still kinda slow if you have
        # a big db, but well kithe is still in beta and nobody else is using it..
        say_with_time("setting values on :kithe_model_type") do
          Kithe::Model.in_batches do |rel|
            rel.pluck("id", "type").each do |id, type_name|
              type = type_name.constantize
              kithe_model_type = if type <= Kithe::Asset
                "asset"
              elsif type <= Kithe::Work
                "work"
              elsif type <= Kithe::Collection
                "collection"
              end
              Kithe::Model.where(id: id).update_all(kithe_model_type: kithe_model_type)
            end
          end
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
