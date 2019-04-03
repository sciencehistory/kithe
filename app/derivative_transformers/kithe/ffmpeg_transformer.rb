require 'tty/command'
module Kithe

  class FfmpegTransformer
    class_attribute :ffmpeg_command, default: "ffmpeg"

    def initialize(bitrate:, stereo:, suffix:, content_type:, codec:, other_options:)
      @bitrate, @stereo, @suffix, @content_type, @codec, @other_options =
      bitrate,   stereo,  suffix,  content_type,  codec,  other_options
    end

    def settings_arguments()
      result  = []
      result += ["-ac", "1"] unless @stereo
      result += ["-codec:a", @codec] if @codec
      result += ["-b:a", @bitrate] if @bitrate
      result += @other_options if @other_options
      result
    end


    # Will raise TTY::Command::ExitError if the external ffmpeg command returns non-null.
    def call(original_file)
      tempfile = Tempfile.new(['temp_deriv', ".#{@suffix}"])
      ffmpeg_args = [ffmpeg_command, "-y", "-i", original_file.path] +
        settings_arguments + [tempfile.path]
      TTY::Command.new(printer: :null).run(*ffmpeg_args)
      return tempfile
    end
  end
end
