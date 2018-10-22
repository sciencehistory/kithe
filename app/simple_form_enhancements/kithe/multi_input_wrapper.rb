# A custom simple_form wrapper intended for displaying attributes which are models which themselves
# have multiple attributes.
#
# Displays with a fieldset and legend tags for proper semenatics for accessibility.
#
# Will display hint and error messages for top-level containing attribute properly.
#
# This is automatically registered with simpleform as kithe_multi_input by our engine railtie.
#
# If you have an attr_json defined to be an Author model, with a :first_name and
# :last_name, you might use this wrapper like this (always with a block arg):
#
#     <%= f.input :author, wrapper: :multi_input, hint: "A hint" do %>
#       <div class="nested-fields">
#         <%= f.fields_for |author_form| do %>
#           <%= author_form.input :first_name %>
#           <%= author_form.input :last_name %>
#         <% end %>
#       </div>
#     <% end %>
#
module Kithe::MultiInputWrapper
  # FUTURE: Could provide optional keyword args to customize classes involved.
  def self.register(simple_form_config)
    simple_form_config.wrappers :kithe_multi_input, tag: 'fieldset', class: 'form-group', error_class: 'form-group-invalid', valid_class: 'form-group-valid' do |b|
      b.use :html5

      b.use :label_text, wrap_with: { tag: "legend", class: 'form-control-label col-form-label pt-0' }

      b.wrapper tag: 'div', unless_blank: true, class: "form-group multi-input-prompts" do |ba|
        # actual `invalid-feedback` class would end up making it hidden, but we give it
        # `custom-invalid-feedback` in case someone wants to target it to override.
        ba.use :full_error, wrap_with: { tag: 'div', class: 'custom-invalid-feedback text-danger small multi-input-error' }
        ba.use :hint, wrap_with: { tag: 'small', class: 'form-text text-muted multi-input-hint' }
      end

      # We need the `input` tag so our block content will be rendered. We don't expect it ever
      # to be used.
      b.use :input
    end
  end
end
