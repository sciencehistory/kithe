# Kithe Derivatives

Kithe adds some additional features on top of Shrine 3.0+'s out of the box derivative feature. Shrine's derivative feature is very flexible and powerful, but also can be hard to get right. It would be a good idea to review shrine derivatives documentation:

* https://shrinerb.com/docs/plugins/derivatives
* https://shrinerb.com/docs/processing

Kithe adds automatic derivative creation (only of `kithe_derivatives` processor) after promotion; and additional methods for defining and managing derivatives, including reliable concurrency-safe
derivatives modification.

You don't have to use kithe's value-added derivative features, but we recommend it.

The `Kithe::AssetUploader` is also configured to store all derivatives in shrine storage `kithe_derivatives`,  rather than the same storage as original files. It's up to your app to define where `kithe_derivatives` points to; it could be the same location as `store` with a different prefix if you like.

## Creating Derivatives

Shrine provides a way to define derivative processors;  kithe gives you an additional way to define individual derivatives, making it easier to later manage them ((re-)create certain derivative types) without re-writing code. No derivatives are defined by default by kithe.

```ruby
class MyAssetUploader < Kithe::AssetUploader
  Attacher.define_derivative(:thumb_small) do |original_file|
    anything_that_returns_io_like_object(original_file)
  end
end
```

The `original_file` block parameter is a ruby `File` object, which is already open for reading. Since it's a File object, you can ask it for it's `#path` if you need a local file path for whatever transformation tool you are using.

