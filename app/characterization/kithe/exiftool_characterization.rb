require 'tty/command'
require 'json'

module Kithe
  # Can run an installed `exiftool` command line, and return results as a JSON hash. exiftool
  # needs to be installed.  This version developed against exiftool 12.60
  #
  # Results are extended with exact command-line arguments given to exiftool in key `Kithe:CliArgs` as
  # an array of Strings.
  #
  # Results can be parsed with accompanying Kithe::Exiftool::Characterization::Result class --
  # in future, if different versions or invocations of exiftool produce different hash results,
  # we can provide different Results parsers, and a switching method to choose right one
  # based on exiftool version and args embedded in results.
  #
  # In cases of errors where exiftool returns errors in hash, hash is still returned, no raise!
  #
  # @example
  #     hash = Kithe::ExiftoolCharacterization.new.call(file_path)
  #
  # * exiftool needs to be installed
  #
  # * Runs with -G0:4 so keys might look like `EXIF:BitsPerSample` or in some cases
  #   have a `Copy1` or `Copy2` in there, like `XMP:Copy1:Make`.  The `g4` arg
  #   results in that `Copy1`, necessary to get multiple validation warnings
  #   all included, but a bit annoying when it puts in extraneous `Copy1` for singular
  #   results sometimes too.
  class ExiftoolCharacterization
    attr_accessor :file_path

    # @param file_path [String] path to a local file
    # @returns Hash
    def call(file_path)
      cmd = TTY::Command.new(printer: :null)

      exiftool_args = [
        "-All",       # all tags
        "--File:All",  # EXCEPT not "File" group tags,
        "-duplicates", # include duplicate values
        "-validate",   # include some validation errors
        "-json",       # json output

        # with exif group names as key prefixes eg "ICC_Profile:ProfileDescription"
        # But also with weird `:Copy1`, `:Copy2` appended for multiples, which we need
        # for `ExifTool:Warning` from `-validate`, to get all of them, that's what the :4 does.
        #
        # https://exiftool.org/forum/index.php?topic=15194.0
        "-G0:4"
      ]

      # exiftool may return a non-zero exit for a corrupt file -- we don't want to raise,
      # it's still usually returning a nice json hash with error message, just store that
      # in the exiftool_result area anyway!
      result = cmd.run!(
        "exiftool",
        *exiftool_args,
        file_path.to_s)


      if result.out.blank? && result.failed?
        raise ArgumentError.new("#{self.class}: #{result.err}")
      end

      # Returns an array of hashes
      # decimal_class: String needed so exiftool version number like `12.60` doesn't
      # wind up truncated to 12.6 as a ruby float!
      result_hash = JSON.parse(result.out, decimal_class: String).first

      # Let's add our invocation options, as a record
      result_hash["Kithe:CliArgs"] = exiftool_args

      result_hash
    end
  end
end
