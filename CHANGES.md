## NEXT

### Added

*

### Fixed

*

## 2.17.0

### Added

* Kithe derivatves store created at in shrine metadata for derivative, as UTC iso8601 string https://github.com/sciencehistory/kithe/pull/190


## 2.16.0

### Added

* Allow and test on Rails 8 https://github.com/sciencehistory/kithe/pull/184

### Fixed

* Fix repeatable_attr_input for Bootstrap 5.x. https://github.com/sciencehistory/kithe/pull/183

## 2.15.1

### Fixed

* Use new ActiveRecord enum args in Raisl 7.0+ to avoid Rails 7.2 deprecation notice. https://github.com/sciencehistory/kithe/pull/182

## 2.15.0

### Added

* Allow Rails 7.2 in gemspec, no code changes required. https://github.com/sciencehistory/kithe/pull/181

## 2.14.0

### Added

* Normalized metadata from ExiftoolCharacterization::Result supports a couple PDF values https://github.com/sciencehistory/kithe/pull/180

## 2.13.0

### Added

*  Kithe::Model sub-classes filter_attributes :json_attributes https://github.com/sciencehistory/kithe/pull/169

* New method Kithe::Model.kithe_earlier_after_commit can be used to register an after_commit
  hook that will fire BEFORE any existing after_commit hooks -- including shrine promotion-related
  ones -- and will work consistently in any version of Rails including Rails 7.1 with run_after_transaction_callbacks_in_order_defined. https://github.com/sciencehistory/kithe/pull/178

## 2.12.0

### Added

* Support Rails 7.1 https://github.com/sciencehistory/kithe/pull/172


## Changed

* Dropped support for Rails < 6, and attr_json < 2. https://github.com/sciencehistory/kithe/pull/170

## 2.11.0

### Added

* Re-use of single shared source tempfile for multiple `add_metadata` and `before_promotion` hooks,
  using `Shrine.with_file`, so long as `Shrine.plugin :tempfile` is enabled in local app. https://github.com/sciencehistory/kithe/pull/167

* Helpers for characterization with exiftool https://github.com/sciencehistory/kithe/pull/168

## 2.10.0

### Added

*  `Kithe::CreateDerivativesJob` can take arguments for #create_derivatives, and rake task
   `kithe:create_derivatives` can now be used to enqueue bg jobs, one per asset. https://github.com/sciencehistory/kithe/pull/166


## 2.9.1

### Fixed

*  Asset#remove_derivatives should delegate extra options too. https://github.com/sciencehistory/kithe/pull/164

## 2.9.0

### Fixed

* Make Kithe::BlacklightTools::SearchServiceBulkLoad / Kithe::BlacklightTools::BulkLoadingSearchService compatible with Blacklight 8.x. Remains compatible with previous BL as well. https://github.com/sciencehistory/kithe/pull/163


## 2.8.0

### Added

* Allow attr_json 2.0, while still allowing 1.0.  If you want one or the other specifically, you may want to lock in your own gemfile. https://github.com/jrochkind/attr_json/blob/master/CHANGELOG.md#200


## 2.7.1

### Fixed

* Severe bug in Single-Table Inheritance fix in 2.7.0 fixed, https://github.com/sciencehistory/kithe/pull/156

## 2.7.0

### Fixed

* A fix for Rails 7 and Kithe::Model Single-Table Inheritance in development-mode. https://github.com/sciencehistory/kithe/pull/154


## 2.6.1 (Aug 23 2022)

Reverts "Work#members association is ordered by default" from 2.6.0, turns out backwards incompat. https://github.com/sciencehistory/kithe/pull/153


## 2.6.0 (Aug 11 2022)

### Backwards incompatible change

* FfmpegExtractJpg defaults to frame_sample_size: false, no frame sampling. It was too RAM risky. https://github.com/sciencehistory/kithe/pull/150

### Fixed

* Fix bug in FfmpegExtractJpg where you couldn't turn off frame sampling. https://github.com/sciencehistory/kithe/pull/150

* Allow Kithe.indexable_settings.writer_settings to be mutated as per docs https://github.com/sciencehistory/kithe/pull/151

### Added

* Work#members association is ordered by default, by position column, then created_at. https://github.com/sciencehistory/kithe/pull/146 [REVERTED in 2.6.1]

* Allow remove_derivatives to receive string arg normalized to symbol https://github.com/sciencehistory/kithe/pull/147

* Support Rails 7.0. https://github.com/sciencehistory/kithe/pull/137


## 2.5.0 (2 Mar 2022)

### Added

* Tools for using a standard shrine derivatives processor with kithe features, including lifecycle management and guard options. https://github.com/sciencehistory/kithe/pull/143

* add Kithe::FfmpegExtractJpg service for extracting frame from video  https://github.com/sciencehistory/kithe/pull/144


## 2.4.0 (14 Feb 2022)

### Added

* FfprobeCharacterization helper class for a/v characterization metadata https://github.com/sciencehistory/kithe/pull/139

* Create an Asset#file_metadata method that delegates to file.metadata for convenience https://github.com/sciencehistory/kithe/pull/140


## 2.3.0 (Dec 2 2021)

### Fixed

* Avoid making a query on every validation https://github.com/sciencehistory/kithe/pull/134

### Added

* Allow customization of Solr indexing `batching` mode batch size. https://github.com/sciencehistory/kithe/pull/135


## 2.2.0 (Nov 15 2021)

### Fixed

* Doc-only change, update docs fro kithe 2.0 change to define_derivative block parameter,
  `attacher:` not `record:`. https://github.com/sciencehistory/kithe/pull/124

* Ruby 3.0 compatibility.

* Fix nested Kithe::Indexable.index_with calls. https://github.com/sciencehistory/kithe/pull/131

### Added

* Spec and doc custom already-working conditional logic within define_derivative. https://github.com/sciencehistory/kithe/pull/123

* Documentation on local over-ride to Kithe::Model#update_index to implement local indexing customization. https://github.com/sciencehistory/kithe/pull/132

### Changed

* Removed hacky workaround to shrine missing func around lazy downloads of originals
  when procesing derivatives. Can use shrine func `download:false` introduced in shrine 3.3
  instead. https://github.com/sciencehistory/kithe/pull/122

## 2.1.0

### Added

* kithe_determine_mime_type plugin keeps using `audio/flac` as in previous versions of marcel,
  instead of `audio/x-flac` as in marcel 1.0. https://github.com/sciencehistory/kithe/pull/117

### Fixed

* Fix bug in obj_extract macro for cases of intermediate array values https://github.com/sciencehistory/kithe/pull/116

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

