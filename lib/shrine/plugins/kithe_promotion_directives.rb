class Shrine
  module Plugins
    # This adds some features around shrine promotion that we found useful for dealing
    # with backgrounding promotion.
    #
    # By default the kithe setup:
    #
    # * Does "promotion" in background job -- metadata extraction, and moving file from 'cache' to 'store'
    # * Runs ActiveSupport-style callbacks around promotion (before_promotion, after_promotion)
    # * Uses these callbacks to make sure we extract metadata on promotion (which shrine doesn't do by default)
    # * Uses these callbacks to trigger our custom create_derivatives code *after* promotion
    #
    # There are times you want to customize these life cycle actions, either disabling them, or switching
    # them from a background job to happen inline in the foreground. Some use cases for this are: 1) in
    # automated testing; 2) when you are running a batch job (eg batch import), you might want to
    # disable some expensive things per-record to instead do them all in batch at the end, or
    # run them inline to keep from clogging up your bg job queue, and have better 'backpressure'.
    #
    # We provide something we call "promotion directives" to let you customize these. You can set
    # them on a shrine Attacher; or on a Kithe `Asset` model individually, or globally on the class.
    #
    # ## Directives
    #
    # * `promote`: default `:background`; set to `:inline` to do promotion inline instead of a background
    #    job, or `false` to make promotion not happen automatically at all.
    #
    # * `skip_callbacks`: default `false`, set to `true` to disable our custom promotion callbacks
    #    entirely, including disabling our default callbacks such as derivative creation and
    #    promotion metadata extraction.
    #
    # * `create_derivatives`: default `background` (create a separate bg job). Also can be `false`
    #    to disable, or `inline` to create derivatives 'inline' when the after_promotion hook
    #    occurs -- which could already be in a bg job depending on `promote` directive!
    #
    # * `delete`: should _deletion_ of shrine attachment happen in a bg job? Default `:background`,
    #    can also be `false` (can't think of a good use case), or `:inline`.
    #
    # # Examples of setting
    #
    # ## Globally on Kithe::Asset
    #
    # Useful for batch processing or changing test defaults.
    #
    #    Kithe::Asset.promotion_directives = { promote: :inline, create_derivatives: false }
    #
    # ## On a Kithe::Asset individual model
    #
    #    asset = Kithe:Assst.new
    #    asset.set_promotion_directives(create_derivatives: :inline)
    #
    # (Aggregates on top of whatever was set at class level of previously set with `Asset#set_promotion_directives)`,
    # does not replace previously settings but merges into them!
    #
    # ## Directly on a shrine attacher
    #
    #   some_asset.file = some_assignable_file
    #   some_asset.file_attacher.set_promotion_directives(skip_callbacks: true)
    #   some_asset.save!
    #
    # (Aggregates on top of whatever was already set, merges into it, does not replace!)
    #
    # ## Checking current settings
    #
    #     some_asset.promotion_directives
    #
    # or
    #
    #     some_asset.file_attacher.promotion_directives
    #
    class KithePromotionDirectives
      # whitelist of allowed promotion_directive keys, so we can raise on typos but still
      # be extensible. Also serves as some documentation of what directives available.
      class_attribute :allowed_promotion_directives,
        instance_writer: false,
        default: [:promote, :skip_callbacks, :create_derivatives, :delete]

      module AttacherMethods

        # Set one or more promotion directives, stored context[:promotion_directives], that
        # will be serialized and restored to context for bg promotion. The values are intended
        # to be simple strings or other json-serializable primitives.
        #
        # set_promotion_directives will merge it's results into existing promotion directives,
        # existing keys will remain. So you can set multiple directives with multiple
        # calls to set_promotion_directives, or pass multiple keys to one calls.
        #
        # @example
        #     some_model.file_attacher.set_promotion_directives(skip_callbacks: true)
        #     some_model.save!
        def set_promotion_directives(hash)
          # ActiveJob sometimes has trouble if there are symbols in there, somewhat
          # unpredictably. And for other reasons, standardize on everything a string.
          hash = hash.collect { |k, v| [k.to_s, v.to_s]}.to_h

          unrecognized = hash.keys.collect(&:to_sym) - KithePromotionDirectives.allowed_promotion_directives
          unless unrecognized.length == 0
            raise ArgumentError.new("Unrecognized promotion directive key: #{unrecognized.join('')}")
          end

          promotion_directives.merge!(hash)
        end

        # context[:promotion_directives], lazily initializing to hash for convenience.
        def promotion_directives
          context[:promotion_directives] ||= {}
        end
      end
    end
    register_plugin(:kithe_promotion_directives, KithePromotionDirectives)
  end
end
