require 'tempfile'
require 'tty/command'

module Kithe
  # Determines MIME/Internet Content Type by calling out to `mediainfo` CLI, which
  # must be installed on machine.
  #
  # Catches some A/v types that for some fles ordinary "magic byte" detection does not.
  #
  # When we had some files not being properly determined to be audio/mpeg, we looked
  # into what Harvard fits used, saw mediainfo was one of the tools, so decided we
  # would use that as a fallback. Since it will be much slower than the magic-byte-based
  # detection.
  #
  # Not sure how reliable `mediainfo` is for non-media files, plus it we use it as a fallback.
  #
  # The API is similar to the internal Shrine::DetermineMimeType::MimeTypeAnalyzer,
  # it is based on that.
  #
  #     MediainfoAnalyzer.new.call(io)
  #     #=> "audio/mpeg"
  #     #=> nil if mediainfo has no idea
  #
  class MediainfoAnalyzer
    class_attribute :mediainfo_command, default: "mediainfo"
    self.mediainfo_command = "mediainfo"

    # returns mime-type as determined by shell out to mediainfo command
    #
    # io argument will have `rewind` called before returning.
    def call(io, _options ={})
      # To use 'mediainfo' we need a local file, which if the file is currently remote means we
      # will have to download a local copy into a tempfile, this could take a while for a big file.
      Shrine.with_file(io) do |tempfile|
        out, err = tty_command.run("#{mediainfo_command} --Inform=\"General;%InternetMediaType%\"", tempfile.path)

        mime_type = out.chomp
        mime_type = nil if mime_type.blank?

        return mime_type
      end
    end

    private

    def tty_command
      @tty_comand ||= TTY::Command.new(printer: :null)
    end

  end
end
