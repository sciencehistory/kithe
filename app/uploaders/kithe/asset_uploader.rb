module Kithe
  # The default shrine uploader class, for handling assets on Kithe::Asset.
  #
  # TODO: Needs to handle validations somehow with direct uploads and backgrounding.
  #
  # TODO: If we don't add FITS and anti-virus, at least sketch out how they could be
  # added by local app, make sure we have architecture to support it. Likely related
  # to backgrounding metadata/validation.
  #
  # TODO: PDF-specific metadata extraction (page number) (may need shrine feature),
  # as well as locally customized metadata pattern in general.
  #
  # FUTURE: Needs ways to customize. Including adding metadata extractors, validations,
  # and also possibly changing things (like determine_mime_type analyzer etc)
  #   * config that turns on/off or changes certain things?
  #   * Way to supply your own completely custom Uploader class?
  #     * Could be a sub-class of this one?
  #     * Some kithe behavior implemented as shrine plugins so you can easily re-use?
  #
  # FUTURE: Look at using client-side-calculated checksums to verify end-to-end.
  # https://github.com/shrinerb/shrine/wiki/Using-Checksums-in-Direct-Uploads
  class AssetUploader < Shrine
    plugin :activerecord

    # Marcel analyzer is pure-ruby and fast. It's from Basecamp and is what
    # ActiveStorage uses. It is very similar to :mimemagic (and uses mimemagic
    # under the hood), but mimemagic seems not to be maintained with up to date
    # magic db? https://github.com/minad/mimemagic/pull/66
    plugin :determine_mime_type, analyzer: :marcel

    # Will save height and width to metadata for image types. (Won't for non-image types)
    plugin :store_dimensions

    # promotion and deletion will be in background.
    plugin :backgrounding
    Attacher.promote { |data| Kithe::AssetPromoteJob.perform_later(data) }
    Attacher.delete { |data| Kithe::AssetDeleteJob.perform_later(data) }

    plugin :add_metadata

    # So we can assign a hash representing cached file
    plugin :parsed_json

    # Makes files stored as /asset/#{asset_pk}/#{random_uuid}.#{original_suffix}
    plugin :kithe_storage_location

    # Allows you to assign hashes like:
    #    { "id" => "http://url", "storage" => "remote_url", headers: { "Authorization" => "Bearer whatever"}}
    # (headers optional), for fetching remote urls on promotion. Useful with browse-everything.
    # WARNING: There's no whitelist, will accept any url. Is this a problem?
    plugin :kithe_accept_remote_url

    # We want to store md5 and sha1 checksums (legacy compat), as well as
    # sha512 (more recent digital preservation recommendation: https://ocfl.io/draft/spec/#digests)
    #
    # We only calculate them on `store` action to avoid double-computation, and because for
    # direct uploads/backgrounding, we haven't actually gotten the file in our hands to compute
    # checksums until then anyway.
    plugin :signature
    add_metadata do |io, context|
      if context[:action] == :store
        {
          md5: calculate_signature(io, :md5),
          sha1: calculate_signature(io, :sha1),
          sha512: calculate_signature(io, :sha512)
        }
      end
    end
    metadata_method :md5, :sha1, :sha512

    # This makes sure metadata is extracted on promotion, and also supports promotion
    # callbacks (before/after/around) on the Kithe::Asset classes.
    plugin :kithe_promotion_hooks
  end
end
