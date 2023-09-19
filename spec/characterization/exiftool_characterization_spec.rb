require 'rails_helper'

describe Kithe::ExiftoolCharacterization do
  # do promotion inline to test what happens in promotion, and don't do derivatives at all -- we
  # don't need them and don't want to wait for them.
  around do |example|
    original = Kithe::Asset.promotion_directives
    Kithe::Asset.promotion_directives = { promote: :inline, create_derivatives: false }

    example.run

    Kithe::Asset.promotion_directives = original
  end

  let(:result) {
    Kithe::ExiftoolCharacterization.new.call(input_path)
  }

  describe "tiff" do
    let(:input_path) {
      (Kithe::Engine.root + "spec/test_support/images/mini_page_scan.tiff").to_s
    }

    it "extracts exiftool result as hash with location prefix" do
      expect(result).to be_present
      expect(result).to be_kind_of(Hash)

      expect(result["ExifTool:ExifToolVersion"]).to match /^\d+(\.\d+)+$/

      # we add cli args...
      expect(result["Kithe:CliArgs"]).to be_present
      expect(result["Kithe:CliArgs"]).to be_kind_of Array


      expect(result["EXIF:BitsPerSample"]).to eq "8 8 8"
      expect(result["EXIF:PhotometricInterpretation"]).to eq "RGB"
      expect(result["EXIF:Compression"]).to eq "Uncompressed"
      expect(result["EXIF:Make"]).to eq "Phase One"
      expect(result["EXIF:Model"]).to eq "IQ3 80MP"

      expect(result["EXIF:XResolution"]).to eq 600
      expect(result["EXIF:YResolution"]).to eq 600

      expect(result["XMP:CreatorTool"]).to eq "Capture One 12 Macintosh"
      expect(result["XMP:Lens"]).to eq "-- mm f/--"
      expect(result["Composite:ShutterSpeed"]).to eq "1/60"
      expect(result["EXIF:ISO"]).to eq 50
      expect(result["ICC_Profile:ProfileDescription"]).to eq "Adobe RGB (1998)"

      expect(result["XMP:DateCreated"]).to eq "2023:06:28 15:32:00"
      expect(result["EXIF:CreateDate"]).to eq "2023:06:28 15:32:00"
      expect(result["EXIF:DateTimeOriginal"]).to eq "2023:06:28 15:32:00"
      expect(result["XMP:MetadataDate"]).to eq "2023:06:28 15:32:00-04:00"
    end
  end

  describe "file that causes exiftool error" do
    let(:input_path)  {
      (Kithe::Engine.root + "spec/test_support/audio/zero_bytes.flac").to_s
    }

    it "does not raise, and has error info stored" do
      expect(result).to be_present
      expect(result).to be_kind_of(Hash)

      expect(result["ExifTool:Error"]).to eq "File is empty"
    end
  end

  describe "corrupt file" do
    let(:input_path) {
      (Kithe::Engine.root + "spec/test_support/images/corrupt_bad.tiff").to_s
    }

    it "flags multiple errors" do
      expect(result["ExifTool:Validate"]).to be_present

      # Exiftool sure packages em weird
      all_warnings = result.slice(
        *result.keys.grep(/ExifTool(:Copy\d+):Warning/)
      ).values

      expect(all_warnings).to include(
        "Missing required TIFF IFD0 tag 0x0100 ImageWidth",
        "Missing required TIFF IFD0 tag 0x0101 ImageHeight",
        "Missing required TIFF IFD0 tag 0x0106 PhotometricInterpretation",
        "Missing required TIFF IFD0 tag 0x0111 StripOffsets",
        "Missing required TIFF IFD0 tag 0x0116 RowsPerStrip",
        "Missing required TIFF IFD0 tag 0x0117 StripByteCounts",
        "Missing required TIFF IFD0 tag 0x011a XResolution",
        "Missing required TIFF IFD0 tag 0x011b YResolution"
      )
    end
  end

  describe "no file found" do
    let(:input_path) {
      "./no/such/file"
    }

    it "raises" do
      expect{
        result
      }.to raise_error(ArgumentError, %r{File not found - ./no/such/file})
    end
  end
end
