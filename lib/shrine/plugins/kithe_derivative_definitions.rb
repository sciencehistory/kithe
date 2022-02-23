class Shrine
  module Plugins
    class KitheDerivativeDefinitions
      def self.configure(uploader, *opts)
        # use Rails class_attribute to conveniently have a class-level place
        # to store our derivative definitions that are inheritable and overrideable.
        # We store it on the Attacher class, because that's where shrine
        # puts derivative processor definitions, so seems appropriate. Normally
        # not touched directly by non-kithe code.
        uploader::Attacher.class_attribute :kithe_derivative_definitions, instance_writer: false, default: []

        # Kithe exersizes lifecycle control over derivatives, normally just the
        # shrine processor labelled :kithe_derivatives. But you can opt additional shrine
        # derivative processors into kithe control by listing their labels in this attribute.
        #
        # @example
        #
        #     class AssetUploader < Kithe::AssetUploader
        #       Attacher.kithe_include_derivatives_processors += [:my_processor]
        #       Attacher.derivatives(:my_processor) do |original|
        #         derivatives
        #       end
        #     end
        #
        uploader::Attacher.class_attribute :kithe_include_derivatives_processors, instance_writer: false, default: []

        # Register our derivative processor, that will create our registered derivatives,
        # with our custom options.
        #
        # We do download: false, so when our `lazy` argument is in use, original does not get eagerly downloaded,
        # but only gets downloaded if needed to make derivatives. This is great for performance, especially
        # when running batch job to add just missing derivatives.
        uploader::Attacher.derivatives(:kithe_derivatives, download: false) do |original, **options|
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
        # (shrine-compatible) IO-like object. It will usually be done inside your custom
        # AssetUploader class definition.
        #
        #     class AssetUploader < Kithe::AssetUploader
        #       Attacher.define_derivative :thumbnail do |original_file|
        #         someTempFileOrOtherIo
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
        # just add a `attacher:` keyword argument to your block, and a `Shrine::Attacher` subclass
        # will be passed in. You can then get the model object from `attacher.record`, or the
        # original file as a `Shrine::UploadedFile` object with `attacher.file`.
        #
        #     Attacher.define_derivative :thumbnail do |original_file, attacher:|
        #        attacher.record.title, attacher.file.width, attacher.file.content_type # etc
        #     end
        #
        # Derivatives are normally uploaded to the Shrine storage labeled :kithe_derivatives,
        # but a definition can specify an alternate Shrine storage id. (specified shrine storage key
        # is applied on derivative creation; if you change it with existing derivatives, they should
        # remain, and be accessible, where they were created; there is no built-in solution at present
        # for moving them).
        #
        #     Attacher.define_derivative :thumbnail, storage_key: :my_thumb_storage do |original| # ...
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

      module AttacherMethods


        # Similar to shrine create_derivatives, but with kithe standards:
        #
        # * Will call the :kithe_derivatives processor (that handles any define_derivative definitions),
        #   plus any processors you've configured with kithe_include_derivatives_processors
        #
        # * Uses the methods added by :kithe_persisted_derivatives to add derivatives completely
        #   concurrency-safely, if the model had it's attachment changed concurrently, you
        #   won't get derivatives attached that belong to old version of original attachment,
        #   and won't get any leftover "orphaned" derivatives either.
        #
        # The :kithe_derivatives processor has additional logic and options for determining
        # *which* derivative definitions -- created with `define_deriative` will be executed:
        #
        # * Ordinarily will create a definition for every definition that has not been marked
        #  `default_create: false`.
        #
        # * But you can also pass `only` and/or `except` to customize the list of definitions to be created,
        #   possibly including some that are `default_create: false`.
        #
        # * Will normally re-create derivatives (per existing definitions) even if they already exist,
        #   but pass `lazy: false` to skip creating if a derivative with a given key already exists.
        #   This will use the asset `derivatives` association, so if you are doing this in bulk for several
        #   assets, you should eager-load the derivatives association for efficiency.
        #
        # If you've added any custom processors with `kithe_include_derivatives_processors`, it's
        # your responsibility to make them respect those options. See #process_kithe_derivative?
        # helper method.
        #
        # create_derivatives should be idempotent. If it has failed having only created some derivatives,
        # you can always just run it again.
        #
        def kithe_create_derivatives(only: nil, except: nil, lazy: false)
          return false unless file

          local_files = self.process_derivatives(:kithe_derivatives, only: only, except: except, lazy: lazy)

          # include any other configured processors
          self.kithe_include_derivatives_processors.each do |processor|
            local_files.merge!(
              self.process_derivatives(processor.to_sym, only: only, except: except, lazy: lazy)
            )
          end

          self.add_persisted_derivatives(local_files)
        end

        # a helper method that you can use in your own shrine processors to
        # handle only/except/lazy guarding logic.
        #
        # @return [Boolean] should the `key` be processed based on only/except/lazy conditions?
        #
        # @param key [Symbol] derivative key to check for guarded processing
        # @param only [Array<Symbol>] If present, method will only return true if `key` is included in `only`
        # @param except [Array<Symbol] If present, method will only return true if `key` is NOT included in `except`
        # @param lazy [Boolean] If true, method will only return true if derivative key is not already present
        #   in attacher with a value.
        #
        def process_kithe_derivative?(key, **options)
          key = key.to_sym
          only = options[:only] && Array(options[:only]).map(&:to_sym)
          except = options[:except] && Array(options[:except]).map(&:to_sym)
          lazy = !! options[:lazy]

          (only.nil? ? true : only.include?(key)) &&
          (except.nil? || ! except.include?(key)) &&
          (!lazy || !derivatives.keys.include?(key))
        end

        # Convenience to check #process_kithe_derivative? for multiple keys at once,
        # @return true if any key returns true
        #
        # @example process_any_kithe_derivative?([:thumb_mini, :thumb_large], only: [:thumb_large, :thumb_mega], lazy: true)
        def process_any_kithe_derivative?(keys, **options)
          keys.any? { |k| process_kithe_derivative?(k, **options) }
        end
      end
    end
    register_plugin(:kithe_derivative_definitions, KitheDerivativeDefinitions)
  end
end
