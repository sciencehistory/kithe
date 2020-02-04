require "shrine/storage/url"

class Shrine
  module Plugins
    # This plugin supports assigning remote URLs to shrine attachments, in uploaders
    # that have normal default cache storage.
    #
    # It also supports specifying custom request headers for those remote URLs, to
    # support OAuth2 Authorization headers, with browse-everything or similar.
    #
    # It uses the shrine-url storage, registering it as storage with key "remote_url";
    # our custom kithe_multi_cache plugin to allow this alternate storage to be set as
    # cache even though it's not main cache; and a #promote override suggested by
    # Janko@shrine to get request headers to be supported.
    #
    # Testing is done in context of Asset model, see asset_spec.rb.
    #
    # FUTURE. Need to whitelist allowed URLs/hostnames. :( A pain cause it'll
    # be different for different apps, so we need to allow uploader customization?
    class KitheAcceptRemoteUrl
      def self.configure(uploader, options = {})
        # Ensure remote_url is registered as a storage
        # Note, using downloader: :net_http so it can be tested with WebMock, would be
        # better not to have to do that.
        # https://github.com/shrinerb/shrine-url/issues/5
        #
        # Lazy default to make it easier to specify other.
        uploader.storages[:remote_url] ||= Shrine::Storage::Url.new
      end

      def self.load_dependencies(uploader, *)
        # Make sure the uploader will accept assignments/promotion from remote_url, using
        # our multi_cache plugin.
        uploader.plugin :kithe_multi_cache, additional_cache: :remote_url
      end

      module AttacherMethods
        # Override to use 'headers' key in UploadedFile data for making remote request,
        # when remote_url is being supplied.
        def promote(storage: store_key, **options)
          if storage.to_s == "remote_url" && file.data["headers"]
            # instead of having Shrine "open" the file itself, we'll "open" it ourselves, so
            # we can add supplied headers. Due to the beauty of design of `down` and `shrine-url`,
            # and lazy opening, they'll end up using what we already opened. This approach
            # suggested by Janko.
            # https://groups.google.com/d/msg/ruby-shrine/SbeGujDa_k8/PeSGwpl9BAAJ
            file.open(headers: file.data["headers"])
          end
          super
        end
      end
    end
    register_plugin(:kithe_accept_remote_url, KitheAcceptRemoteUrl)
  end
end
