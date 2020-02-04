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

    # Marcel analyzer is pure-ruby and fast. It's from Basecamp and is what
    # ActiveStorage uses. It is very similar to :mimemagic (and uses mimemagic
    # under the hood), but mimemagic seems not to be maintained with up to date
    # magic db? https://github.com/minad/mimemagic/pull/66
    plugin :determine_mime_type, analyzer: -> (io, analyzers) do
      mime_type = analyzers[:marcel].call(io)

      # But marcel is not able to catch some of our MP3s as audio/mpeg,
      # let's try mediainfo command line. mediainfo is one of the tools
      # the Harvard Fits tool uses. https://github.com/MediaArea/MediaInfo
      if Kithe.use_mediainfo && mime_type == "application/octet-stream" || mime_type.blank?
        mime_type = Kithe::MediainfoAnalyzer.new.call(io)
      end

      mime_type = "application/octet-stream" if mime_type.blank?

      mime_type
    end

    # Will save height and width to metadata for image types. (Won't for non-image types)
    plugin :store_dimensions

    # promotion and deletion will be in background.
    plugin :backgrounding

    # Useful in case consumers want it, and doesn't harm anything to be available.
    # https://github.com/shrinerb/shrine/blob/master/doc/plugins/rack_response.md
    plugin :rack_response

    # Normally we promote in background with backgrounding, but the set_promotion_directives
    # feature can be used to make promotion not happen at all, or happen in foreground.
    #     asset.file_attacher.set_promotion_directives(promote: false)
    #     asset.file_attacher.set_promotion_directives(promote: "inline")
    Attacher.promote_block do |**data|
      Kithe::TimingPromotionDirective.new(key: :promote, directives: data["promotion_directives"]) do |directive|
        if directive.inline?
          # Foreground, but you'll still need to #reload your asset to see changes,
          # since backgrounding mechanism still reloads a new instance, sorry.
          #Kithe::AssetPromoteJob.perform_now(data)
          promote
        elsif directive.background?
          # What shrine normally expects for backgrounding
          Kithe::AssetPromoteJob.perform_later(self.class.name, record.class.name, record.id, name, file_data)
        end
      end
    end

    # Delete using shrine backgrounding, but can be effected
    # by promotion_directives[:delete], similar to promotion above.
    # Yeah, not really a "promotion" directive, oh well.
    Attacher.destroy_block do |**data|
      Kithe::TimingPromotionDirective.new(key: :delete, directives: data["promotion_directives"]) do |directive|
        if directive.inline?
          destroy
        elsif directive.background?
          # What shrine normally expects for backgrounding
          Kithe::AssetDeleteJob.perform_later(data)
        end
      end
    end

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
