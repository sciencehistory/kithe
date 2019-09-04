module Kithe

  # Derivatives by default will be stored in Shrine storage :kithe_derivatives, so
  # that should be registered in your app.
  #
  # Only one deriv can exist for a given asset_id/key pair, enforced by db constraint.
  class Derivative < ApplicationRecord
    # the fk is to kithe_models STI table, but we only intend for assets
    belongs_to :asset, class_name: "Kithe::Asset"

    include Kithe::DerivativeUploader::Attachment.new(:file, store: :kithe_derivatives)

    delegate :content_type, :size, :height, :width, :url, to: :file, allow_nil: true

    def file
      @__file ||= super
    end
  end
end
