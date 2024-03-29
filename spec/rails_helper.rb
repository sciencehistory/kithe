# Customized from what you get when you run 'rails generate rspec:install' per advice
# for engines at:
# https://www.viget.com/articles/rails-engine-testing-with-rspec-capybara-and-factorygirl/

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

dummy_app_path = File.expand_path("../dummy", __FILE__)
require File.join(dummy_app_path, "config/environment")

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end
RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # Look for factories here in engine, not in dummy app please.
  # A bit hacky, factorybot is insisting on loading other ones too, factory-girl-rails
  # doesn't really assume engines and it's confusing. See:
  # https://github.com/thoughtbot/factory_bot_rails/issues/302
  #
  # We may later use lib/ to make it easier for client apps to re-use factories in their tests.
  FactoryBot.definition_file_paths = ['spec/factories', 'lib/testing_support/factories']
  FactoryBot.find_definitions

  # Let blocks or tests add (eg) `queue_adapter: :inline` to determine Rails
  # ActiveJob queue adapter. :test, :inline:, or :async, presumably.
  # eg `it "does something", queue_adapter: :inline`, or
  # `describe "something", queue_adapter: :inline`
  config.around(:example, :queue_adapter) do |example|
    original = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = example.metadata[:queue_adapter]

    example.run

    ActiveJob::Base.queue_adapter = original
  end


  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end
