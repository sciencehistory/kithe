# Kithe Derivatives

Kithe adds some additional features on top of Shrine 3.0+'s out of the box derivative feature. Shrine's derivative feature is very flexible and powerful, but can be a lot of pieces to get working properly for you. Kithe tries to set things up to work out of the box with a good setup for a digital collections/repository app, while still allowing you the full range of shrine powers.

It would be a good idea to review shrine derivatives documentation:

* https://shrinerb.com/docs/plugins/derivatives
* https://shrinerb.com/docs/processing

Kithe adds: automatic derivative creation after promotion (only of kithe-controlled derivatives, more below); a custom way of defining derivatives to allow more management options; reliable concurrency-safe derivatives modification.

You don't have to use kithe's value-added derivative features, but we recommend it.

The `Kithe::AssetUploader` is also configured to store all derivatives in shrine storage `kithe_derivatives`,  rather than the same storage as original files. It's up to your app to define where `kithe_derivatives` points to; it could be the same location as `store` with a different prefix if you like.

## Creating Derivatives

Shrine provides [a way to define derivative processors](https://shrinerb.com/docs/plugins/derivatives#creating-derivatives);  kithe gives you an additional way to define individual derivatives, making it easier to later manage them — (re-)create certain derivative types — re-using your definitions.

```ruby
class MyAssetUploader < Kithe::AssetUploader
  Attacher.define_derivative(:thumb_small) do |original_file|
    anything_that_returns_io_like_object(original_file)
  end
end
```

The `original_file` block parameter is a ruby `File` object, which is already open for reading. Since it's a File object, you can ask it for it's `#path` if you need a local file path for whatever transformation tool you are using.

The object returned does not need to be a `File` object, it can be any [IO or IO-like](https://github.com/shrinerb/shrine#io-abstraction) object. If you return a ruby `File` or `Tempfile` object, kithe will take care of cleaning the file up from the local file system. You are responsible for cleaning up any intermediate files, ruby stdlib [Tempfile](https://docs.ruby-lang.org/en/2.5.0/Tempfile.html) and [Dir.mktmpdir](https://docs.ruby-lang.org/en/2.5.0/Dir.html#method-c-mktmpdir) may be useful.

The kithe derivative definition functionality comes from a kithe plugin to shrine, [kithe_derivative_definitions](../lib/shrine/plugins/kithe_derivative_definitions.rb).

These kithe derivative definitions will be created by a registered standard shrine derivatives processor with key `kithe_derivatives`, and could be addressed as such with standard shrine functionality:

```ruby
# NOT RECOMMENDED
asset.file_attacher.create_derivatives(:kithe_derivatives)
```

But we don't recommend this. Normally, kithe's asset lifecycle will automatically create derivatives after promotion. (See [Attachment Lifecycle](./file_handling.md#attachmentLifecycle) and [Customizing the ingest lifecycle](./file_handling.md#customizingLifecycle) in the [File Handling Guide](./file_handling.md))

If you do need to manually trigger derivative creation, you can use kithe's concurrency-safe derivative modification methods, such as:


```ruby
asset.create_derivatives
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

If you need more complicated conditional logic, you can just put it in a single derivative definition. If your block takes an `attacher` keyword argument, you will get a `Shrine::Attacher` subclass instance, from which you can call `attacher.record` to get the original Asset model object, or `attacher.file` to get the original file as a `Shrine::UploadedFile` subclass instance.

```ruby
class Asset < Kithe::Asset
  define_derivative(:complicated) do |original_file, attacher:|
    if attacher.file.content_type == "application/x-my-thing"
      return io_object
    elsif attacher.file.size < 2.megabytes
      return something_else
    end
    # okay to sometimes return nil
  end
end
```

### custom conditional derivative creation

If your define_derivative block just returns nil, no derivative will be created. This is a way
to write whatever logic you want for whether to create a derivative.

```ruby
define_derivative(:maybe) do |original_file, attacher:|
  if should_create_maybe_deriv?(attacher.record)
    make_maybe_deriv(original_file)
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


### Kithe-provided derivative-creation tools

While you can write whatever logic you want as a derivative definition, kithe currently packages a few services:

#### Kithe::VipsCliImageToJpeg

Which can create a resized JPG from an image input, using a shell out to the `vips` and `vipsthumbnail` command-line tools.


```ruby
class Asset < Kithe::Asset
  define_derivative(:download_small) do |original_file, add_metadata:|
    Kithe::VipsCliImageToJpeg.new(max_width: 500).call(original_file, add_metadata: add_metadata)
  end
end
```

If you pass `thumbnail_mode: true` when instantiating Kithe::VipsCliImageToJpeg, in addition to resizing it will apply additional best-practice transformations to minimize file size when displaying in a browser, such as: translate to sRGB color space, and strip internal JPG metadata and color profile information.

```ruby
class Asset < Kithe::Asset
  define_derivative(:thumb_small, content_type: "image") do |original_file, add_metadata:|
    Kithe::VipsCliImageToJpeg.new(max_width: 500, thumbnail_mode: true).call(original_file, add_metadata: add_metadata)
  end
end
```

#### Kithe::FfmpegTransformer

Which creates audio files from any audio file original, using a shell out to the `ffmpeg` command-line tool.


```ruby
# Create a stereo 128k mp3 derivative. output_suffix is the only mandatory argument.
define_derivative('mp3', content_type: "audio") do |original_file, add_metadata:|
  Kithe::FfmpegTransformer.new(bitrate: '128k', output_suffix: 'mp3').call(original_file, add_metadata: add_metadata)
end

# A mono webm file at only 64k:
define_derivative('webm', content_type: "audio") do |original_file, add_metadata:|
  Kithe::FfmpegTransformer.new(bitrate: '64k', force_mono: true, output_suffix: 'webm').call(original_file, add_metadata: add_metadata)
end

# libopus is used by default for webm conversions, but you could specify another codec:
define_derivative('webm', content_type: "audio") do |original_file, add_metadata:|
  Kithe::FfmpegTransformer.new(output_suffix: 'webm', audio_codec: 'libopencore-amrwb').call(original_file, add_metadata: add_metadata)
end
```

#### Kithe::FfmpegExtractJpg

Can extract a thumbnail from a video file, via ffmpeg. One handy thing about it is it can use
ffmpeg's ability to extract from a *remote* URL without downloading the whole file. This can be
convenient for performance/efficiency if you store your originals on cloud storage.

However, to take advantage of this feature, avoiding a download, you'd have to write some more
complex code. Same if you want to produce multiple resolution thumbnails. This isn't yet fully documented, but be aware of the existence of this service.

```ruby
image_tmp_file = Kithe::FfmpegExtractJpg.new(start_seconds: start_seconds).call(original, add_metadata: add_metadata)
```

## Manually triggering creaton of derivatives from definitions

You can always call `Kithe::Asset#create_derivatives` on any asset to trigger the `kithe_derivatives` processor in a concurrency-safe way, creating all derivatives you defined with kithe `define_derivative` as above. This is the same method ordinarily used by kithe for automatic lifecycle derivarive creation. When you call it manually, it will always be executed inline without triggering a BG job, if you want concurrency you can wrap it yourself.

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


## More complex derivative handling with a shrine processor

The Kithe `define_derivative` lets you define a block to create a single derivative, that will have a local file passed to it.

If you need more control, you can use a [standard shrine derivative processor](https://shrinerb.com/docs/plugins/derivatives). You might do this for higher performance implementations where you avoid downloading a local file, or want to create several derivatives in one block for performance reasons.

You can register your shrine derivatives processor to be used by kithe lifecycle control (automatic creation, and inline/background control) by adding to an Attacher property in your custom uploader.

```ruby
class AssetUploader < Kithe::uploader
  # kithe property
  Attacher.kithe_include_derivatives_processors += [:my_custom_processor]

  # pure shrine derivatives processor
  Attacher.derivatives(:my_custom_processor, download: false) do |original, **options|
    if process_any_kithe_derivative?([:huge_thumb, :tiny_thumb], **options)
      return_derivatives = {}

      if process_kithe_derivative?(:huge_thumb, **options)
        return_derivatives[:huge_thumb] = create_something_huge
      end

      if process_kithe_derivative?(:tny_thumb, **options)
        return_derivatives[:tiny_thumb] = create_something_tiny
      end

      return_derivatives
    else
      {}
    end
  end
end
```

Kithe provides those methods `process_any_kithe_derivative?` and `process_kithe_derivative?` that
can be used to implement respect for :only, :except, and :lazy arguments. When you provide your
own shrine derivative processor you need to implement support for only/except/lazy yourself, but
these methods can be used to do it easily.

## Rake tasks

Kithe gives you some rake tasks for creating derivatives in bulk. The tasks will not use ActiveJob, but create all derivatives inline, with a nice progress bar.

`./bin/rake kithe:create_derivatives:lazy_defaults` will go through all assets, and create derivatives for all derivative definitions you have configured, only for those derivative keys that don't yet exist. This is useful if you've added a new derivative definition, or otherwise want to ensure all derivatives are created.

`./bin/rake kithe:create_derivatives` has more flexibility specify derivative definitions to create and other parameters, including forcefully re-creating (if your definitions have changed). It also has the ability to create background jobs (ActiveJob) per asset for actual creation work.

Run `./bin/rake kithe:create_derivatives -- -h` for some argument info. (Note the `--` separator argument).

    # IDs are friendlier_id
    ./bin/rake kithe:create_derivatives --work-id=tnroyhj,x7kpj2z

    # Specify specific derivatives, and/or lazy creation (only if not already present)
    ./bin/rake kithe:create_derivatives --lazy --derivative=my_derivative_name,other

    # Specify create per-asset bg jobs for creation
    ./bin/rake kithe:create_derivatives --lazy --bg

    # Or specify specific ActiveJob queue too
    ./bin/rake kithe:create_derivatives --lazy --derivative=some_name --bg=queue_name

## Manually modifying derivatives

You may want to add and replace derivatives without a definition, or to delete existing derivatives. Shrine gives you tools to do this, but it can be a bit tricky to do it in a concurrency-safe way (if multiple processes are editing derivatives at once), and to ensure there are no leftover temporary files on disk even in error conditions. (See https://discourse.shrinerb.com/t/derivatives-and-persistence/230 and https://github.com/shrinerb/shrine/issues/468)

This functionality is provided by the [kithe_peristed_derivatives](../lib/shrine/plugins/kithe_persisted_derivatives.rb) Shrine plugin. In addition to the `create_derivatives` method mentioned, other concurrency-safe value-added methods are provided by kithe.  For instance, it is safe to have two different background jobs using `create_derivatives` or `update_derivatives` at the same time with different keys -- all keys will get succesfully added.

You can use all of these methods with derivatives created by standard shrine derivatives processors, not just the `kithe_derivatives` processor.

`Asset#remove_derivatives` will delete derivatives, making sure the actual files are cleaned up from storage, and save the `Asset` model reflecting the change.

```ruby
asset.remove_derivatives(:thumb_small)
asset.remove_derivatives(:thumb_small, :thumb_large)
```

You can add (or replace) derivatives, as a specified file, with `Asset.update_derivative` or `update_derivatives`.

```ruby
asset.update_derivative(:thumb_small, File.open("something"))
asset.update_derivatives({ thumb_large: any_io_object)
```

Files passed in are assumed to be temporary and deleted, you can pass `delete:false` to disable this.

You can in fact pass in any options recognized by [shrine add_derivatives](https://shrinerb.com/docs/plugins/derivatives#adding-derivatives), including custom storage location and storage upload options; as well as specified metadata to be attached to derivative.


## Accessing derivatives

You access derivatives in the [normal shrine way](https://shrinerb.com/docs/plugins/derivatives#retrieving-derivatives), they are just shrine derivatives once created, on the `file` attachment.

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
