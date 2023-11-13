# An unorthodox approach to Blacklight, with some basic support from Kithe

You don't need to use Blacklight (or even Solr) with kithe at all. If you are using Solr, with or without Blacklight, see Kithe's [support for Solr indexing](./solr_indexing.md).

If you *are* using Blacklight, we propose here an unorthodox and optional way to use Blacklight, where you provide custom view templates for displaying search result items, where your templates are based on your actual ActiveRecord `Kithe::Model`s, instead of Solr results with stored fields (Blacklight `SolrDocuments`). (**requires Blacklight 7**)

## Blacklight assumes Solr stored fields used for templates, and the downsides

Blacklight is written so search results can be displayed entirely from Solr stored fields. Blacklight does not assume you will even have a local rdbms or other store, or that the things indexed in Solr neccessarily come from it. It supports a Solr index in and of itself, without assuming any other application-accessible persistence.

However, in most digital collections/repository use cases -- along with many other domains where using Solr in a Rails app is desirable -- the things indexed to Solr *did* come from a local app persistence store, which is their true canonical representation. In Kithe's case, that local store is a postgres database.

The popular Rails/solr integration [sunspot](https://github.com/sunspot/sunspot#hits-vs-results) gem supports, by default, instead returning the actual ActiveRecord models from you solr query. By transparently fetching from your database using ID's in the Solr results. The [searchkick](https://github.com/ankane/searchkick#results) gem for Rails/ElasticSearch integration does the same.

The typical Blacklight approach has some downsides:

* You need to put everything you might need to render a display into a Solr stored field, which can be using Solr in a way that's not at it's best.
* You need to write code that uses Solr response items differently than code that may be in other parts of your app using your ActiveRecord models, which can lead to less consistency and reusability in your codebase.
* You need to make sure to keep your Solr objects in sync with your actual store objects. Which you need to do anyway at some level, but the need to have *more* info in Solr (everything you need to render display, not just hit on results) can make this more complex, less tolerable to latency, and more confusing when it doesn't match.
* If you need things at display time that are *accross associations* (from a related object), it can be especially tricky to keep them in sync. Or you can, as sufia/hyrax have done, try to have multiple related objects in Solr, and use Solr joins or other techniques to fetch them. But it's inconvenient not to have ordinary ActiveRecord eager loading support. One common example is getting a thumbnail or other media asset that needs to be shown next to each result.

There are reasons you might want to use Solr stored fields anyway, including if you need absolute performance optimization. And some Blacklight app implementers use Solr stored fields for the *results list*, while routing to a more ordinary Rails database-based action for individual record show.

But if you want to use Blacklight but have access to efficiently fetched ActiveRecord models even on index/results list, it's not too hard, and Kithe gives you a bit of optional support. (The performance hit of an extra ActiveRecord fetch is usually negligible, which is why sunspot and searchkick can use this technique by default too)

## Using Blacklight with bulk-fetched Kithe::Model objects powering your results view

### 1. Extend your SolrDocument to have a place to hold them

Blacklight generated an `./app/models/solr_document.rb` into your app. Give it an attribute called `model` to hold the fetched Kithe::Model instance, as simple as this:

```ruby
class SolrDocument
  include Blacklight::SolrDocument
  # ...

  attr_accessor :model
end
```

### 2. Use Kithe functionality to get Blacklight SearchService to bulk fetch models

In your CatalogController, which has also been generated into your app by Blacklight installer, simply:

```ruby
require 'kithe/blacklight_tools/bulk_loading_search_service'
class CatalogController < ApplicationController
  include Blacklight::Catalog
  # ...

  self.search_service_class = Kithe::BlacklightTools::BulkLoadingSearchService
end
```

* Note: If you need other custom functionality in your `Blacklight::SearchService`, and already have or need a custom sub-class of your own, you can just `include Kithe::BlacklightTools::SearchServiceBulkLoad` into it. The `BulkLoadingSearchService` is intended as a convenience only when you need no other customizations to `Blacklight::SearchService`.

Now, after any Blacklight search, all of your `SolrDocument` "document" objects will have a Kithe::Model available from their `#model` method.

One of the main benefits of doing this is being able to use ActiveRecord eager-loading to efficiently (without [n+1 queries](https://medium.com/@bretdoucette/n-1-queries-and-how-to-avoid-them-a12f02345be5)) fetch associated records for results list display.  You can set Rails `includes` (or use any other method that could ordinarily be in an ActiveRecord `scope`) with a `bulk_load_scope` class attribute, like so:

```ruby
class CatalogController < ApplicationController
  include Blacklight::Catalog
  # ...

  self.search_service_class = Kithe::BlacklightTools::BulkLoadingSearchService
  Kithe::BlacklightTools::BulkLoadingSearchService.bulk_load_scope =
    -> { includes(:derivatives, leaf_representative: :derivatives)  }
end
```

That example will give you `leaf_representative` on all works, and loaded derivatives on all leaf representatives or other Assets, with efficient SQL querying.

### 3. Use your loaded models in your views

One way is to simply abandon Blacklight's views entirely and use more ordinary Rails views.

Override the Blacklight document_list partial, by creating an `./app/views/catalog/_document_list.html.erb` that might look like this:

```erb
<% # container for all documents in index list view -%>
<div id="documents" class="documents-<%= document_index_view_type %>">
  <%= render partial: "my_partial", collection: documents.map(&:model).compact, :as => :model %>
</div>
```

Now you provide your own `my_partial` element, which gets a `model` that is the actual Kithe::Model. You are responsible for outputting the hit title, any links to view the search hit in detail, etc., which you can use ordinary Rails techniques for.

If you want to re-use some of Blacklight's own more granular partials or helpers, you might want to pass the full SolrDocument into your partial -- so you can pass it to the more granular Blacklight functions -- rather than just passing in the mapped `model`. All up to you.
