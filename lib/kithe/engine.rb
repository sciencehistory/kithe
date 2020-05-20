require 'shrine'

# Gem "F(x)" or `fx` gem will get schema.rb to include locally-defined custom postgres functions
# and triggers, like we use. So apps can keep using schema.rb instead of structure.sql,
# and still have our custom functions preserved. We need to require it explicitly
# since it'll be an indirect dependency of the end app.
require 'fx'

module Kithe
  class Engine < ::Rails::Engine
    config.generators do |g|
      g.test_framework :rspec, :fixture => false
      g.fixture_replacement :factory_bot, :dir => 'spec/factories'
      g.assets false
      g.helper false
    end
  end
end
