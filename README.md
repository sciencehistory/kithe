# Kithe
An in-progress experiment in shareable tools/components for building a digital collections app in Rails.  Being used for the Science History Institute's digital collections rewrite.

[![Build Status](https://travis-ci.org/sciencehistory/kithe.svg?branch=master)](https://travis-ci.org/sciencehistory/kithe)

Kithe requires you use postgres as your db, 9.5+.

## App setup notes

* You need `config.active_record.schema_format = :sql`, for friendlier_id postgres stored procedure to be recorded in a structure.sql rather than a schema.rb.

## Development

This is a Rails 'engine' whose template was created with: `rails plugin new kithe --full --skip-test-unit --dummy-path=spec/dummy --database=postgresql`

* Note we have chosen not to make it 'mountable' or 'isolated', I think that would be inappropriate for this kind of gem. It _is_ an engine so it can hook into Rails load paths and config as needed.

* Note we are currently using the standard rails-generated dummy app in spec/dummy for testing, rather than [engine_cart](https://github.com/cbeer/engine_cart) or [combustion](https://github.com/pat/combustion). We may try to use [appraisal](https://github.com/thoughtbot/appraisal) in the future to test under multiple rails versions,
possibly still wtih the standard dummy app.

You can use all rails generators (eg `rails g model foo`) and it will generate properly for engine,
including module namespace. You can generally use rake tasks and other rails commands for dummy app, like `rake db:create` etc.

We use rspec for testing, [bundle exec] `rake spec`, `rake`, or `rspec`.


## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
