appraise "rails-52" do
  gem "rails", "~> 5.2.1"
end

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
