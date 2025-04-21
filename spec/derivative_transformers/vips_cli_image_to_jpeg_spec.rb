require 'rails_helper'
require 'dimensions'

# mostly smoke tests, we don't verify much about the output images at present
describe Kithe::VipsCliImageToJpeg do
  let(:input_path) { Kithe::Engine.root.join("spec", "test_support", "images", "photo_800x586.jpg") }
  let(:input_file) { File.open(input_path, encoding: "BINARY") }

  describe "thumbnail mode" do

    it "raises without width" do
      expect {
        Kithe::VipsCliImageToJpeg.new(thumbnail_mode: true).call(input_file)
      }.to raise_error(ArgumentError)
    end

    describe "with width" do
      let(:width) { 100 }

      it "converts" do
        output = Kithe::VipsCliImageToJpeg.new(thumbnail_mode: true, max_width: width).call(input_file)
        expect(output).to be_kind_of(Tempfile)
        expect(Marcel::MimeType.for(output)).to eq("image/jpeg")

        expect(Dimensions.width(output.path)).to eq(width)

        output.close!
      end

      describe "with add_metadata" do
        it "adds metadata" do
          add_metadata = {}

          Kithe::VipsCliImageToJpeg.new(thumbnail_mode: true, max_width: width).call(input_file, add_metadata: add_metadata)
          expect(add_metadata[:vips_version]).to match /\d+\.\d+\.\d+/
          expect(add_metadata[:vips_command]).to match /vipsthumbnail .*\.jpg\[Q=85,interlace,optimize_coding,keep=none\]/
        end
      end
    end
  end

  describe "not thumbnail mode" do
    let(:original_width) { Dimensions.width(input_file.path) }
    it "converts" do
      output = Kithe::VipsCliImageToJpeg.new(thumbnail_mode: false).call(input_file)
      expect(output).to be_kind_of(Tempfile)
      expect(Marcel::MimeType.for(output)).to eq("image/jpeg")

      expect(Dimensions.width(output)).to eq(original_width)

      output.close!
    end

    describe "with width" do
      let(:width) { 100 }

      it "converts" do
        output = Kithe::VipsCliImageToJpeg.new(thumbnail_mode: false, max_width: width).call(input_file)
        expect(output).to be_kind_of(Tempfile)
        expect(Marcel::MimeType.for(output)).to eq("image/jpeg")

        expect(Dimensions.width(output.path)).to eq(width)

        output.close!
      end

      describe "with add_metadata" do
        it "adds metadata" do
          add_metadata = {}

          Kithe::VipsCliImageToJpeg.new(thumbnail_mode: false, max_width: width).call(input_file, add_metadata: add_metadata)
          expect(add_metadata[:vips_version]).to match /\d+\.\d+\.\d+/
          expect(add_metadata[:vips_command]).to match /vipsthumbnail .*\.jpg\[Q=85,interlace,optimize_coding\]/
        end
      end

    end
  end
end
