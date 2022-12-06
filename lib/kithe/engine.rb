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

    # Rails Single-table-inheritance auto-load workaround, further worked around
    # for Rails 7.
    #
    # https://github.com/rails/rails/issues/46625
    # https://github.com/rails/rails/issues/45307
    #
    # Descendants wont' be pre-loaded during initialization, but this is the best
    # we can do.
    initializer ("kithe.preload_single_table_inheritance") do
      unless Rails.configuration.cache_classes && Rails.configuration.eager_load
        Rails.configuration.to_prepare do
          Kithe::Model.preload_sti if Kithe::Model.respond_to?(:preloaded) && !Kithe::Model.preloaded
        rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid => e
          Rails.logger.debug("Could not pre-load Kithe::Models Single-Table Inheritance descendents: #{e.inspect}")
        end
      end
    end

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
