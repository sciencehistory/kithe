class Shrine
  module Plugins
    # Using the shrine signature and add_metadata plugins, ensure that the shrine standard
    # digest/checksum signatures are recorded in metadata.
    #
    # This plugin is NOT included in Kithe::AssetUploader by default, include it in your
    # local uploader if desired.
    #
    # We want to store md5 and sha1 checksums (legacy compat), as well as
    # sha512 (more recent digital preservation recommendation: https://ocfl.io/draft/spec/#digests)
    #
    # We only calculate them only on promotion action (not cache action), to avoid needlessly
    # expensive double-computation, and because for direct uploads/backgrounding, we haven't
    # actually gotten the file in our hands to compute checksums until then anyway.
    #
    # the add_metadata plugin's `metadata_method` is used to make md5, sha1, and sha512 methods
    # available on the Attacher. (They also end up delegated from the Asset model)
    class KitheChecksumSignatures
      def self.load_dependencies(uploader, *)
        uploader.plugin :add_metadata
        uploader.plugin :signature
      end

      def self.configure(uploader, opts = {})
        uploader.class_eval do
          add_metadata do |io, derivative:nil, **context|
            if context[:action] != :cache && derivative.nil?
              {
                md5: calculate_signature(io, :md5),
                sha1: calculate_signature(io, :sha1),
                sha512: calculate_signature(io, :sha512)
              }
            end
          end
          metadata_method :md5, :sha1, :sha512
        end
      end
    end
    register_plugin(:kithe_checksum_signatures, KitheChecksumSignatures)
  end
end
