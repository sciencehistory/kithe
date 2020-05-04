# Our Kithe::Asset model class is meant to be a superclass of a local application asset class, which we
# can call `Asset`, although an app can call it whatever they like.
#
# Kithe::Asset sets it's own shrine uploader class, with a typical shrine:
#
#     include Kithe::AssetUploader::Attachment(:file)
#
# An application Asset subclass will inherit this uploader, which is convenient for getting
# started quickly. But an application will likely want to define its own local uploader
# class, to define it's own metadata, derivatives, and any other custom beahvior.
#
# There isn't an obvious built-into-shrine way to do that, but it turns out simply overriding
# class and instance `*_attacher` methods seems to work out well. See:
# https://discourse.shrinerb.com/t/model-sub-classes-with-uploader-sub-classes/208
#
# So a local application can define it's own shrine uploader, which is highly recommended to
# be a sub-class of Kithe::AssetUploader to ensure it has required and useful
# Kithe behavior:
#
#     # ./app/uploaders/asset_uploader.rb
#     class AssetUploader < Kithe::AssetUploader
#       # maybe we want some custom metadata
#       add_metadata :something do |io|
#         whatever
#       end
#     end
#
# And then set it in ti's custom local Asset class:
#
#     # ./app/models/asset.rb
#     class Asset < Kithe::Asset
#       set_shrine_uploader(AssetUploader)
#     end
#
# If a local app has it's own inheritance hieararchy of children below that (eg) Asset class,
# they can each (optionally) also override with a custom Uploader. It is recommended that
# the Uploader inheritance hieararchy match the model inheritance hieararchy, to have
# all behavior consistent. For instance:
#
#     class AudioAssetUploader < AssetUploader
#     end
#
#     class AudioAsset < Asset
#       set_shrine_uploader(AudioAssetUploader)
#     end
#
module Kithe::Asset::SetShrineUploader
  extend ActiveSupport::Concern

  class_methods do
    def set_shrine_uploader(uploader_class)
      subclass_attachment = uploader_class::Attachment.new(:file)

      define_singleton_method :file_attacher do |**options|
        subclass_attachment.send(:class_attacher, **options)
      end

      define_method :file_attacher do |**options|
        subclass_attachment.send(:attacher, self, **options)
      end
    end
  end

end
