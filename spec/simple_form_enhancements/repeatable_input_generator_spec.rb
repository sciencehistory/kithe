require 'rails_helper'
require 'simple_form'
require 'attr_json'

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
    # Then had to hack further to get it to happen lazily with our temporary class setup
    # involved. :(
    #
    # This is how I'm trying to keep HTML production tests reasonable, may be a better
    # way?
    output_concatted = false
    allow(self).to receive(:document_root_element).and_wrap_original do |m, *args|
      unless output_concatted
        concat output
        output_concatted = true
      end
      m.call(*args)
    end
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
      let(:instance) {
        TestWork.create!(title: "test", multi_model: [{value: "one"}, {value: "two"}])
      }

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

      describe "build: :at_least_one" do
        let(:generator) do
          generator = nil
          helper.simple_form_for(instance, url: "http://example/target") do |form|
            generator = Kithe::RepeatableInputGenerator.new(form, :multi_model, block, build: :at_least_one)
          end
          generator
        end

        describe "with empty array" do
          let(:instance) { TestWork.new(title: "test", multi_model: []) }
          it "includes an input" do
            assert_select("input[type=text]", count: 1)
          end
        end
        describe "with nil" do
          let(:instance) { TestWork.new(title: "test", multi_model: nil) }
          it "includes an input" do
            assert_select("input[type=text]", count: 1)
          end
        end
        describe "with an element" do
          let(:instance) { TestWork.new(title: "test", multi_model: [{ value: "present" }]) }
          it "includes onluy one input" do
            input = assert_select("input[type=text]", count: 1).first
            expect(input["value"]).to eq("present")
          end
        end
      end
    end

    describe "specified simple_form_input_arg required" do
      let(:instance) { TestWork.new }

      let(:generator) do
        generator = nil
        helper.simple_form_for(instance, url: "http://example/target") do |form|
          generator = Kithe::RepeatableInputGenerator.new(form, :multi_model, block, simple_form_input_args: { required: true })
        end
        generator
      end

      it "outputs as required" do
        assert_select("abbr[title='required']")
      end
    end
  end

  describe "for a repeated primitive string" do
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

    it "has no duplicate id attribute values" do
      # cause that is illegal in HTML among other reasons
      id_values = css_select("*[id]").collect { |n| n["id"] }
      expect(id_values.count).to eq(id_values.uniq.count)
    end

    describe(:with_html_attributes) do
      let(:generator) do
        generator = nil
        helper.simple_form_for(instance, url: "http://example/target") do |form|
          generator = Kithe::RepeatableInputGenerator.new(form,
            :string_array, nil,
            html_attributes: { data: { foo: "bar" } } )
        end
        generator
      end

      it "has attributes on input" do
        links = assert_select('input[name="test_work[string_array_attributes][]"]:not([type=hidden])')
        expect(links.all? {|el| el['data-foo'] == "bar"}).to be(true)
      end

    end

    describe "build: :at_least_one" do
      let(:generator) do
        generator = nil
        helper.simple_form_for(instance, url: "http://example/target") do |form|
          generator = Kithe::RepeatableInputGenerator.new(form, :string_array, nil, build: :at_least_one)
        end
        generator
      end

      describe "with empty array" do
        let(:instance) { TestWork.new(title: "test", string_array: []) }
        it "includes an input" do
          assert_select("input[type=text]", count: 1)
        end
      end
      describe "with nil" do
        let(:instance) { TestWork.new(title: "test", string_array: nil) }
        it "includes an input" do
          assert_select("input[type=text]", count: 1)
        end
      end
      describe "with an element" do
        let(:instance) { TestWork.new(title: "test", string_array: ["present"]) }
        it "includes onluy one input" do
          input = assert_select("input[type=text]", count: 1).first
          expect(input["value"]).to eq("present")
        end
      end
    end

    describe "with custom block" do
      let(:block) do
        proc do |input_name, value|
          "<span input_name='#{input_name}' value='#{value}'>".html_safe
        end
      end

      let(:generator) do
        generator = nil
        helper.simple_form_for(instance, url: "http://example/target") do |form|
          generator = Kithe::RepeatableInputGenerator.new(form, :string_array, block)
        end
        generator
      end

      it "calls block properly" do
        # block called once for each existing value
        assert_select("span[input_name=?][value=?]", "test_work[string_array_attributes][]", "one")
        assert_select("span[input_name=?][value=?]", "test_work[string_array_attributes][]", "two")

        # and the 'add' button has good html
        link = assert_select('a.add_fields', count: 1).first
        template = link["data-association-insertion-template"]
        expect(template).to include("<span input_name='test_work[string_array_attributes][]' value=''>")
      end
    end
  end
end
