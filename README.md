# Kithe
An experiment in shareable tools/components for building a digital collections app in Rails.

[![Build Status](https://github.com/sciencehistory/kithe/workflows/CI/badge.svg?branch=master)](https://github.com/sciencehistory/kithe/actions?query=workflow%3ACI+branch%3Amaster)

[![Gem Version](https://badge.fury.io/rb/kithe.svg)](https://badge.fury.io/rb/kithe)

## What is kithe?

Kithe is a toolkit for building digital collections/repository applications in Rails. It comes out of experience in the [samvera](https://samvera.org/) community of open source library-archives-museums digital collections/preservation work (but is not a samvera project).

Kithe does not use fedora or valkyrie, but stores all metadata using ActiveRecord.  Kithe requires you use postgres 9.5+ as your db. While kithe provides some additional architecture and support on top of "ordinary" ActiveRecord, it tries to mostly let you develop as you would any Rails app, inclduing all choices and you'd normally have, and taking advantage of standard ActiveRecord-based functionality.  Kithe bases it's file handling framework on [shrine](https://shrinerb.com), supporting cloud or local file storage.

Kithe will not give you a working "turnkey" application. It is a collection of tools to help you write a Rails app. You may end up using some but not all of kithe's tools.  The range of tools provided and areas of an app given some support in kithe will probably grow over time, in hopefully a careful and cautious way.

In that it provides tools and not a turnkey app, develping an app based on kythe in some ways similar to developing an app based on [valkyrie](https://github.com/samvera-labs/valkyrie). They both provide basic architecture for modelling/persistence, although in quite different ways. Kithe also provides tools in addition to modelling/persistence, but does _not_ provide the data-mapper/repository pattern valkyrie does, or any built-in abstraction for persisting anywhere but a postgres DB.

If you are comparing it to a "solution bundle" digital collections platform, kithe may seem like more work. But experience has shown me that in our domain, historically "solution bundles" can be less of a "turnkey" approach than they seem, and can have greater development cost over total app lifecycle than anticipated. If you have similar experience that leads you to consider a more 'bespoke' app approach -- you may want to consider kithe. We hope to provide architecturally simple support and standardization for your custom app, taking care of some of the common "hard parts" and leaving you with flexibility to build out the app that meets your needs.

Kithe has beeen developed in tandem with the Science History Institute's in-development [replacement digital collections](https://github.com/sciencehistory/scihist_digicoll) app, and you can look there for a model/canonical/demo kithe use.

The Science History Institute app is live and working, so kithe is 1.0. We are serious about [semantic verisioning](https://semver.org/) and will endeavor to release backwards breaking changes only with a major release, and minimize major releases.

While it is working well for us, since it hasn't had wide use, it could still be considered somewhat of an experiment. But you are invited to try it out and see how it works. You are welcome to use it, but also welcome to copy any code or just ideas from kithe.

Any questions or feedback of any kind are very welcome and encouraged, in the github project issues, samvera slack, or wherever is convenient.


# Kithe parts

Some guide documentation is available to explain each of kithe's major functionality areas. Definitely start with the modelling guide.

* [Modelling and Persistence](./guides/modelling.md):  It can be somewhwat challenging to figure out a good way to model our data in an rdbms. We give you a hopefully flexible and understandable architecture that is designed to support efficient performance. It's influenced by PCDM and traditional samvera modelling. It's based on [attr_json](https://github.com/jrochkind/attr_json) to let you model arbitrary and complex object-oriented data that gets persisted as a serialized json hash. It uses rails Single Table Inheritance to support hetereogenous associations and collections. The modelling classes in some places use postgres-specific features for efficiency.

  * [Work representatives](./guides/work_representative.md). Built in associations to support "representative", using postgres recursive CTE's to compute the "leaf" representative, designed to support efficient use of the DB including pre-loading leaf representatives.

  * Kithe objects use UUIDv4's as internal primary keys, but also provide a "friendlier_id" with a shorter unique alphanumeric identifier for URLs and other UI. By default they are supplied by a postgres stored procedure, but your code can set them to whatever you like.

* [Form support](./guides/forms.md): Dealing with complex and _repeatable_ data, as our modelling layer allows, can be tricky in an HTML form. We supply javascript-backed Rails form input help for repeatable and compound/nested data.

* [File handling](./guides/file_handling.md): Handling files is at the core of digital repository use cases. We need a file handling framework that is flexible, predictable and reliable, and architected for performance. We try to give you one based on the [shrine](https://shrinerb.com) file attachment toolkit for ruby.

  * [Derivatives](./guides/derivatives.md) A flexible and reliable derivatives architecture, designed to ensure data consistency without race conditions, and support efficient DB usage patterns.

* [Solr Indexing](./guides/solr_indexing.md): Uses [traject](https://github.com/traject/traject) for defining mappings from your model objects to what you want in a Solr index. Uses ActiveRecord callbacks to automatically sync saves to solr, with many opportunities for customization.
  * Not coupled to any other kithe components, could be used independently, hypothetically on any ActiveRecord model.
  * Written after review of "prior art"  in [sunspot](https://github.com/sunspot/sunspot) and [searchkick](https://github.com/ankane/searchkick) (which both used AR callback-based indexing), and others.

* A [recommended approach for using Blacklight](./guides/blacklight_approach.md) with search result view templates based on actual ActiveRecord models. It is totally optional to use Blacklight at all with kithe, or to use this approach if you do.

### Also

* [Kithe::Parameters](./app/models/kithe/parameters.rb) provides some shortcuts around Rails "strong params" for attr_json serialized attributes.

* [Kithe::ConfigBase](./app/models/kithe/config_base.rb) A totally optional solution for managing environmental config variables.

* [ArrayInclusionValdaitor](./app/validators/array_inclusion_validator.rb) Useful for validating on attr_json arrays of primitives.

## Setting up your app to use kithe

So you want to start an app that uses kithe. We should later provide better 'getting started' guide. For now some sketchy notes:

* Again re-iterate that kithe requires your Rails app use postgres, 9.5+.

* kithe requires Rails 5.2 or 6.0.

* To install migrations from kithe to setup your database for it's models: `rake kithe_engine:install:migrations`

* Kithe view support generally assumes your app uses bootstrap 4, and uses [simple form](https://github.com/plataformatec/simple_form) configured with bootstrap settings. See https://github.com/plataformatec/simple_form#bootstrap . So you should install simple_form and bootstrap 4.

* Specific additional pre-requisites/requirements can sometimes be found in individual feature docs. And include the Javascript from [cocoon](https://github.com/nathanvda/cocoon), for form support for repeatable-field editing forms. We haven't quite figured out our preferred sane approach for sharing Javascript via kithe.

Note that at present kithe will end up forcing your app to use `:sql` [style schema dumps](https://guides.rubyonrails.org/v3.2.8/migrations.html#types-of-schema-dumps). We may try to fix this.

## To be done

Considering some blacklight integration support.

Other components/features may become more clear as we continue to develop. It's possible that kithe won't (at least for a long time) contain controllers themselves (it may contain some helper methods for controllers), or generalized permissions architecture. Both of these are some of the things most particular to specific apps, that are hard to generalize without creating monsters.


## Development

This is a Rails 'engine' whose template was created with: `rails plugin new kithe --full --skip-test-unit --dummy-path=spec/dummy --database=postgresql`

* Note we have chosen not to make it 'mountable' or 'isolated', I think that would be inappropriate for this kind of gem. It _is_ an engine so it can hook into Rails load paths and config as needed.



* Note we are currently using the standard rails-generated dummy app in spec/dummy for testing, rather than [engine_cart](https://github.com/cbeer/engine_cart) or [combustion](https://github.com/pat/combustion).
  * Before you run the tests for the first time, create the database by running: `rails db:setup`. This will create two databases, kithe_development and kithe_test.
  * We do use [appraisal](https://github.com/thoughtbot/appraisal) to test under multiple rails versions,but still wtih the standard dummy app. It works for both Rails 5.2 and 6.0, because Rails structure changes have settled down.
  * Locally you can run `bundle exec appraisal rspec` to run tests multiple times for each rails we have configured, or eg `bundle exec appraisal rails-60 rspec` for a particular one.
  * If the project `Gemfile` _or_ `Appraisal` file changes, you may need to re-run `bundle exec appraisal install` and commit changes.

You can use all rails generators (eg `rails g model foo`) and it will generate properly for engine,
including module namespace. You can generally use rake tasks and other rails commands for dummy app, like `rake db:create` etc.

We use rspec for testing, [bundle exec] `rake spec`, `rake`, or `rspec`.

Release new gem versions with `bundle exec rake release` (after making sure ./lib/kithe/version.rb is appropriate)


## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
