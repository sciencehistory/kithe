require 'tty/command'
module Kithe

  class FfmpegTransformer
    class_attribute :ffmpeg_command, default: "ffmpeg"

    # Specifies the most important args to send to ffmpeg for creating audio and video derivatives.
    #
    # @output_suffix  [String] the output suffix, like `mp3` or `webm`
    # @bitrate  [String]  Constant bitrate arg passed to ffmpeg with "-b:a", `64k`
    # @force_mono  [Binary] Whether to mix down the audio to a single mono channel.
    # @audio_codec  [String] the codec to use for transcoding audio. Passed to ffmpeg with -codec:a, `libopus`
    # @other_ffmpeg_args [Array<String>] any extra arguments to pass to ffmpeg.
    def initialize(output_suffix:, bitrate:nil, force_mono:false, audio_codec:nil, other_ffmpeg_args:nil)
      @output_suffix, @bitrate, @force_mono, @audio_codec, @other_ffmpeg_args =
       output_suffix,  bitrate,  force_mono,  audio_codec,  other_ffmpeg_args

      # Default settings:
      @audio_codec ||= 'libopus' if output_suffix == 'webm'

      # Validation:
      if other_ffmpeg_args && other_ffmpeg_args.class != Array
        raise ArgumentError.new('If "other_ffmpeg_args" is not nil, it needs to be an array of strings.')
      end
      if bitrate && !/\d+k/.match(bitrate)
        raise ArgumentError.new('If "bitrate" is not nil, it needs to be a string like "64k" or "128k".')
      end
    end

    def settings_arguments()
      result  = []
      result += ["-ac", "1"] if @force_mono
      result += ["-codec:a", @audio_codec] if @audio_codec
      result += ["-b:a", @bitrate] if @bitrate
      result += @other_ffmpeg_args if @other_ffmpeg_args
      result
    end

    # Will raise TTY::Command::ExitError if the ffmpeg returns non-null.
    def call(original_file)
      tempfile = Tempfile.new(['temp_deriv', ".#{@output_suffix}"])
      ffmpeg_args =  [ffmpeg_command, "-y", "-i", original_file.path]
      ffmpeg_args += settings_arguments + [tempfile.path]
      TTY::Command.new(printer: :null).run(*ffmpeg_args)
      return tempfile
    end
  end
end
