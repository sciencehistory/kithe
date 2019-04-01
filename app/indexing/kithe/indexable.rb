# TODO. Docs
# TODO need a `with_writer` or `with_indexing` or whatever method, that prob uses a thread-current.
# TODO, we are assuming id->id solr mapping, for deletion callbacks.
module Kithe
  module Indexable
    extend ActiveSupport::Concern

    class IndexableSettings
      attr_accessor :solr_url, :writer_class_name, :writer_settings
      def initialize(solr_url:, writer_class_name:, writer_settings:)
        @solr_url = solr_url
        @writer_class_name = writer_class_name
        @writer_settings = writer_settings
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
        writer_class_name: "Traject::SolrJsonWriter",
        writer_settings: {
          # as default we tell the solrjsonwriter to use no threads,
          # no batching. softCommit on every update. Least surprising
          # default configuration.
          "solr_writer.thread_pool" => 0,
          "solr_writer.batch_size" => 1,
          "solr_writer.solr_update_args" => { softCommit: true }
        }
      )
    end


    # in progress, really ugly implementation.
    #
    # Set some indexing parameters for the block yielded. For instance, to batch updates:
    #
    #     Kithe::Indexable.index_with(batching: true)
    #        lots_of_records.each(&:update_index)
    #     end
    #
    # And they will use a batching Traject writer for much more efficiency.
    #
    #
    # What else do we want?
    #  * Supply custom local writer.
    #  * supply custom writer options.
    #  * flush custom local writer?
    #  * optionally close custom local writer?
    #  * we need a way to specify in index_with whether to do commits on every update, commits at end, and soft/hard
    #     * batching by default should not do softCommits, but do a commit at the end instead. Even though
    #       by default other writes do soft commits.
    #
    # Also pass in custom writer or mapper to #update_index
    def self.index_with(batching: false, auto_callbacks: true)
      settings = ThreadSettings.push(batching: batching, auto_callbacks: auto_callbacks)
      yield settings
    ensure
      settings.pop
    end

    def self.auto_callbacks?(model)
      model.kithe_indexable_auto_callbacks && model.kithe_indexable_mapper && !ThreadSettings.current.suppressed_callbacks?
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
      class_attribute :kithe_indexable_auto_callbacks

      # after new, update, destroy, all of em. We'll figure out what to do
      # in the RecordIndexUpdater.
      after_commit :update_index, if: -> { Kithe::Indexable.auto_callbacks?(self) }
    end

    def update_index
      RecordIndexUpdater.new(self).update_index
    end

    class RecordIndexUpdater
      attr_reader :record
      def initialize(record)
        @record = record
      end

      def update_index
        if should_be_in_index?
          mapper.process_with([record]) do |context|
            writer.put(context)
          end
        else
          writer.delete(record.id)
        end
      end

      def writer
        @writer ||= ThreadSettings.current.writer  || Kithe::Indexable.settings.writer_instance!
      end

      # A traject Indexer, probably a subclass of Kithe::Indexer, that we are going to
      # use with `process_with`.
      def mapper
        if record.kithe_indexable_mapper.nil?
          raise TypeError.new("Can't call update_index without `kithe_indexable_mapper` given for #{record.inspect}")
        end
        record.kithe_indexable_mapper
      end

      def should_be_in_index?
        # TODO, add a record should_index? method like searchkick
        # https://github.com/ankane/searchkick/blob/5d921bc3da69d6105cbc682ea3df6dce389b47dc/lib/searchkick/record_indexer.rb#L44
        !record.destroyed? && record.persisted?
      end
    end

  end
end
