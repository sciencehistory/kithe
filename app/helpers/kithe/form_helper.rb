module Kithe::FormHelper
  # Just a convenience to do simple_form_for with the Kithe::FormBuilder
  #
  # Just simple_form_for with a `builder:` arg that defaults to
  # Kithe::FormBuilder.  This pattern is advised by simple_form:
  # https://github.com/plataformatec/simple_form#custom-form-builder
  def kithe_form_for(object, *args, &block)
    options = args.extract_options!
    options[:builder] ||= Kithe::FormBuilder

    simple_form_for(object, *(args << options), &block)
  end
end
