require 'rails_helper'

# inspired by https://github.com/rails/rails/blob/b2eb1d1c55a59fee1e6c4cba7030d8ceb524267c/activemodel/test/cases/validations/inclusion_validation_test.rb
describe ArrayInclusionValidator do
  temporary_class("MyWork") do
    Class.new(Kithe::Work) do
      clear_validators!

      attr_json :str_array, :string, array: true
      validates :str_array, array_inclusion: { in: ["one", "two", "three"]}
    end
  end

  it "validates inclusion" do
    expect(MyWork.new(str_array: ["one", "two"])).to be_valid
    expect(MyWork.new(str_array: ["one", "two", "one"])).to be_valid
  end

  it "allows empty array" do
    expect(MyWork.new(str_array: [])).to be_valid
  end

  it "allows nil" do
    expect(MyWork.new()).to be_valid
  end

  it "rejects invalid" do
    expect(MyWork.new(str_array: ["one", "extra"])).not_to be_valid
    expect(MyWork.new(str_array: ["extra"])).not_to be_valid
  end

  it "has good error" do
    work = MyWork.new(str_array: ["bad"])
    expect(work).not_to be_valid
    expect(work.errors[:str_array]).to eq(["is not included in the list"])
  end

  describe "custom formatted error message" do
    temporary_class("MyCustomWork") do
      Class.new(Kithe::Work) do
        clear_validators!

        attr_json :str_array, :string, array: true
        validates :str_array, array_inclusion: { in: ["one", "two", "three"], message: "option %{rejected_values} not allowed" }
      end
    end

    it "has good message" do
      work = MyCustomWork.new(str_array: ["one", "bad", "bad", "baddy"])
      expect(work).not_to be_valid
      expect(work.errors[:str_array]).to eq(["option \"bad\",\"baddy\" not allowed"])
    end
  end
end
