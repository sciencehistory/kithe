module Kithe
  class CreateDerivativesJob < Job
    def perform(asset)
        asset.create_derivatives
    end
    # This error typically occurs when several large assets, whose derivatives
    # take a long time to generate, are deleted immediately after ingest.
    rescue_from(ActiveJob::DeserializationError) do |exception|
      Rails.logger.error("Kithe::CreateDerivativesJob: Unable to create derivatives for this asset, as it was unavailable. Details: #{exception}")
    end
  end
end
