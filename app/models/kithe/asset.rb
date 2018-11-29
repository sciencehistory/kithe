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
  def add_derivative(key, io, storage_key: :kithe_derivatives, metadata: {})
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
