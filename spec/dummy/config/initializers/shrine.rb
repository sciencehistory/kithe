# # For now, to get console to work with shrine, we define storages in the initializer.

# require 'shrine'
# require "shrine/storage/file_system"
# # wanted to use kithe_asset_store and kithe_asset_cache as keys to stay out of way of any other use,
# # but backgrounding is broken. https://github.com/shrinerb/shrine/issues/310
# Shrine.storages = {
#   cache: Shrine::Storage::FileSystem.new("tmp/kithe_shrine_testing/", prefix: "cache"), # temporary
#   store: Shrine::Storage::FileSystem.new("tmp/kithe_shrine_testing/", prefix: "store"), # permanent
# }
