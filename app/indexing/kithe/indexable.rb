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
  #     Kithe::Indexable.settings.solr_url = "http://localhost:8983/solr/collection_name"
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

    class IndexableSettings
      attr_accessor :solr_url, :writer_class_name, :writer_settings,
                    :model_name_solr_field, :solr_id_value_attribute, :disable_callbacks
      def initialize(solr_url:, writer_class_name:, writer_settings:,
                     model_name_solr_field:, solr_id_value_attribute:, disable_callbacks: false)
        @solr_url = solr_url
        @writer_class_name = writer_class_name
        @writer_settings = writer_settings
        @model_name_solr_field = model_name_solr_field
        @solr_id_value_attribute = solr_id_value_attribute
      end

      # Use configured solr_url, and merge together with configured
      # writer_settings
      def writer_settings
        if solr_url
          { "solr.url" => solr_url }.merge(@writer_settings)
        else
          @writer_settings
        end
      end

      # Turn writer_class_name into an actual Class object.
      def writer_class
        writer_class_name.constantize
      end

      # Instantiate a new writer based on `writer_class_name` and `writer_settings`
      def writer_instance!(additional_settings = {})
        writer_class.new(writer_settings.merge(additional_settings))
      end
    end

    # Global Kithe::Indexable settings, actually a Kithe::Indexable::Settings
    # object, but you will generally use it as a simple value object with getters
    # and setters.
    #
    # * solr_url: Where to send to Solr when indexing, the base url
    #
    #     Kithe::Indexable.settings.solr_url = "http://localhost:8983/solr/collection_name"
    #
    # * model_name_solr_field: If you'd like a custom solr field to store model class name in.
    #
    #     Kithe::Indexable.settings.model_name_solr_field = "my_model_name_field"
    #
    # * solr_id_value_attribute: What attribute from your AR models to send to Solr
    #   `id` uniqueKey field, default the AR `id` pk, you may wish to set to `friendlier_id`.
    #
    # * writer_settings: Settings to be passed to the Traject writer, by default a
    #   Traject::SolrJsonWriter. To maintain the default settings, best to merge
    #   your new ones into defaults.
    #
    #       Kithe::Indexable.settings.writer_settings.merge!(
    #         # by default we send a softCommit on every update, maybe you
    #         # want not to?
    #         "solr_writer.solr_update_args" => {}
    #         # extra long timeout?
    #         "solr_writer.http_timeout" => 100
    #       )
    #
    # * writer_class_name: By default Traject::SolrJsonWriter, but maybe
    #   you want to set to some other Traject::Writer. The writer Kithe::Indexable
    #   will send index add/remove requests to.
    #
    #       Kithe::Indexable.settings.writer_class_name = "Traject::SomeOtherWriter"
    #
    # * disable_callbacks: set to true to globally disable automatic after_commit
    mattr_accessor :settings do
      # set up default settings
      IndexableSettings.new(
        solr_url: "http://localhost:8983/solr/default",
        model_name_solr_field: "model_name_ssi",
        solr_id_value_attribute: "id",
        writer_class_name: "Traject::SolrJsonWriter",
        writer_settings: {
          # as default we tell the solrjsonwriter to use no threads,
          # no batching. softCommit on every update. Least surprising
          # default configuration.
          "solr_writer.thread_pool" => 0,
          "solr_writer.batch_size" => 1,
          "solr_writer.solr_update_args" => { softCommit: true },
          "solr_writer.http_timeout" => 3,
          "logger" => Rails.logger,

          # MAYBE? no skippable exceptions please
          # "solr_writer.skippable_exceptions" => []
        },
        disable_callbacks: false
      )
    end


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
    # * Globally in `Kithe::Indexable.settings.disable_callback`
    # * On class or instance using class_attribute `kithe_indexable_auto_callbacks`
    # * If no kithe_indexable_mapper is configured on record, then no callbacks.
    # * Using thread-current settings usually set by .index_with
    def self.auto_callbacks?(model)
      !Kithe::Indexable.settings.disable_callbacks &&
        model.kithe_indexable_auto_callbacks &&
        model.kithe_indexable_mapper &&
        !ThreadSettings.current.disabled_callbacks?
    end

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

      # after new, update, destroy, all of em. We'll figure out what to do
      # in the RecordIndexUpdater.
      after_commit :update_index, if: -> { Kithe::Indexable.auto_callbacks?(self) }
    end

    # Update the Solr index for this object -- may remove it from index or add it to
    # index depending on state.
    #
    # Will use the configured kithe_indexable_mapper by default, or you can pass one in.
    #
    # By default will use a per-update writer, or thread/block-specific writer configured with `self.index_with`,
    # or you can pass one in.
    def update_index(mapper: kithe_indexable_mapper, writer:nil)
      RecordIndexUpdater.new(self, mapper: mapper, writer: writer).update_index
    end
  end
end
