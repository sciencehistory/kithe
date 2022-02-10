require 'rails_helper'

# mostly smoke tests, we don't verify much about the output images at present
describe Kithe::FfprobeCharacterization do
  describe "video" do
    let(:input_path) { Kithe::Engine.root.join("spec", "test_support", "video", "very_small_h264.mp4").to_s }
    let(:characterization) { described_class.new(input_path)}

    it "returns normalized data" do
      expect(characterization.normalized_metadata).to eq({
        "width" => 224,
        "height" => 168,
        "frame_rate" => 15.0,
        "duration_seconds" => 2.006,
        "audio_codec" =>"aac",
        "video_codec" => "h264",
        "audio_bitrate" => 369135,
        "video_bitrate" => 105848,
        "bitrate" => 484466,
        "audio_sample_rate" => 48000,
        "audio_channels" => 6,
        "audio_channel_layout" => "5.1"
      })
    end

    it "can return complete output" do
      expect(characterization.ffprobe_hash).to be_kind_of(Hash)

      expect(characterization.ffprobe_hash).to have_key("streams")
      expect(characterization.ffprobe_hash).to have_key("format")
      expect(characterization.ffprobe_hash).to have_key("program_version")
      expect(characterization.ffprobe_hash).to have_key("library_versions")
      expect(characterization.ffprobe_hash).to have_key("ffprobe_options_used")
    end

    describe "with File input" do
      let(:input_file) { File.open(input_path, encoding: "BINARY") }
      let(:characterization) { described_class.new(input_file)}

      it "can return normalized data" do
        expect(characterization.normalized_metadata).to eq({
          "width" => 224,
          "height" => 168,
          "frame_rate" => 15.0,
          "duration_seconds" => 2.006,
          "audio_codec" =>"aac",
          "video_codec" => "h264",
          "audio_bitrate" => 369135,
          "video_bitrate" => 105848,
          "bitrate" => 484466,
          "audio_sample_rate" => 48000,
          "audio_channels" => 6,
          "audio_channel_layout" => "5.1"
        })
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
end
