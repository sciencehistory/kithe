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


  # Adds an associated derivative with key and io bytestream specified.
  # Normally you don't use this, you would define derivatives and use
  # higher-level API to manage them, but this one is used by higher level API.
  #
  # Makes sure referential integrity isn't violated despite possible concurrency:
  # * Only one derivative with a certain key per asset can exist (uses an optimistic create
  #   rescuing db constraint violations and recovering)
  # * If the asset file has changed in the db since we loaded this in memory,
  #   we simply don't update anything -- the asset we wanted to create a derivative
  #   for isn't there anymore, it's been deleted, no problem. (Uses db pessimistic locking
  #   to make sure in-db asset sha512 is what we expect and remains so until after we save.)
  #
  # Will overrwrite any existing derivative with that key.
  def add_derivative(key, io, storage_key: :kithe_derivatives, metadata: {})
    unless self.persisted? && self.sha512.present?
      raise ArgumentError.new("Can not safely add derivative to an asset without a persisted sha512 value")
    end

    retries ||= 0
    deriv ||= Kithe::Derivative.new(key: key.to_s, asset: self)

    # skip cache phase, right to specified storage, but with metadata extraction.
    uploader ||= deriv.file_attacher.shrine_class.new(storage_key)
    uploaded_file ||= uploader.upload(io, record: deriv, metadata: metadata)

    deriv.file_attacher.set(uploaded_file)

    Kithe::Asset.transaction do
      # pessimistic lock on the asset still existing with the same sha. We can
      # count on sha512 existing, cause kithe says so.

      existing = Kithe::Asset.where(id: self.id).where("file_data -> 'metadata' ->> 'sha512' = ?", self.sha512).lock.first
      unless existing
        # the file we're trying to add a derivative to doesn't exist anymore, forget it
        uploaded_file.delete
        return nil
      end
      # wait gotta delete the thing too.
      deriv.save!
    end

    deriv
  rescue ActiveRecord::RecordNotUnique => e
    # A derivative with this key and asset id already existed, fetch it, and
    # retry to set the specified UploadedFile on THAT one.
    retries += 1
    if retries < 3
      deriv = Kithe::Derivative.where(key: key.to_s, asset: self).first
      retry
    else
      # we're giving up, delete the file we uploaded to storage, and
      # raise, instead of silently failing.
      uploaded_file.delete if uploaded_file
      raise e
    end
  end

  def remove_derivative(key)
    deriv = Kithe::Derivative.where(key: key.to_s, asset: self).first
    deriv.destroy! if deriv
  end
end
