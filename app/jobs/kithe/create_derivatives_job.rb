module Kithe
  # Create derivatives in a bg job.
  #
  # Used as part of kithe standard ingest flow, to create all derivatives in bg job for new
  # ingest
  #
  # Can also be used explicitly, with args, to create only certain derivs, optionally lazily
  #
  # @example
  #
  #   CreateDerivativesJob.new(asset).perform_later
  #
  #   CreateDerivativesJob.new(asset, lazy: true).perform_later
  #
  #   CreateDerivativesJob.new(asset, only: :some_deriv, lazy: true).perform_later
  #
  #   CreateDerivativesJob.new(asset, except: :other_deriv, lazy: true).perform_later
  class CreateDerivativesJob < Job
    def perform(asset, lazy: false, only: nil, except: nil)
        asset.create_derivatives(lazy: lazy, only: only, except: except)
    end
    # This error typically occurs when several large assets, whose derivatives
    # take a long time to generate, are deleted immediately after ingest.
    rescue_from(ActiveJob::DeserializationError) do |exception|
      Rails.logger.error("Kithe::CreateDerivativesJob: Unable to create derivatives for this asset, as it was unavailable. Details: #{exception}")
    end
  end
end
