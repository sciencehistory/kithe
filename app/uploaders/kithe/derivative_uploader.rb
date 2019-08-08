require 'mini_mime'

module Kithe
  # The derivative uploader doesn't have to do too much, we don't even use
  # promotion for derivatives, just writing directly to a storage.
  #
  # But it needs activerecord integration, and limited metadata automatic extraction.
  class DerivativeUploader < Shrine
    plugin :activerecord

    plugin :determine_mime_type, analyzer: :marcel
    # Will save height and width to metadata for image types. (Won't for non-image types)
    # on_error: :ignore is consistent with behavior < 2.19.0 shrine. We don't want
    # to log on errors of unrecognized file type for extracting height/width, that's
    # fine.
    plugin :store_dimensions, on_error: :ignore

    # Useful in case consumers want it, and doesn't harm anything to be available.
    # https://github.com/shrinerb/shrine/blob/master/doc/plugins/rack_response.md
    plugin :rack_response

    # should this be in a plugin? location in file system based on original asset
    # id and derivative key, as well as unique random file id from shrine.
    def generate_location(io, context)
      # assumes we're only used with Derivative model, that has an asset_id and key
      asset_id = context[:record].asset_id
      key = context[:record].key
      original = super
      [asset_id, key, original].compact.join("/")
    end


    # Override to fix "filename" metadata to be something reasonable, regardless
    # of what if anything was the filename of the IO being attached. shrine S3 will
    # insist on setting a default content-disposition with this filename.
    def extract_metadata(io, context = {})
      result = super

      if context.dig(:metadata, :kithe_derivative_key) &&
         context[:record]
        extension = MiniMime.lookup_by_content_type(result["mime_type"] || "")&.extension
        result["filename"] = "#{context[:record].asset.friendlier_id}_#{context[:metadata][:kithe_derivative_key]}.#{extension}"
      end

      return result
    end
  end
end
