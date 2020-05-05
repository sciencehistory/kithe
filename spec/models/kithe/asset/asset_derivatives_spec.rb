require 'rails_helper'

# our configuration, customization, and added value on top of shrine derivatives.
# https://shrinerb.com/docs/plugins/derivatives
# https://shrinerb.com/docs/plugins/derivatives
describe "customized shrine derivatives", queue_adapter: :test do
  around do |example|
    original = Kithe::Asset.promotion_directives
    Kithe::Asset.promotion_directives = { promote: :inline, create_derivatives: false }

    example.run
    Kithe::Asset.promotion_directives = original
  end

  def derivative_file!
    # oops, shrine will delete it if we supply it as a derivative!
    StringIO.new(File.read(Kithe::Engine.root.join("spec/test_support/images/2x2_pixel.jpg"))).tap do |io|
      # workaround weird ruby 2.7 bug
      io.set_encoding("BINARY", "BINARY")
    end
  end

  def original_file!
    # oops, shrine will delete it if we supply it as a derivative!
    StringIO.new(File.read(Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg"))).tap do |io|
      # workaround weird ruby 2.7 bug
      io.set_encoding("BINARY", "BINARY")
    end
  end

  describe "standard shrine deriv definitions" do
    temporary_class("CustomUploader") do
      fixed_deriv_io = derivative_file!

      Class.new(Kithe::AssetUploader) do
        self::Attacher.derivatives do |io|
          {
            fixed: fixed_deriv_io
          }
        end
      end
    end

    temporary_class("CustomAsset") do
      Class.new(Kithe::Asset) do
        set_shrine_uploader(CustomUploader)
      end
    end

    it "sets up derivative properly" do
      asset = CustomAsset.create!(title: "test", file: original_file!)
      asset.file_derivatives!

      derivative = asset.file_derivatives[:fixed]
      expect(derivative).to be_present

      expect(derivative.exists?).to be(true)
      expect(derivative.read).to eq(derivative_file!.read)
      derivative.rewind

      expect(derivative.storage_key).to eq(:kithe_derivatives)

      # have some pexpected metadata, including good constructed 'filename'
      expect(derivative.metadata["size"]).to eq(derivative_file!.length)
      expect(derivative.metadata["mime_type"]).to eq("image/jpeg")
      expect(derivative.metadata["height"]).to eq(2)
      expect(derivative.metadata["width"]).to eq(2)
      expect(derivative.metadata["filename"]).to eq("#{asset.friendlier_id}_fixed.jpeg")

      # path on storage is nice and pretty
      expect(derivative.id).to match %r{\A#{asset.id}/fixed/[a-f0-9]+\.jpeg\Z}
    end
  end
end
