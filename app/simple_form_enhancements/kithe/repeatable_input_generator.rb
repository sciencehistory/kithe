# Uses our multi_input simple_form wrapper.
#
# This is normally expected only to be called by Kithe::FormBuilder#repeatable_attr_input ,
# see docs there, as well as guide docs at [Kithe Forms Guide](../../../guides/forms.md)
#
# FUTURE: more args to customize classses and labels.
class Kithe::RepeatableInputGenerator
  attr_reader :form_builder, :attribute_name, :html_attributes, :simple_form_input_args
  # the block that captures what the caller wants to be repeatable content.
  # It should take one block arg, a form_builder.
  attr_reader :caller_content_block

  def initialize(form_builder, attribute_name, caller_content_block, primitive: nil, html_attributes: nil, build: nil, simple_form_input_args: {})
    @form_builder = form_builder
    @attribute_name = attribute_name
    @caller_content_block = caller_content_block
    @primitive = primitive
    @html_attributes = html_attributes
    @simple_form_input_args = simple_form_input_args

    unless attr_json_registration && attr_json_registration.type.is_a?(AttrJson::Type::Array)
      raise ArgumentError, "can only be used with attr_json-registered attributes"
    end

    unless base_model.class.method_defined?("#{attribute_name}_attributes=".to_sym)
      raise ArgumentError, "Needs a '#{attribute_name}_attributes=' method, usually from attr_json_accepts_nested_attributes_for"
    end

    if html_attributes.present? && (!primitive? || caller_content_block)
      raise ArgumentError, "html_attributes argument is only valid if primitive field without block given"
    end

    # kinda cheesy, but seems good enough?
    if build == :at_least_one && base_model.send(attribute_name).blank?
      if primitive?
        base_model.send("#{attribute_name}=", [""])
      else
        base_model.send("#{attribute_name}=", [{}])
      end
    end
  end

  def render
    # Rails form_builder doesn't create the right input names on nil,
    # we need an empty array so it knows it's a to-many.
    if base_model.send(attribute_name).nil?
      base_model.send("#{attribute_name}=", [])
    end

    # simple_form #input method, with a block for custom input content.
    form_builder.input(attribute_name, wrapper: :vertical_collection, **simple_form_input_args) do
      template.safe_join([
        placeholder_hidden_input,
        existing_value_inputs,
        template.content_tag(:div, class: "repeatable-add-link") do
          add_another_link
        end
      ])
    end
  end

  # If they passed no content block, assume primitive mode
  def primitive?
    if @primitive.nil?
      # Guess, if they passed in no block, they gotta get primitive, or else
      # if the attr_json registration looks primitive.
      @caller_content_block.nil? || attr_json_registration.type.base_type_primitive?
    else
      @primitive
    end
  end

  private

  # Hidden input is to make sure that if the user in UI deletes _all_ instances of a repeatable block,
  # server-side code still gets something submitted to know to blank it out.
  #
  # For primitive types, that's just making sure there is an array submitted (with an empty string
  # value in it, we rely on the attributes= method to strip out.
  #
  # For hash/model values, it's a bit trickier with an empty hash with a destroy value, which
  # the *_attributes= method will also strip out, as it ignores destroy values -- relies on
  # `reject_if: :all_blank` being set on nested attributes call.
  def placeholder_hidden_input
    if primitive?
      template.hidden_field_tag "#{form_builder.object_name}[#{attribute_name}_attributes][]", ""
    else
      template.hidden_field_tag "#{form_builder.object_name}[#{attribute_name}_attributes][_kithe_placeholder][_destroy]", 1
    end
  end

  # The concatenated inputs for any existing values, for either primitive mode or model mode.
  #
  # For primitive mode, the inputs will end up with `name` attributes like `work[attribute_name][]` -- which will
  # end up in submitted params as an array of strings.
  #
  # For models, it'll be proper nested hashes.
  #
  # In either case, wrapped in proper DOM for Cocoon JS to target, including the 'remove' button.
  def existing_value_inputs
    if primitive?
      # We can't use fields_for, and in fact we don't (currently) yield at all,
      # we do clever things with arrays.
      (base_model.send(attribute_name) || []).collect do |str|
        wrap_with_repeatable_ui do
          if caller_content_block.nil?
            default_primitive_input(str)
          else
            caller_content_block.call(primitive_input_name, str)
          end
        end
      end
    else
      # we use fields_for, which will repeatedly yield on repeating existing content
      form_builder.fields_for(attribute_name) do |sub_form|
        wrap_with_repeatable_ui do
          caller_content_block.call(sub_form)
        end
      end
    end
  end


  def default_primitive_input(value=nil)
    # Counting on the _attributes= method added by AttrJson::NestedAttributes, with handling
    # for primitives that removes empty strings from value before writing.
    #
    # For now we disable rails automatic generation of `id` attribute, becuase it
    # would not be unique. FUTURE: perhaps we'll generate unique IDs, need to deal
    # with cocoon JS for added elements.

    tag_attributes = {
      id: nil,
      class: "form-control input-primitive"
    }
    tag_attributes.merge!(html_attributes) if html_attributes

    template.text_field_tag(primitive_input_name, value, tag_attributes)
  end

  # We use _attributes setter, and make sure to set to array value.
  def primitive_input_name
    "#{form_builder.object_name}[#{attribute_name}_attributes][]"
  end

  def template
    form_builder.template
  end

  # The actual instance that the form is editing in the top-level (as far as is known to us here)
  # form builder.
  def base_model
    form_builder.object
  end


  # @return [AttrJson::AttributeDefinition] for the `attribute_name` passed in on the model passed in.
  #   Or nil if there is none -- in which case this component can't do it's thing.
  def attr_json_registration
    @attr_json_registration ||= base_model.class.attr_json_registry[attribute_name]
  end

  # Either an AttrJson::Model class, or the symbol representing the type of the primitive class, like
  # `:string`.
  def repeatable_thing_class
    base_type = attr_json_registration.type.base_type
    if base_type.is_a?(AttrJson::Model)
      base_type
    else
      # Will return a symbol name, confusingly
      base_type.type
    end
  end

  # Wraps with the proper DOM for cocooon JS, along with the remove button.
  # @yield pass block with content to wrap
  def wrap_with_repeatable_ui
    # * cocoon JS wants "nested-fields"
    # * 'row' and is for bootstrap 5 -- but doens't mess up bootstrap 4 because
    #      conveniently the 'form-row' ends up taking precedence.
    # * form-row is for bootstrap 4. Doesn't exist in bootstrap 5.
    template.content_tag(:div, class: "nested-fields form-row row") do
      template.content_tag(:div, class: "col") do
        yield
      end +
      template.content_tag(:div, class: "col-auto") do
        remove_link
      end
    end
  end

  def add_another_link
    # We need to create "blank" unit of repetatable content as HTML, that we'll
    # put as a string in a data attribute on the link. This is what cocooon does.
    #
    # To do that, we need to create a "blank" object of the relevant type,
    # to pass to `fields_for` to create a sub-form-builder, to pass to the caller-provided
    # block, to generate the HTML for 'empty' object.


    # child index gets replaced by cocoon JS, to make sure multiple additions have
    # different paths in the submitted form data.
    #
    # We do not need to CGI.escape, because rails link_to genereator will do that for us.

    template.link_to(add_another_text, "#",
      # cocoon JS needs add_fields class
      class: "add_fields",
      # these are just copied from what cocoon does/wants
      data: {
        association: attribute_name.to_s.singularize,
        associations: attribute_name.to_s.pluralize,
        association_insertion_template: insertion_template
      })
  end

  def add_another_text
    if base_model.class.respond_to?(:human_attribute_name)
      I18n.t("kithe.repeatable_input.add_a", name: base_model.class.human_attribute_name(attribute_name))
    elsif repeatable_type_class.respond_to?(:model_name)
      I18n.t("kithe.repeatable_input.add_a", name: attribute_model_class.model_name.human)
    else
      I8n.t("kithe.repeatable_input.add_bare")
    end
  end


  # Link to "remove" UI. We have the right classes for cocoon JS to notice,
  # but unlike cocoon we don't need to deal with "_destroy" stuff for AR,
  # our attr_json things have no separate existence beyond what will be
  # submitted with form.
  def remove_link
    # cocoon JS needs class specifically remove_fields.dynamic, just treat em all
    # like dynamic, it seems okay.
    template.link_to(I18n.t("kithe.repeatable_input.remove"), '#', class: "remove_fields dynamic btn btn-secondary")
  end

  def insertion_template
    if primitive?
      wrap_with_repeatable_ui do
        if caller_content_block
          caller_content_block.call(primitive_input_name, nil)
        else
          default_primitive_input
        end
      end
    else
      new_object = new_template_model

      form_builder.fields_for(attribute_name, new_object, :child_index => "new_#{attribute_name}") do |sub_form|
        wrap_with_repeatable_ui do
          caller_content_block.call(sub_form)
        end
      end
    end
  end



  # When we generate the repeatable unit, it needs to have a model, so
  # it can generate based on model. If the relevant object is an AttrJson::Model,
  # we create an `empty` object using #cast from the relevant type class, which
  # should get defaults and such.
  #
  # If it's not, we just return nil, which should be fine for primitives.
  #
  # Cocoon had to do more complicated things with ActiveRecord and/or other
  # ORMs.
  def new_template_model
    type = attr_json_registration.type
    if type.is_a?(AttrJson::Type::Array)
      type = type.base_type
    end

    if type.is_a?(AttrJson::Type::Model)
      type.cast({})
    else
      nil
    end
  end

end
