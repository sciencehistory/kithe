require_relative 'boot'

require 'rails/all'
require 'sprockets/railtie'

Bundler.require(*Rails.groups)
require "kithe"

module Dummy
  class Application < Rails::Application
    # Initialize configuration defaults current Rails version!
    # Eg 5.2 or 7.0 or what have you.
    config.load_defaults Rails::VERSION::STRING.to_f

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end

