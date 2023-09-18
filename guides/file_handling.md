# File Handling in Kithe

The [Kithe data model](./modelling.md) consists of Collections, Works, and Assets. An Asset record represents an individual ingested file/bytestream. A Kithe::Asset instance provides access to that bytestream through it's `file` attribute, with an implementation using the [shrine](https://shrinerb.com/) ([git](https://github.com/shrinerb/shrine)) attachment toolkit.

You will normally have a local model class that sub-classes Kithe::Asset. You could also have your own local inheritance hieararchy of Assets.

```ruby
class Asset < Kithe::Asset
  # custom local logic
end

# or perhaps, up to you
class ApplicationAsset < Kithe::Asset
end
class AudioAsset < ApplicationAsset
end
```

Shrine is a very powerful toolkit, but it can be a bit tricky to get all the parts working together properly. Kithe sets up the `Asset#file` attachment with the `Kithe::AssetUploader` shrine uploader which has been customized with certain defaults and custom shrine plugins to give you a good and flexible out of the box experience. That is, we add a layer on top of shrine, but the custom kithe layer lies lightly, and you can almost always do anything standard shrine you'd like as well.

You should be able to use any storage location supported by shrine (and it is not too hard to write new storage adapters for shrine). But kithe has been developed ensuring that storage on S3 works, and we suggest S3 for production. For dev/test, you may want to use local file storage -- any supported shrine storage should work more or less interchangeably.

We set up file handling to do expensive work (metadata extraction, derivatives, etc) in background ActiveJob(s), although you can flexibly control this on a case by case basis.

We also ensure all configuration works well with "direct uploads" -- javascript in browser uploading directly to storage location. For instance, metadata extraction and derivative generation are configured to happen at the `promotion` stage (ordinarily in an ActiveJob), since the complete file will not be available earlier than that when using direct upload techniques.

See also our separate [Derivatives Guide](./derivatives.md)


<a name="definingStorage"></a>
## Defining your shrine storages

Your app needs to define where files will be stored. In addition to the standard shrine `store` and `cache` locations, kithe configures derivatives to be stored in a location pointed to by key `kithe_derivatives`. To configure S3 storage for all three locations, you might:

```ruby
# config/initializers/shrine.rb

s3_options = {
    access_key_id:     Rails.application.secrets.s3_access_key_id,
    secret_access_key: Rails.application.secrets.s3_secret_access_key,
    region:            Rails.application.secrets.s3_region,
    bucket:            Rails.application.secrets.s3_bucket
}
Shrine.storages = {
  cache: Shrine::Storage::S3.new(prefix: "cache", **s3_options),
  store: Shrine::Storage::S3.new(prefix: "store", **s3_options),
  kithe_derivatives: Shrine::Storage::S3.new(prefix: "kithe_derivatives", **s3_options)
}
```

While that example has all three storage locations in the same S3 bucket with a different prefix, you can also use entirely different S3 buckets.

