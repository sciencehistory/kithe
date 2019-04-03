# TODO. Docs
# TODO need a `with_writer` or `with_indexing` or whatever method, that prob uses a thread-current.
# TODO, we are assuming id->id solr mapping, for deletion callbacks.
module Kithe
  module Indexable
    extend ActiveSupport::Concern

    class IndexableSettings
      attr_accessor :solr_url, :writer_class_name, :writer_settings, :model_name_solr_field, :disable_callbacks
      def initialize(solr_url:, writer_class_name:, writer_settings:, model_name_solr_field:, disable_callbacks: false)
        @solr_url = solr_url
        @writer_class_name = writer_class_name
        @writer_settings = writer_settings
        @model_name_solr_field = model_name_solr_field
      end

      def writer_settings
        if solr_url
          { "solr.url" => solr_url }.merge(@writer_settings)
        else
          @writer_settings
        end
      end

      def writer_class
        writer_class_name.constantize
      end

      def writer_instance!(additional_settings = {})
        writer_class.new(writer_settings.merge(additional_settings))
      end
    end

    mattr_accessor :settings do
      IndexableSettings.new(
        solr_url: "http://localhost:8983/solr/default",
        model_name_solr_field: "model_name_ssi",
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
          # no skippable exceptions please
          # "solr_writer.skippable_exceptions" => []
        }
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
    def self.index_with(batching: false, auto_callbacks: true, writer: nil, on_finish: nil)
      settings = ThreadSettings.push(
        batching: batching,
        auto_callbacks: auto_callbacks,
        writer: writer,
        on_finish: on_finish)

      yield settings
    ensure
      settings.pop if settings
    end

    def self.auto_callbacks?(model)
      !Kithe::Indexable.settings.disable_callbacks &&
        model.kithe_indexable_auto_callbacks &&
        model.kithe_indexable_mapper &&
        !ThreadSettings.current.suppressed_callbacks?
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
