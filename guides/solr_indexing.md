# Indexing to Solr

Kithe includes support for indexing to [Solr](http://lucene.apache.org/solr/). By default it uses [ActiveRecord after_commit callbacks](https://guides.rubyonrails.org/active_record_callbacks.html) to automatically index on save.  The code and APIs were written after some examination of the 'prior art' of callback-based indexing features in [sunspot](https://github.com/sunspot/sunspot) and [searchkick](https://github.com/ankane/searchkick).

The indexing mapping and Solr writing are based on and use [traject](https://github.com/traject/traject).

The kithe indexing code does not assume you are using Blacklight, although you can; it just gets things into Solr for to use however you like, using whatever Solr schema you like.

(Interested in indexing to something other than Solr, like ElasticSearch? Not currently built in, but the architecture should be able to support that; the first step would be writing an Elastic Search writer for traject. Feel free to get in touch for discussion.)

## Set your Solr URL

```ruby
# perhaps in config/initializers/kithe_indexable.rb
Kithe::Indexable.settings.solr_url = ENV['SOLR_URL']

# or wherever else you'd like to get it from, use your own conditional logic
# for different url depending on Rails.env, etc.
```

## Define an indexer

An indexer or mapper is a class that defines the logic for translating from an ActiveRecord model to a Hash of fields/value-arrays to add to Solr. Our indexing support does not assume (or provide support for) complete "round-trippable" storage to Solr; instead index to Solr only what you actually need for your use of Solr for searching support. It's up to you what fields to index, to  Solr `stored` or `indexed` fields, etc.

Indexing is based on [traject](https://github.com/traject/traject), and we provide a `Kithe::Indexer` that is a sublcass of `Traject::Indexer`, with some custom functionality and default settings more suitable to us. 

Create a class that sub-classes `Kithe::Indexer`, perhaps:

```ruby
class WorkIndexer < Kithe::Indexer
  # traject indexing directives are supplied in a `configure` block in your subclass
  configure do
    # The `obj_extract` macro is made available by Kithe::Indexer, that just calls
    # methods on your model instances, and collects the results.
    to_field "additional_title_ssim", obj_extract("additional_title")

    # Assume `authors` returns an array of 0 or more Author objects, which
    # have a "last_name" attribute. This will collect all `last_name`s of all
    # `authors`
    to_field "author_last_name_ssim", obj_extract("authors", "last_name")
  end
end
```

Becuase this is a traject indexer, you can use other features of traject to define indexing logic however you like. You might want to look at the [traject README](https://github.com/traject/traject#indexing-rules-to_field).

```ruby
  configure do
    to_field "author_names_ssim", obj_extract("authors"), transform( ->(author) { "#{author.last}, #{author.first}" })

    each_record do |record, context|
      context.add_output(:some_complicated_thing, get_complicated_thing(record))
    end
  end
```

*Note, if familiar with Traject*, unlike typical Traject use, a Kithe::Indexer has no writer set. Kithe decouples it's indexer from it's writer, instead of using an indexer with an embedded writer.

### Kithe::Indexer adds id and class name to Solr by default

You will generally need the pk and class name of the object in the Solr index so Kithe::Indexer  has that set up already.

The object primary key in `id`, which for Kithe::Models is a UUIDv4, will be sent to Solr field `id`. (Not currently customizable or disable-able)

The object class name will by default be sent to Solr field `model_name_ssi`. You can change this field with `Kithe::Indexable.settings.model_name_solr_field=`, or set it to false to disable.

### Set the indexer on your work class, enabling automatic callback-based indexing

In your local `Work` class...

```ruby
class Work < Kithe::Work
  self.kithe_indexable_mapper = WorkIndexer.new
  #...
```

* Note we set it to `WorkIndexer.new`, an instance. (This is a result of some traject legacy architectural choices, and us trying to maximize performance here)

Once you have set a `kithe_indexable_mapper` for your class, it will be automatically sync'd to Solr on every save or destroy. (See below for various ways to disable temporarily or permanently)

By default, it will be sent with a solr [softCommit](https://lucidworks.com/2013/08/23/understanding-transaction-logs-softcommit-and-commit-in-sorlcloud/), although this can also be customized. It's recommended you use an `autoCommit` setting your solrconfig.xml to periodically hard commit,
since default kithe settings will only do softCommits.

## Batch updating (and batch writer-configuration changes)

By default, every time you save or destroy a model with indexing set up, an individual http update request is sent to Solr. If you are doing a lot of them, this is not a very performant way to interact with Solr.

To instead batch updates within a certain context do:

```ruby
Kithe::Indexable.index_with(batching: true) do
  # some things that may save or destroy indexable objects
end
```

Saving or destroying will still automatically trigger a solr sync, but all of these syncs will be batched in fewer http requests to Solr.

Note that `index_with` is implemented in terms of Thread.current, so it's batching settings apply to everything in the block, but do not automatically apply to any new threads you might create in the block.

### Batch every controller?

Would you like to have every controller in your app batch solr index updates within each action? You can!

```ruby
class ApplicationController < ActionController::Base
  around_action :batch_kithe_indexable

  def batch_kithe_indexable
    Kithe::Indexable.index_with(batching: true) do
      yield
    end
  end
```

As `index_with(batching: true)` only creates a Traject::Writer lazily on demand, this should not add appreciable overhead to actions that don't end up triggering any Solr updates.



## Disabling automatic callbacks

Perhaps you have indexing set up, by setting a `kithe_indexable_mapper` in your model class, but you want to disable the automatic callbacks, either temporarily or permanently. There are a variety you can do that.

* Disable globally and universally:  `Kithe::Indexable.settings.disable_callbacks = true`
* Disable globally for a particular class, using a Rails class_attribute:
  `SomeClass.kithe_indexable_auto_callbacks = false`
* Disable for a particular instance, using that same class_attribute:
  `some_model.kithe_indexable_auto_callbacks = false`
* Disable for a given block of code, using `index_with`:

      Kithe::Indexable.index_with(disable_callbacks: true) do
        # you can save and destroy indexable models, the code
        # to sync with solr will not be called at all
      end


## Calling #update_index manually

Whether or not you have automatic `after_commit` callbacks enabled, you can always force a sync of a model to Solr index with:

    some_model.update_index

This could add/update or remove a document from the (Solr) index, depending on model state.

This will respect any other settings set by a surrounding `index_with` block, including batching.

## Bulk (re-)indexing and index cleanup.

No rake tasks are provided to do bulk indexing, but using the batching functionality it is straightforward for you to implement one. You might want to use a progress bar etc, but a barebones implementation that will work fine:

```ruby
desc "Sync all Works and Collections to Solr index"
task :reindex do
  Kithe::Indexable.index_with(batching: true) do
    Kithe::Model.where("kithe_model_type": ["collection", "work"]).find_each do |model|
      model.update_index
    end
  end
end
```

Under normal use, you should never have documents leftover in your solr index that have been deleted in your db, since the Solr documents should be deleted on #destroy. But if things get out of sync, we provide a utility:

    Kithe::SolrUtil.delete_solr_orphans

## Under test

While writing tests in your app, for performance (or to avoid needing a running Solr) you may want to only enable the callbacks that sync models on save for tests that need it.

For RSpec, add to your `spec_helper.rb` or `rails_helper.rb`:

```ruby
RSpec.configure do |config|
  config.before(:suite) do
    Kithe::Indexable.settings.disable_callbacks = true
  end

  config.around(:each, :indexable_callbacks) do |example|
    original = Kithe::Indexable.settings.disable_callbacks
    Kithe::Indexable.settings.disable_callbacks = !example.metadata[:indexable_callbacks]
    example.run
    Kithe::Indexable.settings.disable_callbacks = original
  end
end
```

And use:

```ruby
describe Work, indexable_callbacks: true do
  it "indexes" do
    Product.create!(name: "Apple")
    # Perhaps you want to use WebMock to confirm it sent something to Solr,
    # or whatever your front-end Solr searching code is to confirm it's in there
  end
end
```

## Customizing Solr updating patterns

By default, Kithe::Indexable uses the `Traject::SolrJsonWriter` to send updates,
and every time it sends an update to Solr, it does it with a softCommit.

You can customize the Trjaect::Writer class used globally:

    Kithe::Indexable.settings.writer_class_name = "Whatever::CompatibleTrajectWriter"

This would also be a way to get indexing to go to something other than Solr, if an appropriate `Traject::Writer` were written.

You can also specify whatever traject "settings" the writer may understand. For instance, if you wanted to _not_ send an update with softCommit, but just rely on `<autoSoftCommit>` in your `solrconfig.xml` (because you don't mind some latency for better performance):

    Kithe::Indexalbe.settings.writer_settings.merge!(
      "solr_writer.solr_update_args" => {}
    )

Or you could send a hard commit (not recommended) or adjust http timeouts, or any other settings Traject::SolrJsonWriter supports, see docs in [traject](https://github.com/traject/traject/blob/master/lib/traject/solr_json_writer.rb).

For temporarily using a different writer or different writer settings, `with_index` also supports a `writer` arg.

```ruby
# hard-commit on every write, with very large batching
writer = Traject::SolrJsonWriter.new(
  "solr_writer.solr_update_args" = { commit: true},
  "solr_writer.batch_size" => 1000
)
Kithe::Indexable.index_with(writer: writer, on_finish: ->(writer) { writer.flush } ) do
  # do some things that trigger solr updates
end
```

## Use with non Kithe::Model ActiveRecord classes?

While Kithe::Indexable was developed for use with `Kithe::Model` (your collections, works, and assets), it's implementation should be independent of it. (Although we aren't currently testing that).

Just add `include Kithe::Indexable` to any ActiveRecord::Base class, and you should get all the indexing functionality documented above for any arbitrary ActiveRecord model.

