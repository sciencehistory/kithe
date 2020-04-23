class Shrine
  module Plugins
    # This adds some features around shrine promotion that we found useful for dealing
    # with backgrounding promotion.
    #
    # * TODO: Don't hard-code here. It will run shrine uploader metadata extraction routines on _any promotion_,
    #   also adding a `promoting: true` key to the shrine context for that metadata
    #   extraction. (Using shrine refresh_metadata plugin)
    #
    # * We separately give our Kithe::Asset model class an activemodel callback
    #   "promotion" hook. This plugin will call those callbacks around promotion (whether background
    #   or foreground) -- before, after, or around.
    #
    #   If a callback does a `throw :abort` before promotion, it can cancel promotion. This could
    #   be used to cancel promotion for a validation failure of some kind -- you'd want to somehow
    #   store or notify what happened, otherwise to the app and it's users it will just look like
    #   the thing was never promoted for unknown reasons.
    #
    #   After promotion hooks can be used to hook into things you want to do only after a promotion;
    #   since promotion is backgrounded it would be otherwise inconvenient to execute something
    #   only after promotion completes.
    #
    #   The default Kithe::Asset hooks into after_promotion to run derivatives creation
    #   routines.
    #
    # * A special :promotion_directives key in the shrine context, which will be serialized
    #   and restored to be preserved even accross background promotion. It is intended to hold
    #   a hash of arbitrary key/values.  The special key :skip_callbacks, when set to a truthy
    #   value, will prevent the promotion callbacks discussed above from happening. So if you want
    #   to save a Kithe::Asset and have promotion happen as usual, but _not_ trigger any callbacks
    #   (including derivative creation):
    #
    #   some_asset.file = some_assignable_file
    #   some_asset.file_attacher.set_promotion_directives(skip_callbacks: true)
    #   some_asset.save!
    #
    #   You can add other arbitrary keys which your own code in an uploader or promotion
    #   callback may consult, with `set_promotion_directives` as above. To consult, check
    #   attacher.promotion_directives[:some_key]
    #
    #   You can also set promotion directives globally for Kithe::Asset or a sub-class, in
    #   a class method. Especially useful for batch processing.
    #
    #       Kithe::Asset.promotion_directives = { promote: :inline, create_derivatives: :inline }
    #
    class KithePromotionDirectives
      # whitelist of allowed promotion_directive keys, so we can raise on typos but still
      # be extensible. Also serves as some documentation of what directives available.
      class_attribute :allowed_promotion_directives,
        instance_writer: false,
        default: [:promote, :skip_callbacks, :create_derivatives, :delete]

      # def self.load_dependencies(uploader, *)
      #   uploader.plugin :refresh_metadata
      #   uploader.plugin :backgrounding
      # end

      module AttacherMethods

        # Set one or more promotion directives, in context[:promotion_directives], that
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
          # unpredictably.
          hash = hash.collect { |k, v| [k.to_s, v === Symbol ? v.to_s : v.to_s]}.to_h

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
