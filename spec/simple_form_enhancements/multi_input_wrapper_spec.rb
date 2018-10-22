require 'rails_helper'
require 'simple_form'

# Kind of hacky way we figured out to test simple form generation, it works!
# Might abstract out into something that can be shared with other specs later.
describe "multi_input_wrapper", type: :helper do
  around(:all) do |suite|
    TestModel = Class.new do
      include ActiveModel::Model

      attr_accessor :author_error, :author

      validate :add_errors

      def add_errors
        errors.add(:author_error, "cannot be blank")
      end
    end

    suite.run

    Object.send(:remove_const, :TestModel)
  end

  let(:model_instance) { TestModel.new }

  it "displays with no hint or error" do
    result_html_str = helper.simple_form_for(model_instance, url: "") do |f|
      f.input :author, wrapper: :kithe_multi_input
    end

    result_html = Nokogiri::HTML.fragment(result_html_str)

    expect(fieldset = result_html.at_css("fieldset")).to be_present
    expect(legend = fieldset.at_css("legend")).to be_present
    expect(fieldset.at_css(".multi-input-prompts")).not_to be_present
  end

  it "displays with hint and error" do
    model_instance.tap(&:validate)
    result_html_str = helper.simple_form_for(model_instance, url: "") do |f|
      f.input :author_error, wrapper: :kithe_multi_input, hint: "author error hint"
    end

    result_html = Nokogiri::HTML.fragment(result_html_str)

    expect(fieldset = result_html.at_css("fieldset")).to be_present
    expect(legend = fieldset.at_css("legend")).to be_present

    expect(prompts = fieldset.at_css(".multi-input-prompts")).to be_present
    expect(prompts.at_css(".multi-input-hint")).to be_present
    expect(prompts.at_css(".multi-input-error")).to be_present
  end
end
