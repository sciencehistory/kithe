# Creates derivatives from definitions stored on an Asset class
class Kithe::Asset::DerivativeCreator
  attr_reader :definitions, :asset, :only, :except, :lazy, :mark_created

  # A helper class that provides the implementation for Kithe::Asset#create_derivatives,
  # normally only expected to be called from there.
  #
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
  # @param lazy (default false), Normally we will create derivatives for all applicable definitions,
  #   overwriting any that already exist for a given key. If the definition has changed, a new
  #   derivative created with new definition will overwrite existing. However, if you pass lazy false,
  #   it'll skip derivative creation if the derivative already exists, which can save time
  #   if you are only intending to create missing derivatives.  With lazy:false, the asset
  #   derivatives association will be consulted, so should be eager-loaded if you are going
  #   to be calling on multiple assets.
  # @param mark_created [Boolean] if true will set shrine metadata indicating we've done
  #   derivative creation phase, so Asset#derivatives_created? will return true. Defaults to nil,
  #   meaning true if and only if `only` is nil -- mark created if creating default derivatives.
  def initialize(definitions, asset, only:nil, except:nil, lazy: false)
    @definitions = definitions
    @asset = asset
    @only = only && Array(only)
    @except = except && Array(except)
    @lazy = !!lazy
  end

  def call
    return unless asset.file.present? # if no file, can't create derivatives

    definitions_to_create = applicable_definitions

    if lazy
      existing_derivative_keys = asset.file_derivatives.keys
      definitions_to_create.reject! do |defn|
        existing_derivative_keys.include?(defn.key)
      end
    end

    return {} unless definitions_to_create.present?

    derivatives = {}

    # Note, MAY make a superfluous copy and/or download of original file, ongoing
    # discussion https://github.com/shrinerb/shrine/pull/329#issuecomment-443615868
    # https://github.com/shrinerb/shrine/pull/332
    Shrine.with_file(asset.file) do |original_file|
      definitions_to_create.each do |defn|
        deriv_bytestream = defn.call(original_file: original_file, record: asset)

        if deriv_bytestream
          derivatives[defn.key] =  deriv_bytestream
        end

        original_file.rewind
      end
    end

    derivatives
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
    candidates = definitions.find_all do |defn|
      (only.nil? ? defn.default_create : only.include?(defn.key)) &&
      (except.nil? || ! except.include?(defn.key)) &&
      defn.applies_to?(asset)
    end

    # Now we gotta filter out any duplicate keys based on our priority rules, but keep
    # the ordering. First we sort such that in case of duplicated key,
    # our preferred most-specific-content-type match is LAST, cause in general
    # we want last defn to win.
    candidates.sort! do |a, b|
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
end
