require 'tty/command'
module Kithe

  class FfmpegTransformer
    class_attribute :ffmpeg_command, default: "ffmpeg"
    attr_reader :format_label

    # Example:
    # props = {:label=>:mono_webm, :front_end_label=>"Mono webm audio",
    # :suffix=>"webm", :content_type=>"audio/webm",
    # :conversion_settings=>["-ac", "1", "-codec:a", "libopus", "-b:a", "64k"]}
    # Kithe::FfmpegTransformer.new(props).call(original_file)
    # See ffmpeg_transformer_settings.rb for more examples.

    def initialize(properties)
      @properties = properties
    end

    # Will raise TTY::Command::ExitError if the external ffmpeg command returns non-null.
    def call(original_file)
      tempfile = Tempfile.new([@properties[:label].to_s, ".#{@properties[:suffix]}"])
      ffmpeg_args = [ffmpeg_command, "-y", "-i", original_file.path] +
        @properties[:conversion_settings] +
        [tempfile.path]
      TTY::Command.new(printer: :null).run(*ffmpeg_args)
      return tempfile
    end
  end
end
