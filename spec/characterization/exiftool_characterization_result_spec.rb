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

  it "has results" do
    expect(result.exiftool_version).to match /12\.\d+(\.\d+)?/

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
end
