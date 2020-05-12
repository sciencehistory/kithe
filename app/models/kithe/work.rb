class Kithe::Work < Kithe::Model
  after_initialize do
    self.kithe_model_type = "work" if self.kithe_model_type.nil?
  end
  before_validation do
    self.kithe_model_type = "work" if self.kithe_model_type.nil?
  end

end