If your files are all entirely public, you [may want to set the `public: true` key](https://github.com/shrinerb/shrine/blob/v2.15.0/doc/storage/s3.md#public-uploads):

```ruby
Shrine.storages[:kithe_derivatives] =
  Shrine::Storage::S3.new(prefix: "store",
                          bucket: "some_bucket",
                          public: true,
                          ...)
```

This will make the Shrine storage upload with an S3 public ACL, and also effect the default URLs generated directly to content in S3 (to be public URLs rather than signed URLs). If you plan to serve derivatives as public content from public S3 urls, you might want to set far-future cache-control headers (as all storage locations should be unique to particular unique file), with the [upload_options](https://github.com/shrinerb/shrine/blob/v2.15.0/doc/storage/s3.md#upload-options) argument:

```ruby
Shrine.storages[:kithe_derivatives] =
  Shrine::Storage::S3.new(prefix: "store",
                          bucket: "some_bucket",
                          upload_options: {
                            cache_control:  "max-age=31536000",
                            metadata_directive: "REPLACE"
                          }
                          public: true,
                          ...)
```

You can also set shrine storages to use local file system, perhaps for dev or test. You could use conditional logic to set up storages differently depending on Rails.env.

```ruby
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads_cache"),
  store: Shrine::Storage::FileSystem.new("public", prefix: "uploads_store"),
  kithe_derivatives: Shrine::Storage::FileSystem.new("public", prefix: "derivatives")
}
```

That example will write all content to the Rails app `./public` directory, so it can be easily served without extra lgoic, but of course will have no access control. While we don't recommend doing so, if you wanted to use file system storage in production with access control, you might not want to write it to `./public`.

For test, you may be interested in [shrine in-memory storage](https://github.com/shrinerb/shrine-memory).

**Note on clearing "cache" storage** Shrine "cache" storage, by design, fills up with files that are no longer needed. There is no way to eliminate this completely, as someone could always abandon a file without completing an ingest process.  You will want to periodically remove files from "cache" storage that are older than some time (longer than should be neccessary to go through "promotion"), using [S3 lifecycle rules](https://docs.aws.amazon.com/AmazonS3/latest/user-guide/create-lifecycle.html), or via [shrine API](https://github.com/shrinerb/shrine#clearing-cache). This should not be necessary with the `store` or `kithe_derivatives` storage locations.


## Some standard kithe shrine uploader logic

The [Kithe::AssetUploader](../app/uploaders/kithe/asset_uploader.rb) is a shrine uploader class that's used by default for Assets. It includes a number of shrine plugins, both standard shrine, and custom kithe plugins. Some of the things it does:

* height/width metadata extraction for images
* content-type/media-type analysis based on file content, not trusting filename
* if an upload original filename has no extension, add one appropriate for determined content-type
* set *storage locations* to be more convenient for manual identification and debugging
  * original files are stored at `asset/#{asset_uuid_id}/#{a_unique_file_id}.suffix`
  * derivatives are stored at `#{asset_uuid_id}/#{derivative_key}/#{unique_file_id}.suffix`

Along with custom kithe functionality documented below.

<a name="attachmentLifecycle"></a>
## Attachment Lifecycle

Shrine uses a two-stage storage flow. All shrine attachments have a "cache" storage location which is used for files that have not yet been permanently saved, and a "store" storage location which files are moved to once the model they are attached to (in this case a Kithe::Asset) has had the attachment succesfully saved and committed to the database. (This allows a file to be somewhere in order for it or it's associated model to be validated or otherwise checked before it's permanently saved).  Shrine uses the term <i>promotion</i> for the process of moving a file from `cache` to `store`.

If you are using "direct uploads", Javascript in the browser sends the upload to the `cache` location before the user has even submitted a form. Upon submitting a form, the cache location is set in the `Asset` model. After saving the asset model with a new cache location, <i>promotion</i> is triggered.

During "promotion", the file is copied to the permanent `store` location. In kithe, the promotion phase happens by default in a background ActiveJob, and also by default includes metadata extraction and [derivative generation](./derivatives.md).

kithe adds ActiveRecord-style callbacks around promotion to the Asset class: `before_promotion`, `after_promotion`, `around_promotion`. If promotion is happening in a bg job, all these callbacks will be triggered within that job.

Let's outline the attachment ingest/add lifecycle again with more details:

1. File or file location details are set on an asset
      ```
      asset.file = File.open("something")
      # or
      asset.file = { storage: "cache", id: "path/to/file.jpg" }
      asset.save!
      ```

2. After model is succesfully committed to DB (now pointing at file on "cache"), the Kithe::AssetPromoteJob is kicked off to handle promotion. You can ask `asset.stored?` to see if it's in permanent `store` location yet.

3. `before_promotion` callbacks are called, and the have the opportunity cancel promotion.
    * Kithe by default has a `before_promotion` hook to run any defined metadata extraction.

4. File is "promoted" to the permanent `store` location.

5. If promotion was succesfully committed to the db, `after_promotion` callbacks are called.
    * Kithe by default has an `after_promotion` hook to launch a *separate* job to [create any derivatives](./derivatives.md) defined with the `kithe_derivatives` processor.

### Attaching files

You can use any of the standard shrine methods to attach a file, and kithe provides no extra help here.

You can attach a `File` object by assigning to the `file` attribute we've used for the attachment. This is most useful in tests or batch processes, there isn't much call for it in interactive production code.

```ruby
some_asset.file = File.open("something")
```

In fact, you can assign any ["IO-like object"](https://github.com/shrinerb/shrine#io-abstraction), which also includes the Rails/rack object in params should you have submitted a file directly to a Rails controller action. `some_asset.file = params[:some_file_input_name]`.

In both these cases, the file is copied to your 'cache' storage inline, and some _limited_ metadata is extracted -- copy of file to 'store' and more complete metadata extraction (including SHA fingerprints) will only be done on "promotion" after you `save` the model, ordinarily in a background ActiveJob triggered in an `after_commit` hook.

We do not recommend you submit files directly to the Rails app with an HTML file input however. It's a better UX to use a "direct upload" process (similar to what hyrax uses), where javascript sends the file directly to storage before submit. Ideally, directly to an S3 bucket without even involving your Rails app and tying up Rails app workers. You will want to have your front-end javascript store the file wherever you have configured as `cache` storage. Then, you can send the file location to your Rails app, and you can set it in the asset object with a hash of shrine metadata identifying the location, like so:

```ruby
some_asset.file = { "storage" => "cache", "id" => "path/on/cache/storage.jpg" }
```

Note keys must be Strings not Symbols. You can also set to a JSON serialized String, useful so your front-end can send the hash serialized in a single hidden input.

```ruby
some_asset.file = "{\"storage\":\"cache\",\"id\":\"path/on/cache/storage.jpg\"}"
```

Direct uploads can be a little bit tricky to implement; kithe doesn't currently provide any tools to help with the front-end implementation, although may in the future. For more information, see shrine documentation and tutorials on direct uploads:

* https://shrinerb.com/docs/direct-s3
* https://twin.github.io/better-file-uploads-with-shrine-direct-uploads/
* https://github.com/shrinerb/shrine/wiki/Adding-Direct-App-Uploads
* https://github.com/shrinerb/shrine/wiki/Adding-Direct-S3-Uploads
* https://github.com/erikdahlstrand/shrine-rails-example

When you are assigning a hash with existing `cache` location data, from a direct upload, very little is done on assignment, making it cheap and quick. After you succesfully save the model with the new assignment, "promotion" will be triggered in a background ActiveJob, from an `after_commit` hook, to stream the file from the remote location, extract metadata, and store.

If you have a reference to a Kithe::Asset instance, you can see if it's been promoted yet by checking its `#stored?` method.

In any case, when you assign and save _new_ file information on an asset, any previous stored bytes and derivatives are automatically cleaned up for you, in a reliable and concurrency-safe fashion.

<a name="readingFiles"></a>
### Reading files and file info

This is all done via entirely standard Shrine techniques.

`some_asset.file` will return a [Shrine::UploadedFile](https://shrinerb.com/rdoc/classes/Shrine/UploadedFile/InstanceMethods.html) object. It is "IO-like", you can read it like you would a file to access the bytestream, streaming bytes from the possibly remote storage. Useful methods include [#stream](https://shrinerb.com/rdoc/classes/Shrine/UploadedFile/InstanceMethods.html#method-i-stream), [#open](https://shrinerb.com/rdoc/classes/Shrine/UploadedFile/InstanceMethods.html#method-i-open), [download](https://shrinerb.com/rdoc/classes/Shrine/UploadedFile/InstanceMethods.html#method-i-download).

You can also access some metadata about the file; many methods are delegated from `Kithe::Asset`, so you can just ask for `asset.size` (filesize in bytes), as well as `#original_filename`, `#content_type`,  `#height`, and `#width`. Most of these metadata fields are only available after "promotion" has occured, you can ask `some_asset.stored?` to see if promotion is complete.

### Asset URLs and Delivering bytestreams to browser

You could write a controller action to return the file bytes, similar to what Hyrax does via it's [DownloadController](https://github.com/samvera/hyrax/blob/d4dcf4c6cb2a98f375d0a8aded97f428ce10ead0/app/controllers/hyrax/downloads_controller.rb).

The [shrine rack_response plugin](https://github.com/shrinerb/shrine/blob/v2.15.0/doc/plugins/rack_response.md) could be used for this, making it fairly straightforward to write a delivery action -- even supporting HTTP "Range" headers.  It should stream the bytes directly from your remote storage (eg S3); however, there can be some [difficulties in making sure Rails is streaming and not buffering](https://github.com/rails/rails/issues/18714#issuecomment-96204444).  And even in the best case, you are still keeping a Rails request worker busy for at least as long as it takes to stream the bytes from the remote storage. _So we don't recommend this technique._

Alternately, you can get a URL directly to the asset at whatever storage location, with `an_asset.file.url` -- a method on the Shrine::UploadedFile, which is forwarded to the relevant Shrine::Storage class.

For `Shrine::Storage::FileSystem`-stored files, if they are all public and need no authorization, and you store files in `./public`, that could work seamlessly.

If your files are stored on S3, there are some additional arguments that can be given to `asset.file.url`, and you can get either S3 "public" or [signed](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-signed-urls.html) URLs.

If you created your `Shrine::Storage::S3` with `public: true`, causing all files to get public-read ACLs, [#url](https://shrinerb.com/rdoc/classes/Shrine/Storage/S3.html#method-i-url) will simply return a standard public URL, great.

Otherwise, `#url` will return a unique signed-url, which provides time-limited access to even a  non-public file. You can pass `public: true` (or false) to specifically ask for a public or signed URL. You can also pass additional options as suitable for [Aws::S3::Object#presigned_url](http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#presigned_url-instance_method) or [Aws::S3::Object#public_url](http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#public_url-instance_method), to control expiration time, instruct S3 to deliver response with certain headers like Content-Disposition, etc.

S3 signed URLs are nice for providing access to non-public resources, but they can introduce problems with HTTP cacheability, since generally every response will have a unique S3 signed URL delivered for a given resource. Additionally, _generating_ a signed S3 URL _may_ take enough CPU time that it becomes problematic with very many on a page. You may want to include URLs on pages that point to internal app controller actions, which then redirect to an S3 url (or deliver the bytes directly).

There are different trade-offs with different file delivery mechanisms, and we haven't quite figured out the best for our usage patterns. Kithe (via shrine) aims to give you the tools to build whatever works for you at any given time.

### Promotion callbacks

Kithe lets you register before/after/around callbacks on promotion, on your Asset class. Promotion is a pretty key lifecycle point which you often want to hook into. You might want to analyze the file before promotion (virus checker?). After promotion is when the file is first fully processed and available, so after promotion you might want to kick off some form of indexing, or cache invalidation.

You can use `before_promotion`, `after_promotion`, and `around_promotion` like any standard [ActiveRecord callback](https://guides.rubyonrails.org/active_record_callbacks.html), on your custom local Asset class.

`Kithe::Asset` already has a `before_promotion` callback registered for triggering shrine metadata extraction, and an `after_promotion` callback registered for kicking off derivatives in a background job.

```ruby
class LocalAsset < Kithe::Asset
  before_promotion do
    if want_to_cancel?(self)
      # consistent with other AR callbacks, throw :abort will cancel
      # the promotion process.
      throw :abort
    end
  end

  after_promotion :some_method_in_your_class, if: ->(model) {  }
```

At the point the before callback is triggered, metadata has already been extracted, and you have access to it. If you abort the promotion, the extracted metadata will not be saved, and promotion won't happen. It's up to you and your app to log or store or notify that this happened in whatever way makes sense, kithe data structures won't make it clear why promotion didn't happen.

### Re-use of local source file for performance

If you need access ot a file on disk, you want to use `Shrine.with_file` on the `source_io`.

```ruby
class LocalAsset < Kithe::Asset
  before_promotion do
    Shrine.with_file(self.file) do |local_file|
      # ...
    end
  end
end
```

**AND** you should make sure to add the shrine `tempfile` plugin to the global `Shrine` object in an initializer:

```ruby
Shrine.plugin :tempfile
```

Then, kithe will make sure that a single local copy is made during the promotion process and re-used for all your metadata and before_promotion hooks.

<a name="customizingLifecycle"></a>
### Customizing the ingest lifecycle

After you save a Kithe::Asset where you've _changed_ the `file` attachment, after the db commit has succeeded, shrine will ordinarily trigger promotion. Kithe sets up some custom logic to by default put promotion in a background job, and automatically trigger derivatives creation after promotion, in a separate background job.

The kithe custom logic also includes ways to override this though, globally or for a particular asset instance, which we call "promotion directives".

If you'd like to save an Asset, but disable the promotion step entirely, before saving set a promotion directive:

```ruby
asset.set_promotion_directives(promote: false)
asset.save!
```

In this case the attachment will not be automatically promoted from `cache` storage, and the metadata extraction and derivative generation normally a part of promotion will not happen automatically. You could still trigger promotion manually:

```ruby
asset.promote
```

Which would trigger promotion along with all promotion callbacks (by default metadata extraction, and derivative generaton in a separate launched ActiveJob).

If you instead want promotion to happen, but inline instead of kicking off a background job:

```ruby
asset.set_promotion_directives(promote: :inline)
asset.save!
```

The `Kithe::AssetPromoteJob` won't be queued, promotion will happen immediately. By default, it will still trigger a `Kithe::CreateDerivativesJob` to create [derivatives](./derivatives.md) you have defined as defaults though. If you want this to be disabled, or inline too:

```ruby
asset.set_promotion_directives(promote: :inline, create_derivatives: false)
# or
asset.set_promotion_directives(promote: :inline, create_derivatives: :inline)
asset.save!
```

You can combine values for `promote` and `create_derivatives` however you like. For instance, to leave the promotion in a background job, but have the derivatives created in that same job instead of a `Kithe::CreateDerivativesJob` being queued, just `asset.set_promotion_directives(create_derivatives: :inline)`

You can also turn *off* the promotion callbacks; metadata extraction, derivatives launching, and any local promotion callbacks you've registered.

```ruby
asset.set_promotion_directives(skip_callbacks: true)
```

And if you'd like to set these promotion directives *globally*, you can do so on the `Kithe::Asset` class (or on specific sub-classes applying only to those subclasses), using the `promotion_directives` class attribute.

```ruby
Kithe::Asset.promotion_directives = { promote: :inline, create_derivatives: false }
```

This can be useful if you want to globally opt-out of kithe default behavior. But also for a batch process -- if you are ingesting hundreds of assets, you may not want to kick off background jobs for them all and fill up your job queue. Or for setting up your testing environment.

## Custom Shrine Uploader

By default, `Kithe::Asset` and any local sub-classes use the [Kithe::AssetUploader](../app/uploaders/kithe/asset_uploader.rb), which includes a bunch of kithe plugins to make all this kithe behavior happen, and a bunch of shrine plugins that make sense for kithe use cases, to give you out of the box working behavior without having to spend a lot of time setting things up.

But in your local Asset subclass, you can set your own local shrine uploader instead. This way you have access to the full power of shrine. You can include any additional shrine plugins you want, define custom metadata extractors, and define [derivatives](./derivatives.md). You use the kithe method `set_shrine_uploader` to "override" the uploader from `Kithe::Asset`. We recommend your custom uploader _subclass_ `Kithe::AssetUploader`, so you start with the default kithe behavior.

```ruby
# app/models/asset.rb
class Asset < Kithe::Asset
  set_shrine_uploader(AssetUploader)
end

# app/uploader/asset_uploader.rb
class AssetUploader < Kithe::AssetUploader
  # gives us md5, sha1, sha512
  plugin :kithe_checksum_signatures

  # lets you assign remote urls for browseeverything-style use cases
  plugin :kithe_accept_remote_url
end
```

## Custom Metadata and Characterization

You can use shrine's [add_metadata](https://shrinerb.com/docs/plugins/add_metadata) plugin, already included in `Kithe::AssetUploader` to add arbitrary metadata.

To fit in with shrine's lifecycle, recommend you guard metadata extraction with `context[:action] != :cache`. You may also wish to calculate the metadata only for originals (not derivatives); unless you do want it calculated for (or only for) derivatives.

```ruby
class AssetUploader < Kithe::AssetUploader
  add_metadata :something_fancy do |source_io, derivative:nil, **context|
    if context[:action] != :cache && derivative.nil?
      calculate_fancy_content(source_io)
    end
  end
end
```

### Re-use of local source file for performance

If you need access ot a file on disk, you want to use `Shrine.with_file` on the `source_io`.

```ruby
class AssetUploader < Kithe::AssetUploader
  add_metadata :something_fancy do |source_io, derivative:nil, **context|
    Shrine.with_file(source_io) do |local_file|
      # ...
    end
  end
end
```

**AND** you want to make sure to add the shrine `tempfile` plugin to the global `Shrine` object in an initializer:

```ruby
Shrine.plugin :tempfile
```

Then, kithe will make sure that a single local copy is made during the promotion process and re-used for all your metadata and before_promotion hooks.

### FFprobe helper

Kithe also provides a helper class to do audio/video characterization with `ffprobe` (a tool
that comes with ffmpeg). Here's an example of extracting multiple metadata fields, only for video input, using an `ffprobe`-based extractor that comes with kithe -- executing only on `store` action, and only for originals not derivatives.

```ruby
# audio/video file characterization
add_metadata do |source_io, context|
  Kithe::FfprobeCharacterization.characterize_from_uploader(source_io, context)
end
```

### Exiftool helper

Kithe includes a convenience class for running and interpreting exiftool output. The tool outputs
json, but as it's fairly large, you might want to create a separate attribute from shrine metadata
and store it there. This shows one way you might do that:

```ruby
class MyAsset < Kithe::Asset
  before_promotion :store_exiftool

  def store_exiftool
    # assume we've created an attribute for exiftool_result
    Shrine.with_file(self.file) do |local_file|
      self.exiftool_result = Kithe::ExiftoolCharacterization.new.call(local_file.path)
    end
  end
end

## then later....
exiftool_result = Kithe::ExiftoolCharacterization.presenter(some_asset.exiftool_result)
exiftool_result.camera_model # etc
```

## Validation?

The built-in [shrine validation architecture](https://github.com/shrinerb/shrine/blob/master/doc/validation.md#readme) is targetted at interactive forms, and doesn't make a lot of sense in our scenario where  where metadata extraction and promotion happen in the background.

We haven't totally worked out what makes sense in kithe. But it will probably involve registering a before_promotion callback to cancel promotion based on asset metadata, and record that (with error messages?) somewhere in your app, for presentation later.

## Note on deleting and callbacks

If you delete an `Asset` using ActiveRecord `destroy`, shrine will take care of making sure the actual bytestream in storage is deleted too. If you use ActiveRecord `delete`, which doesn't call shrine callbacks, it won't be able to. So beware!

Likewise, if you are setting a new `file` on an `Asset`, make sure to do it in a way that does not disable ActiveRecord callbacks, to make sure kithe and shrine have the chance to remove originals and derivatives for the old replaced file that is no longer referenced after save.


## Optional plugins

Shrine provides a few plugins that are not by default included in `Kithe::AssetUploader`, but which you can include in your custom local uploader.

### kithe_checksum_signatures

Calculates metadata for some some standard fixity checksums: sha1, md5, and sha512. And provides methods on the `asset.file` object to access.

### kithe_accept_remote_url

Adding this plugin into your uploader, you can assign *remote urls* to an `asset.file`, and they will be copied locally on promotion phase.

You assign this with a hash with special storage key `remote_url`, and `id` pointing to URL. (It is also possible to specify HTTP client headers to use in `headers` key, such as an Authorization bearer token).

```ruby
some_asset.file = { "storage" => "remote_url", "id" => "http://example.org/something.jpg" }
```

You could use this as a way to attach files identified with the front-end from [browse-everything](https://github.com/samvera/browse-everything), without using the back-end of browse-everything. Just use kithe's built-in handling of attaching any `remote_url`.

**Do Note** There's currently no built-in whitelisting, any URL you provide will be streamed and attached. Handle validation in your controller layer if needed, or ask us for a feature.


