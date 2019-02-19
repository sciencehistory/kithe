# File Handling in Kithe

The [Kithe data model](./modelling.md) consists of Collections, Works, and Assets. An Asset record represents an individual ingested file/bytestream. A Kithe::Asset instance provides access to that bytestream through it's `file` attribute, with an implementation using the [shrine](https://shrinerb.com/) ([git](https://github.com/shrinerb/shrine)) attachment toolkit.

File handling is set up to support storage on S3 of all your files, and we recommend that for production. Other cloud storage as supported by shrine will likely also work. For dev/test, you may want to use local file storage -- any supported shrine storage should work more or less interchangeably. File handling is set up to "expensive" file work in background ActiveJob(s), and also to work well with "direct uploads" (javascript in browser uploading directly to storage location).

## Orientation to shrine and kithe's use of it

* shrine is a "file attachment toolkit for ruby". It is incredibly flexible and customizable, but can sometimes feel like a pile of legos dumped on the floor you have to put together. Additionally, choices you make in one area of shrine attachment handling can interact with other areas, it can be hard to get it all working well together. So kithe provides a [shrine uploader](https://twin.github.io/better-file-uploads-with-shrine-uploader/) (the part of shrine with logic for adding files) that makes a lot of choices for the intended shrine use cases, and also adds some custom kithe plugins targetted at our choices and use cases: [Kithe::AssetUploader](../app/uploaders/kithe/asset_uploader.rb)

* One fundamental shrine concept is the two-stage storage process. All shrine attachments have a "cache" storage location which is used for files that have not yet been permanently saved, and a "store" storage location which files are moved to once the model they are attached to (in this case a Kithe::Asset) has had the attachment succesfully saved and committed to the database. Shrine uses the term "promotion" for the process of moving a file from "cache" to "store". In our case, we also do most metadata extraction during promotion -- and typically do promotion in a background ActiveJob.

* The use pattern we are focusing on and think is best for a production application includes: 1)  "direct upload" (front-end sends files directly to storage, ideally without involving a Rails worker thread), and 2) Doing any expensive file operations that require reading/writing all bytes (the shrine "promotion" step) of a file in a background ActiveJob.  Together with the first point, this means the back-end app typically doesn't even see the actual file bytes until a background job. We've set up the shrine uploader to give you convenient ways to deal with this somewhat inconvenient situation, such as forcing metadata extraction in "promotion".

* At the time of writing kithe, the "versions" plugin including in shrine for handling derivatives was not, in our opinion, suitable for our needs. So kithe provides it's own custom derivatives implementation. That it can assume certain things about the data model and shrine uploader, makes it somewhat easier for us to give it the features we need for our use cases, including concurrency-safety. See [Kithe Derivatives Guide](./derivatives.md)

<a name="definingStorage"></a>
## Defining your shrine storages

Your app needs to define where files will be stored. In addition to the standard shrine `store` and `cache` locations, if you are using kithe's derivatives implementation, you need a `kithe_derivatives` location. To configure S3 storage for all three locations, you might:

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

## Attaching files

As a shrine attachment, you can attach a `File` object by assigning to the `file` attribute we've used for the attachment. This is most useful in tests or batch processes, there isn't much call for it in interactive production code.

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

Due to a custom shrine plugin kithe includes, you can also attach a file from an arbitrary URL with the special storage key `remote_url`:

```ruby
some_asset.file = { "storage" => "remote_url", "id" => "http://example.org/something.jpg" }
```

