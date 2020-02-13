class Shrine
  module Plugins
    class KitheMetadataOnPromote
      # Simply makes it so metadata is refreshed before promotion, with `promoting: true` added
      # to context.
      #
      # The point ot this is for promotion in bg using backgrounding,
      # where you have some metadata set only for promotion in bg. But for consistency
      # it will refresh metadata on any promotion. See also https://shrinerb.com/docs/metadata#a-extracting-with-promotion
      #
      # You may want to guard metadata extractions with `context[:action] != :cache` (do not
      # extract in initial cache phase), or `context[:promoting] != true` (extract in cache phase
      # but not in promotion phase). Using these `!=` comparisons, you still get everything
      # re-extracted on a simple `refresh_metdata!` to recalculate.
      module AttacherMethods
        def promote(**options)
          self.refresh_metadata!(promoting: true)

          super
        end
      end
    end
    register_plugin(:kithe_metadata_on_promote, KitheMetadataOnPromote)
  end
end
