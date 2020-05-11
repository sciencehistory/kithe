require 'rails_helper'

# our configuration, customization, and added value on top of shrine derivatives.
# https://shrinerb.com/docs/plugins/derivatives
describe "customized shrine derivatives", queue_adapter: :inline do
  let(:derivative_file_path) { Kithe::Engine.root.join("spec/test_support/images/2x2_pixel.jpg") }
  let(:original_file_path) { Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg") }

  describe "kithe derivative definitions" do
    temporary_class("CustomUploader") do
      call_fakeio = method(:fakeio) # weird closure issue
      deriv_path = derivative_file_path
      Class.new(Kithe::AssetUploader) do
        self::Attacher.define_derivative(:fixed) do |io|
          call_fakeio.(File.binread(deriv_path))
        end
      end
    end

    temporary_class("CustomAsset") do
      Class.new(Kithe::Asset) do
        set_shrine_uploader(CustomUploader)
      end
    end

    it "automatically sets up derivative properly" do
      asset = CustomAsset.create!(title: "test", file: File.open(original_file_path))
      # happened in BG job, so have to reload to see it.
      asset.reload

      derivative = asset.file_derivatives[:fixed]
      expect(derivative).to be_present

      expect(derivative.exists?).to be(true)
      expect(derivative.read).to eq(File.binread(derivative_file_path))
      derivative.rewind

      expect(derivative.storage_key).to eq(:kithe_derivatives)

      # have some expected metadata, including good constructed 'filename'
      expect(derivative.metadata["size"]).to eq(File.binread(derivative_file_path).length)
      expect(derivative.metadata["mime_type"]).to eq("image/jpeg")
      expect(derivative.metadata["height"]).to eq(2)
      expect(derivative.metadata["width"]).to eq(2)
      expect(derivative.metadata["filename"]).to eq("#{asset.friendlier_id}_fixed.jpeg")

      # path on storage is nice and pretty
      expect(derivative.id).to match %r{\A#{asset.id}/fixed/[a-f0-9]+\.jpeg\Z}
    end


    it "can manually #create_derivatives" do
      asset = CustomAsset.create!(title: "test", file: File.open(original_file_path))
      asset.reload

      asset.file_attacher.set_derivatives({})
      asset.save!
      asset.reload
      expect(asset.file_derivatives).to be_empty

      asset.create_derivatives
      asset.reload
      derivative = asset.file_derivatives[:fixed]
      expect(derivative).to be_present

      expect(derivative.exists?).to be(true)
    end


    it "can remove derivatives" do
      asset = CustomAsset.create!(title: "test", file: File.open(original_file_path))
      asset.reload

      asset.remove_derivative(:fixed)
      expect(asset.file_derivatives.keys).to be_empty
      asset.reload
      expect(asset.file_derivatives.keys).to be_empty
    end

    describe "with existing derivative", queue_adapter: :inline do
      let(:asset) do
        asset = CustomAsset.create!(title: "test", file: File.open(original_file_path))
        asset.reload
        asset.create_derivatives
        asset.reload
      end

      it "deletes stored derivative file when model is deleted" do
        derivatives = asset.file_derivatives.values
        expect(derivatives).to be_present

        asset.destroy!
        expect(derivatives.none? {|d| d.exists? }).to be(true)
      end

      it "deletes stored derivatives on new file assignment" do
        derivatives = asset.file_derivatives.values
        expect(derivatives).to be_present

        asset.file = File.open(original_file_path)
        asset.save!
        asset.reload

        expect(derivatives.none? {|d| d.exists? }).to be(true)
      end

      describe "#update_derivative" do
        it "can add a derivative" do
          result = asset.update_derivative("test", StringIO.new("test"))

          expect(result).to be_kind_of(Shrine::UploadedFile)
          expect(asset.file_derivatives[:test].read).to eq("test")
          expect(asset.file_derivatives[:test].storage_key).to eq(:kithe_derivatives)
        end

        it "can add a derivative with meadata" do
          result = asset.update_derivative("test", StringIO.new("test"), metadata: { "manual" => "value"} )

          expect(result).to be_kind_of(Shrine::UploadedFile)
          expect(asset.file_derivatives[:test].metadata["manual"]).to eq("value")
          expect(asset.file_derivatives[:test].metadata["size"]).to be_present
        end
      end
    end
  end
end
