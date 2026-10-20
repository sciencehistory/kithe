module Kithe
  # Kithe::Indexable is a module that can add sync'ing to Solr (or maybe other index)
  # to a model.
  #
  # While it is currently only tested with Kithe::Models, it doesn't have any
  # Kithe::Model-specific code, and should work with any ActiveRecord model class, with
  # `include Kithe::Indexable`.
  #
  # For a complete overview, see the [Guide Documentation](../../../guides/solr_indexing.md)
  #
  # The Solr instance to send updates to is global configuration:
  #     Kithe.indexable_settings.solr_url = "http://localhost:8983/solr/collection_name"
  #
  # To configure how a model is mapped to a Solr document, you create a `Kithe::Indexer` sub-class, which
  # can use our obj_extract method, as well as any other traject indexer code.
  #
  # ```ruby
  # class WorkIndexer < KitheIndexer
  #   to_field "additional_title_ssim", obj_extract("additional_titles")
  #   to_field "author_names_ssim", obj_extract("authors"), transform(->(auth) { "#{auth.lastname} #{auth.firstname}" })
  # end
  #
  # Then you specify *an instance* as the indexer to use for mapping in your model class:
  #
  # ```ruby
  # class Work < Kithe::Work
  #   self.kithe_indexable_mapper = WorkIndexer.new
  # end
  # ```
  #
  # Now by default every time you save or destroy a Work object, it will be sync'd to Solr.
  #
  # For efficiency, if you're going to be making a bunch of model saves, you will want to
  # have them batched when sent to Solr:
  #
  # ```ruby
  # Kithe::Indexable.index_with(batching: true) do
  #   SomeModel.transaction do
  #     some_model.save
  #     other_model.save
  #   end
  # end
  #
  # You don't need to use an ActiveRecord transaction, but if you do it should be _inside_ the
  # `index_with` block.
  #
  # To force a sync to solr, you can call `model.update_index` on any Kithe::Indexable model.
  #
  # There are also various ways to disable the automatic indexing callbacks, and other customizations.
  # See the [Solr Indexing Guide](../../../guides/solr_indexing.md)
  #
  module Indexable
    extend ActiveSupport::Concern

    # Set some indexing parameters for the block yielded. For instance, to batch updates:
    #
    #     Kithe::Indexable.index_with(batching: true)
    #        lots_of_records.each(&:update_index)
    #     end
    #
    # And they will use a batching Traject writer for much more efficiency.
    #
    # Also pass in custom writer or mapper to #update_index
    #
    # If using ActiveRecord transactions, `.transaction do` should be INSIDE `index_with`,
    # not outside.
    def self.index_with(batching: false, disable_callbacks: false, writer: nil, on_finish: nil)
      settings = ThreadSettings.push(
        batching: batching,
        disable_callbacks: disable_callbacks,
        writer: writer,
        on_finish: on_finish)

      yield settings
    ensure
      settings.pop if settings
    end

    # Are automatic after_commit callbacks currently enabled? Will check a number
    # of things to see, as we have a number of places these can be turned on/off.
    # * Globally in `Kithe.indexable_settings.disable_callback`
    # * On class or instance using class_attribute `kithe_indexable_auto_callbacks`
    # * If no kithe_indexable_mapper is configured on record, then no callbacks.
    # * Using thread-current settings usually set by .index_with
    def self.auto_callbacks?(model)
      !Kithe.indexable_settings.disable_callbacks &&
        model.kithe_indexable_auto_callbacks &&
        model.kithe_indexable_mapper &&
        !ThreadSettings.current.disabled_callbacks?
    end

    # Rails sets these on every update, so they never count as a meaningful change when
    # checking kithe_indexable_non_indexed_attributes.
    AUTO_TIMESTAMP_ATTRIBUTES = %w{updated_at updated_on}.freeze

    included do
      # A whole bunch of class attributes is not great design, but it's so convenient
      # to have rails class_attribute semantics (can be set on class or instance, inherits well, so long
      # as you don't mutate values), and it works for now.

      # Set to an _instance_ of a Kithe::Indexer or Traject::Indexer subclass.
      # eg;
      #
      #     self.kithe_indexable_mapper = MyWorkIndexer.new
      #
      # Re-using the same instance performs so much better becuase of how traject is set up, although
      # may do weird things with dev-mode class reloading we'll have to workaround
      # later maybe.
      class_attribute :kithe_indexable_mapper

      # whether to invoke after_commit callback, default false. Set to true
      # to have auto indexing happening.
      class_attribute :kithe_indexable_auto_callbacks, default: true

      # Attribute names (symbols or strings) that do NOT affect indexing, changes only
      # to these attributes will not result in a re-index.
      #
      #     self.kithe_indexable_non_indexed_attributes = [:json_attributes, :internal_note]
      #
      class_attribute :kithe_indexable_non_indexed_attributes, default: nil

      # An allow-list alternative to kithe_indexable_non_indexed_attributes. If set, ONLY
      # changes to listed attributes will trigger reindex. Create and destroy still always do.
      #
      #     self.kithe_indexable_only_indexed_attributes = [:title, :description]
      #
      class_attribute :kithe_indexable_only_indexed_attributes, default: nil

      # To support kithe_indexable_non_indexed_attributes and kithe_indexable_only_indexed_attributes,
      # accumulate names of changed attributes across all saves in a transaction, since after_commit
      # has lost access to them from multiple individual saves in a transaction.
      after_save :_kithe_track_changed_attributes
      after_touch :_kithe_track_changed_attributes
      after_rollback { @_kithe_changed_attributes = nil }

      # after new, update, destroy, all of em. We'll figure out what to do
      # in the RecordIndexUpdater.
      #
      # The changed attribute tracking check comes first, it must always run (and reset) even when
      # auto_callbacks? is false.
      after_commit :update_index, if: -> {
        _kithe_check_possibly_indexed_changes_and_reset && Kithe::Indexable.auto_callbacks?(self)
      }
    end

    # Update the Solr index for this object -- may remove it from index or add it to
    # index depending on state.
    #
    # Will use the configured kithe_indexable_mapper by default, or you can pass one in.
    #
    # By default will use a per-update writer, or thread/block-specific writer configured with `self.index_with`,
    # or you can pass one in.
    #
    # This method is part of Kithe API, including allowing local apps to override! Backwards
    # compatibilty matters for semver with any change to method signature.
    def update_index(mapper: kithe_indexable_mapper, writer:nil)
      RecordIndexUpdater.new(self, mapper: mapper, writer: writer).update_index
    end

    private

    def _kithe_track_changed_attributes
      (@_kithe_changed_attributes ||= Set.new).merge(saved_changes.keys)
    end

    # For the after_commit callback condition: true if this was a destroy, or any attribute changed in
    # this transaction is considered indexed. A save with no changes at all does not index.
    # Also resets tracking for the next transaction, which is done here so it is read before it is
    # reset, regardless of after_commit callback ordering.
    def _kithe_check_possibly_indexed_changes_and_reset
      changed = @_kithe_changed_attributes.to_a
      @_kithe_changed_attributes = nil

      # insist on including primary keys as indexed, to make sure we index on create.
      primary_keys = Array(self.class.primary_key).map(&:to_s)

      non_indexed = if kithe_indexable_non_indexed_attributes.present?
        # if we are excluding any, we need to exclude updated_at too, or it will end up trigger anyway
        kithe_indexable_non_indexed_attributes.map(&:to_s) - primary_keys + AUTO_TIMESTAMP_ATTRIBUTES
      end

      only_indexed = if kithe_indexable_only_indexed_attributes.present?
        kithe_indexable_only_indexed_attributes.map(&:to_s) + primary_keys
      end

      if only_indexed
        changed = changed & only_indexed
      end

      if non_indexed
        changed = changed - non_indexed
      end

      destroyed? || changed.any?
    end
  end
end
