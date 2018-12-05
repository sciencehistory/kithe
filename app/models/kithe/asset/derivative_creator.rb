# Creates derivatives from definitions stored on an Asset class
class Kithe::Asset::DerivativeCreator
  attr_reader :definitions, :asset, :only, :except

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
    @only = only && Array(only)
    @except = except && Array(except)
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

  # Filters definitions to applicable ones. Based on:
  # * default_create attribute, and only/except arguments
  # * content_type filters
  #
  # The content_type filters are tricky because if more than one definition
  # matches for the same key, we want to use the most specific content_type match.
  #
  # Otherwise, with or without content_type, if more than one definition matches we
  # execute only the last.
  def applicable_definitions
    # Find all matching definitions, and put them in the candidates hash,
    # so we can choose the best one for each
    candidates = definitions.find_all do |d|
      (only.nil? ? d.default_create : only.include?(d.key)) &&
      (except.nil? || ! except.include?(d.key)) &&
      (d.content_type.nil? || d.content_type == asset.content_type || d.content_type == asset.content_type.sub(%r{/.+\Z}, ''))
    end

    # Now we gotta filter out any duplicate keys based on our priority rules, but keep
    # the ordering. First we sort such that in case of duplicated key,
    # our preferred most-specific-content-type match is LAST, cause in general
    # we want last defn to win.
    candidates.sort! do |a, b|
      byebug if a.nil? || b.nil?

      if a.key != b.key
        0
      else
        most_specific = [b,a].find { |d| d.content_type.present? && d.content_type.include?('/') } ||
          [b,a].find { |d| d.content_type.present? } || b
        if most_specific == a
          1
        else
          -1
        end
      end
    end

    # Now we uniq keeping last defn
    candidates.reverse.uniq {|d| d.key }.reverse
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
