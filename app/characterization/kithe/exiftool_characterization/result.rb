module Kithe
  class ExiftoolCharacterization
    # Retrieve known info out of exiftool results.
    #
    # It can be really tricky to get this reliably from arbitrary files/cameras, there's a lot of variety
    # in EXIF/XMP/etc use.
    #
    # We do this right now for our use cases, in terms of what data we want, and what is actually
    # found in ours. PR's welcome to generalize!
    #
    # In the future, we might have differnet result classes for different versions of exiftool or ways
    # of calling it, it's best to instantiate this with:
    #
    #     result = Kithe::ExiftoolChacterization.presenter(some_result_hash)
    class Result
      attr_reader :result

      def initialize(hash)
        @result = hash
      end

      def exiftool_version
        result["ExifTool:ExifToolVersion"]
      end

      def exif_tool_args
        result["Kithe:CliArgs"]
      end

      def bits_per_sample
        result["EXIF:BitsPerSample"]
      end

      def photometric_interpretation
        result["EXIF:PhotometricInterpretation"]
      end

      def compression
        result["EXIF:Compression"]
      end

      def camera_make
        result["EXIF:Make"]
      end

      def camera_model
        result["EXIF:Model"]
      end

      def dpi
        # only "dpi" if unit is inches
        return nil unless result["EXIF:ResolutionUnit"] == "inches"

        if result["EXIF:XResolution"] == result["EXIF:YResolution"]
          result["EXIF:XResolution"]
        else
          # for now, we bail on complicated case
          nil
        end
      end

      def software
        result["XMP:CreatorTool"]
      end

      def camera_lens
        result["XMP:Lens"]
      end

      def shutter_speed
        result["Composite:ShutterSpeed"]
      end

      def camera_iso
        result["EXIF:ISO"]
      end

      def icc_profile_name
        result["ICC_Profile:ProfileDescription"]
      end

      # We look in a few places, and we only return date not time because
      # getting timezone info is unusual, and it's all we need right now.
      #
      # @return Date
      def creation_date
        str_date = result["EXIF:DateTimeOriginal"] || result["EXIF:DateTimeOriginal"] || result["XMP:DateCreated"]
        Date.strptime(str_date, '%Y:%m:%d')
      rescue Date::Error
        return nil
      end

    end
  end
end
