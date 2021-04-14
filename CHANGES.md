## NEXT

### Added

* Include AttrJson::Record::QueryScopes in Kithe::Model https://github.com/sciencehistory/kithe/pull/120

## 2.1.0

### Added

* kithe_determine_mime_type plugin keeps using `audio/flac` as in previous versions of marcel,
  instead of `audio/x-flac` as in marcel 1.0. https://github.com/sciencehistory/kithe/pull/117

### Fixed

* Fix bug in obj_extract macro for cases of intermediate array valueshttps://github.com/sciencehistory/kithe/pull/116

* avoid deprecated ActiveModel::Error API https://github.com/sciencehistory/kithe/pull/118

## 2.0.3

### Fixed

* Reduce kithe gem release package size by eliminating accidental log files. https://github.com/sciencehistory/kithe/pull/114

## 2.0.2

### Fixed

* Indexing: Allow configurable solr_id_value_attribute values to correctly Solr delete. https://github.com/sciencehistory/kithe/pull/109

* Kithe::ConfigBase source file moved to ./lib a rails non-auto-loading location, to make it easier to use in non-deprecating and functioning way from a Rails app config or initialization file, which is one of it's main use cases. https://github.com/sciencehistory/kithe/pull/112

## 2.0.1

### Fixed

* Fix default traject logger Rails.logger [#98](https://github.com/sciencehistory/kithe/pull/98)

## 2.0.0

**We aren't aware of anyone other than Science History Institute using kithe 1.x in production, so haven't invested time in making the change notes _quite_ as complete or migration process as painless as if we were. But if you are in this situation please get in touch via GH Issues for guidance.**

* use fx gem to so schema.rb can contain pg functions, no need for structure.sql anymore, and consuming apps won't be forced to use structure.sql. They ARE forced to use fx gem's overrides of Rails schema dumping, including some local patches. https://github.com/teoljungberg/fx https://github.com/teoljungberg/fx/pull/53

### File attachment handling and derivatives

The main changes in kithe 2.0 are around file attachment handling: upgrading to [shrine](https://shrinerb.com/) 3.x, and changing derivatives from custom implementation to be based on shrine 3.x's.

You can also now create a local shrine Uploader class for your local Kithe::Asset subclasses -- and have different ones for different local Asset classes in a local inheritance hieararchy. This lets you access the full power of shrine customization and configuration.

See https://github.com/sciencehistory/kithe/issues/81

*  Use `set_shrine_uploader` in your local Asset class(es) to set to a local shrine uploader class. It is strongly recommended this local uploader class subclass `Kithe::AssetUploader`.

* The default shrine uploader no longer includes remote_url assigning functionality, add `plugin :kithe_accept_remote-url` to your local uploader to restore it.

* The default shrine uploader no longer includes fixity checksum extracting by default, add `plugin :kithe_checksum_signatures` to your local uploader to get back standard fixity checksum signature extraction.

* Kithe derivatives are now defined in your *uploader* class with `Attacher.define_derivative` instead of your Asset model class with `define_derivative`. The method is mostly the same though.
  * but optional keyword argument on your deriv definition block is now `attacher:` instead of `record:`, and returns a shrine Attacher instance. You can ask `attacher.record` to get the model.

* The `derivatives_created?` and `mark_created` methods are gone, they werne't used that much and were incompatible with async derivative creation. You can easily check if a particular derivative is present, but there is no longer any way to know if kithe thinks it's "done" with derivative creation.

* It is no longer possible to have individual derivative definitions stored in different storage locations, they are all stored in `:kithe_derivatives`.

* On your Asset models:
  * you no longer have a `derviative_for` method, use standard shrine techniques for accessing derivatives. Such as `asset.file_url(derivative_key)`, `asset.file(derivative_key)`, `asset.file_derivatives`.
  * There is no longer a `derivatives` ActiveRecord association. Derivatives are inside the Asset record itself, using standard shrine technology.
  * There is no longer a `with_representative_derivatives` scope, it's no longer needed. Intead, you probably just want something like: `asset.members.include(:leaf_representative)`, that's enough to do it.

* The `Asset#create_derivatives` , `Asset#update_derivative`(s) and `Asset#remove_derivatives` methods have been slightly altered in name and signature, but they are all still there, and still can be used to mutate derivatives in concurrency-safe manner.

* See also [Migrating Derivatives to Kithe 2.0](migrating_derivatives_to_2.md) guide.

