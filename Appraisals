# bug in Rails pre-7.0 does not require 'logger' when it should....
# concurrent-ruby prior to 1.3.5 masked the problem, and the easiest
# way for us to get CI to work for such Rails is to use an older concurrent-ruby
# version, other attempts to workaround were not succesful.
#
#
# Rails will not be releasing a fix for Rails prior to 7.1.0
# to release a fix. https://github.com/rails/rails/pull/54264
#

appraise "rails-60" do
  gem "rails", "~> 6.0.0"
  gem "concurrent-ruby", "< 1.3.5"
end

appraise "rails-61" do
  gem "rails", "~> 6.1.0"
  gem "concurrent-ruby", "< 1.3.5"
end

appraise "rails-70" do
  gem "rails", "~> 7.0.0"
  gem "concurrent-ruby", "< 1.3.5"
end

appraise "rails-71" do
  gem "rails", "~> 7.1.0"
end

appraise "rails-72" do
  gem "rails", "~> 7.2.0"
end

appraise "rails-80" do
  gem "rails", "~> 8.0.0"
end
