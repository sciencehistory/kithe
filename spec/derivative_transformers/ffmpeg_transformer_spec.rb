require 'rails_helper'

# mostly smoke tests, we don't verify much about the output images at present
describe Kithe::FfmpegTransformer do
  let(:input_path) { Kithe::Engine.root.join("spec", "test_support", "audio", "ice_cubes.mp3") }
  let(:input_file) { File.open(input_path, encoding: "BINARY") }

  describe "properly handles common ffmpeg arguments" do
    it "uses ffmpeg defaults for mp3" do
      instance = described_class.new(output_suffix: 'mp3')
      args = instance.transform_arguments
      expect(args).to match_array([])
    end
    it "adds a bitrate when specified" do
      instance = described_class.new(output_suffix: 'mp3', bitrate: '64k')
      args = instance.transform_arguments
      expect(args).to match_array(["-b:a", "64k"])
    end
    it "mixes down to mono when asked to" do
      instance = described_class.new(output_suffix: 'mp3', force_mono: true)
      args = instance.transform_arguments
      expect(args).to match_array(["-ac", "1"])
    end
    it "supplies default codec for webm" do
      instance = described_class.new(output_suffix: 'webm')
      args = instance.transform_arguments
      expect(args).to match_array(["-codec:a", "libopus"])
    end
    it "does not however supply a codec for mp3" do
      instance = described_class.new(output_suffix: 'mp3', bitrate: '64k', force_mono: true)
      args = instance.transform_arguments()
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
    it "requires other_ffmpeg_args to be an array" do
      expect {
        instance = described_class.new(output_suffix: 'mp3', force_mono: true, other_ffmpeg_args:'-timelimit 120')
        args = instance.transform_arguments
      }.to raise_error(ArgumentError)
    end
    it "adds extra arguments when correctly supploed" do
      instance = described_class.new(output_suffix: 'mp3', force_mono: true, other_ffmpeg_args:['-timelimit', '120'])
      args = instance.transform_arguments
      expect(args).to match_array(["-ac", "1", "-timelimit", "120"])
    end
  end

  describe "correctly performs conversions" do
    it "raises ExitError when ffmpeg fails; does not fail silently" do
      expect {
        instance = described_class.new(output_suffix: 'mp3', audio_codec: 'nonexistent_codec')
        output = instance.call(input_file)
      }.to raise_error(TTY::Command::ExitError)
    end

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
      # Magic-number based mime detection yields 'video/webm' here, even in the absence
      # of a video stream. The correct mimetype is really 'audio/webm.'
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

  describe "ffmpeg command metadata" do
    it "is provided when arg is given" do
      add_metadata = {}

      instance = described_class.new(output_suffix: 'mp3', force_mono: true, bitrate: '32k')
      output = instance.call(input_file, add_metadata: add_metadata)

      expect(add_metadata[:ffmpeg_version]).to match /\d+\.\d+/
      expect(add_metadata[:ffmpeg_command]).to match /ffmpeg -y -i .*\.mp3/
    end
  end
end
