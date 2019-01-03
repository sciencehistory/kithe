require 'attr_json'

class Kithe::Model < ActiveRecord::Base
  include AttrJson::Record
  include AttrJson::NestedAttributes
  include AttrJson::Record::Dirty

  attr_json_config(default_accepts_nested_attributes: { reject_if: :all_blank })

  validates_presence_of :title

  # this should only apply to Works, but we define it here so we can preload it
  # when fetching all Kithe::Model. And it's to Kithe::Model so it can include
  # both Works and Assets. We do some app-level validation to try and make it used
  # as intended.
  has_many :members, class_name: "Kithe::Model", foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy
  belongs_to :parent, class_name: "Kithe::Model", inverse_of: :members, optional: true


  # Mainly meant for Works (maybe Collection too?), but on Kithe::Model to allow rails eager
  # loading on hetereogenous fetches
  belongs_to :representative, class_name: "Kithe::Model", optional: true
  belongs_to :leaf_representative, class_name: "Kithe::Model", optional: true
  before_save :set_leaf_representative
  after_save :update_referencing_leaf_representatives


  # recovering a bit from our generalized members/parent relationship with validations.
  # parent has to be a Work, and Collections don't have parents (for now?), etc.
  # Could make this an injectable dependency for other apps?
  validates_with Kithe::Validators::ModelParent

  def initialize(*_)
    raise TypeError.new("Kithe::Model is abstract and cannot be initialized") if self.class == ::Kithe::Model
    super
  end

  # We want friendlier_id to be in URLs, not id
  def to_param
    friendlier_id
  end

  # Due to rails bug, we don't immediately have the database-provided value after create. :(
  # If we ask for it and it's empty, go to the db to get it
  # https://github.com/rails/rails/issues/21627
  def friendlier_id(*_)
    in_memory = super

    if !in_memory && persisted? && !@friendlier_id_retrieved
      in_memory = self.class.where(id: id).limit(1).pluck(:friendlier_id).first
      write_attribute(:friendlier_id, in_memory)
      clear_attribute_change(:friendlier_id)
      # just to avoid doing it multiple times if it's still unset in db for some reason
      @friendlier_id_retrieved = true
    end

    in_memory
  end

  # hacky :(
  def derivatives(*args)
    raise TypeError.new("Only valid on Kithe::Asset") unless self.kind_of?(Kithe::Asset)
    super
  end
  # hacky :(
  def derivatives=(*args)
    raise TypeError.new("Only valid on Kithe::Asset") unless self.kind_of?(Kithe::Asset)
    super
  end

  private

  # if a representative is set, set leaf_representative by following
  # the tree with an efficient recursive CTE
  def set_leaf_representative
    return if self.kind_of?(Kithe::Asset) # not applicable
    return unless will_save_change_to_representative_id?

    # a postgres recursive CTE to find the ultimate leaf through
    # a possible chain of works, guarding against cycles.
    # https://www.postgresql.org/docs/9.1/queries-with.html
    recursive_cte = <<~EOS
      WITH RECURSIVE find_terminal(id, link) AS (
          SELECT m.id, m.representative_id
          FROM kithe_models m
          WHERE m.id = #{self.class.connection.quote self.representative_id}
        UNION
          SELECT m.id, m.representative_id
          FROM kithe_models m, find_terminal ft
          WHERE m.id = ft.link
      ) SELECT id
        FROM find_terminal
        WHERE link IS NULL
        LIMIT 1;
    EOS

    result = self.class.connection.select_value(recursive_cte)
    self.leaf_representative_id = result
  end
end
