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
  #
  # When magicc-byte analyzer can't determine mime type, will fall back to  `mediainfo`
  # CLI _if_ `Kithe.use_mediainfo` is true (defaults to true if mediainfo CLI is
  # available). (We need better ways to customize uploader.)
  class AssetUploader < Shrine
    plugin :activerecord

    # useful in forms to preserve entry on re-showing a form on validation error,
    # so it can be submitted again.
    plugin :cached_attachment_data

    # Used in a before_promotion hook to have our metadata extraction happen on
    # promotion, possibly in the background.
    plugin :refresh_metadata

    plugin :kithe_determine_mime_type

    # Will save height and width to metadata for image types. (Won't for non-image types)
    # ignore errors (often due to storing a non-image file), consistent with shrine 2.x behavior.
    plugin :store_dimensions, on_error: :ignore

    # Useful in case consumers want it, and doesn't harm anything to be available.
    # https://github.com/shrinerb/shrine/blob/master/doc/plugins/rack_response.md
    plugin :rack_response

    # Set up logic for backgrounding, which can be set by promotion_directives
    plugin :kithe_controllable_backgrounding

    plugin :add_metadata

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
      if context[:action] != :cache
        {
          md5: calculate_signature(io, :md5),
          sha1: calculate_signature(io, :sha1),
          sha512: calculate_signature(io, :sha512)
        }
      end
    end
    metadata_method :md5, :sha1, :sha512


    # Gives us (set_)promotion_directives methods on our attacher to
    # house lifecycle directives, about whether promotion, deletion,
    # derivatives happen in foreground, background, or not at all.
    plugin :kithe_promotion_directives

    plugin :kithe_promotion_callbacks
  end
end
