require 'rails_helper'

describe Kithe::FfmpegExtractJpg do
  let(:video_path) { Kithe::Engine.root.join("spec", "test_support", "video", "very_small_h264.mp4").to_s }

  describe "from local path" do
    it "extracts" do
      result = Kithe::FfmpegExtractJpg.new.call(video_path)

      expect(result).to be_present
      expect(result).to be_kind_of(Tempfile)
      expect(Marcel::MimeType.for(StringIO.new(result.read))).to eq "image/jpeg"
    end

    it "can extract with a frame sample" do
      extractor = Kithe::FfmpegExtractJpg.new(frame_sample_size: 300)

      result = extractor.call(video_path)

      expect(result).to be_kind_of(Tempfile)
      expect(Marcel::MimeType.for(StringIO.new(result.read))).to eq "image/jpeg"
    end

    it "sets add_metadata" do
      add_metadata = {}

      extractor = Kithe::FfmpegExtractJpg.new(frame_sample_size: 300)
      extractor.call(video_path, add_metadata: add_metadata)

      expect(add_metadata[:ffmpeg_version]).to match /\d+\.\d+/
      expect(add_metadata[:ffmpeg_command]).to match /ffmpeg -y -i .*\.jpg/
    end
  end

  describe "from File" do
    let(:video_file) { File.open(video_path) }

    it "extracts" do
      result = Kithe::FfmpegExtractJpg.new.call(video_file)

      expect(result).to be_present
      expect(result).to be_kind_of(Tempfile)
      expect(Marcel::MimeType.for(StringIO.new(result.read))).to eq "image/jpeg"
    end

    it "sets add_metadata" do
      add_metadata = {}

      Kithe::FfmpegExtractJpg.new.call(video_file, add_metadata: add_metadata)

      expect(add_metadata[:ffmpeg_version]).to match /\d+\.\d+/
      expect(add_metadata[:ffmpeg_command]).to match /ffmpeg -y -i .*\.jpg/
    end
  end

  describe "from Shrine::UploadedFile without good url" do
    let(:uploaded_file_obj) do
      Shrine.storages[:cache].upload(File.open(video_path), "something.mp4")

      Shrine::UploadedFile.new(
        id: "something.mp4",
        storage: :cache,
        metadata: {}
      )
    end

    it "extracts" do
      result = Kithe::FfmpegExtractJpg.new.call(uploaded_file_obj)

      expect(result).to be_present
      expect(result).to be_kind_of(Tempfile)
      expect(Marcel::MimeType.for(StringIO.new(result.read))).to eq "image/jpeg"
    end

    it "sets add_metadata" do
      add_metadata = {}

      Kithe::FfmpegExtractJpg.new.call(uploaded_file_obj, add_metadata: add_metadata)

      expect(add_metadata[:ffmpeg_version]).to match /\d+\.\d+/
      expect(add_metadata[:ffmpeg_command]).to match /ffmpeg -y -i .*\.jpg/
    end
  end

  describe "from Shrine::UploadedFile with good url" do
    let(:uploaded_file_obj) do
      Shrine.storages[:cache].upload(File.open(video_path), "something.mp4")

      Shrine::UploadedFile.new(
        id: "something.mp4",
        storage: :cache,
        metadata: {}
      )
    end

    let(:url) { "https://example.com/something.mp4" }

    before do
      allow(uploaded_file_obj).to receive(:url).and_return(url)
    end

    # Can't test much with no great way to mock a url ffmpeg will request,
    # but we can test it shells out a good ffmpeg command I guess
    it "extracts" do
      expect_any_instance_of(TTY::Command).to receive(:run) do |instance, *args|
        expect(args[0..3]).to eq ["ffmpeg", "-y", "-i", url]
      end

      result = Kithe::FfmpegExtractJpg.new.call(uploaded_file_obj)
    end

    it "sets add_metadata" do
      add_metadata = {}

      expect_any_instance_of(TTY::Command).to receive(:run) do |instance, *args|
        expect(args[0..3]).to eq ["ffmpeg", "-y", "-i", url]
      end

      Kithe::FfmpegExtractJpg.new.call(uploaded_file_obj, add_metadata: add_metadata)

      expect(add_metadata[:ffmpeg_version]).to match /\d+\.\d+/
      expect(add_metadata[:ffmpeg_command]).to match /ffmpeg -y -i .*\.jpg/
    end
  end


  # Can't test much with no great way to mock a url ffmpeg will request,
  # but we can test it shells out a good ffmpeg command I guess
  describe "from url" do
    let(:url) { "http://example.org/video.mp4" }

    it "extracts" do
      expect_any_instance_of(TTY::Command).to receive(:run) do |instance, *args|
        expect(args[0..3]).to eq ["ffmpeg", "-y", "-i", url]
      end

      result = Kithe::FfmpegExtractJpg.new.call(url)
    end

    it "sets add_metadata" do
      add_metadata = {}

      expect_any_instance_of(TTY::Command).to receive(:run) do |instance, *args|
        expect(args[0..3]).to eq ["ffmpeg", "-y", "-i", url]
      end

      Kithe::FfmpegExtractJpg.new.call(url, add_metadata: add_metadata)

      expect(add_metadata[:ffmpeg_version]).to match /\d+\.\d+/
      expect(add_metadata[:ffmpeg_command]).to match /ffmpeg -y -i .*\.jpg/
    end
  end
end
