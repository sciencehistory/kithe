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

  # a self-referential many-to-many is a bit confusing, but our "contains" relation
  # is such! We define it on Model for all model types, although it's mostly motivated
  # by (collection <-> work).
  # https://medium.com/@jbmilgrom/active-record-many-to-many-self-join-table-e0992c27c1e
  has_many :contains_contained_by, foreign_key: :containee_id, class_name: "Kithe::ModelContains", inverse_of: :containee
  has_many :contained_by, through: :contains_contained_by, source: :container, dependent: :destroy, inverse_of: :contains

  has_many :contains_contains, foreign_key: :container_id, class_name: "Kithe::ModelContains", inverse_of: :container
  has_many :contains, through: :contains_contains, source: :containee, dependent: :destroy, inverse_of: :contained_by



  # Mainly meant for Works (maybe Collection too?), but on Kithe::Model to allow rails eager
  # loading on hetereogenous fetches
  belongs_to :representative, class_name: "Kithe::Model", optional: true
  belongs_to :leaf_representative, class_name: "Kithe::Model", optional: true
  before_save :set_leaf_representative, if: ->(model) { model.will_save_change_to_representative_id? }

  after_save :update_referencing_leaf_representatives
  before_destroy :nullify_representative_ids

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


  # insist that leaf_representative is an Asset, otherwise return nil.
  # nil means there is no _asset_ leaf, and lets caller rely on leaf being
  # an asset.
  def leaf_representative
    leaf = super
    leaf.kind_of?(Kithe::Asset) ? leaf : nil
  end

  # if a representative is set, set leaf_representative by following
  # the tree with an efficient recursive CTE to find proper value.
  #
  # Normally this is called for you in callbacks, and you don't need to
  # call manually. But if things get out of sync, you can.
  #
  #    work.set_leaf_representative
  #    work.save!
  def set_leaf_representative
    if self.kind_of?(Kithe::Asset) # not applicable
      self.leaf_representative_id = nil
    end

    # a postgres recursive CTE to find the ultimate leaf through
    # a possible chain of works, guarding against cycles.
    # https://www.postgresql.org/docs/9.1/queries-with.html
    recursive_cte = <<~EOS
      WITH RECURSIVE find_terminal(id, link) AS (
          SELECT m.id, m.representative_id
          FROM kithe_models m
          WHERE m.id = $1
        UNION
          SELECT m.id, m.representative_id
          FROM kithe_models m, find_terminal ft
          WHERE m.id = ft.link
      ) SELECT id
        FROM find_terminal
        WHERE link IS NULL
        LIMIT 1;
    EOS

    # trying to use a prepared statement, hoping it means performance advantage
    result = self.class.connection.select_all(
      recursive_cte,
      "set_leaf_representative",
      [[nil, self.representative_id]],
      preparable: true
    ).first.try(:dig, "id")

    self.leaf_representative_id = result
  end

  private




  # if leaf_representative changed, set anything that might reference
  # us to have a new leaf_representative, by fetching the tree with
  # an efficient recursive CTE. https://www.postgresql.org/docs/9.1/queries-with.html
  #
  # Note, does the update directly to db for efficiency, no rails
  # callbacks will be called for other nodes that were updated.
  def update_referencing_leaf_representatives
    return if self.kind_of?(Kithe::Asset) # not applicable
    return unless saved_change_to_leaf_representative_id?

    # update in one statement with a recursive CTE for maximal
    # efficiency. Not using a prepared statement here, not
    # sure if it actually matters?

    recursive_cte_update = <<~EOS
      UPDATE kithe_models
      SET leaf_representative_id = #{self.class.connection.quote self.leaf_representative_id}
      WHERE id IN (
        WITH RECURSIVE search_graph(id, link) AS (
                SELECT m.id, m.representative_id
                FROM kithe_models m
                WHERE m.id = #{self.class.connection.quote self.id}
              UNION
                SELECT m.id, m.representative_id
                FROM kithe_models m, search_graph sg
                WHERE m.representative_id = sg.id
        )
        SELECT id
        FROM search_graph
        WHERE id != #{self.class.connection.quote self.id}
      );
    EOS
    self.class.connection.exec_update(recursive_cte_update)
  end

  def nullify_representative_ids
    recursive_cte_update = <<~EOS
      UPDATE kithe_models
      SET leaf_representative_id = NULL, representative_id = NULL
      WHERE id IN (
        WITH RECURSIVE search_graph(id, link) AS (
                SELECT m.id, m.representative_id
                FROM kithe_models m
                WHERE m.id = #{self.class.connection.quote self.id}
              UNION
                SELECT m.id, m.representative_id
                FROM kithe_models m, search_graph sg
                WHERE m.representative_id = sg.id
        )
        SELECT id
        FROM search_graph
        WHERE id != #{self.class.connection.quote self.id}
      );
    EOS

    self.class.connection.exec_update(recursive_cte_update)
  end
end
