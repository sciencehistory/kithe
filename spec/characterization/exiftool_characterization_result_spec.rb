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

  let(:hash) {
    Kithe::ExiftoolCharacterization.new.call((Kithe::Engine.root + "spec/test_support/images/mini_page_scan.tiff").to_s)
  }

  let(:result) {
   Kithe::ExiftoolCharacterization::Result.new(hash)
  }

  it "can be produced by Kithe::ExiftoolCharacterization.presenter_for" do
    expect(Kithe::ExiftoolCharacterization.presenter_for(hash)).to be_kind_of Kithe::ExiftoolCharacterization::Result
  end

  it "has results" do
    expect(result.exiftool_version).to match /\d\d\.\d+(\.\d+)?/

    expect(result.exif_tool_args).to eq(
      ["-All", "--File:All","-duplicates", "-validate", "-json", "-G0:4"]
    )

    expect(result.bits_per_sample).to eq "8 8 8"

    expect(result.photometric_interpretation).to eq "RGB"

    expect(result.compression).to eq "Uncompressed"

    expect(result.camera_make).to eq "Phase One"

    expect(result.camera_model).to eq "IQ3 80MP"

    expect(result.dpi).to eq 600

    expect(result.software).to eq "Capture One 12 Macintosh"

    expect(result.camera_lens).to eq "-- mm f/--"

    expect(result.shutter_speed).to eq "1/60"

    expect(result.camera_iso).to eq 50

    expect(result.icc_profile_name).to eq "Adobe RGB (1998)"

    expect(result.creation_date).to eq Date.new(2023, 6, 28)
  end

  describe "PDF" do
    let(:hash) {
      Kithe::ExiftoolCharacterization.new.call((Kithe::Engine.root + "spec/test_support/pdf/py-pdf-sample-files/minimal-document.pdf").to_s)
    }

    it "produces selected PDF-specific metadata" do
      expect(result.page_count).to eq 1
      expect(result.pdf_version).to eq "1.5"
    end
  end

  describe "validation warnings" do
    let(:hash) {
      Kithe::ExiftoolCharacterization.new.call((Kithe::Engine.root + "spec/test_support/images/corrupt_bad.tiff").to_s)
    }

    it "are output" do
      expect(result.exiftool_validation_warnings).to contain_exactly(
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

  describe "nil input" do
    let(:result) {
      Kithe::ExiftoolCharacterization::Result.new(nil)
    }

    it "nil output with no complaints" do
      expect(result.camera_lens).to eq nil

      expect(result.creation_date).to eq nil

      expect(result.dpi).to eq nil

      expect(result.exiftool_validation_warnings).to eq []
    end
  end
end
