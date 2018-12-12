# Modelling and Persistence

Kithe provides a base for some modelling of some key domain objects, that is *influenced by* and *based on* (but does not completely match) [PCDM](https://github.com/duraspace/pcdm/wiki) and traditional hyrax/samvera domain modelling.

Kithe provides three classes of models:  Work, Asset, and Collection.

They all live in the postgres database; using [ActiveRecord single-table inheritance](https://guides.rubyonrails.org/association_basics.html#single-table-inheritance), they actually all live in the same `kithe_models` database, with the parent ruby class `Kithe::Model`.

**Kithe::Work** is the basic unit of interest for a digital collections/repo app. It might represent a scanned book; a photograph or set of photographs; a PDF dissertation (possibly with accompanying material); etc.   An app is expected to have one (_or more_) custom sub-classes of Kithe::Work, with custom defined metadata. (See "attr_json and custom app classes" section below)  In addition to metadata, each work can have zero or more attached children/`members`, which can be either other Works or **Assets**, and have an order. A Work may belong to zero or more *Collections*.

**Kithe::Asset** represents a single ingested file (digital object), and metadata (technical, descriptive, whatever) about it. Each Asset normally belongs to exactly one `parent` Work, which it is a member of. An Asset is allowed to have no parent, mainly intended for ingested Assets waiting for assignment.
  * (not yet complete) Assets additionally have "derivatives" (thumbnails, transformations), which are usually automatically generated.
  * Kithe::Asset roughly corresponds to a samvera "FileSet" plus it's "File" object. In PCDM terms, it's kind of an "Object" combined with a single "File". Unlike in samvera/PCDM, an Asset belongs to at most _one_ parent work. This makes the implementation a lot simpler, easier to make performant, and allows an Asset to more easily inherit certain things, like permissions, from it's parent. We believe this is sufficient for a large swath of apps; an app that needs a many-to-many children/membership relationship would have to add that modelling itself.
  * It is expected you will have at least one subclass of Kithe::Asset. This is where you define derivatives, you can also add custom metadata or other customizations here.

**Kithe::Collection** is a group of Kithe::Works. The association between collection and work is many-to-many, a work can be in several collections. A work has an `in_collection` association; a collection has a (to be determined name, can't re-use `member` though) association to it's member works.

* You may have one or more custom sub-classes of Kithe::Collection in your app if you'd like to add additional metadata fields or behavior or different collection types.

* Hypothetically, the `parent_id` column normally used for Work members/parents could be used for nested/child Collections, we haven't carried this through yet.

All Kithe::Model objects are required to have a single non-empty `title`, which can be used for labelling in interfaces.

## Single-Table Inheritance

Works, Assets, and Collections all are sub-classes of Kithe::Model, and use [ActiveRecord single-table inheritance](https://guides.rubyonrails.org/association_basics.html#single-table-inheritance) so they all live in the single `kithe_models` table.

This is one way to make it easy to implement (in a simple and performant way) hetereogenous associations -- such as a Work's members being made up of both Works and Assets, in a single ordered list. It also makes it more straightforward to fetch hetereogenous lists, with one db query. We think it will also make it more straightforward to reliably implement preservation activities and functionality, if all objects of preservation interest can be in a single table. (It is also analagous to what [valkyrie](https://github.com/samvera-labs/valkyrie)'s postgres adapter does, although valkryie doesn't use the Rails single-table inheritance feature).

The downside of single-table inheritance is that the base kithe_models table may include some columns only relevant to certain sub-classes. This includes association modelling -- while the `parent_id` column is intended for work/child relationships, there is no database constraint preventing making an Asset a parent (not intended to be allowed by kithe modelling). In some cases, we can work around this generalization with app-level Rails validations or other model code, or even using [ActiveRecord ignored_columns feature](https://blog.bigbinary.com/2016/05/24/rails-5-adds-active-record-ignored-columns.html) to hide some columns from some sub-classes.

The generalization can possibly be useful in the future in some cases. We've basically defined a single one-to-many association from any Kithe::Model to any other (work members/parent), and a single many-to-many (collection association); perhaps in the future we can generalize this for more purposes, maybe even add a 'type' qualifier to each association.

**Note Well** Because of [how Rails Single-Table Inheritance interacts with dev-mode auto-loading](https://guides.rubyonrails.org/autoloading_and_reloading_constants.html#autoloading-and-sti), for any custom subclasses you define, you should add a to_prepare block to load them, perhaps in your config/application.rb. If you have a local `Work` and `Asset` class:

    config.to_prepare do
      require_dependency "work"
      require_dependency "asset"
    end

## Primary keys:  friendlier_id

All Kithe::Models (Work, Asset, Collection) use UUID primary keys (and thus foreign keys representing these pks, of course), using [standard Rails/postgres functionality](https://guides.rubyonrails.org/active_record_postgresql.html#uuid). This seems inline with where many other samvera community apps are going, when they have the chance.

But UUIDs are inconveniently long in URLs or other user-visible UI. So all Kithe::Model objects also have a `friendlier_id` column, intended for an within-app-unique string identifier to be used in URLs and other UI.

The `friendlier_id` column is set with database constraints to be non-nil and enforced-unique. Kithe migrations also install a custom postgres stored procedure used to set a default value on insert. It creates a value that is a random 9 chars 0-9 and a-z. (It outwardly has the rough form of a "noid", but has none of the noids features like a checksum).

However, your app can choose to explicitly set a `friendlier_id` on insert instead of using the default postgres stored procedure . Perhaps from an existing enterprise identifier minting system you have (Ark), or a ruby gem your app may choose to use ([noid-rails](https://github.com/samvera/noid-rails)?).  Because the `friendlier_id` is not actually a db pk/fk, you can also change it on a given record at any time with no need for updating any fks or other internal data integrity issues -- although of course it will change your URLs that are in terms of `friendlier_id`.

Kithe::Model overrides [Rails to_param](https://api.rubyonrails.org/classes/ActiveRecord/Integration.html#method-i-to_param) to use the friendlier_id. In your controller, you will probably want: `Kithe::Work.find_by_friendlier_id(params[:id])` instead of the usual `find(params[:id])`.

## attr_json, and custom app classes

It is expected that you will have at least one custom local Work class, which sub-classes `Kithe::Work`.  You can also have multiple sub-classes, if you need different kinds of works with different metadata or logic. In that case, you might want to create a single local app superclass for all your subclasses, say `ApplicationWork` kind of like Rails `ApplicationRecord` and `ApplicationJob` -- so you have a place to put things you want to apply to all your sub-classes.

Kithe recommends you use [attr_json](https://github.com/jrochkind/attr_json) to create your custom local metadata attributes. Kithe::Model classes all have a `json_attributes` jsonb column to hold attributes serialized to a json hash with attr_json.  This lets us avoid some of the column-expanding inconvenience of Single Table Inheritance.  It also generally gives us a "schemaless" approach to domain metadata, which has been show to be useful in past samvera community and other digital collections platforms -- avoiding the complexity of managing and effectively using the normalized rdbms schemas we'd need for digital collections type metadata otherwise.

attr_json lets you define attributes as primitive types (string, integer, datetime, etc), arrays of primitive types -- or as entire models that can be nested/compund.  Example:

```ruby
class Work < Kithe::Work
  attr_json :more_titles, :string, array: true
  attr_json :authors, Author.to_type, array: true
end

class Author
  include AttrJson::Model

  validates_presence_of :first, :last

  attr_json :first, :string
  attr_json :last, :string
end

work = Work.create!(title: "hello",
                    more_titles: ["one", "two"])
                    authors: [{ first: "John", last: "Smith"}]
work.authors.first # => an Author model object

# or set with Author model object instead:
work = Work.create!(title: "hello",
                    authors: [Author.new(first: "John", last: "Smith")])
```

Note that you can provide validations on your compound models. Kithe provides some form builder support for editing array attr_json attributes, primitive or model. Arrays of primitive attributes have a lot of limitations in validation convenience, and in presenting validations on a form. You could consider a model of only one attribute as an alternative. But if you do have primitive array attributes, see `Kithe::ArrayInclusionValidation` for some validaton assistance.

### Race conditions and optimistic locking

One down-side of storing all attributes serialized in a json hash, is that every save to db with Rails will overwrite the entire json_attributes column. If you have two processes/threads whose execution overlaps, one trying to update (eg) a "publisher" attribute and the other a "language" attribute -- one of the updates could be lost.

One way to prevent that is using standard [Rails optimistic locking](https://api.rubyonrails.org/classes/ActiveRecord/Locking/Optimistic.html). Although it can be tricky to figure out how to recover from StaleObjectErrors. In the future, kithe may turn on optimistic locking for all Kithe::Models, and provide some code to make it easier to handle StaleObjectErrors. For now, if you'd like to use optimistic locking, your app can simply in it's own migration add an appropriate  `lock_version` column to `kithe_models`.


## To-be-done

Not yet implemented: Derivatives, representatives, collection membership, more.

