# Uses our multi_input simple_form wrapper.
#
# FUTURE: more args to customize classses and labels.
#
# TODO: generating objects not working when we start out with nil/empty array.
# write some tests first please.
class Kithe::RepeatableInputGenerator
  attr_reader :form_builder, :attribute_name
  # the block that captures what the caller wants to be repeatable content.
  # It should take one block arg, a form_builder.
  attr_reader :caller_content_block
  def initialize(form_builder, attribute_name, caller_content_block)
    @form_builder = form_builder
    @attribute_name = attribute_name
    @caller_content_block = caller_content_block

    unless attr_json_registration && attr_json_registration.type.is_a?(AttrJson::Type::Array)
      raise ArgumentError, "can only be used with attr_json-registered attributes"
    end
  end

  def render
    # Rails form_builder doesn't create the right input names on nil,
    # we need an empty array so it knows it's a to-many.
    if base_model.send(attribute_name).nil?
      base_model.send("#{attribute_name}=", [])
    end

    # simple_form #input method, with a block for custom input content.
    form_builder.input(attribute_name, wrapper: :kithe_multi_input) do
      template.safe_join([
        form_builder.fields_for(attribute_name) do |sub_form|
          repeatable_unit(sub_form)
        end,
        template.content_tag(:div, class: "repeatable-add-link") do
          add_another_link
        end
      ])
    end
  end

  private

  def template
    form_builder.template
  end

  # The one that is current in our top-level (as far as is known to us here)
  # form builder.
  def base_model
    form_builder.object
  end

  def attr_json_registration
    @attr_json_registration ||= base_model.class.attr_json_registry[attribute_name]
  end

  # The caller-provided repeatable content, wrapped in our the right DOM
  # for JS, including the 'remove' ui.
  #
  # form_builder is passed in, becuase it may be a sub-form created with `fields_for`,
  # for nested models.
  def repeatable_unit(form_builder)
    # cocoon JS wants "nested-fields"
    template.content_tag(:div, class: "nested-fields form-row") do
      template.content_tag(:div, class: "col") do
        caller_content_block.call(form_builder)
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

    new_object = new_template_model

    label = generate_label(new_object)

    # child index gets replaced by cocoon JS, to make sure multiple additions have
    # different paths in the submitted form data.
    #
    # We do not need to CGI.escape, because rails link_to genereator will do that for us.
    insertion_template = form_builder.fields_for(attribute_name, new_object, :child_index => "new_#{attribute_name}") do |sub_form|
      repeatable_unit(sub_form)
    end


    template.link_to(label, "#",
      # cocoon JS needs add_fields class
      class: "add_fields",
      # these are just copied from what cocoon does/wants
      data: {
        association: attribute_name.to_s.singularize,
        associations: attribute_name.to_s.pluralize,
        association_insertion_template: insertion_template
      })
  end

  def generate_label(new_object)
    label = "Add another"

    if base_model.class.respond_to?(:human_attribute_name)
      label += " #{base_model.class.human_attribute_name(attribute_name)}"
    elsif new_object.respond_to?(:model_name)
      label += " #{c}"
    end

    label
  end


  # Link to "remove" UI. We have the right classes for cocoon JS to notice,
  # but unlike cocoon we don't need to deal with "_destroy" stuff for AR,
  # our attr_json things have no separate existence beyond what will be
  # submitted with form.
  def remove_link
    # cocoon JS needs class remove_fields.dynamic, just treat em all
    # like dynamic, it seems okay.
    template.link_to("Remove", '#', class: "remove_fields dynamic btn btn-warning")
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
