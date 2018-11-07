class AddFileDataToModel < ActiveRecord::Migration[5.2]
  def change
    add_column :kithe_models, :file_data, :jsonb
  end
end
