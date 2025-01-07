require 'rails_helper'

# mostly smoke tests, we don't verify much about the output images at present
describe Kithe::FfprobeCharacterization do
  describe "video" do
    let(:input_path) { Kithe::Engine.root.join("spec", "test_support", "video", "very_small_h264.mp4").to_s }
    let(:characterization) { described_class.new(input_path)}

    let(:normalized_output) do
      {
        "width"=>224,
        "height"=>168,
        "frame_rate"=>15.0,
        "duration_seconds"=>2.005,
        "audio_codec"=>"aac",
        "video_codec"=>"h264",
        "audio_bitrate"=>369135,
        "video_bitrate"=>105848,
        "bitrate"=>484708,
        "audio_sample_rate"=>48000,
        "audio_channels"=>6,
        "audio_channel_layout"=>"5.1"
      }
    end

    it "returns normalized data" do
      expect(characterization.normalized_metadata).to eq(normalized_output)
    end

    it "can return complete output" do
      expect(characterization.ffprobe_hash).to be_kind_of(Hash)

      expect(characterization.ffprobe_hash).to have_key("streams")
      expect(characterization.ffprobe_hash).to have_key("format")
      expect(characterization.ffprobe_hash).to have_key("program_version")
      expect(characterization.ffprobe_hash).to have_key("library_versions")
      expect(characterization.ffprobe_hash).to have_key("ffprobe_options_used")
    end

    it "can return ffprobe version" do
      expect(characterization.ffprobe_version).to match /[0-9.]+/
    end

    describe "with File input" do
      let(:input_file) { File.open(input_path, encoding: "BINARY") }
      let(:characterization) { described_class.new(input_file)}

      it "can return normalized data" do
        expect(characterization.normalized_metadata).to eq(normalized_output)
      end
    end

    describe "with URL input" do
      let(:input_url) { "http://exaple.org/some_file.mp4"}
      before do
        stub_request(:get, input_url).to_return(body: File.open(input_path))
      end

      it "can return normalized data" do
        expect(characterization.normalized_metadata).to eq(normalized_output)
      end
    end
  end

  describe "audio" do
    let(:input_path) { Kithe::Engine.root.join("spec", "test_support", "audio", "ice_cubes.mp3") }
    let(:characterization) { described_class.new(input_path)}

    it "returns normalized data" do
      expect(characterization.normalized_metadata).to eq({
        "duration_seconds" => 1.593,
        "audio_codec" => "mp3",
        "audio_bitrate" => 290897,
        "bitrate" => 292534,
        "audio_sample_rate" => 44100,
        "audio_channels" => 2,
        "audio_channel_layout" => "stereo"
      })
    end
  end

  describe ".characterize_from_uploader" do
    let(:video_file_path) { Kithe::Engine.root.join("spec", "test_support", "video", "very_small_h264.mp4").to_s }

    temporary_class("UploaderWithFfprobeCharacterization") do
      Class.new(Kithe::AssetUploader) do
        add_metadata do |source_io, context|
          Kithe::FfprobeCharacterization.characterize_from_uploader(source_io, context)
        end
      end
    end

    temporary_class("CustomAsset") do
      Class.new(Kithe::Asset) do
        set_shrine_uploader(UploaderWithFfprobeCharacterization)
      end
    end

    describe "on cache storage", queue_adapter: :test do
      it "does not characterize" do
        asset = CustomAsset.create!(title: "test", file: File.open(video_file_path))
        asset.reload

        expect(asset.file.metadata.keys).not_to include("bitrate", "duration_seconds")
      end
    end

    describe "after promotion", queue_adapter: :inline do
      it "characterizes" do
        asset = CustomAsset.create!(title: "test", file: File.open(video_file_path))
        asset.reload

        expect(asset.file.metadata.keys).to include("bitrate","duration_seconds")
      end

      describe "with image file" do
        let(:image_file_path) { Kithe::Engine.root.join("spec", "test_support", "images", "photo_800x586.jpg").to_s }

        it "does not characterize or error" do
          asset = CustomAsset.create!(title: "test", file: File.open(image_file_path))
          asset.reload

          expect(asset.file.metadata.keys).not_to include("bitrate", "duration_seconds")
        end
      end
    end
  end
end
