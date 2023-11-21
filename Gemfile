source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Declare your gem's dependencies in kithe.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

# To use a debugger
# gem 'byebug', group: [:development, :test]

group :development, :test do
  gem 'rspec-rails', '>= 5.0', '< 7'
  gem 'rspec-mocks', '>= 3.12.1' # for ruby 3.2 need at least
  gem 'pry-byebug', '~> 3.6'
  # 6.3.0 and 6.4.0 have a bug https://github.com/thoughtbot/factory_bot_rails/issues/433
  gem 'factory_bot_rails', '~> 6.2', "!= 6.3.0", "!= 6.4.0"
  # only used for current mechanism of testing working with cocoon JS
  gem "sprockets-rails"
end
