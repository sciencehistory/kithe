require 'tty/command'
module Kithe
  class FfmpegCliAudio
    class_attribute :ffmpeg_command, default: "ffmpeg"
    attr_reader :destination_format

    AUDIO_DERIVATIVE_FORMATS = {
      standard_webm: { suffix: 'webm', content_type: 'audio/webm',
        extra_args: ["-ac", "1", "-codec:a", "libopus", "-b:a", "64k"]},
      standard_mp3:  { suffix: 'mp3',  content_type: 'audio/mpeg',
        extra_args: ["-ac", "1", "-b:a", "64k"]}
    }

    def initialize(destination_format)
      if destination_format.nil?
        raise ArgumentError.new("No destination format specified.")
      end
      @destination_format = destination_format
    end

    # Will raise TTY::Command::ExitError if the external ffmpeg command returns non-null.
    def call(original_file)
      props = AUDIO_DERIVATIVE_FORMATS[destination_format]
      destination_path = "#{Dir.tmpdir()}/#{destination_format.to_s}.#{props[:suffix]}"
      ffmpeg_args = [ffmpeg_command, "-i" , original_file.path ] +
        props[:extra_args] +
        [destination_path]
      TTY::Command.new(printer: :null).run(*ffmpeg_args)
      return File.open(destination_path)
    end
  end
end
