# TODO. Docs
# TODO need a `with_writer` or `with_indexing` or whatever method, that prob uses a thread-current.
# TODO, we are assuming id->id solr mapping, for deletion callbacks.
module Kithe
  module Indexable
    extend ActiveSupport::Concern

    # These settings need to be _global_, not class-inheritable. We'll put them
    # here for now, `Kithe::Indexable.solr_url = "https://whatever/solr/whatever"
    # They might go elsewhere later.
    mattr_accessor :solr_url do
      "http://localhost:8983/"
    end

    mattr_accessor :traject_writer_settings do
      {
        # for now we tell the solrjsonwriter to use no threads
        # no batching.
        "solr_writer.thread_pool" => 0,
        "solr_writer.batch_size" => 1,
      }
    end
    # add in the url setting on the fly, so changes change it appropriately.
    def self.composed_traject_writer_settings
      {"solr.url" => Kithe::Indexable.solr_url}.merge(self.traject_writer_settings)
    end

    mattr_accessor :traject_writer_class_name do
      "Traject::SolrJsonWriter"
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
    #  * Turn off callbacks.
    #  * Supply custom local writer.
    #  * supply custom writer options.
    #  * flush custom local writer?
    #  * optionally close custom local writer?
    #
    # Also pass in custom writer or mapper to #update_index
    def self.index_with(batching: false)
      local_writer = false

      if batching
        local_writer = true
        Thread.current[:kithe_indexable_writer] =
          traject_writer_class_name.constantize.new(
            composed_traject_writer_settings.merge(
              "solr_writer.batch_size" => 100,
              "solr.url" => Kithe::Indexable.solr_url
            )
          )
      end

      if local_writer
        original_writer = Thread.current[:kithe_indexable_writer]
      end

      yield
    ensure
      if local_writer
        Thread.current[:kithe_indexable_writer].close
        Thread.current[:kithe_indexable_writer] = original_writer
      end
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
      after_commit :update_index, if: -> { kithe_indexable_auto_callbacks && kithe_indexable_mapper }
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
        # TODO solr_url should be from config. Actually move it to
        # defaults in Kithe::Indexer?
        @writer ||= Thread.current[:kithe_indexable_writer] || Kithe::Indexable.traject_writer_class_name.constantize.new(Kithe::Indexable.composed_traject_writer_settings)
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
