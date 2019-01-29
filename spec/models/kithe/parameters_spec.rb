require 'rails_helper'


RSpec.describe Kithe::Parameters, type: :model do
  # adapted from a test in Rails source
  it "works like a regular ActionController::Parameters" do
    hash = { "foo" => { "bar" => { "0" => { "baz" => "hello", "zot" => "1" } } } }
    ac_params = ActionController::Parameters.new(hash)
    params = Kithe::Parameters.new(ac_params)

    sanitized = params.require(:foo).permit(bar: [:baz])
    expect(sanitized[:bar].to_unsafe_h).to eq({ "0" => { "baz" => "hello" } })
  end

  describe "true value in filter" do
    let(:complex_hash) do
      { "something" => {
        "one" => {
          "more" => "value"
        },
        "another" => [1, 2]
      }}
    end

    it "accepts scalar" do
      params = Kithe::Parameters.new(
        model: {
          unselected: 'value',
          scalar_value: 1
        }
      )
      sanitized = params.require(:model).permit(scalar_value: true)
      expect(sanitized.to_unsafe_h).to eq("scalar_value" => 1)
    end

    it "accepts array of scalars" do
      params = Kithe::Parameters.new(
        model: {
          unselected: 'value',
          scalar_values: ["a", "b", "c"]
        }
      )
      sanitized = params.require(:model).permit(scalar_values: true)
      expect(sanitized.to_unsafe_h).to eq("scalar_values" => ["a", "b", "c"])
    end

    it "accepts complex hash" do
      params = Kithe::Parameters.new(
        model: {
          unselected: 'value',
          complex_hash: complex_hash
        }
      )
      sanitized = params.require(:model).permit(complex_hash: true)
      expect(sanitized.to_unsafe_h).to eq("complex_hash" => complex_hash)
    end

    it "accepts array of complex hash" do
      params = Kithe::Parameters.new(
        model: {
          unselected: 'value',
          complex_hashes: [complex_hash, complex_hash]
        }
      )
      sanitized = params.require(:model).permit(complex_hashes: true)
      expect(sanitized.to_unsafe_h).to eq("complex_hashes" => [complex_hash, complex_hash])
    end
  end

  describe "permit_attr_json" do
    temporary_class("TestWork") do
      Class.new(Kithe::Work) do
        clear_validators!

        attr_json :str_array, :string, array: true
        attr_json :int_array, :integer, array: true
      end
    end

    let(:params) do
      Kithe::Parameters.new(
        model: {
          "unselected" => 'value',
          "str_array" => ["one", "two"],
          "int_array_attributes" => [1,2],
          "other_value" => "value"
        }
      )
    end

    it "automatically includes with and without _attributes" do
      sanitized = params.require(:model).permit_attr_json(TestWork).permit
      expect(sanitized.to_unsafe_h).to eq("str_array" => ["one", "two"], "int_array_attributes" => [1,2])
    end

    it "can exclude with :except" do
      sanitized = params.require(:model).permit_attr_json(TestWork, except: "str_array").permit
      expect(sanitized.to_unsafe_h).to eq("int_array_attributes" => [1,2])
    end

    it "can additionally use ordinary permit" do
      sanitized = params.require(:model).permit_attr_json(TestWork).permit(:other_value)
      expect(sanitized.to_unsafe_h).to eq("str_array" => ["one", "two"], "int_array_attributes" => [1,2], "other_value" => "value")
    end
  end
end
