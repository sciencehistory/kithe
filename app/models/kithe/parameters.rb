# Kithe::Parameters are a sub-class of Rails [ActionController::Parameters](https://api.rubyonrails.org/classes/ActionController/Parameters.html)
# (ie [StrongParameters](https://guides.rubyonrails.org/action_controller_overview.html#strong-parameters) )
# with a couple additional features:
#
# 1. White-list top-level keys containing _any_ content
#    with a 'true' value in the filter list.
#
# 2. Automatically add attributes declared with `attr_json` to the
#    whitelisted-for-anything values.
#
# ## Motivation
#
# Complex nested data with attr_json can be used with ordinary Rails strong
# params just like rails associations. But attr_json data can get more complex
# than typical for Rails, and really unwieldy to use.
#
# The strong param guide itself says "The strong parameter API was designed with the most common use
# cases in mind. It is not meant as a silver bullet to handle all of your whitelisting problems."
#
# Since attr_json keys are serialized in their entirety replacing whatever else was
# already there, we believe it is safe to use them with a heavy-handed 'whitelist
# whatever scalar or nested values occur there' approach.
#
# ## Examples
#
# Wrap the `params` Rails gives you in a Kithe::Parameters, and use
# the 'true' key to whitelist anything.
#
#      Kithe::Parameters.new(params).require(:model).permit(some_attr_json_value: true)
#
# Will allow the `some_attr_json_value` key to have _anything_ in it's value:
# primitives, hashes, nested, arrays, etc. Instead of requiring you to describe it's
# "shape" as usual with strong params.
#
# Or auto-allow all declared attr_json keys from some model:
#
#     Kithe::Parameters.new(params).require(:model).permit_attr_json(MyModel).permit
#
# Exclude some attr_json definitions:
#
#     Kithe::Parameters.new(params).require(:model).
#       permit_attr_json(MyModel, except: ["not_this_one", "or_this_one"]).
#       permit
#
# Combine permit_attr_json with ordinary strong params permit filters:
#
#     Kithe::Parameters.new(params).require(:model).
#       permit_attr_json(MyModel).
#       permit(:title, :parent_id, :representative_id, :contained_by_ids => [])
#
# ## Alternatives
#
# We believe this is safe and effective for our use cases. If you disagree or find
# it sketchy, you can use ordinary Rails strong params. Or you can use
# [reform](https://github.com/trailblazer/reform), which should work just fine
# with attr_json/kithe (let us know if you run into any trouble). Or anything
# else!
#
# ## Future?
#
# Should we move this class to attr_json, is it generally useful for attr_json
# users?
class Kithe::Parameters < ActionController::Parameters
  attr_reader :auto_allowed_keys

  def initialize(hash = {})
    if hash.respond_to?(:to_unsafe_h)
      hash = hash.to_unsafe_h
    end
    super(hash)
  end

  def permit_attr_json(klass, except:nil)
    keys = klass.attr_json_registry.attribute_names.collect(&:to_sym)
    keys = keys - Array(except).collect(&:to_sym) if except
    keys = keys.flat_map do |k|
      [k, "#{k}_attributes".to_sym]
    end

    @auto_allowed_keys = keys

    return self
  end

  def permit(*filters)
    whitelisted = self.class.new

    hash_arg = permit_keyword_args(filters)

    hash_arg.keys.each do |key|
      if hash_arg[key] == true
        hash_arg.delete(key)
        if self.has_key?(key)
          whitelisted[key] = self[key]
          self.delete(key)
        end
      end
    end

    return super.merge(whitelisted.permit!)
  end

  private

  def permit_keyword_args(filters)
    kw_args = {}

    if auto_allowed_keys.present?
      kw_args.merge!(
        auto_allowed_keys.collect {|k| [k, true] }.to_h
      )
    end

    if filters.last.kind_of?(Hash)
      kw_args.merge!(filters.last)
    end

    kw_args
  end
end
