require 'rails_helper'
require 'shrine/plugins/kithe_checksum_signatures'

# This kithe plugin is optional, let's make sure it works how we expect
describe Shrine::Plugins::KitheChecksumSignatures, queue_adpater: :inline do
  temporary_class("ChecksumUploader") do
    Class.new(Kithe::AssetUploader) do
      plugin :kithe_checksum_signatures
    end
  end

  temporary_class("ChecksumAsset") do
    Class.new(Kithe::Asset) do
      set_shrine_uploader(ChecksumUploader)
    end
  end

  around do |example|
    original = Kithe::Asset.promotion_directives
    Kithe::Asset.promotion_directives = { promote: :inline }

    example.run

    Kithe::Asset.promotion_directives = original
  end

  it "provides checksum metadata after promotion" do
    asset = ChecksumAsset.create!(title: "test", file: StringIO.new("test"))
    asset.reload

    expect(asset).to be_stored
    expect(asset.file.metadata.slice("md5", "sha1", "sha512")).to all(be_present)
  end

  describe "without promotion" do
    around do |example|
      original = Kithe::Asset.promotion_directives
      Kithe::Asset.promotion_directives = { promote: false }

      example.run

      Kithe::Asset.promotion_directives = original
    end

    it "does not extract checksum metadata on cache" do
      asset = ChecksumAsset.create!(title: "test", file: StringIO.new("test"))
      asset.reload

      expect(asset).not_to be_stored
      expect(asset.file.metadata.slice("md5", "sha1", "sha512")).not_to include(be_present)
    end
  end

  describe "derivatives" do
    it "do not get checksum metadata" do
      asset = ChecksumAsset.create!(title: "test", file: StringIO.new("test"))
      asset.update_derivative("test", StringIO.new("test deriv"))

      expect(asset.file_derivatives[:test]).to be_present
      expect(asset.file_derivatives[:test].metadata.slice("md5", "sha1", "sha512")).not_to include(be_present)
    end
  end
end
