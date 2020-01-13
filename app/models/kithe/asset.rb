class Kithe::Asset < Kithe::Model
  has_many :derivatives, foreign_key: "asset_id", inverse_of: "asset", dependent: :destroy # dependent destroy to get shrine destroy logic for assets

  # These associations exist for hetereogenous eager-loading, but hide em.
  # They are defined as self-pointing below.
  # ignored_columns doesn't do everything we'd like, but it's something: https://github.com/rails/rails/issues/34344
  self.ignored_columns = %w(representative_id leaf_representative_id)
  belongs_to :representative, -> { none }, class_name: "Kithe::Model"
  belongs_to :leaf_representative, -> { none }, class_name: "Kithe::Model"
  private :representative, :representative=, :leaf_representative, :leaf_representative=

  after_initialize do
    self.kithe_model_type = "asset" if self.kithe_model_type.nil?
  end
  before_validation do
    self.kithe_model_type = "asset" if self.kithe_model_type.nil?
  end


  # TODO we may need a way for local app to provide custom uploader class.
  # or just override at ./kithe/asset_uploader.rb locally?
  include Kithe::AssetUploader::Attachment.new(:file)

  # for convenience, let's delegate some things to shrine parts
  delegate :content_type, :original_filename, :size, :height, :width, :page_count,
    :md5, :sha1, :sha512,
    to: :file, allow_nil: true
  delegate :stored?, to: :file_attacher
  delegate :set_promotion_directives, to: :file_attacher

  after_save :remove_invalid_derivatives

  # will be sent to file_attacher.promotion_directives=, provided by our
  # kithe_promotion_hooks shrine plugin.
  class_attribute :promotion_directives, instance_writer: false, default: {}

  class_attribute :derivative_definitions, instance_writer: false, default: []

  # Callbacks are called by our kiteh_promotion_callbacks shrine plugin, around
  # shrine promotion. A before callback can cancel promotion with the usual
  # `throw :abort`. An after callback may want to trigger things you want
  # to happen only after asset is promoted, like derivatives.
  define_model_callbacks :promotion

  after_promotion :schedule_derivatives

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

  # Returns all derivative keys with a definition, as array of strings
  def self.defined_derivative_keys
    self.derivative_definitions.collect(&:key).uniq.collect(&:to_s)
  end

  # If you have a subclass that has inherited derivative definitions, you can
  # remove them -- only by key, will remove any definitions with that key regardless
  # of content_type restrictions.
  #
  # This could be considered rather bad OO design, you might want to consider
  # a different class hieararchy where you don't have to do this. But it's here.
  def self.remove_derivative_definition!(*keys)
    keys = keys.collect(&:to_sym)
    self.derivative_definitions = self.derivative_definitions.reject do |defn|
      keys.include?(defn.key.to_sym)
    end
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
  def create_derivatives(only: nil, except: nil, lazy: false, mark_created: nil)
    DerivativeCreator.new(derivative_definitions, self, only: only, except: except, lazy: lazy, mark_created: mark_created).call
  end

  # Adds an associated derivative with key and io bytestream specified.
  # Normally you don't use this with derivatives defined with `define_derivative`,
  # this is used by higher-level API. But if you'd like to add a derivative not defined
  # with `define_derivative`, or for any other reason would like to manually add
  # a derivative, this is public API meant for that.
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
    if association(:derivatives).loaded?
      derivatives.find_all { |d| d.key == key.to_s }.each do |deriv|
        derivatives.delete(deriv)
      end
    else
      Kithe::Derivative.where(key: key.to_s, asset: self).each do |deriv|
        deriv.destroy!
      end
    end
  end

  # Just finds the Derivative object matching supplied key. if you're going to be calling
  # this on a list of Asset objects, make sure to preload :derivatives association.
  def derivative_for(key)
    derivatives.find {|d| d.key == key.to_s }
  end

  # Runs the shrine promotion step, that we normally have in backgrounding, manually
  # and in foreground. You might use this if a promotion failed and you need to re-run it,
  # perhaps in bulk. It's also useful in tests.
  #
  # This will no-op unless the attached file is stored in cache -- that is, it
  # will no-op if the file has already been promoted. In this way it matches ordinary
  # shrine promotion. (Do we need an option to force promotion anyway?)
  #
  # Note that calling `file_attacher.promote` on it's own won't do quite the right thing,
  # and won't respect that the file is already cached.
  def promote(action: :store, context: {})
    return unless file_attacher.cached?

    context = {
      action: action,
      record: self
    }.merge(context)

    file_attacher.promote(file_attacher.get, **context)
  end

  # The derivative creator sets metadata when it's created all derivatives
  # defined as `default_create`. So we can tell you if it's done or not.
  def derivatives_created?
    if file
      !!file.metadata["derivatives_created"]
    end
  end

  # Take out a DB lock on the asset with unchanged sha512 saved in metadata. If a lock
  # can't be acquired -- which would be expected to be because the asset has already changed
  # and has a new sha for some reason -- returns nil.
  #
  # Useful for making a change to an asset making sure it applies to a certain original file.
  #
  # Needs to be done in a transaction, and you should keep the transaction SMALL AS POSSIBLE.
  # We can't check to make sure you're in a transaction reliably because of Rails transactional
  # tests, you gotta do it!
  #
  # This method is mostly intended for internal Kithe use, cause it's a bit tricky.
  def acquire_lock_on_sha
    raise ArgumentError.new("Can't acquire lock without sha512 in metadata") if self.sha512.blank?

    Kithe::Asset.where(id: self.id).where("file_data -> 'metadata' ->> 'sha512' = ?", self.sha512).lock.first
  end

  # Intentionally only true if there WAS a sha512 before AND it's changed.
  # Allowing false on nil previous sha512 allows certain conditions, mostly only
  # in testing, where you want to assign a derivative to not-yet-promoted file.
  def saved_change_to_file_sha?
    saved_change_to_file_data? &&
      saved_change_to_file_data.first.try(:dig, "metadata", "sha512") != nil &&
      saved_change_to_file_data.first.try(:dig, "metadata", "sha512") !=
        saved_change_to_file_data.second.try(:dig, "metadata", "sha512")
  end

  # An Asset is it's own representative
  def representative
    self
  end
  alias_method :leaf_representative, :representative
  def representative_id
    id
  end
  alias_method :leaf_representative_id, :representative_id

  def initialize(*args)
    super
    if promotion_directives.present?
      file_attacher.set_promotion_directives(promotion_directives)
    end
  end

  private

  # called by after_promotion hook
  def schedule_derivatives
    return unless self.derivative_definitions.present? # no need to schedule if we don't have any

    Kithe::TimingPromotionDirective.new(key: :create_derivatives, directives: file_attacher.promotion_directives) do |directive|
      if directive.inline?
        Kithe::CreateDerivativesJob.perform_now(self)
      elsif directive.background?
        Kithe::CreateDerivativesJob.perform_later(self)
      end
    end
  end

  # Meant to be called in after_save hook, looks at activerecord dirty tracking in order
  # to removes all derivatives if the asset sha512 has changed
  def remove_invalid_derivatives
    if saved_change_to_file_sha?
      derivatives.destroy_all
    end
  end
end
