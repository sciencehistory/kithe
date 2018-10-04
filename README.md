# Kithe
An in-progress experiment in shareable tools/components for building a digital collections app in Rails.  Being used for the Science History Institute's digital collections rewrite.

[![Build Status](https://travis-ci.org/sciencehistory/kithe.svg?branch=master)](https://travis-ci.org/sciencehistory/kithe)

## Development

This is a Rails 'engine' whose template was created with: `rails plugin new kithe --full --skip-test-unit --dummy-path=spec/dummy --database=postgresql`

* Note we have chosen not to make it 'mountable' or 'isolated', I think that would be inappropriate for this kind of gem. It _is_ an engine so it can hook into Rails load paths and config as needed.
* Note we are currently using the standard rails-generated dummy app in spec/dummy for testing. We may consider either [engine_cart](https://github.com/cbeer/engine_cart) or [combustion](https://github.com/pat/combustion) in the future to make multi-rails-version testing possible. (Hopefully near future before we too much to re-jigger)

You can use all rails generators (eg `rails g model foo`) and it will generate properly for engine,
including module namespace. You can generally use rake tasks and other rails commands for dummy app, like `rake db:create` etc.

We use rspec for testing, [bundle exec] `rake spec`, `rake`, or `rspec`.


## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
