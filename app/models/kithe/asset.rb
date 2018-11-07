class Kithe::Asset < Kithe::Model
  # TODO we may need a way for local app to provide custom uploader class.
  # or just override at ./kithe/asset_uploader.rb locally?
  include Kithe::AssetUploader::Attachment.new(:file)

  # for convenience, let's delegate some things to shrine parts
  delegate :content_type, :size, :height, :width, to: :file, allow_nil: true
  delegate :stored?, to: :file_attacher
end
