require 'shrine/storage/url'

class Shrine
  module Plugins
    # Set file location to "asset/#{asset_uuid_id}/#{unique_file_id}" -- regardless of
    # asset sub-class, since they all have unique ids, just all under asset/.
    #
    # If no Asset pk is available (direct upload or unsaved Asset), will be stored just
    # under "asset/#{unique_file_id}.#{suffix}"
    #
    # We are choosing to store under Asset UUID PK instead of friendlier_id, friendlier_id
    # is good for public URLs and UI, but actual PK is more reliable/immutable.
    #
    # ALSO: this plugin takes care of bad names from use of shrine-url with query params,
    # when storage "remote_url" is recognized.
    module KitheStorageLocation
      module InstanceMethods
        def generate_location(io, context)
          # If it doesn't have a id, we're probably storing in cache, possibly as part
          # of direct upload endpoint. A better path will be created on store.
          id = context[:record].id if context[:record].respond_to?(:id)

          # remove query param from shrine-url ids that are urls, that is not actually part of
          # filename and should not be part of location. workaround.
          # https://github.com/shrinerb/shrine-url/issues/4
          # Not needed when https://github.com/shrinerb/shrine/pull/326 is in a shrine release.
          basename = super
          if io.respond_to?(:storage) && io.storage.is_a?(Shrine::Storage::Url)
            basename = URI.parse(basename).path
          end

          ["asset", id, basename].compact.join("/")
        end
      end
    end
    register_plugin(:kithe_storage_location, KitheStorageLocation)
  end
end
