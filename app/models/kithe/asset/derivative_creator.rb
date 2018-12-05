# Creates derivatives from definitions stored on an Asset class
class Kithe::Asset::DerivativeCreator
  attr_reader :definitions, :asset

  # Creates derivatives according to derivative definitions.
  # Normally any definition with `default_create` true, but that can be
  # changed with `only:` and `except:` params, which take arrays of definition keys.
  #
  # Bytestream returned by a derivative definition block will be closed AND unlinked
  # (deleted) if it is a File or Tempfile object.
  #
  # @param definitions an array of DerivativeDefinition
  # @param asset an Asset instance
  # @param only array of definition keys, only execute these (doesn't matter if they are `default_create` or not)
  # @param except array of definition keys, exclude these from definitions of derivs to be created
  def initialize(definitions, asset, only:nil, except:nil)
    @definitions = definitions
    @asset = asset
    @only = only
    @except = except
  end

  def call
    # Note, MAY make a superfluous copy and/or download of original file, ongoing
    # discussion https://github.com/shrinerb/shrine/pull/329#issuecomment-443615868
    # https://github.com/shrinerb/shrine/pull/332
    Shrine.with_file(asset.file) do |original_file|
      applicable_definitions.each do |defn|
        deriv_bytestream = defn.call(original_file: original_file, record: asset)
        if deriv_bytestream
          asset.add_derivative(defn.key, deriv_bytestream, storage_key: defn.storage_key)
          cleanup_returned_io(deriv_bytestream)
        end
        original_file.rewind
      end
    end
  end

  private

  def applicable_definitions
    definitions.find_all { |d| d.default_create }
  end

  def cleanup_returned_io(io)
    if io.respond_to?(:close!)
      # it's a Tempfile, clean it up now
      io.close!
    elsif io.is_a?(File)
      # It's a File, close it and delete it.
      io.close
      File.unlink(io.path)
    end
  end
end