You could use this as a way to attach files identified with the front-end from [browse-everything](https://github.com/samvera/browse-everything), without using the back-end of browse-everything. Just use kithe's built-in handling of attaching any `remote_url`.

**Do Note** There's currently no built-in whitelisting, any URL you provide will be streamed and attached. Handle validation in your controller layer if needed, or ask us for a feature.

In all of these hash-assignment cases, whether `cache` or `remote_url`, very little is done on assignment. After you succesfully save the model with the new assignment, "promotion" will be triggered in a background ActiveJob, from an `after_commit` hook, to stream the file from the remote location, extract metadata, and store.

If you've fetched a Kithe::Asset, you can see if it's been promoted yet by checking `#stored?`.

In any case, assignment and save of _new_ file information on an asset should properly handle removing stored bytes from any old attachment, along with any derivatives, in a reliable and concurrency-safe fashion.

<a name="readingFiles"></a>
## Reading files and file info

`some_asset.file` will return a [Shrine::UploadedFile](https://shrinerb.com/rdoc/classes/Shrine/UploadedFile/InstanceMethods.html) object. It is "IO-like", you can read it like you would a file to access the bytestream, streaming bytes from the possibly remote storage. Useful methods include [#stream](https://shrinerb.com/rdoc/classes/Shrine/UploadedFile/InstanceMethods.html#method-i-stream), [#open](https://shrinerb.com/rdoc/classes/Shrine/UploadedFile/InstanceMethods.html#method-i-open), [download](https://shrinerb.com/rdoc/classes/Shrine/UploadedFile/InstanceMethods.html#method-i-download).

You can also access some metadata about the file; many methods are delegated from `Kithe::Asset`, so you can just ask for `asset.size` (filesize in bytes), as well as `#original_filename`, `#content_type`,  `#height`, and `#width`. Most of these metadata fields are only available after "promotion" has occured, you can ask `some_asset.stored?` to see if promotion is complete.

### Delivering bytestreams to browser

You could write a controller action to return the file bytes, similar to what Hyrax does via the .

All kithe shrine uploader classes include the [shrine rack_response plugin](https://github.com/shrinerb/shrine/blob/v2.15.0/doc/plugins/rack_response.md), which makes it fairly straightforward to write a delivery action -- even supporting HTTP "Range" headers.  It should stream the bytes directly from your remote storage (eg S3); however, there can be some [difficulties in making sure Rails is streaming and not buffering](https://github.com/rails/rails/issues/18714#issuecomment-96204444).  And even in the best case, you are still keeping a Rails request worker busy for at least as long as it takes to stream the bytes from the remote storage.

Alternately, you can get a URL directly to the asset at whatever storage location, with `an_asset.file.url` -- a method on the Shrine::UploadedFile, which is forwarded to the relevant Shrine::Storage class.

For `Shrine::Storage::FileSystem`-stored files, if they are all public and need no authorization, and you store files in `./public`, that could work seamlessly.

If your files are stored on S3, there are some additional arguments that can be given to `asset.file.url`, and you can get either S3 "public" or [signed](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-signed-urls.html) URLs.

If you created your `Shrine::Storage::S3` with `public: true`, causing all files to get public-read ACLs, [#url](https://shrinerb.com/rdoc/classes/Shrine/Storage/S3.html#method-i-url) will simply return a standard public URL, great.

Otherwise, `#url` will return a unique signed-url, which provides time-limited access to even a  non-public file. You can pass `public: true` (or false) to specifically ask for a public or signed URL. You can also pass additional options as suitable for [Aws::S3::Object#presigned_url](http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#presigned_url-instance_method) or [Aws::S3::Object#public_url](http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#public_url-instance_method), to control expiration time, instruct S3 to deliver response with certain headers like Content-Disposition, etc.

S3 signed URLs are nice for providing access to non-public resources, but they can introduce problems with HTTP cacheability, since generally every response will have a unique S3 signed URL delivered for a given resource. Additionally, _generating_ a signed S3 URL _may_ take enough CPU time that it becomes problematic with very many on a page. You may want to include URLs on pages that point to internal app controller actions, which then redirect to an S3 url (or deliver the bytes directly).

There are different trade-offs with different file delivery mechanisms, and we haven't quite figured out the best for our usage patterns. Kithe (via shrine) aims to give you the tools to build whatever works for you at any given time.

## The promotion flow, and controlling inline vs background ActiveJob execution

After you save a Kithe::Asset where you've _changed_ the `file` attachment, shrine will trigger "promotion" in an ActiveRecord `after_commit` hook. We use the shrine [backgrounding](https://github.com/shrinerb/shrine/blob/master/doc/plugins/backgrounding.md) plugin to make this, by default, happen in an ActiveJob.

We also make sure the Kithe::AssetUploader metadata extraction happens at the beginning of the promotion phase (ordinarily in the bg ActiveJob), since we are planning for a direct-upload use case where the back-end doesn't have access to the file until promotion, and we want to do expensive metadata extraction in the bg.

After the shrine promotion is complete, more custom kithe functionality will, by default, kick off an additional ActiveJob to create any default derivative definitions. (see [Derivatives Guide](./derivatives.md))

Kithe adds functionality to let you hook your own callbacks into the promotion process, and also control whether these steps happen via backgrounding, or inline, or are disabled. We call this feature "promotion_directives". It's a bit messy, but is the best thing I could come up with for now to control backgrounding of a multi-background-job process, and seems to be working out.

If you'd like to save an Asset, but disable the promotion step entirely, before saving set a promotion directive:

```ruby
asset.set_promotion_directives(promote: false)
asset.save!
```

Promotion won't occur at all, so you will never get metadata extracted and file copied to `store` location. If you want to promote yourself later, `Kithe::Asset#promote` is available, just:  `asset.promote`.

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

You can also set promotion_directives globally, on a class attribute of `Kithe::Asset` or any subclass. This can be useful for a batch process where you don't want to fill up your job queues. You could use it to just change your app behavior globally, although that's not recommended.

```ruby
# Globally in this entire process, do promotion and derivatives inline
Kithe::Asset.promotion_directives = { promote: :inline, create_derivatives: :inline }
```

<a name='callbacks'></a>
## Promotion callbacks

As another kithe customization, we have implemented an [ActiveRecord callback](https://api.rubyonrails.org/classes/ActiveRecord/Callbacks.html) on Kithe::Asset, for the `promote` event. Especially since promotion usually happens in the background, it can be useful to be able to hook into it.

In your local Kithe::Asset subclass you can define before, after, or around callbacks.

```ruby
class LocalAsset < Kithe::Asset
  before_promote do
    if want_to_cancel?(self)
      # consistent with other AR callbacks, throw :abort will cancel
      # the promotion process.
      throw :abort
    end
  end

  after_promote :some_method_in_your_class, if: ->(model) {  }
```

At the point the before callback is triggered, metadata has already been extracted, and you have access to it. If you abort the promotion, the extracted metadata will not be saved, and promotion won't happen. It's up to you and your app to log or store or notify that this happened in whatever way makes sense, kithe data structures won't make it clear why promotion didn't happen.

If you want to consult any promotion_directives in a callback, you can look at `self.file_attacher.promotion_directives`.

If you want to _suppress all promotion callbacks_, you can set a promotion directive: `asset.set_promotion_directives(skip_callbacks: true)`. This would mean default derivative generation wouldn't happen either.

In the future we might want to explore a different architecture, perhaps based [around event-based/pub-sub](https://zorbash.com/post/the-10-minute-rails-pubsub/) for promotion and derivatives.

## Validation?

The built-in [shrine validation architecture](https://github.com/shrinerb/shrine/blob/master/doc/validation.md#readme) is targetted at interactive forms, and doesn't make a lot of sense in our scenario where  where metadata extraction and promotion happen in the background.

Plus, you don't have an easy way to add your own validations to the `Kithe::AssetUploader`.

We haven't totally worked out what makes sense in kithe. One possibility would be using a before_promotion callback as above, to cancel promotion based on metadata, and record that (with error messages?) somewhere in your app, for presentation later.

## Custom Metadata?

Normally in shrine, [you define metadata extraction routines](https://github.com/shrinerb/shrine/blob/v2.15.0/doc/metadata.md#readme) inside of your uploader class.

However, Kithe gives you a pre-build uploader, `Kithe::AssetUploader`. It does define some standard metadata extraction, including: MD5, SHA1, and SHA512 fingerprints (SHA512 is recommended for use, the others are for legacy comparisons); mime/content-type sniffed from "magic bytes" (does not trust client statement); height and width for image types; and filesize.

It's not totally clear what pattern we want to establish for local metadata, it remains to be worked out. You could use perhaps hook into promotion callbacks, or we could provide additional API, or we may need to allow a custom uploader. (See below).

## Customize the shrine Uploader?

Do we want to provide a way for you to specify a local custom uploader class to be used with `Kithe::Asset`? Maybe. Remains to be worked out. A custom local uploader might sub-class `Kithe::AssetUploader` and add functionality (shrine supports uploader sub-classes), or might re-use the kithe-provided shrine uploader plugins for kithe compatibility.

## list of all custom kithe plugins

* [kithe_accept_remote_url](../lib/shrine/plugins/kithe_accept_remote_url.rb) Allows a shrine storage that accepts remote urls as "cache" to be promoted, including supporting specifying custom headers (such as auth) to be sent to remote server. **Warning** will accept any remote_url, no whitelisting at present.
  * [kithe_multi_cache](../lib/shrine/plugins/kithe_accept_remote_url.rb) Allows multiple "cache" storages o a shrine uploader, so `kithe_accept_remote_url` can be supported simultaneously and in addition to a normal cache storage.

* [kithe_storage_location](../lib/shrine/plugins/kithe_storage_location.rb) Sets path in "store" storage (such as S3) to be "asset/{asset uuid}/{random unique id}". (Future: Should use a SHA checksum for final component instead?)

* [kithe_promotion_hooks](../lib/shrine/plugins/kithe_storage_location.rb). Customization of the promotion process to:
  * ensure metadata is extracted at beginning of promotion
  * support `promotion` hooks in the Kithe::Asset ActiveRecord class.
  * support `promotion_directives`, ensuring when set, they are sent and restored in the promotion ActiveJob, so they are still present to take effect there.
