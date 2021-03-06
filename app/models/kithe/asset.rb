class Kithe::Asset < Kithe::Model
  include Kithe::Asset::SetShrineUploader

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
  include Kithe::AssetUploader::Attachment(:file)

  # for convenience, let's delegate some things to shrine parts
  delegate :content_type, :original_filename, :size, :height, :width, :page_count,
    :md5, :sha1, :sha512,
    to: :file, allow_nil: true
  delegate :stored?, to: :file_attacher
  delegate :set_promotion_directives, :promotion_directives, to: :file_attacher


  # will be sent to file_attacher.set_promotion_directives, provided by our
  # kithe_promotion_hooks shrine plugin.
  class_attribute :promotion_directives, instance_accessor: false, default: {}

  # Callbacks are called by our kiteh_promotion_callbacks shrine plugin, around
  # shrine promotion. A before callback can cancel promotion with the usual
  # `throw :abort`. An after callback may want to trigger things you want
  # to happen only after asset is promoted, like derivatives.
  define_model_callbacks :promotion

  before_promotion :refresh_metadata_before_promotion
  after_promotion :schedule_derivatives

  # A convenience to call file_attacher.create_persisted_derivatives (from :kithe_derivatives)
  # to create derivatives with conncurrent access safety, with the :kithe_derivatives
  # processor argument, to create derivatives defined using kithe_derivative_definitions.
  #
  # This is designed for use with kithe_derivatives processor, and has options only relevant
  # to it, although could be expanded to take a processor argument in the future if needed.
  #
  # Create derivatives for every definition added to uploader/attacher with kithe_derivatives
  # `define_derivative`. Ordinarily will create a definition for every definition
  # that has not been marked `default_create: false`.
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
  #
  # ## Avoiding eager-download
  #
  # Additionally, this has a feature to 'trick' shrine into not eager downloading
  # the original before our kithe_derivatives processor has a chance to decide if it
  # needs to create any derivatives (based on `lazy` arg), making no-op
  # create_derivatives so much faster and more efficient, which matters when doing
  # bulk operations say with our rake task.
  #
  # kithe_derivatives processor must then do a Shrine.with_file to make sure
  # it's a local file, when needed.
  #
  # See https://github.com/shrinerb/shrine/issues/470
  #
  def create_derivatives(only: nil, except: nil, lazy: false)
    source = file
    return false unless source

    #local_files = file_attacher.process_derivatives(:kithe_derivatives, only: only, except: except, lazy: lazy)
    local_files = _process_kithe_derivatives_without_download(source, only: only, except: except, lazy: lazy)

    file_attacher.add_persisted_derivatives(local_files)
  end

  # Working around Shrine's insistence on pre-downloading original before calling derivative processor.
  # We want to avoid that, so when our `lazy` argument is in use, original does not get eagerly downloaded,
  # but only gets downloaded if needed to make derivatives.
  #
  # This is a somewhat hacky way to do that, loking at the internals of shrine `process_derivatives`,
  # and pulling them out to skip the parts we don't want. We also lose shrine instrumentation
  # around this action.
  #
  # See: https://github.com/shrinerb/shrine/issues/470
  #
  # If that were resolved, the 'ordinary' shrine thing would be to replace calls
  # to this local private method with:
  #
  #     file_attacher.process_derivatives(:kithe_derivatives, only: only, except: except, lazy: lazy)
  #
  private def _process_kithe_derivatives_without_download(source, **options)
    processor = file_attacher.class.derivatives_processor(:kithe_derivatives)
    local_files = file_attacher.instance_exec(source, **options, &processor)
  end

  # Just a convennience for file_attacher.add_persisted_derivatives (from :kithe_derivatives),
  # feel free to use that if you want to add more than one etc.  By default stores to
  # :kithe_derivatives, just as `add_persisted_derivatives` does.
  #
  # Note that just like shrine's own usual `add_derivative(s)`, it assumes any files
  # you pass it are meant to be temporary and will delete them, unless you pass
  # `delete: false`.
  #
  # Adds an associated derivative with key and io bytestream specified,
  # doing so in a way that is safe from race conditions under multi-process
  # concurrency.
  #
  # Normally you don't use this with derivatives defined with `define_derivative`,
  # this is used by higher-level API. But if you'd like to add a derivative not defined
  # with `define_derivative`, or for any other reason would like to manually add
  # a derivative.
  #
  # Can specify any options normally allowed for kithe `add_persisted_derivatives`,
  # which are also generally any allowed for shrine `add_derivative`.
  #
  #     asset.update_derivative("big_thumb", File.open(something))
  #     asset.update_derivative("something", File.open(something), delete: false)
  #     asset.update_derivative("something", File.open(something), storage_key: :registered_storage, metadata: { "foo": "bar" })
  #
  # @param key derivative-type identifying key
  # @param io An IO-like object (according to Shrine), bytestream for the derivative
  # @param storage_key what Shrine storage to store derivative file in, default :kithe_derivatives
  # @param metadata an optional hash of key/values to set as default metadata for the Derivative#file
  #   shrine object.
  #
  # @return [Shrine::UploadedFile] the Derivative created, or false if it was not created because no longer
  #   applicable (underlying Asset#file has changed in db)
  def update_derivative(key, io, **options)
    result = update_derivatives({ key => io }, **options)
    result && result.values.first
  end

  def update_derivatives(deriv_hash, **options)
    file_attacher.add_persisted_derivatives(deriv_hash, **options)
  end

  # just a convenience for kithe remove_persisted_derivatives
  def remove_derivatives(*keys)
    file_attacher.remove_persisted_derivatives(*keys)
  end

  # Runs the shrine promotion step, that we normally have in backgrounding, manually
  # and in foreground. You might use this if a promotion failed and you need to re-run it,
  # perhaps in bulk. It's also useful in tests. Also persists, using shrine `atomic_promote`.
  #
  # This will no-op unless the attached file is stored in cache -- that is, it
  # will no-op if the file has already been promoted. In this way it matches ordinary
  # shrine promotion. (Do we need an option to force promotion anyway?)
  #
  # Note that calling `file_attacher.promote` or `atomic_promote` on it's own won't do
  # quite the same things.
  def promote(action: :store, **context)
    return unless file_attacher.cached?

    context = {
      action: action,
      record: self
    }.merge(context)

    file_attacher.atomic_promote(**context)
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

    # copy class-level global promotion directives as initial instance value
    if self.class.promotion_directives.present?
      self.set_promotion_directives(self.class.promotion_directives)
    end
  end

  private

  # called by after_promotion hook
  def schedule_derivatives
    return unless self.file_attacher.kithe_derivative_definitions.present? # no need to schedule if we don't have any

    Kithe::TimingPromotionDirective.new(key: :create_derivatives, directives: file_attacher.promotion_directives) do |directive|
      if directive.inline?
        Kithe::CreateDerivativesJob.perform_now(self)
      elsif directive.background?
        Kithe::CreateDerivativesJob.perform_later(self)
      end
    end
  end

  # Called by before_promotion hook
  def refresh_metadata_before_promotion
    file.refresh_metadata!(promoting: true)
  end
end
