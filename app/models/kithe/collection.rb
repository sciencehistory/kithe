class Kithe::Collection < Kithe::Model
  after_initialize do
    self.kithe_model_type = "collection" if self.kithe_model_type.nil?
  end
  before_validation do
    self.kithe_model_type = "collection" if self.kithe_model_type.nil?
  end
end
