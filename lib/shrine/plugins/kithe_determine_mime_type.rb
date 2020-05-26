class Shrine
  module Plugins
    # Custom kithe logic for determining mime type, using the shrine mime_type plugin.
    #
    # We start out using the `marcel` analyzer.
    # Marcel analyzer is pure-ruby and fast. It's from Basecamp and is what
    # ActiveStorage uses. It is very similar to :mimemagic (and uses mimemagic
    # under the hood), but mimemagic seems not to be maintained with up to date
    # magic db? https://github.com/minad/mimemagic/pull/66
    #
    # But marcel is not able to catch some of our MP3s as audio/mpeg. The
    # `mediainfo` CLI is, and is one of the tools Harvard FITS uses.
    # If marcel came up blank, AND we are configured to use mediainfo CLI
    # (which by default we will be if it's available), we will try
    # shelling out to mediainfo command line.
    #
    # https://github.com/MediaArea/MediaInfo
    #
    # Ensure that if mime-type can't be otherwise determined, it is assigned
    # "application/octet-stream", basically the type for generic binary.
    class KitheDetermineMimeType
      def self.load_dependencies(uploader, *)
        uploader.plugin :determine_mime_type, analyzer: -> (io, analyzers) do
          mime_type = analyzers[:marcel].call(io)


          if Kithe.use_mediainfo && mime_type == "application/octet-stream" || mime_type.blank?
            mime_type = Kithe::MediainfoAnalyzer.new.call(io)
          end

          mime_type = "application/octet-stream" if mime_type.blank?

          mime_type
        end
      end
    end
    register_plugin(:kithe_determine_mime_type, KitheDetermineMimeType)
  end
end
