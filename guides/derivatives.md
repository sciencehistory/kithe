# Kithe Derivatives

Kithe has a custom implementation of derivatives, built on shrine, but not using the existing shrine plugins related to derivatives (such as shrine "versions"). At the time of this writing, existing shrine plugins were not suitable for us. By being able to assume ActiveRecord (rather than shrine's agnosticism), our particular Kithe::Asset model, and an uploader that takes SHA fingerprints, we are able to provide a derivatives framework to conveniently meet expected use cases.

The Kithe Derivatives model is an ActiveRecord model -- each derivative is stored as a row in a  `kithe_derivatives` table, via the Kithe::Derivatives model.  A Kithe::Asset `has_many` Kithe::Derivatives, which each `belong_to` a Kithe::Asset, using ordinary ActiveRecord associations.

    Kithe::Asset <-->> Kithe::Derivatives

Each Kithe::Derivative has a shrine attachment in the `file` attribute, and a string `key` identifying the type of derivative, such as `thumb_small`.

## Definining derivatives

No derivatives are automatically defined/created by Kithe. You can define derivative definitions on your local Kithe::Asset subclass(es).

```ruby
class Asset < Kithe::Asset
  define_derivative(:thumb_small) do |original_file|
    anything_that_returns_io_like_object(original_file)
  end
end
```

The `original_file` block parameter is a ruby `File` object, which is already open for reading. Since it's a File object, you can ask it for it's `#path` if you need a local file path for whatever transformation tool you are using.

The object returned does not need to be a `File` object, it can be any [IO or IO-like](https://github.com/shrinerb/shrine#io-abstraction) object. If you return a ruby `File` or `Tempfile` object, kithe will take care of cleaning the file up from the local file system. You are responsible for cleaning up any intermediate files, ruby stdlib [Tempfile](https://docs.ruby-lang.org/en/2.5.0/Tempfile.html) and [Dir.mktmpdir](https://docs.ruby-lang.org/en/2.5.0/Dir.html#method-c-mktmpdir) may be useful.

### Kithe-provided derivative-creation tools

While you can write whatever logic you want as a derivative definition, kithe at the moment packages one (more in the future) service, Kithe::VipsCliImageToJpeg, which can create a resized JPG from an image input, using a shell out to the `vips` and `vipsthumbnail` command-line tools.

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

### Definining derivatives based on original content-type

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

### Specifying a derivative-specific shrine storage

Derivatives are by default stored to the Shrine storage set for `kithe_derivatives`. If you'd
like to have certain derivatives stored elsewhere, you can supply a `storage_key` arg specifying a [shrine storage you have defined](./file_handling.md#definingStorage).

```ruby
class Asset < Kithe::Asset
  define_derivative(:download_huge, storage_key: :some_shrine_storage) do |original_file|
    anything_that_returns_io_like_object(original_file)
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

## Derivatives in background

The default derivatives are created automatically in the shrine promotion step.

If you have an asset, and want to know if the default derivatives have been created yet, you can look at `asset.deriatives_created?`.  As the background process makes a mark in the asset shrine metadata when it's complete.

For more info on disabling default derivative generation or forcing it to be inline, see the [File Handling Guide](./file_handling#callbacks).

## Manually triggering derivative definitions to be created

You can always call `Kithe::Asset#create_derivatives` on any asset to trigger creation from derivative definitions. This is the same method ordinarily used automatically. It will always be executed inline without triggering a BG job, if you want concurrency you can wrap it yourself.

```ruby
# (Re-)create all derivatives from default definitions, perhaps becuase you've
# changed the definitions
some_asset.create_derivatives

# Create all derivatives from default definitions, only if they don't already exist
some_asset.create_derivatives(lazy:true)

# Create specific named derivatives, which may include ones defined with `create_default: false`.
some_asset.create_derivatives(only: [:thumb_small, :thumb_medium])
```

## Rake tasks

Kithe gives you some rake tasks for creating derivatives. The tasks will not use ActiveJob, but create all derivatives inline, with a nice progress bar.

`./bin/rake kithe:create_derivatives:lazy_defaults` will go through all assets, and create derivatives for all derivative definitions you have configured, only for those derivative keys that don't yet exist. This is useful if you've added a new derivative definition, or otherwise want to ensure all derivatives are created. It will also set the flag for `asset.derivatives_created?` on every asset, after ensuring all derivatives are created.

`./bin/rake kithe:create_derivatives` has more flexibility specify derivative definitions to create and other parameters, including forcefully re-creating (if your definitions have changed). More example docs could be useful, but for now try running `./bin/rake kithe:create_derivatives -- -h`

## Concurrency contract

Especially with derivatives being created in the background, one could imagine cases where a two derivatives are attached with the same key; a derivative is attached to an Asset which has changed to a new original such that the derivative is no longer valid; "orphaned derivatives" exist for an asset that has been deleted.

Kithe derivatives logic makes sure that only one derivative for a given key on a particular asset exists; that an attached derivative found in the db always matches the original it's related to in the db; and that derivatives are properly deleted (both the ActiveRecord model and the bytestream in whatever storage) so can never become orphaned. The logic leans on existing shrine logic, uses database features like transactions and locks, and makes use of the calculated SHA512 checksum in the db to make sure derivatives match originals.

If this isn't happening, it's a bug.

This guarantee applies for automatic derivative creation, manual use of `#create_derivatives`, as well as `update_derivative` (below).

The Kithe::CreateDerivativesJob should be idempotent, and safe to re-run on errors.

## Manually adding derivative file without a definition

If you'd like to set a derivative to an arbitrary bytestream without using the derivative definitions feature, you can use `update_derivative`.

```ruby
asset.update_derivative(:derivative_key, io_object)
```

You can also specify a shrine storage key to store under, and/or any custom metadata you'd like attached to the derivative.

```ruby
asset.update_derivative(:derivative_key, io_object,
  storage_key: :some_shrine_storage,
  metadata: {
    "some_metadata_key" => "some_value"
  }
)
```

Using the `update_derivative` method, you are protected by the concurrency guarantees above. If a derivative with the specified key already existed, it will be properly replaced (and bytestream in storage will be properly cleaned up).

## Accessing derivatives

If you have an asset, you can simply look at it's `derivatives` association of Kithe::Derivatives.

As a convenenience, you can also use `derivative_for` to find a Kithe::Derivative matching a certain key: `asset.derivative_for(:thumb_small)`.

That will cause a load of the ActiveRecord `derivatives` association if it isn't already loaded. ActiveRecord eager-loading is encouraged to avoid "n+1 queries", see [Representative Guide](./work_representative.md#eagerLoading)

Derivatives have some basic metadata calculated and available.

```ruby
derivative = asset.derivative_for(:thumb_small)
derivative.content_type
derivative.size # in bytes
derivative.height, derivative.width # for images only
```

Additional metadata can be assigned when using `update_derivative`. There isn't current API to assign/define additional metadata using derivative definitions.

A Kithe::Derivative object has a shrine attachment in `derivative.file`, and delegates `derivative.url` to `derivative.file.url`.

See guidance for delivering files to browser in [File Handling Guide](./file_handling.md#readingFiles), it all applies to derivatives as well.

## Deleting derivative

You can just delete the Kithe::Derivative instance through ordinary ActiveRecord, there are no concurrency concerns. As a convenience, you can also do:

```ruby
asset.remove_derivative(:thumb_small)
```

