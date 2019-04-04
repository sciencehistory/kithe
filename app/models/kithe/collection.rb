class Kithe::Collection < Kithe::Model
  # Collections don't have derivatives, but we want to allow Rails eager loading
  # of association on hetereogenous fetches of Kithe::Model, so this is clever.
  has_many :derivatives, -> { none }
  private :derivatives, :derivatives=, :derivative_ids, :derivative_ids=

  after_initialize do
    self.kithe_model_type = "collection" if self.kithe_model_type.nil?
  end
  before_validation do
    self.kithe_model_type = "collection" if self.kithe_model_type.nil?
  end

end
