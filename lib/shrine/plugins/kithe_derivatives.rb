require 'mini_mime'

class Shrine
  module Plugins
    # Includes the Shrine `derivatives` plugin with some configuration, and
    # extra features. The metadata for shrine derivatives is stored in the same
    # JSON as the main file.
    #
    # * default kithe storage location of :kithe_derivatives
    #
    # * nice metadata["filename"] for derivatives, instead of default shrine fairly
    #   random (filename ends up used by default in content-disposition headers when delivered)
    #
    # * Includes kithe_persisted_derivatives with #add_persisted_derivatives
    #   and #create_persisted_derivatives methods for concurrency-safe
    #   derivative persisting.
    #
    # ## Shrine derivatives references
    #
    # https://shrinerb.com/docs/plugins/derivatives
    # https://shrinerb.com/docs/processing
    class KitheDerivatives
      def self.load_dependencies(uploader, *)
        uploader.plugin :derivatives, storage: -> (derivative) do
          # default derivatives storage to
          :kithe_derivatives
        end

        uploader.plugin :kithe_persisted_derivatives
        uploader.plugin :kithe_derivative_definitions
      end

      module InstanceMethods

        # 1. Override to fix "filename" metadata to be something reasonable, regardless
        # of what if anything was the filename of the IO being attached. shrine S3 will
        # insist on setting a default content-disposition with this filename, so we
        # can use that.
        #
        # 2. Set any specified derivative metadata on derivative. Specified add_metadata
        # found in context.
        def extract_metadata(io, derivative:nil, **context)
          result = super

          if derivative && context[:record] && result["mime_type"]
            extension = MiniMime.lookup_by_content_type(result["mime_type"] || "")&.extension || "bin"
            result["filename"] = "#{context[:record].friendlier_id}_#{derivative}.#{extension}"
          end

          # If derivative, add timestamp and any specified extra data
          if derivative
            result["created_at"] ||= Time.current.utc.iso8601.to_s

            if (metadata = context.dig(:add_metadata, derivative)).present?
              result.merge!(metadata.stringify_keys)
            end
          end

          result
        end
      end

    end
    register_plugin(:kithe_derivatives, KitheDerivatives)
  end
end

