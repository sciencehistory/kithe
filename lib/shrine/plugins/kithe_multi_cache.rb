class Shrine
  module Plugins
    # Allows an uploader to have more than one 'cache' -- although the main one registered
    # as normal will ordinarily be used, you can manually assign UploadedFiles (or hashes)
    # specifying other caches, and they will be accepted, and promoted.
    #
    # Invented for use with shrine-url.
    #
    #     Shrine.storages = {
    #       cache: ...,
    #       store: ...,
    #       remote_url: Shrine::Storage::Url.new
    #      }
    #
    #     class SomeUploader < Shrine
    #       plugin :kithe_multi_cache, additional_cache: [:remote_url, :something_else]
    #       ...
    #     end
    #
    # Now in your model, you can
    #
    #     my_model.attached_file = { "id" => "http://example.com", "storage" => "remote_url"}
    #
    # And the data can be saved, and the remote url (shrine-url) file will be promoted as usual,
    # even though it's not registered as the cache storage.
    #
    # NOTE: This implementation can be made a lot simpler once this PR is in a shrine release:
    # https://github.com/shrinerb/shrine/pull/319
    # https://github.com/shrinerb/shrine/commit/88c23d54814568b04987680f00b6b36f421c8d81
    module KitheMultiCache
      def self.configure(uploader, options = {})
        uploader.opts[:kithe_multi_cache_keys]  = Array(options[:additional_cache]).collect(&:to_s)
      end

      # override #cache to lazily extend with our custom module. Kinda hacky,
      # but couldn't think of any other way to only extend the "cache" uploader,
      # and not the "store" uploader.
      module AttacherMethods
        def cache(*args)
          cache_uploader = super

          unless @kithe_multi_cache_overridden
            cache_uploader.extend(CacheInstanceMethods)
            @kithe_multi_cache_overridden = true
          end

          cache_uploader
        end
      end

      # Not a standard shrine plugin module, one we manually use to extend
      # just the cache object.
      module CacheInstanceMethods
        def uploaded?(uploaded_file)
          super || opts[:kithe_multi_cache_keys].include?(uploaded_file.storage_key)
        end
      end
    end

    register_plugin(:kithe_multi_cache, KitheMultiCache)
  end
end
