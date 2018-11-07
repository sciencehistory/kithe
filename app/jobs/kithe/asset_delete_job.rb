module Kithe
  class AssetDeleteJob < Job
    def perform(data)
      AssetUploader::Attacher.delete(data)
    end
  end
end
