module TemporaryClassForSpecs
  # We often need temporary classes in our tests, especially models, and because
  # a lot of ActiveModel wants to introspect on class name, anonymous classes
  # don't always work well. PARTICULARLY for single-table inheritance, where
  # the class name is needed for the type value.
  #
  # This goes in a describe block, and will create a class under top-level name
  # given, and then remove it after block. Eg:
  #
  #     describe "something" do
  #       temporary_class("TestDummyClass") do
  #          Class.new(Kithe::Work) do
  #            attr_json :foo, :string
  #          end
  #       end
  #     end
  #
  # We've had to do some serious contortions to make this work. We want to try to
  # let you refer to other rspec `let`-defined variables in your class def (which
  # you now can, sort of).
  #
  # We have to flush the somewhat not public ActiveSupport::Dependencies::Reference cache
  # too, since it's cached the class we're removing. :(
  #
  # Can't figure out a better way, this is mostly working.
  def temporary_class(class_name, &block)
    if Object.const_defined?(class_name)
      raise ArgumentError, "#{class_name} conflicts with an existing class/constant"
    end

    before(:each) do
      stub_const(class_name, self.instance_exec(&block))
    end

    after(:each) do
      # only exists before Rails 7
      if defined?(ActiveSupport::Dependencies::Reference.clear!)
        ActiveSupport::Dependencies::Reference.clear!
      end
    end
  end
end
