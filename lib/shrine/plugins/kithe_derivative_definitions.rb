class Shrine
  module Plugins
    class KitheDerivativeDefinitions
      def self.configure(uploader, *opts)
        # use Rails class_attribute to conveniently have a class-level place
        # to store our derivative definitions that are inheritable and overrideable.
        # We store it on the Attacher class, because that's where shrine
        # puts derivative processor definitions, so seems appropriate.
        uploader::Attacher.class_attribute :kithe_derivative_definitions, instance_writer: false, default: []

        # Register our derivative processor, that will create our registered derivatives,
        # with our custom options.
        uploader::Attacher.derivatives(:kithe_derivatives) do |original, **options|
          Kithe::Asset::DerivativeCreator.new(self.class.kithe_derivative_definitions,
            source_io: original,
            shrine_attacher: self,
            only: options[:only],
            except: options[:except],
            lazy: options[:lazy]
          ).call
        end
      end

      module AttacherClassMethods
        # Establish a derivative definition that will be used to create a derivative
        # when #create_derivatives is called, for instance automatically after promotion.
        #
        # The most basic definition consists of a derivative key, and a ruby block that
        # takes the original file, transforms it, and returns a ruby File or other
        # (shrine-compatible) IO-like object. It will usually be done inside a custom Asset
        # class definition.
        #
        #     class Asset < Kithe::Asset
        #       define_derivative :thumbnail do |original_file|
        #       end
        #     end
        #
        # The original_file passed in will be a ruby File object that is already open for reading. If
        # you need a local file path for your transformation, just use `original_file.path`.
        #
        # The return value can be any IO-like object. If it is a ruby File or Tempfile,
        # that temporary file will be deleted for you after the derivative has been created. If you
        # have to make any intermediate files, you are responsible for cleaning them up. Ruby stdlib
        # Tempfile and Dir.mktmpdir may be useful.
        #
        # If in order to do your transformation you need additional information about the original,
        # just add a `record:` keyword argument to your block, and the Asset object will be passed in:
        #
        #     define_derivative :thumbnail do |original_file, record:|
        #        record.width, record.height, record.content_type # etc
        #     end
        #
        # Derivatives are normally uploaded to the Shrine storage labeled :kithe_derivatives,
        # but a definition can specify an alternate Shrine storage id. (specified shrine storage key
        # is applied on derivative creation; if you change it with existing derivatives, they should
        # remain, and be accessible, where they were created; there is no built-in solution at present
        # for moving them).
        #
        #     define_derivative :thumbnail, storage_key: :my_thumb_storage do |original| # ...
        #
        # You can also set `default_create: false` if you want a particular definition not to be
        # included in a no-arg `asset.create_derivatives` that is normally triggered on asset creation.
        #
        # And you can set content_type to either a specific type like `image/jpeg` (or array of such) or a general type
        # like `image`, if you want to define a derivative generation routine for only certain types.
        # If multiple blocks for the same key are defined, with different content_type restrictions,
        # the most specific one will be used.  That is, for a JPG, `image/jpeg` beats `image` beats no restriction.
        def define_derivative(key, content_type: nil, default_create: true, &block)
          # Make sure we dup the array to handle sub-classes on class_attribute
          self.kithe_derivative_definitions = self.kithe_derivative_definitions.dup.push(
            Kithe::Asset::DerivativeDefinition.new(
              key: key,
              content_type: content_type,
              default_create: default_create,
              proc: block
            )
          ).freeze
        end

        # Returns all derivative keys registered with a definition, as array of strings
        def defined_derivative_keys
          self.kithe_derivative_definitions.collect(&:key).uniq.collect(&:to_s)
        end

        # If you have a subclass that has inherited derivative definitions, you can
        # remove them -- only by key, will remove any definitions with that key regardless
        # of content_type restrictions.
        #
        # This could be considered rather bad OO design, you might want to consider
        # a different class hieararchy where you don't have to do this. But it's here.
        def remove_derivative_definition!(*keys)
          keys = keys.collect(&:to_sym)
          self.kithe_derivative_definitions = self.kithe_derivative_definitions.reject do |defn|
            keys.include?(defn.key.to_sym)
          end.freeze
        end
      end
    end
    register_plugin(:kithe_derivative_definitions, KitheDerivativeDefinitions)
  end
end
