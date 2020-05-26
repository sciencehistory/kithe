require 'shrine/storage/url'

class Shrine
  module Plugins
    # Set custom storage locations/paths for both the original file which is the main
    # file in the shrine attachment at Asset#file, and any shrine derivatives.
    #
    # Shrine's default is to just put both of these at top-level `[randomID].suffix`. We
    # instead:
    #
    # ## Original file
    #
    # Stored at `asset/#{asset_uuid_id}/#{unique_file_id}.suffix` -- regardless of
    # asset sub-class, since they all have unique ids, just all under asset/. (In retrospect,
    # maybe shoudl have left `asset/` off, and let consumer specify a prefix when configuring
    # storage).
    #
    # If no Asset pk is available (direct upload or unsaved Asset), will be stored just
    # under "asset/#{unique_file_id}.#{suffix}"
    #
    # We are choosing to store under Asset UUID PK instead of friendlier_id, friendlier_id
    # is good for public URLs and UI, but actual PK is more reliable/immutable.
    #
    # ## Derivatives
    #
    # Stored at `#{asset_uuid_id}/derivative_key/#{unique_file_id}.suffix`.
    #
    # If asset uuid pk is not available, will raise a TypeError and refuse to store
    # derivative. (This may have to be thought through more.)
    #
    # If you want an additional prefix, supply it hwen configuring kithe_derivatives
    # storage.
    module KitheStorageLocation
      module InstanceMethods
        def generate_location(io, derivative: nil, **context)
          original = super

          if derivative
            _kithe_generate_derivative_location(io, original: original, derivative: derivative, **context)
          else
            _kithe_generate_main_location(io, original: original, **context)
          end
        end

        private

        def _kithe_generate_main_location(io, original:, **context)
          # If it doesn't have a id, we're probably storing in cache, possibly as part
          # of direct upload endpoint. A better path will be created on store.
          id = context[:record].id if context[:record].respond_to?(:id)

          basename = original

          ["asset", id, basename].compact.join("/")
        end

        # Usually NOT in the same bucket/prefix as the originals/main attachments.
        # You can set a prefix yourself in your shrine storage config if you want them
        # on the same bucket, and probably should.
        def _kithe_generate_derivative_location(io, original:, derivative:, record:, **context)
          # for now to be save, insist the record exist and have an id so we can get the
          # correct derivative location. This is consistent with kithe 1.x behavior. We can
          # enhance later maybe.
          unless record && record.id
            raise TypeError.new("Can't determine correct derivative location without a persisted record. Record: #{record}")
          end
          unless derivative && original
            raise ArgumentError.new("Missing required argument")
          end

          [record.id, derivative, original].join("/")
        end
      end
    end
    register_plugin(:kithe_storage_location, KitheStorageLocation)
  end
end
