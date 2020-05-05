require 'mini_mime'

class Shrine
  module Plugins
    # Some default configuration and customization and convenience methods
    # for using shrine's built-in derivatives. The metadata for shrine
    # derivatives is stored in the same JSON as the main file.
    #
    # * default kithe storage location of :kithe_derivatives
    # * nice metadata["filename"] for derivatives, instead of default shrine fairly
    #   random (filename ends up used by default in content-disposition headers when delivered)
    class KitheDerivatives
      def self.load_dependencies(uploader, *)
        uploader.plugin :derivatives, storage: -> (derivative) do
          # default derivatives storage to
          :kithe_derivatives
        end
      end

      module InstanceMethods

        # Override to fix "filename" metadata to be something reasonable, regardless
        # of what if anything was the filename of the IO being attached. shrine S3 will
        # insist on setting a default content-disposition with this filename.

        def extract_metadata(io, derivative:nil, **context)
          result = super

          if derivative && context[:record] && result["mime_type"]
            extension = MiniMime.lookup_by_content_type(result["mime_type"] || "")&.extension || "bin"
            result["filename"] = "#{context[:record].friendlier_id}_#{derivative}.#{extension}"
          end

          result
        end
      end

    end
    register_plugin(:kithe_derivatives, KitheDerivatives)
  end
end

