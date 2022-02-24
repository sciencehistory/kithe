require 'tty/command'

module Kithe
  # Creates a JPG screen capture using ffmpeg, by default with the `thumbnail`
  # filter to choose a representative frame from the first minute or so.
  #
  # @example tempfile = FfmpegExtractJpg.new.call(shrine_uploaded_file)
  # @example tempfile = FfmpegExtractJpg.new.call(url)
  # @example tempfile = FfmpegExtractJpg.new(start_seconds: 60).call(shrine_uploaded_file)
  # @example tempfile = FfmpegExtractJpg.new(start_seconds: 10, width_pixels: 420).call(shrine_uploaded_file)
  class FfmpegExtractJpg
    class_attribute :ffmpeg_command, default: "ffmpeg"
    attr_reader :start_seconds, :frame_sample_size, :width_pixels

    # @param start_seconds [Integer] seek to this point to find thumbnail. If it's
    #   after the end of the video, you won't get a thumb back though! [Default 0]
    #
    # @param frame_sample_size [Integer] argument passed to ffmpeg thumbnail filter,
    #   how many frames to sample, starting at start_seconds, to choose representative
    #   thumbnail. If set to false, thumbnail filter won't be used. If this one
    #   goes past the end of the video, ffmpeg is fine with it. [Default 900, around
    #   30 seconds at 30 fps]
    #
    # @width_pixels [Integer] output thumb at this width. aspect ratio will be
    #   maintained. Warning, if it's larger than video original, ffmpeg will
    #   upscale!  If set to nil, thumb will be output at original video
    #   resolution. [Default nil]
    def initialize(start_seconds: 0, frame_sample_size: 900, width_pixels: nil)
      @start_seconds = start_seconds
      @frame_sample_size = frame_sample_size
      @width_pixels = width_pixels
    end



    # @param input_arg [String,File,Shrine::UploadedFile] local File; String that
    #   can be URL or local file path; or Shrine::UploadedFile. If Shrine::UploadedFile,
    #   we'll try to get a URL from it if we can, otherwise use or make a local tempfile.
    #   Most efficient is if we have a remote URL to give ffmpeg, one way or another!
    #
    # @returns [Tempfile] jpg extracted from movie
    def call(input_arg)
      if input_arg.kind_of?(Shrine::UploadedFile)
        if input_arg.respond_to?(:url) && input_arg.url&.start_with?(/https?\:/)
          _call(input_arg.url)
        else
          Shrine.with_file(input_arg) do |local_file|
            _call(local_file.path)
          end
        end
      elsif input_arg.respond_to?(:path)
        _call(input_arg.path)
      else
        _call(input_arg.to_s)
      end
    end

    private

    # Internal implementation, after input has already been normalized to an
    # string that can be an ffmpeg arg.
    #
    # @param ffmpeg_source_arg [String] filepath or URL. ffmpeg can take urls, which
    # can be very efficient.
    #
    # @returns Tempfile pointing to a thumbnail
    def _call(ffmpeg_source_arg)
      tempfile = Tempfile.new(['temp_deriv', ".jpg"])

      ffmpeg_args = [ffmpeg_command, "-y"]
      if start_seconds && start_seconds > 0
        ffmpeg_args.concat ["-ss", start_seconds.to_i]
      end

      ffmpeg_args.concat ["-i", ffmpeg_source_arg]

      video_filter_parts = []
      video_filter_parts << "thumbnail=#{frame_sample_size}" if frame_sample_size
      video_filter_parts << "scale=#{width_pixels}:-1" if width_pixels
      if video_filter_parts
        ffmpeg_args.concat ["-vf", video_filter_parts.join(',')]
      end

      ffmpeg_args.concat ["-frames:v",  "1"]

      ffmpeg_args << tempfile.path

      TTY::Command.new(printer: :null).run(*ffmpeg_args)

      return tempfile
    rescue StandardError => e
      tempfile.unlink if tempfile
      raise e
    end
  end
end
