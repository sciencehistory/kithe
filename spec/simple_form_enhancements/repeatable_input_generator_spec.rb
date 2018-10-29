require 'rails_helper'
require 'simple_form'

# We want to spec our repeatable input generation. We want to test it in a de-coupled
# fashion, try to 'unit' test it, not in integration with other things or assuming other things,
# (other than attr_json) to ensure it's a loosely coupled independent component.
#
# This is hard to figure out how to do simply for several different reasons, we've done our best.
#
# * We test the actual Kithe::RepeatableInputGenerator, instead of the
# cover method in Kithe::FormBuilder#repeatable_model_input
#
# * We're testing HTML generation, but not a full integration test with JS.
#   We test it has the HTML Cocoon JS expects.
#
# * We do a weird things so we can use Rails assert_select against
#   arbitrary method output.
#
# There might be better ways to test this func, not sure.
describe Kithe::RepeatableInputGenerator, type: :helper do
    let(:output) { generator.render }
    before do
      # total hack to let us use assert_select
      # https://coderwall.com/p/fkh-fq/right-way-to-stub-views-in-helper-specs
      #
      # This is how I'm trying to keep HTML production tests reasonable, may be a better
      # way?
      concat output
    end

  describe "for a repeated model" do
    temporary_class "TestNestedModel" do
      Class.new do
        include AttrJson::Model

        attr_json :value, :string
      end
    end

    temporary_class "TestWork" do
      Class.new(Kithe::Work) do

        attr_json :multi_model, TestNestedModel.to_type, array: true

        attr_json_accepts_nested_attributes_for :multi_model
      end
    end

    let(:block) {
      proc { |sub_form| sub_form.input :value, label: false  }
    }

    let(:generator) do
      generator = nil
      helper.simple_form_for(instance, url: "http://example/target") do |form|
        generator = Kithe::RepeatableInputGenerator.new(form, :multi_model, block)
      end
      generator
    end

    describe "existing record" do
      let(:instance) { TestWork.create!(title: "test", multi_model: [{value: "one"}, {value: "two"}])}

      it "produces form with good HTML" do
        assert_select("fieldset.form-group") do
          assert_select("legend", text: "Multi model", count: 1)

          assert_select("div.nested-fields.form-row", count: 2)

          assert_select("div.nested-fields.form-row") do
            assert_select("input[name=?][value=?]", "test_work[multi_model_attributes][0][value]", "one")
          end

          assert_select("div.nested-fields.form-row") do
            assert_select("input[name=?][value=?]", "test_work[multi_model_attributes][1][value]", "two")
          end

          assert_select("div.nested-fields.form-row") do
            assert_select(".remove_fields.dynamic", text: "Remove")
          end

          assert_select("div.repeatable-add-link") do
            link = assert_select('a.add_fields', count: 1).first

             # data attributes Cocoon JS wants
             expect(link["data-association"]).to eq("multi_model")
             expect(link["data-associations"]).to eq("multi_models")

             template = link["data-association-insertion-template"]
             expect(template).to be_present
             expect(Nokogiri::HTML.fragment(template).at_css('input[name="test_work[multi_model_attributes][new_multi_model][value]"]')).to be_present

             expect(link.text).to eq("Add another Multi model")
          end
        end
      end

      describe "new record" do
        let(:instance) { TestWork.new }

        it "produces form with good HTML" do
          assert_select("fieldset.form-group") do
            assert_select("legend", text: "Multi model", count: 1)

            assert_select("div.nested-fields.form-row", count: 0)

            assert_select("div.repeatable-add-link") do
              link = assert_select('a.add_fields', count: 1).first

               # data attributes Cocoon JS wants
               expect(link["data-association"]).to eq("multi_model")
               expect(link["data-associations"]).to eq("multi_models")

               template = link["data-association-insertion-template"]
               expect(template).to be_present
               expect(Nokogiri::HTML.fragment(template).at_css('input[name="test_work[multi_model_attributes][new_multi_model][value]"]')).to be_present
            end
          end
        end
      end
    end
  end

  describe "for a repeated string" do
    temporary_class "TestWork" do
      Class.new(Kithe::Work) do

        attr_json :string_array, :string, array: true
      end
    end

    let(:instance) { TestWork.create!(title: "foo", string_array: ["one", "two"]) }

    let(:generator) do
      generator = nil
      helper.simple_form_for(instance, url: "http://example/target") do |form|
        generator = Kithe::RepeatableInputGenerator.new(form, :string_array, nil)
      end
      generator
    end

    it "produces form with good HTML" do
      # puts Nokogiri::HTML.fragment(output).to_xml(indent: 2)
      assert_select("fieldset.form-group") do
        assert_select("legend", text: "String array", count: 1)

        assert_select("div.nested-fields.form-row", count: 2)

        assert_select("div.nested-fields.form-row") do
          assert_select("input[name=?][value=?]", "test_work[string_array_attributes][]", "one")
        end

        assert_select("div.nested-fields.form-row") do
          assert_select("input[name=?][value=?]", "test_work[string_array_attributes][]", "two")
        end

        link = assert_select('a.add_fields', count: 1).first

        # data attributes Cocoon JS wants
        expect(link["data-association"]).to eq("string_array")
        expect(link["data-associations"]).to eq("string_arrays")

        template = link["data-association-insertion-template"]
        expect(template).to be_present
        expect(Nokogiri::HTML.fragment(template).at_css('input[name="test_work[string_array_attributes][]"]')).to be_present
      end
    end
  end
end
