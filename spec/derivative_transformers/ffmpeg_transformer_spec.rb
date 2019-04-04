require 'rails_helper'

# mostly smoke tests, we don't verify much about the output images at present
describe Kithe::FfmpegTransformer do
  let(:input_path) { Kithe::Engine.root.join("spec", "test_support", "audio", "ice_cubes.mp3") }
  let(:input_file) { File.open(input_path, encoding: "BINARY") }

  describe "properly handles common ffmpeg arguments" do
    it "uses ffmpeg defaults for mp3" do
      instance = described_class.new(output_suffix: 'mp3')
      args = instance.settings_arguments()
      expect(args).to match_array([])
    end
    it "adds a bitrate when specified" do
      instance = described_class.new(output_suffix: 'mp3', bitrate: '64k')
      args = instance.settings_arguments()
      expect(args).to match_array(["-b:a", "64k"])
    end
    it "mixes down to mono when asked to" do
      instance = described_class.new(output_suffix: 'mp3', force_mono: true)
      args = instance.settings_arguments()
      expect(args).to match_array(["-ac", "1"])
    end
    it "supplies default codec for webm" do
      instance = described_class.new(output_suffix: 'webm')
      args = instance.settings_arguments()
      expect(args).to match_array(["-codec:a", "libopus"])
    end
    it "does not however supply a codec for mp3" do
      instance = described_class.new(output_suffix: 'mp3', bitrate: '64k', force_mono: true)
      args = instance.settings_arguments()
      expect(args).to match_array(["-ac", "1", "-b:a", "64k"])
    end
    it "requires bitrate to be a string" do
      expect {
        instance = described_class.new(output_suffix:'mp3', bitrate:128)
      }.to raise_error(TypeError)
    end
    it "requires bitrate to be correctly formatted" do
      expect {
        instance = described_class.new(output_suffix:'mp3', bitrate:'128')
      }.to raise_error(ArgumentError)
    end
    it "only takes extra args as an array" do
      expect {
        instance = described_class.new(output_suffix: 'mp3', force_mono: true, other_ffmpeg_args:'-timelimit 120')
        args = instance.settings_arguments()
      }.to raise_error(ArgumentError)
    end
    it "adds extra arguments" do
      instance = described_class.new(output_suffix: 'mp3', force_mono: true, other_ffmpeg_args:['-timelimit', '120'])
      args = instance.settings_arguments()
      expect(args).to match_array(["-ac", "1", "-timelimit", "120"])
    end
  end

  describe "not thumbnail mode" do
    it "converts to mp3" do
      instance = described_class.new(output_suffix: 'mp3', force_mono: true, bitrate: '32k')
      output = instance.call(input_file)
      expect(output).to be_kind_of(Tempfile)
      expect(Marcel::MimeType.for(output)).to eq("audio/mpeg")
      output.close!
    end
    it "converts to webm" do
      instance = described_class.new(output_suffix: 'webm', force_mono: true, bitrate: '32k')
      output = instance.call(input_file)
      # Marcel should technically be smart enough to detect 'audio/mpeg' here,
      # but actually returns 'video/webm' even in the absence of a video stream.
      # Not the end of the world.
      expect(/webm/.match(Marcel::MimeType.for(output))).not_to be_nil
      output.close!
    end
    it "converts to flac" do
      instance = described_class.new(output_suffix: 'flac', bitrate: '32k')
      output = instance.call(input_file)
      expect(output).to be_kind_of(Tempfile)
      expect(Marcel::MimeType.for(output)).to eq("audio/flac")
      output.close!
    end
  end
end
