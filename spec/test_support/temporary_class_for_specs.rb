module TemporaryClassForSpecs
  # We often need temporary classes in our tests, especially models, and because
  # a lot of ActiveModel wants to introspect on class name, anonymous classes
  # don't always work well.
  #
  # This goes in a describe block, and will create a class under top-level name
  # given, and then remove it after block. It uses before/after(:all) to only
  # do that once per block given.  Eg:
  #
  #     describe "something" do
  #       temporary_class("TestDummyClass") do
  #          Class.new(Kithe::Work) do
  #            attr_json :foo, :string
  #          end
  #       end
  #     end
  #
  # Oops, this does not actually currently let you redefine classes with same name in
  # a nested example group, so it goes.
  def temporary_class(class_name, &block)
    if Object.const_defined?(class_name)
      raise ArgumentError, "#{class_name} conflicts with an existing class/constant"
    end

    before(:all) do
      Object.const_set(class_name, block.call)
    end
    after(:all) do
      Object.send(:remove_const, class_name)
    end
  end
end
