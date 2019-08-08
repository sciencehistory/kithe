module Kithe
  # Just a handy class for handling logic with our promotion directives
  # for "timing" promotion directives whose values are "false", "background",
  # or "inline", where the default is "background"
  #
  # These directives are :promote, :create_derivatives, and :delete
  #
  # You might use like:
  #
  #     Kithe::LifecyclePromotionDirective.new(key: :promotion, directives: asset.file_attacher.promotion_directives) do |directive|
  #       if directive.inline?
  #         run_something
  #       elsif directive.background?
  #         SomeJob.perform_later
  #       end
  #     end
  class TimingPromotionDirective
    DEFAULT_VALUE = "background"
    ALLOWED_VALUES = ["background", "inline", "false"]

    attr_reader :directive_key, :directives

    def initialize(key:, directives: )
      @directive_key = key.to_sym
      @directives = directives

      unless ALLOWED_VALUES.include?(directive_value)
        raise ArgumentError.new("Unrecognized value `#{directive_value}` for `#{key}`; must be #{ALLOWED_VALUES}")
      end

      yield self
    end

    def directive_value
      @directive_value ||= begin
        value = (directives || {})[directive_key]
        # not blank?, cause false we want to recognize.
        (value.nil? || value == "") ? DEFAULT_VALUE : value.to_s
      end
    end

    def inline?
      directive_value == "inline"
    end

    def background?
      directive_value == "background"
    end

    def disabled?
      directive_value == "false"
    end
  end
end
