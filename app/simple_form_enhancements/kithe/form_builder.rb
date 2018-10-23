# A SimpleForm::FormBuilder sub-class with custom kithe features:
#
# * repeatable_model_input
#
# If you use the `kithe_form_for` helper instead of `simple_form_for`, you get
# a custom Kithe::FormBuilder in your simple_form building.
class Kithe::FormBuilder < SimpleForm::FormBuilder


  # Produce a form input for a repeatable attr_json field. Takes care
  # of the add/remove UI apparatus -- generated HTML assumes Bootstrap 4.
  #
  # If you have a repeatable AttrJson::Model attribute, you might write
  # a form input for it like this:
  #
  #     <%= kithe_form_for(@work) do |f| %>
  #       <%= f.repeatable_model_input(:author) do |sub_form| %>
  #          <div class="form-row">
  #            <div class="col-auto">
  #              <%= sub_form.input :category, collection: SOME_CATEGORIES, label: false %>
  #            </div>
  #            <div class="col">
  #              <%= sub_form.input :value, label: false %>
  #            </div>
  #          </div>
  #       <% end %>
  #     <% end %>
  #
  # Note that it _requires_ a block, consisting of the HTML for a single element of
  # the repeatable entry -- using the yielded sub_form parameter as a form builder.
  #
  # repeatable_model_input generates HTML with data attributes that will be used by
  # Javascript to make the field repeatable. Currently we are using the cocoon javascript
  # (although not the cocoon generator methods), so you'll need to `//= require cocoon` in your
  # app JS.
  #
  # Note we use simple_form `input` method in our block above -- this will allow any errors
  # on nested objects to show up appropriately! simple_form errors on the main :author element
  # will show up properly too, courtesy of the kithe multi_input_wrapper. Likewise,
  # [simple_form i18n](https://github.com/plataformatec/simple_form#i18n) on top-level
  # as well as nested elements should show up, for labels and hints. It may be tricky
  # to figure out proper i18n key paths for nested elements.
  #
  # Actual implementation code is over in Kithe::RepeatableInputGenerator
  #
  # Note: Need attr_json_accepts_nested_attributes_for
  #
  # FUTURE: Provide options to customize classes and labels on generated wrapping UI apparatus.
  def repeatable_model_input(attr_name, primitive: false, &block)
    #repeatable_main_content(attr_name, &block)
    Kithe::RepeatableInputGenerator.new(self, attr_name, block, primitive: primitive).render
  end
end
