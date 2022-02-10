require 'tty/command'
require 'json'

module Kithe
  # Characterizes Audio or Video files using `ffprobe`, a tool that comes with `ffmpeg`.
  #
  # You can pass in a local File object (with a pathname), a local String pathname, or
  # a remote URL. (Remote URLs will be passed directy to ffprobe, which can efficiently
  # fetch just the bytes it needs)
  #
  # You can get back normalized A/V metadata:
  #
  #     metadata = FfprobeCharacterization.new(url).normalized_metadata
  #
  # Or the complete FFprobe response as JSON. (We try to use ffprobe options that
  # are exhausitive as to what is returned, including ffprobe version(s))
  #
  #     ffprobe_results = FfprobeCharacterization.new(url).ffprobe_hash
  #
  class FfprobeCharacterization
    class_attribute :ffprobe_command, default: "ffprobe"

    attr_reader :input_arg

    # @param input [String,File] local File OR local filepath as String, OR remote URL as string
    #   If you have a remote url, just passing hte remote url is way more performant than
    #   downloading it yourself locally -- ffprobe will just fetch the bytes it needs.
    def initialize(input)
      if input.respond_to?(:path)
        input = input.path
      end
      @input_arg = input
    end

    # ffprobe args come from this suggestion:
    #
    # https://gist.github.com/nrk/2286511?permalink_comment_id=2593200#gistcomment-2593200
    #
    # We also add in various current version tags! If we're going to record all ffprobe
    # output, we'll want that too!
    def ffprobe_options
      [
        "-hide_banner",
        "-loglevel", "fatal",
        "-show_error", "-show_format", "-show_streams", "-show_programs",
        "-show_chapters", "-show_private_data", "-show_versions",
        "-print_format", "json",
      ]
    end

    # ffprobe output parsed as JSON...
    def ffprobe_hash
      @ffprobe_hash ||= JSON.parse(ffprobe_stdout).merge(
        "ffprobe_options_used" => ffprobe_options.join(" ")
      )
    end

    # Returns a FLAT JSON-able hash of normalized a/v metadata.
    #
    # Tries to standardize to what ActiveEncode uses, with some changes and additions.
    # https://github.com/samvera-labs/active_encode/blob/42f5ed5427a39e56093a5e82123918c4b2619a47/lib/active_encode/technical_metadata.rb
    #
    # A video file or other container can have more than one audio or video stream in it, although
    # this is somewhat unusual for our domain. For the stream-specific audio_ and video_ metadata
    # returned, we just choose the *first* returned audio or video stream (which may be more or
    # less arbitrary)
    #
    # See also #ffprobe_hash for complete ffprobe results
    def normalized_metadata
      # overall  audio_sample_rate are null, audio codec is wrong
      @normalized_metadata ||= {
        "width" => first_video_stream_json&.dig("width"),
        "height" => first_video_stream_json&.dig("height"),
        "frame_rate" => video_frame_rate_as_float, # frames per second
        "duration_seconds" => ffprobe_hash&.dig("format", "duration")&.to_f&.round(3),
        "audio_codec" => first_audio_stream_json&.dig("codec_name"),
        "video_codec" => first_video_stream_json&.dig("codec_name"),
        "audio_bitrate" => first_audio_stream_json&.dig("bit_rate")&.to_i,
        "video_bitrate" => first_video_stream_json&.dig("bit_rate")&.to_i,
        # extra ones not ActiveEncode
        "bitrate" => ffprobe_hash.dig("format", "bit_rate")&.to_i, # overall bitrate of whole file
        "audio_sample_rate" => first_audio_stream_json&.dig("sample_rate")&.to_i, # in Hz
        "audio_channels" => first_audio_stream_json&.dig("channels")&.to_i, # usually 1 or 2 (for stereo)
        "audio_channel_layout" => first_audio_stream_json&.dig("channel_layout"), # stereo or mono or (dolby) 2.1, or something else.
      }.compact
    end

    private

    def ffprobe_stdout
      @ffprobe_output ||= TTY::Command.new(printer: :null).run(
                            ffprobe_command,
                            *ffprobe_options,
                            # warning some S3 urls are failing, some weird escaping, have to figure
                            # it out.
                            input_arg,
                            timeout: 10).out
    end

    def first_video_stream_json
      @first_video_stream_json ||= ffprobe_hash["streams"].find { |stream| stream["codec_type"] == "video" }
    end

    def first_audio_stream_json
      @first_audio_stream_json ||= ffprobe_hash["streams"].find { |stream| stream["codec_type"] == "audio" }
    end

    # There are a few different values we could choose here. We're going to choose
    # `avg_frame_rate` == total duration / number of frames,
    # vs (not chosen) `r_frame_rate ` "the lowest framerate with which all timestamps can be represented accurately (it is the least common multiple of all framerates in the stream)"
    #
    # (note this sometimes gets us not what we expected, like it gets us 29.78 fps instead of 29.97)
    #
    # Then we have to change it from numerator/denomominator to float truncated to two decimal places,
    # which we let ruby rational do for us.
    def video_frame_rate_as_float
      avg_frame_rate = first_video_stream_json&.dig("avg_frame_rate")
      Rational(avg_frame_rate).to_f.round(2) if avg_frame_rate
    end
  end
end
