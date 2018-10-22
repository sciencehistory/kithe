module Kithe
  class Engine < ::Rails::Engine
    config.generators do |g|
      g.test_framework :rspec, :fixture => false
      g.fixture_replacement :factory_bot, :dir => 'spec/factories'
      g.assets false
      g.helper false
    end

    # should only affect kithe development
    config.active_record.schema_format = :sql

    initializer "kithe.simple_form.register_multi_input", after: "finisher_hook" do
      require 'simple_form'
      SimpleForm.setup do |config|
        Kithe::MultiInputWrapper.register(config)
      end
    end
  end
end
