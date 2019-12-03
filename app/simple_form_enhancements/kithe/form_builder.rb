# A SimpleForm::FormBuilder sub-class with custom kithe features:
#
# * repeatable_model_input
#
# If you use the `kithe_form_for` helper instead of `simple_form_for`, you get
# a custom Kithe::FormBuilder in your simple_form building.
class Kithe::FormBuilder < SimpleForm::FormBuilder


  # Produce a form input for a repeatable attr_json field. Takes care
  # of the add/remove UI apparatus -- generated HTML assumes Bootstrap 4,
  # and simple_form Bootstrap config with a :vertical_collection wrapper.
  #
  # See the [Forms Guide](../../../guides/forms.md) for more usage information.
  #
  # Actual implementation code is over in Kithe::RepeatableInputGenerator
  #
  # This is a method rather than a simple form component mostly becuase simple form components
  # don't allow a block param like this, and that works out so well here.
  #
  # FUTURE: Provide options to customize classes and labels on generated wrapping UI apparatus.
  #
  # @param attr_name [Symbol] Model attribute to generate input for, same one
  #   you'd pass to a form builder.
  # @param build [Boolean] nil default, or set to :at_least_one to have an empty input
  #   generated even if the model includes no elements.
  # @param html_attributes [Hash] hash of additional attributes to add to a generated simple
  #   primitive <input> tag. Useful for data- attributes for custom JS behavior. Only valid
  #   if the generator will be generating a simple primtiive input for you, otherwise will
  #   raise ArgumentError if you try.
  # @yield [builder] For model-type attributes (not primitives), yields a sub-builder similar to `fields_for`.
  # @yiieldparam [SimpleForm::FormBuilder] builder
  # @yield [input_name, value] For primitive-type attributes, different yield.
  # @yieldparam [String] input_name  that should be used as HTML "name" attribute on input
  # @yieldparam [String] value that should be used as existing value when generating input for
  #   primitive, usually by passing to `value` attribute in some input builder.
  # @yieldparam [Hash] hash of additional keyword args to pass to underlying simple_form
  #    #input method. Eg `required`.
  def repeatable_attr_input(attr_name, html_attributes: nil, build: nil, simple_form_input_args: {},  &block)
    #repeatable_main_content(attr_name, &block)
    Kithe::RepeatableInputGenerator.new(self, attr_name, block,
      html_attributes: html_attributes,
      simple_form_input_args: simple_form_input_args,
      build: build).render
  end
end
