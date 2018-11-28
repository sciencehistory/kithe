module Kithe
  # The derivative uploader doesn't have to do too much, we don't even use
  # promotion for derivatives, just writing directly to a storage.
  #
  # But it needs activerecord integration, and limited metadata automatic extraction.
  class DerivativeUploader < Shrine
    plugin :activerecord

    plugin :determine_mime_type, analyzer: :marcel
    plugin :store_dimensions


    # should this be in a plugin? location in file system based on original asset
    # id and derivative key, as well as unique random file id from shrine.
    def generate_location(io, context)
      # assumes we're only used with Derivative model, that has an asset_id and key
      asset_id = context[:record].asset_id
      key = context[:record].key
      original = super
      [asset_id, key, original].compact.join("/")
    end
  end
end
