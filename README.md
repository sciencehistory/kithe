# Kithe
An experiment in shareable tools/components for building a digital collections app in Rails.

[![Build Status](https://github.com/sciencehistory/kithe/workflows/CI/badge.svg?branch=master)](https://github.com/sciencehistory/kithe/actions?query=workflow%3ACI+branch%3Amaster) [![Gem Version](https://badge.fury.io/rb/kithe.svg)](https://badge.fury.io/rb/kithe)

## What is kithe?

Kithe is a toolkit for building digital collections/repository applications in Rails. It comes out of experience in the [samvera](https://samvera.org/) community of open source library-archives-museums digital collections/preservation work (but is not a samvera project).

Kithe does not use fedora or valkyrie, but stores all metadata using ActiveRecord.  Kithe requires you use postgres 9.5+ as your db. It uses [shrine](https://shrinerb.com) for file-handling/asset-storing and tries to support developing your app as a normal Rails/ActiveRecord app. It will not give you a working turnkey application, but is a collection of tools for building an app with certain patterns.

Kithe provides tools to supports these architectural patterns:

* [Modelling and Persistence](./guides/modelling.md):
  * A Collection/Work/Asset model based on Samvera/PCDM, using rails Single-Table Inheritance to support hetereogenous associations with efficient rdbms lookup.
  * Using Postgres JSONB for "schema-less" flexible storage, via [attr_json](https://github.com/jrochkind/attr_json), supporting complex structured nested repeatable data values.
  * [Work representatives](./guides/work_representative.md) via ActiveRecord association, using postgres recursive CTE's to compute the "leaf" representative, designed to support efficient use of the DB including pre-loading leaf representatives.
  * UUIDv4's as internal primary keys, but also provide a "friendlier_id" with a shorter unique alphanumeric identifier for URLs and other UI. By default they are supplied by a postgres stored procedure, but your code can set them to whatever you like.

* [Form support](./guides/forms.md):  Easy Rails-like forms for that complex nested and repeatable form data, leaning on simple_form.
  * An extension to Rails "strong parameters" that make some common patterns for
    embedded JSON attributes more convenient, [Kithe::Parameters](./app/models/kithe/parameters.rb)

* [File handling](./guides/file_handling.md): A framework that let's you easily plug in your own custom characterization and derivatives handling, to be handled in an efficient and flexible way, ordinarily using background jobs. Implemented on top of [shrine](https://shrinerb.com).
  * [Derivatives](./guides/derivatives.md) handling ensures data consistency without race conditions, and efficient querying patterns, letting you plugin custom derivatives creation, with some standard routines included.

* [Solr Indexing](./guides/solr_indexing.md): Built-in Solr indexing using [traject](https://github.com/traject/traject) for defining mappings from your model objects to what you want in a Solr index. Uses ActiveRecord callbacks to automatically sync saves to solr, with many opportunities for customization.
  * Not coupled to any other kithe components, could be used independently, hypothetically on any ActiveRecord model.

* A [recommended approach for using Blacklight](./guides/blacklight_approach.md) with search result view templates based on actual ActiveRecord models. Blacklight use is optional with kithe, but kithe works well with blacklight.

* Assorted optional utilities
  * [Kithe::ConfigBase](./app/models/kithe/config_base.rb) A totally optional solution for managing environmental config variables.

  * [ArrayInclusionValdaitor](./app/validators/array_inclusion_validator.rb) Useful for validating on attr_json arrays of primitives.

## Setting up your app to use kithe

So you want to start an app that uses kithe. We should later provide better 'getting started' guide. For now some sketchy notes:

* Again re-iterate that kithe requires your Rails app use postgres, 9.5+.

* kithe works with Rails 5.2 through 6.1.

* To install migrations from kithe to setup your database for it's models: `rake kithe_engine:install:migrations`

* Kithe view support generally assumes your app uses bootstrap 4, and uses [simple form](https://github.com/plataformatec/simple_form) configured with bootstrap settings. See https://github.com/plataformatec/simple_form#bootstrap . So you should install simple_form and bootstrap 4.

* Specific additional pre-requisites/requirements can sometimes be found in individual feature docs. And include the Javascript from [cocoon](https://github.com/nathanvda/cocoon), for form support for repeatable-field editing forms. We haven't quite figured out our preferred sane approach for sharing Javascript via kithe.


## Why kithe?

Kithe tries to let you develop your app like "an ordinary Rails app" (in all it's possible variations), while handling some of the rough spots common to the kinds of modelling and administration common to digital collections domains.  But developers should be able to use standard Rails patterns and skills to develop an app to your specific local needs, familiar and no more complicated than building any other Rails app.

In that kithe provides tools and not a turnkey app, develping an app based on kythe in some ways similar to developing an app based on [valkyrie](https://github.com/samvera-labs/valkyrie) (but not hyrax). They both provide basic architecture for modelling/persistence, although in quite different ways. Kithe also provides tools in addition to modelling/persistence, but does _not_ provide the data-mapper/repository pattern valkyrie does, or any built-in abstraction for persisting anywhere but a postgres DB.

If you are comparing it to a "solution bundle" digital collections platform like hyrax, kithe may seem like more work. But experience has shown us that in our domain, "solution bundles" can turn out less of a "turnkey" approach than they seem, and can have greater development cost over total app lifecycle than anticipated. If you have similar experience that leads you to consider a more 'bespoke' app approach -- you may want to consider kithe. We hope to provide architecturally simple support and standardization for your custom app, taking care of some of the common "hard parts" and leaving you with flexibility to build out the app that meets your needs.

Kithe has beeen developed in tandem with the Science History Institute's in-development [replacement digital collections](https://github.com/sciencehistory/scihist_digicoll) app, which has been in production for several years using kithe.

We are serious about [semantic verisioning](https://semver.org/) and will endeavor to release backwards breaking changes only with a major release, and minimize major releases.

Kithe is working well for us, but has had limited (but non-zero) adoption from other institutions. It's still somewhat of an experiment, but one we think is going well. If you would consider developing a digital collections/repository app in "just Rails", we think it's worth investigating if kithe can save you some trouble in some rough common use cases. You are invited to try it out and see how it works, using kithe directly, or copying any code or just ideas from kithe.

Any questions or feedback of any kind are very welcome and encouraged!  In the github project issues, samvera slack, or wherever is convenient.

## To be done

Considering some additional blacklight integration support, is any needed?

Other components/features may become more clear as we continue to develop. It's possible that kithe won't (at least for a long time) contain controllers themselves (it may contain some helper methods for controllers), or generalized permissions architecture. Both of these are some of the things most particular to specific apps, that are hard to generalize without creating monsters.


## Development

This is a Rails 'engine' whose template was created with: `rails plugin new kithe --full --skip-test-unit --dummy-path=spec/dummy --database=postgresql`

* Note we have chosen not to make it 'mountable' or 'isolated', I think that would be inappropriate for this kind of gem. It _is_ an engine so it can hook into Rails load paths and config as needed.

* Note we are currently using the standard rails-generated dummy app in spec/dummy for testing, rather than [engine_cart](https://github.com/cbeer/engine_cart) or [combustion](https://github.com/pat/combustion).
  * Before you run the tests for the first time, create the database by running: `rails db:setup`. This will create two databases, kithe_development and kithe_test.
  * Some of the rspec tests depend on [FFmpeg](https://ffmpeg.org/) for testing file derivative transformations. Mac users can install [ffmpeg via homebrew](https://formulae.brew.sh/formula/ffmpeg): `brew install ffmpeg`
  * We do use [appraisal](https://github.com/thoughtbot/appraisal) to test under multiple rails versions, but still with the standard dummy app. It works for both Rails 5.2 and 6.0, because Rails structure changes have settled down.
  * Locally you can run `bundle exec appraisal rspec` to run tests multiple times for each rails we have configured, or eg `bundle exec appraisal rails-60 rspec` for a particular one.
  * If the project `Gemfile` _or_ `Appraisal` file changes, you may need to re-run `bundle exec appraisal install` and commit changes.

You can use all rails generators (eg `rails g model foo`) and it will generate properly for engine,
including module namespace. You can generally use rake tasks and other rails commands for dummy app, like `rake db:create` etc.

We use rspec for testing, [bundle exec] `rake spec`, `rake`, or `rspec`.

Release new gem versions with `bundle exec rake release` (after making sure ./lib/kithe/version.rb is appropriate)


## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
