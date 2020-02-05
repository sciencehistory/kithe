require "shrine/storage/url"

class Shrine
  module Plugins
    # This plugin supports assigning remote URLs to shrine attachments, in uploaders
    # that have normal default cache storage.
    #
    # It also supports specifying custom request headers for those remote URLs, to
    # support OAuth2 Authorization headers, with browse-everything or similar.
    #
    #     model.attachment_column = {
    #       "storate" => "remote_url",
    #       "id" => "http://example.com/image.jpg",
    #       "headers" => {
    #         "Authorization" => "something"
    #       }
    #     }
    #
    # If you provide the (optional) "headers" key, they will wind up stored with
    # file data in "metadata" hash, as "remote_url_headers". And they will be
    # used with HTTP request to fetch the URL given, when promoting.
    #
    # The implementation uses the shrine-url storage, registering it as storage with key "remote_url";
    # our custom kithe_multi_cache plugin to allow this alternate storage to be set as
    # cache even though it's not main cache; and a #promote override suggested by
    # Janko@shrine to get request headers to be supported.
    #
    # Testing is done in context of Asset model, see asset_spec.rb.
    #
    # FUTURE. Need to whitelist allowed URLs/hostnames. :( A pain cause it'll
    # be different for different apps, so we need to allow uploader customization?
    class KitheAcceptRemoteUrl
      STORAGE_KEY = :remote_url
      METADATA_KEY = "remote_url_headers"

      def self.configure(uploader, options = {})
        # Ensure remote_url is registered as a storage
        #
        # Lazy default to make it easier to specify other if an app wants to.
        uploader.storages[STORAGE_KEY] ||= Shrine::Storage::Url.new
      end

      def self.load_dependencies(uploader, *)
        # Make sure the uploader will accept assignments/promotion from remote_url, using
        # our multi_cache plugin.
        uploader.plugin :kithe_multi_cache, additional_cache: :remote_url
      end

      module FileMethods
        attr_reader :url_fetch_headers
        def initialize(data)
          # passed in as headers top-level key, but any but whitelisted keys actually
          # end up being thrown out by shrine, and too hard to change that, so
          # we'll copy it to 'metadata'
          if data["storage"].to_s == STORAGE_KEY.to_s && data["headers"]
            data["metadata"] ||= {}
            data["metadata"][METADATA_KEY] = data["headers"]
          end
          super
        end
      end

      module AttacherMethods

        # Override to use 'headers' key in UploadedFile data for making remote request,
        # when remote_url is being supplied.
        def promote(storage: store_key, **options)
          if file.storage_key.to_s == STORAGE_KEY.to_s && file.data.dig("metadata", METADATA_KEY)
            # instead of having Shrine "open" the file itself, we'll "open" it ourselves, so
            # we can add supplied headers. Due to the beauty of design of `down` and `shrine-url`,
            # and lazy opening, they'll end up using what we already opened. This approach
            # suggested by Janko.
            # https://groups.google.com/d/msg/ruby-shrine/SbeGujDa_k8/PeSGwpl9BAAJ
            file.open(headers: file.data.dig("metadata", METADATA_KEY))
          end
          super
        end
      end
    end
    register_plugin(:kithe_accept_remote_url, KitheAcceptRemoteUrl)
  end
end