The object returned does not need to be a `File` object, it can be any [IO or IO-like](https://github.com/shrinerb/shrine#io-abstraction) object. If you return a ruby `File` or `Tempfile` object, kithe will take care of cleaning the file up from the local file system. You are responsible for cleaning up any intermediate files, ruby stdlib [Tempfile](https://docs.ruby-lang.org/en/2.5.0/Tempfile.html) and [Dir.mktmpdir](https://docs.ruby-lang.org/en/2.5.0/Dir.html#method-c-mktmpdir) may be useful.

The kithe derivative definition functionality is provided by shrine plugins [kithe_derivative_definitions](../lib/shrine/plugins/kithe_derivative_definitions.rb).

Once defined, you could create them using standard shrine methods, with the `kithe_derivatives` processor.

```ruby
# NOT RECOMMENDED
asset.file_attacher.create_derivatives(:kithe_derivatives)
```

But we recommend you use kithe's concurrency-safe derivative modification methods instead, below.

### The kithe_derivatives processor: Custom lifecycle

All derivatives defined this way will be created by a shrine derivatives processor called `kithe_derivatives`.

This shrine derivatives processor is ordinarily automatically executed by kithe _after_ file promotion, in a separate background job. See [Attachment Lifecycle](./file_handing.md#attachmentLifecycle) and [Customizing the ingest lifecycle](./file_handing.md#customizingLifecycle) in the [File Handling Guide](./file_handing.md)

### Kithe-provided derivative-creation tools

While you can write whatever logic you want as a derivative definition, kithe currently packages two (more in the future) services:
    * Kithe::VipsCliImageToJpeg, which can create a resized JPG from an image input, using a shell out to the `vips` and `vipsthumbnail` command-line tools.
    * Kithe::FfmpegTransformer, which creates audio files from any audio file original, using a shell out to the `ffmpeg` command-line tool.

```ruby
class Asset < Kithe::Asset
  define_derivative(:download_small) do |original_file|
    Kithe::VipsCliImageToJpeg.new(max_width: 500).call(original_file)
  end
end
```

If you pass `thumbnail_mode: true` when instantiating Kithe::VipsCliImageToJpeg, in addition to resizing it will apply additional best-practice transformations to minimize file size when displaying in a browser, such as: translate to sRGB color space, and strip internal JPG metadata and color profile information.

```ruby
class Asset < Kithe::Asset
  define_derivative(:thumb_small) do |original_file|
    Kithe::VipsCliImageToJpeg.new(max_width: 500, thumbnail_mode: true).call(original_file)
  end
end
```
Some audio examples using `Kithe::FfmpegTransformer`.

```ruby
# Create a stereo 128k mp3 derivative. output_suffix is the only mandatory argument.
define_derivative('mp3', content_type: "audio") do |original_file|
  Kithe::FfmpegTransformer.new(bitrate: '128k', output_suffix: 'mp3').call(original_file)
end

# A mono webm file at only 64k:
define_derivative('webm', content_type: "audio") do |original_file|
  Kithe::FfmpegTransformer.new(bitrate: '64k', force_mono: true, output_suffix: 'webm').call(original_file)
end

# libopus is used by default for webm conversions, but you could specify another codec:
define_derivative('webm', content_type: "audio") do |original_file|
  Kithe::FfmpegTransformer.new(output_suffix: 'webm', audio_codec: 'libopencore-amrwb').call(original_file)
end
```

### Definining derivatives for specific original content-type

If you'd like to have a definition that only is invoked for certain content-types, you can supply a `content_type` arg with a content-type like `"image/jpeg"`, or just the primary type like `"image"`.

```ruby
class Asset < Kithe::Asset
  define_derivative(:thumb_small, content_type: "application/pdf") do |original_file|
    anything_that_returns_io_like_object(original_file)
  end
end
```

If multiple derivatives definitions are provided for the same key, only the _most specific_ will be run (content-type with subtype, content-type with primary type only, definition with no content-type).

If you need more complicated conditional logic, you can just put it in a single derivative definition. If your block takes a `record` keyword argument, you can get the Kithe::Asset to query and branch upon.

```ruby
class Asset < Kithe::Asset
  define_derivative(:complicated) do |original_file, record:|
    if record.content_type == "application/x-my-thing"
      return io_object
    elsif record.size < 2.megabytes
      return something_else
    end
    # okay to sometimes return nil
  end
end
```


### Definining non-default derivatives

The derivative defined above will be automatically created after Asset promotion. If you'd like to create a derivative definition that will not be automatically created, but can be invoked manually with `create_derivatives` (see below), you can define it with `default_create: false`.

```ruby
class Asset < Kithe::Asset
  define_derivative(:weird_derivative, create_default: false) do |original_file|
    anything_that_returns_io_like_object(original_file)
  end
end
```

## Manually triggering derivative definitions to be created

You can always call `Kithe::Asset#create_derivatives` on any asset to trigger creation from derivative definitions. This is the same method ordinarily used automatically. It will always be executed inline without triggering a BG job, if you want concurrency you can wrap it yourself.

It will by default only execute the `kithe_derivatives` processor; derivative definitions defined using kithe's `define_derivative` function above.

If derivatives already exist, they will ordinarily be re-created and overwritten (in a concurrency-safe way).

You can give the `kithe_derivatives` processor additional arguments to limit what derivative definitions get created. `lazy:true` will only create derivatives that don't already exist, useful for filling in derivatives for a newly added definition. `only` and `except` can also be used to specify a subset of derivative definitions.

```ruby
# (Re-)create all derivatives from default definitions, perhaps becuase you've
# changed the definitions
some_asset.create_derivatives

# Create all derivatives from default definitions, only if they don't already exist
some_asset.create_derivatives(lazy:true)

# Create specific named derivatives, which may include ones defined with `create_default: false`.
some_asset.create_derivatives(only: [:thumb_small, :thumb_medium])
```

Derivative definitions not applicable to the content-type of an asset original will simply be skipped. Derivative definitions defined as `create_default: false`, will only be used if included in an `only` argument.

## Rake tasks

Kithe gives you some rake tasks for creating derivatives in bulk. The tasks will not use ActiveJob, but create all derivatives inline, with a nice progress bar.

`./bin/rake kithe:create_derivatives:lazy_defaults` will go through all assets, and create derivatives for all derivative definitions you have configured, only for those derivative keys that don't yet exist. This is useful if you've added a new derivative definition, or otherwise want to ensure all derivatives are created.

`./bin/rake kithe:create_derivatives` has more flexibility specify derivative definitions to create and other parameters, including forcefully re-creating (if your definitions have changed). More example docs could be useful, but for now try running `./bin/rake kithe:create_derivatives -- -h`

## Manually modifying derivatives

You may want to add and replace derivatives without a definition, or to delete existing derivatives. Shrine gives you tools to do this, but it can be a bit tricky to do it in a concurrency-safe way (if multiple processes are editing derivatives at once), and to ensure there are no leftover temporary files on disk even in error conditions. (See https://discourse.shrinerb.com/t/derivatives-and-persistence/230 and https://github.com/shrinerb/shrine/issues/468)

This functionality is provided by the [kithe_peristed_derivatives](../lib/shrine/plugins/kithe_persisted_derivatives.rb) Shrine plugin. In addition to the `create_derivatives` method mentioned, other concurrency-safe value-added methods are provided by kithe.  For instance, it is safe to have two different background jobs using `create_derivatives` or `update_derivatives` at the same time with different keys -- all keys will get succesfully added.

You can use all of these methods with derivatives created by standard shrine derivatives processors, not just the `kithe_derivatives` processor.

`Asset#remove_derivative` will delete derivatives, making sure the actual files are cleaned up from storage, and save the `Asset` model reflecting the change.

```ruby
asset.remove_derivative(:thumb_small)
asset.remove_derivative(:thumb_small, :thumb_large)
```

You can add (or replace) derivatives, as a specified file, with `Asset.update_derivative` or `update_derivatives`.

```ruby
asset.update_derivative(:thumb_small, File.open("something"))
asset.update_derivatives({ thumb_large: any_io_object)
```

Files passed in are assumed to be temporary and deleted, you can pass `delete:false` to disable this.

You can in fact pass in any options recognized by [shrine add_derivatives](https://shrinerb.com/docs/plugins/derivatives#adding-derivatives), including custom storage location and storage upload options; as well as specified metadata to be attached to derivative.


## Accessing derivatives

You access derivatives in the normal shrine way, they are just shrine derivatives once created, on the `file` attachment.

```ruby
asset.file_derivatives # a hash of derivative keys and Shrine::UploadedFile objects
asset.file_derivatives.has_key?(:thumb_small) # do we have one?
asset.file_derivatives[:thumb_small].exists? # is it in place on storage as expected?
asset.file(:thumb_small) # Shrine::Uploaded file for :thumb_small derivative
asset.file_url(:thumb_small) # one way to get derivative url
# can pass usual shrine options, in this case for S3 storage...
asset.file_url(:thumb_small, public: false, expires_in: time)
```

Derivatives also have some basic metadata calculated and available.

```ruby
asset.file_derivatives[:thumb_small].content_type
asset.file_derivatives[:thumb_small].size # in bytes

# for images only:
asset.file_derivatives[:thumb_small].width
asset.file_derivatives[:thumb_small].height

asset.file_derivatives[:thumb_small].metadata # hash with string keys
```

You can add more metadata extractors for derivatives using standard shrine techniques.


See guidance for delivering files to browser in [File Handling Guide](./file_handling.md#readingFiles), it all applies to derivatives as well.
