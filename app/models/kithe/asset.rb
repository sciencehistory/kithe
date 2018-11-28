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
  # * Only one derivative with a certain key per asset can exist
  # * If the asset file has changed in the db since we loaded this in memory,
  #   we simply don't update anything -- the asset we wanted to create a derivative
  #   for isn't there anymore, it's been deleted, no problem.
  #
  # Will overrwrite any existing derivative with that key.
  def add_derivative(key, io, storage_key: :kithe_derivatives, metadata: {})
    deriv = Kithe::Derivative.new(key: key.to_s, asset: self)

    # skip cache phase, right to specified storage, but with metadata extraction.
    uploader = deriv.file_attacher.shrine_class.new(storage_key)
    uploaded_file = uploader.upload(io, record: deriv, metadata: metadata)

    deriv.file_attacher.set(uploaded_file)
    deriv.save!

    deriv
  end

end
