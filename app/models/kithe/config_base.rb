require 'singleton'
require 'concurrent'

module Kithe
  # A central place for environmental/infrastructure type configuration. There were
  # many existing ruby/rails 'config' solutions, but none did quite what I wanted without extra
  # complexity. We will try to avoid kithe dependencies on this file, this is available solely
  # as something for an individual app to use when it is convenient.
  #
  # Kithe::Config:
  #
  # * uses an explicit declared list of allowable config keys, no silent typos
  # * can read from a local YAML file or ENV, by default letting ENV override local YAML file values.
  # * Can transform string values from ENV to some other value type
  # * Lets you set defaults in code, including defaults which are based on values from other
  #   config keys.
  # * Flat list of keys, you can 'namespace' in your key names if you want, nested hashes in my
  #   experience add too much complexity and bug potential. Kithe::ConfigBase does _not_ use
  #   the problematic [hashie](https://github.com/intridea/hashie) gem.
  #
  # # Usage
  #
  # You will define a custom app subclass of Kithe::ConfigBase, and define allowable config
  # keys in there. In the simplest case:
  #
  #     class Config < Kithe::ConfigBase
  #       config_file Rails.root.join("config", "local_env.yml")
  #       define_key :foo_bar, default: "foo bar"
  #     end
  #
  # We recommend you put your local class in `./lib` to avoid any oddness with Rails auto-re-loading.
  #
  # This can then be looked up with:
  #
  #     Config.lookup("foo_bar")
  #
  # If you request a key that was not defined, an ArgumentError is raised. `lookup` will happily
  # return nil if no value or default were provided. Instead, for early raise (of a TypeError) on
  # nil or `blank?`:
  #
  #     Config.lookup!("foo_bar")
  #
  # By default this will load from:
  #   1. a system ENV value `FOO_BAR`
  #   2. the specified `config_file` (can specify an array of multiple, later in list take priority;
  #      config files are run through ERB)
  #   3. the default provided in the `define_key` definition
  #
  # All values are cached after first lookup for performance and stabilty -- this
  # kind of environmental configuration should not change for life of process.
  #
  # ## Specifying ENV lookup
  #
  # You can disable the ENV lookup:
  #
  #     define_key :foo_bar, env_key: false
  #
  # Or specify a value to use in ENV lookup, instead of the automatic translation:
  #
  #     define_key :foo_bar, env_key: "unconventional_foo_bar"
  #
  # Since ENV values are always strings, you can also specify a proc meant for use to transform to some
  # other type:
  #
  #     define_key :foo_bar, system_env_transform: ->(str) { Integer(str) }
  #
  # A built in transform is provided for keys meant to be boolean, which uses ActiveModel-compatible
  # translation ("0", "false" and empty string are falsey):
  #
  #     define_key :foo_bar, system_env_transform: Kithe::ConfigBase::BOOLEAN_TRANSFORM
  #
  # ## Default value as proc
  #
  # A default value can be provided as a proc. It is still only lazily executed once.
  #
  #     define_key :foo_bar, default: -> { "something" }
  #
  # A proc default value can also use other config keys, simply by looking them up as usual:
  #
  #     define_key :foo_bar, default: => { "#{Config.lookup!('baz')} plus more" }
  #
  # ## Future possible enhancements
  #
  # * Specify proc or regexp defining allowable values, raise early if no match.
  # * This is not completely thread-safe on boot, if multiple threads somehow concurrently
  #   trigger first load of conf files. But probably shouldn't happen, should be fine.
  class ConfigBase
    include Singleton

    class_attribute :config_file_paths, instance_writer: false, default: [].freeze

    NoValueProvided = Object.new
    private_constant :NoValueProvided

    BOOLEAN_TRANSFORM = lambda { |v| ! v.in?(ActiveModel::Type::Boolean::FALSE_VALUES) }

    def initialize
      @key_definitions = {}
    end

    def self.define_key(*args)
      instance.define_key(*args)
    end

    def self.lookup(*args)
      instance.lookup(*args)
    end

    def self.lookup!(*args)
      instance.lookup!(*args)
    end

    def self.config_file(args)
      self.config_file_paths = (self.config_file_paths + Array(args)).freeze
    end

    def define_key(name, env_key: nil, default: nil, system_env_transform: nil)
      @key_definitions[name.to_sym] = {
        name: name.to_s,
        env_key: env_key,
        default: default,
        system_env_transform: system_env_transform
      }
    end

    def lookup(name)
      defn = @key_definitions[name.to_sym]
      raise ArgumentError.new("No env key defined for: #{name}") unless defn

      defn[:cached_result] ||= begin
        result = system_env_lookup(defn)
        result = file_lookup(defn) if result == NoValueProvided
        result = default_lookup(defn) if result == NoValueProvided
        result = nil if result == NoValueProvided
        result
      end
    end

    # like lookup, but raises on no or blank value.
    def lookup!(name)
      lookup(name).tap do |value|
        raise TypeError, "No value was provided for `#{name}`" if value.blank?
      end
    end

    private

    def system_env_lookup(defn)
      return NoValueProvided if defn[:env_key] == false

      value = if defn[:env_key] && ENV.has_key?(defn[:env_key].to_s)
        ENV[defn[:env_key].to_s]
      elsif ENV.has_key?(defn[:name].upcase)
        ENV[defn[:name].upcase]
      end

      if value
        defn[:system_env_transform] ? defn[:system_env_transform].call(value) : value
      else
        NoValueProvided
      end
    end

    def file_lookup(defn)
      @loaded_from_files ||= load_from_files!
      if @loaded_from_files.has_key?(defn[:name])
        @loaded_from_files[defn[:name]]
      else
        NoValueProvided
      end
    end

    def load_from_files!
      loaded = {}
      config_file_paths.each do |file_path|
        if File.exist?(file_path)
          loaded.merge!( YAML.load(ERB.new(File.read(file_path)).result) || {} )
        end
      end
      return loaded
    end

    def default_lookup(defn)
      if !defn.has_key?(:default)
        NoValueProvided
      elsif defn[:default].respond_to?(:call)
        # allow a proc that gets executed on demand
        defn[:default].call
      else
        defn[:default]
      end
    end
  end
end
