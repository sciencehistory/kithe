appraise "rails-60" do
  gem "rails", "~> 6.0"
end

appraise "rails-61" do
  gem "rails", "~> 6.1"
end

appraise "rails-70" do
  gem "rails", "~> 7.0"

  # sprockets-rails is generated into gemfile in Rails 7.0, where it
  # was a gemspec dependency in previous rails. We'll just
  # add it here for now. Used for testing cocoon integration,
  # we are currently including cocoon via sprockets.
  gem 'sprockets-rails', :require => 'sprockets/railtie'
end

appraise "rails-71" do
  gem "rails", "~> 7.1"

  # sprockets-rails is generated into gemfile in Rails 7.1, where it
  # was a gemspec dependency in previous rails. We'll just
  # add it here for now. Used for testing cocoon integration,
  # we are currently including cocoon via sprockets.
  gem 'sprockets-rails', :require => 'sprockets/railtie'

  # need a custom branch of db-query-matchers until/unless it's updated
  # to allow rails 7.1
  # https://github.com/civiccc/db-query-matchers/pull/56
  gem "db-query-matchers", github: "jrochkind/db-query-matchers", branch: "allow_rails_7.1"
end
