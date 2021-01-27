require 'shrine'

# Gem "F(x)" or `fx` gem will get schema.rb to include locally-defined custom postgres functions
# and triggers, like we use. So apps can keep using schema.rb instead of structure.sql,
# and still have our custom functions preserved. We need to require it explicitly
# since it'll be an indirect dependency of the end app.
#
# But we need to patch it to create functions first so we can use them as default values
# https://github.com/teoljungberg/fx/issues/33
# https://github.com/teoljungberg/fx/pull/53
require 'fx'

# not auto-loaded, let's just load it for backwards compat though
require "kithe/config_base"

module Kithe
  class Engine < ::Rails::Engine
    config.generators do |g|
      g.test_framework :rspec, :fixture => false
      g.fixture_replacement :factory_bot, :dir => 'spec/factories'
      g.assets false
      g.helper false
    end

    # the fx gem lets us include stored procedures in schema.rb. For it to work
    # in kithe's case, the stored procedures have to be *first* in schema.rb,
    # so they can then be referenced as default value for columns in tables
    # subsequently created. We configure that here, forcing it for any app, yes, sorry.
    Fx.configure do |config|
      config.dump_functions_at_beginning_of_schema = true
    end
  end
end
