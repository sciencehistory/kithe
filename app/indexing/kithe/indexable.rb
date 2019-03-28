# TODO. Docs
# TODO need a `with_writer` or `with_indexing` or whatever method, that prob uses a thread-current.
# TODO, we are assuming id->id solr mapping, for deletion callbacks.
module Kithe
  module Indexable
    extend ActiveSupport::Concern

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
        @writer ||= Traject::SolrJsonWriter.new(mapper.settings.merge("solr.url" => "http://localhost:8983"))
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
