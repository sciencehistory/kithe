module Kithe
  class AssetPromoteJob < Job
    def perform(data)
      AssetUploader::Attacher.promote(data)
    end
  end
end
