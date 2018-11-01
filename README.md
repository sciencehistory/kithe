# Kithe
An in-progress experiment in shareable tools/components for building a digital collections app in Rails.

[![Build Status](https://travis-ci.org/sciencehistory/kithe.svg?branch=master)](https://travis-ci.org/sciencehistory/kithe)

## What is kithe?

Kithe is a toolkit for building digital collections/repository applications in Rails. It comes out of experience in the [samvera](https://samvera.org/) community of open source library-archives-museums digital collections/preservation work (but is not a samvera project).

Kithe does not use fedora or valkyrie, but stores all metadata using ActiveRecord, and some extensions/choices with ActiveRecord that try to take a light touch and leave the persistence mostly just standard ActiveRecord.  Kithe requires you use postgres as your db, 9.5+. In general, kithe will try to provide additional architecture and support on top of "ordinary" approaches to Rails apps.

Kithe will not give you a working "turnkey" application. It is a collection of tools to help you write a Rails app. It intends to provide tools and standard architecture for things most common to our digital collections/repository domain. You'll still have to write an app. The intention is that you will be able to choose to use more or fewer of kithe's tools -- although using the kithe basic domain modelling is _probably usually_ necessary for the other mix-and-match tools to work.  The range of tools provided and areas of an app given some support for in kithe will probably grow over time, in hopefully a careful and cautious way.

You still need to make your own app, with kithe providing some support. In this way, develping an app based on kythe in some ways analagous to developing an app based on [valkyrie](https://github.com/samvera-labs/valkyrie). They both provide basic standard architecture for modelling/persistence, although in very different ways. Kithe will provide both more and less than valkyrie.  If you are comparing it to a "solution bundle" digital collections platform, kithe may seem like "more work". But experience has shown me that in our domain, historically "solution bundles" can be less of a "turnkey" approach than they seem, and can have greater development cost over total app lifecycle than anticipated. If you have similar experience that leads you to consider a more 'bespoke' app approach -- you may want to consider kithe as some (hopefully) architecturally simple support and standardization for your custom app that still leaves you with tons of flexibility.

Kithe is at the beginning stages of development. It is pre-1.0 and can change in backwards incompat ways. It is probably not ready for using seriously unless you really know what you're getting into. But trying it out is very invited and encouraged!

Kithe is being developed in tandem with the Science History Institute's in-development [replacement digital collections](https://github.com/sciencehistory/scihist_digicoll) app, and you can look there for a model/canonical/demo kithe use.

# Kithe parts

Some guide documentation is available to explain kithe's architectures and components. Definitely start with the modelling guide.

* [Modelling](./guides/modelling.md)
* [Form support](./guides/forms.md): repeatable inputs, including for compound/nested models

## Setting up your app to use kithe

So you want to start an app that uses kithe. We should later provide better 'getting started' guide. For now some sketchy notes:

* Again re-iterate that kithe requires your Rails app use postgres, 9.5+.

* To get migrations from kithe to setup your database for it's models: `rake kithe_engine:install:migrations`

* Kithe view support generally assumes your app uses bootstrap 4, and uses [simple form](https://github.com/plataformatec/simple_form) configured with bootstrap settings. See https://github.com/plataformatec/simple_form#bootstrap

* Specific additional pre-requisites/requirements can sometimes be found in individual feature docs. And include the Javascript from [cocoon](https://github.com/nathanvda/cocoon), for form support for repeatable-field editing forms.

Note that at present kithe will end up forcing your app to use `:sql` [style schema dumps](https://guides.rubyonrails.org/v3.2.8/migrations.html#types-of-schema-dumps). We may try to fix this.

## To be done

File handling in general including derivatives is next on the plate.

There is also definitely planned to be solr indexing and some blacklight integration support. (These currently considered requirements for getting the Science History Institute's app to production, depending on the kithe features).

Other components/features may become more clear as we continue to develop. It's possible that kithe won't (at least for a long time) contain controllers themselves (it may contain some helper methods for controllers), or generalized permissions architecture. Both of these are some of the things most particular to specific apps, that are hard to generalize without creating monsters.


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
