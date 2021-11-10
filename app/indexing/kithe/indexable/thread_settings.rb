module Kithe
  module Indexable
    # An object that is stored in Thread.current to represent current indexing/writing settings,
    # used to implement Kithe::Indexable.index_with
    #
    # The public API is that Kithe::Indexable.index_with calls:
    # * ThreadSettings.push(settings) to register current settings
    # * ThreadSettings.current.pop at end of block to un-register them
    #
    # Then code in Kithe::Indexable can check `ThreadSettings.current` to get
    # the current ThreadSettings. It returns a "null object" representing no
    # settings if there are none, so calling code can do things like:
    #
    #     ThreadSettings.current.disabled_callbacks?
    #
    # and
    #
    #     ThreadSettings.current.writer
    #
    # without worrying about if there are current settings.
    #
    class ThreadSettings
      THREAD_CURRENT_KEY = :kithe_indexable_current_writer_settings

      # @param (see #initialize)
      def self.push(**kwargs)
        original = Thread.current[THREAD_CURRENT_KEY]
        instance = new(**kwargs.merge(original_settings: original))
        Thread.current[THREAD_CURRENT_KEY] = instance

        instance
      end

      # Returns a ThreadSettings currently stored in Thread.current, or else
      # A Null object (Null Object Pattern) representings no settings.
      def self.current
        Thread.current[THREAD_CURRENT_KEY] || NullSettings.new
      end

      # Ordinarily you will not use this directly, it's called by .push.
      # But param definitions are here.
      #
      # @param batching [Boolean] if true, set up a batching writer. Incompatible
      #   with other writer-related settings.
      #
      # @param disable_callbacks [Boolean] if true, automatic after_commit callbacks
      #   are currently disabled.
      #
      # @param original_settings [ThreadSettings] when .push passes this in, so it
      #   can be restored on .pop
      #
      # @param writer [Traject::Writer] a writer to be used as current default for indexing.
      #   May be set up with unusual settings, or even be an unusual writer class.
      #
      # @param on_finish [Proc] proc object which will be called on .pop (normally at end of
      #   index_with block). It will be passed the operative Traject::Writer for that block.
      def initialize(batching:, disable_callbacks:, original_settings:,
        writer:, on_finish:)
        @original_settings = original_settings
        @batching = !!batching
        @disable_callbacks = disable_callbacks
        @on_finish = on_finish

        @writer = writer

        if @batching && @writer
          raise ArgumentError.new("either `batching:true` convenience, or `writer:` specified, you can't do both")
        end

        @local_writer = false
      end
      private_class_method :new # should use class.push and instance.pop instead.


      # Is there a writer configured for current settings? If so, return it. May
      # return nil.
      #
      # In case of `batching:true`, the batching writer will be lazily created on
      # first time #writer is asked for.
      def writer
        @writer ||= begin
          if @batching
            @local_writer = true
            Kithe.indexable_settings.writer_instance!("solr_writer.batch_size" => 100)
          end
        end
      end

      # Are automatic after_commit callbacks currently disabled?
      def disabled_callbacks?
        @disable_callbacks
      end

      # Remove this object from Thread.current, replacing with any previous current
      # settings.
      def pop
        # only call on-finish if we have a writer, batch writers are lazily
        # created and maybe we never created one
        if @writer
          # if we created the writer ourselves locally and nobody
          # specified an on_finish, close our locally-created writer.
          on_finish = if @local_writer && @on_finish.nil?
            proc {|writer| writer.close }
          else
            @on_finish
          end
          on_finish.call(@writer) if on_finish
        end

        Thread.current[THREAD_CURRENT_KEY] = @original_settings
      end

      private

      # "Null object" representing no current settings set.
      class NullSettings
        # need do nothing on pop, cause we're nothing.
        def pop
        end

        # no local writer
        def writer
        end

        # no suppressed callbacks
        def disabled_callbacks?
          false
        end
      end
    end
  end
end
