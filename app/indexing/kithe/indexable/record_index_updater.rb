module Kithe
  module Indexable
    # The class actually responsible for updating a record to Solr.
    # Normally called from #update_index in a Kithe::Indexable model.
    #
    #     Kithe::Indexable::RecordIndexUpdater.new(model).update_index
    #
    # #update_index can add _or_ remove the model from Solr index, depending on model
    # state.
    #
    # The RecordIndexUpdater will determine the correct Traject::Writer to send output to, from local
    # initialize argument, current thread settings (usually set by Kithe::Indexable.index_with),
    # or global settings.
    class RecordIndexUpdater
      # record to be sync'd to Solr or other index
      attr_reader :record

      # @param record [ActiveRecord::Base] The record to be sync'd to index, usually
      #   a Kithe::Model
      #
      # @param mapper [Traject::Indexer] Can pass in a custom Traject::Indexer to use
      #   to map from source record to index (Solr) document. Any configured 'writer'
      #   in the indexer is ignored, we decouple Traject indexer from writer. By default
      #   it's nil, meaning we'll find the indexer to use from current thread settings,
      #   or global settings.
      #
      # @param writer [Traject::Writer] Can pass i a custom Traject::Writer which the
      #   index representation will be sent to. By default it's nil, meaning we'll find
      #   the writer to use from current thread settings or global settings.
      def initialize(record, mapper:nil, writer:nil)
        @record = record
        @writer = writer
        @mapper = mapper
      end

      # Sync #record to the (Solr) index. Depending on record state, we may:
      #
      # * Add object to index. Run it through the current #mapper, then send it to the
      #   current #writer with `writer.put`
      # * Remove object from index. Call `#delete(id)` on the current #writer.
      def update_index
        if should_be_in_index?
          mapper.process_with([record]) do |context|
            writer.put(context)
          end
        else
          writer.delete(record.id)
        end
      end

      # The Traject::Indexer we'll use to map the #record into an index representation,
      # by calling #process_with on the indexer.
      #
      # If a mapper was passed in #initialize, that'll be used. Otherwise the one set
      # on the record's class_attribute `kithe_indexable_mapper` will be used.
      #
      # If no mapper can be found, raises a TypeError.
      def mapper
        @mapper ||= begin
          if record.kithe_indexable_mapper.nil?
            raise TypeError.new("Can't call update_index without `kithe_indexable_mapper` given for #{record.inspect}")
          end
          record.kithe_indexable_mapper
        end
      end

      # The Traject::Writer we'll send the indexed representation to after mapping it.
      # Could be an explicit writer passed into #initialize, or a current thread-settings
      # writer, or a new writer created from global settings.
      def writer
        @writer ||= ThreadSettings.current.writer  || Kithe::Indexable.settings.writer_instance!
      end

      # Is this record supposed to be represented in the solr index?
      def should_be_in_index?
        # TODO, add a record should_index? method like searchkick
        # https://github.com/ankane/searchkick/blob/5d921bc3da69d6105cbc682ea3df6dce389b47dc/lib/searchkick/record_indexer.rb#L44
        !record.destroyed? && record.persisted?
      end
    end
  end
end
