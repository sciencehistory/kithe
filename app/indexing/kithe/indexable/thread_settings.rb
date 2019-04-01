module Kithe
  module Indexable
    class ThreadSettings
      THREAD_CURRENT_KEY = :kithe_indexable_current_writer_settings

      def self.push(**kwargs)
        original = Thread.current[THREAD_CURRENT_KEY]
        instance = new(kwargs.merge(original_settings: original))
        Thread.current[THREAD_CURRENT_KEY] = instance

        instance
      end

      # Returns a ThreadSettings currently stored in Thread.current, or else
      # A Null object (Null Object Pattern) representings no settings.
      def self.current
        Thread.current[THREAD_CURRENT_KEY] || NullSettings.new
      end

      # Nobody uses this it's private, use Kithe::Indexable::ThreadSettings.push, and
      # some_thread_settings.pop or Kithe::Indexable::ThreadSettings.current.pop
      def initialize(batching:, auto_callbacks:, original_settings:,
        writer:)
        @original_settings = original_settings
        @batching = !!batching
        @suppress_callbacks = !auto_callbacks

        @writer = writer

        if @batching && @writer
          raise ArgumentError.new("either `batching:true` convenience, or `writer:` specified, you can't do both")
        end


        @local_writer = false
      end
      private_class_method :new # should use class.push and instance.pop instead.


      def writer
        @writer ||= begin
          if @batching
            @local_writer = true
            Kithe::Indexable.settings.writer_instance!("solr_writer.batch_size" => 100)
          end
        end
      end

      def suppressed_callbacks?
        @suppress_callbacks
      end

      def pop
        if @local_writer
          writer.close
        end
        Thread.current[THREAD_CURRENT_KEY] = @original_thread_current_settings
      end

      private

      class NullSettings
        # need do nothing on pop, cause we're nothing.
        def pop
        end

        # no local writer
        def writer
        end

        # no suppressed callbacks
        def suppressed_callbacks?
          false
        end
      end
    end
  end
end