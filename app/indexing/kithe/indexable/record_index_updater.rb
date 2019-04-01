module Kithe
  module Indexable
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
