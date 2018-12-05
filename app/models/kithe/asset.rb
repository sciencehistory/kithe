class Kithe::Asset < Kithe::Model
  has_many :derivatives, dependent: :destroy # dependent destroy to get shrine destroy logic for assets

  # TODO we may need a way for local app to provide custom uploader class.
  # or just override at ./kithe/asset_uploader.rb locally?
  include Kithe::AssetUploader::Attachment.new(:file)

  # for convenience, let's delegate some things to shrine parts
  delegate :content_type, :original_filename, :size, :height, :width, :page_count,
    :md5, :sha1, :sha512,
    to: :file, allow_nil: true
  delegate :stored?, to: :file_attacher

  after_save :remove_invalid_derivatives

  class_attribute :derivative_definitions, instance_writer: false, default: []

  # Establish a derivative definition that will be used to create a derivative
  # when #create_derivatives is called, for instance automatically after promotion.
  #
  # The most basic definition consists of a derivative key, and a ruby block that
  # takes the original file, transforms it, and returns a ruby File or other
  # (shrine-compatible) IO-like object. It will usually be done inside a custom Asset
  # class definition.
  #
  #     class Asset < Kithe::Asset
  #       define_derivative :thumbnail do |original_file|
  #       end
  #     end
  #
  # The original_file passed in will be a ruby File object that is already open for reading. If
  # you need a local file path for your transformation, just use `original_file.path`.
  #
  # The return value can be any IO-like object. If it is a ruby File or Tempfile,
  # that temporary file will be deleted for you after the derivative has been created. If you
  # have to make any intermediate files, you are responsible for cleaning them up. Ruby stdlib
  # Tempfile and Dir.mktmpdir may be useful.
  #
  # If in order to do your transformation you need additional information about the original,
  # just add a `record:` keyword argument to your block, and the Asset object will be passed in:
  #
  #     define_derivative :thumbnail do |original_file, record:|
  #        record.width, record.height, record.content_type # etc
  #     end
  #
  # Derivatives are normally uploaded to the Shrine storage labeled :kithe_derivatives,
  # but a definition can specify an alternate Shrine storage id. (specified shrine storage key
  # is applied on derivative creation; if you change it with existing derivatives, they should
  # remain, and be accessible, where they were created; there is no built-in solution at present
  # for moving them).
  #
  #     define_derivative :thumbnail, storage_key: :my_thumb_storage do |original| # ...
  #
  # You can also set `default_create: false` if you want a particular definition not to be
  # included in a no-arg `asset.create_derivatives` that is normally triggered on asset creation.
  #
  # And you can set content_type to either a specific type like `image/jpeg` (or array of such) or a general type
  # like `image`, if you want to define a derivative generation routine for only certain types.
  # If multiple blocks for the same key are defined, with different content_type restrictions,
  # the most specific one will be used.  That is, for a JPG, `image/jpeg` beats `image` beats no restriction.
  def self.define_derivative(key, storage_key: :kithe_derivatives, content_type: nil, default_create: true, &block)
    # Make sure we dup the array to handle sub-classes on class_attribute
    self.derivative_definitions = self.derivative_definitions.dup.push(
      DerivativeDefinition.new(
        key: key,
        storage_key: storage_key,
        content_type: content_type,
        default_create: default_create,
        proc: block
      )
    )
  end

  # Create derivatives for every definition added with `define_derivative. Ordinarily
  # will create a definition for every definition that has not been marked `default_create: false`.
  #
  # But you can also pass `only` and/or `except` to customize the list of definitions to be created,
  # possibly including some that are `default_create: false`.
  #
  # create_derivatives should be idempotent. If it has failed having only created some derivatives,
  # you can always just run it again.
  #
  # Will normally re-create derivatives (per existing definitions) even if they already exist,
  # but pass `lazy: false` to skip creating if a derivative with a given key already exists.
  # This will use the asset `derivatives` association, so if you are doing this in bulk for several
  # assets, you should eager-load the derivatives association for efficiency.
  def create_derivatives(only: nil, except: nil, lazy: false)
    DerivativeCreator.new(derivative_definitions, self, only: only, except: except, lazy: lazy).call
  end

  # Adds an associated derivative with key and io bytestream specified.
  # Normally you don't use this, you would define derivatives and use
  # higher-level API to manage them, but this one is used by higher level API.
  #
  # Ensures safe from race conditions under multi-thread/process concurrency, to
  # make sure any existing derivative with same key is atomically replaced,
  # and if the asset#file is changed to a different bytestream (compared to what's in memory
  # for this asset), we don't end up saving a derivative based on old one.
  #
  # Can specify any metadata values to be force set on the Derivative#file, and
  # a specific Shrine storage key (defaults to :kithe_derivatives shrine storage)
  #
  # @param key derivative-type identifying key
  # @param io An IO-like object (according to Shrine), bytestream for the derivative
  # @param storage_key what Shrine storage to store derivative file in, default :kithe_derivatives
  # @param metadata an optional hash of key/values to set as default metadata for the Derivative#file
  #   shrine object.
  #
  # @return [Derivative] the Derivative created, or nil if it was not created because no longer
  #   applicable (underlying Asset#file has changed in db)
  def update_derivative(key, io, storage_key: :kithe_derivatives, metadata: {})
    DerivativeUpdater.new(self, key, io, storage_key: storage_key, metadata: metadata).update.tap do |result|
      self.derivatives.reset if result
    end
  end

  def remove_derivative(key)
    deriv = Kithe::Derivative.where(key: key.to_s, asset: self).first
    if deriv
      deriv.destroy!
      self.derivatives.reset
    end
  end

  # Runs the shrine promotion step, that we normally have in backgrounding, manually
  # and in foreground. You might use this if a promotion failed and you need to re-run it,
  # perhaps in bulk. It's also useful in tests.
  #
  # This will no-op unless the attached file is stored in cache -- that is, it
  # will no-op if the file has already been promoted. In this way it matches ordinary
  # shrine promotion. (Do we need an option to force promotion anyway?)
  def promote(action: :store, context: {})
    return unless file_attacher.cached?

    context = {
      action: action,
      record: self
    }.merge(context)

    # A bit trickier than expected: https://github.com/shrinerb/shrine/issues/333
    copy_of_data = file_attacher.uploaded_file(self.file.to_json)

    file_attacher.promote(copy_of_data, context)
  end

  private

  # Meant to be called in after_save hook, looks at activerecord dirty tracking in order
  # to removes all derivatives if the asset sha512 has changed
  def remove_invalid_derivatives
    if file_data_previously_changed? &&
      file_data_previous_change.first.try(:dig, "metadata", "sha512") !=
        file_data_previous_change.second.try(:dig, "metadata", "sha512")
      derivatives.destroy_all
    end
  end
end
