module Kithe
  class CreateDerivativesJob < Job
    def perform(asset, mark_created: nil)
      begin
        asset.create_derivatives(mark_created: mark_created)
      rescue ActiveJob::DeserializationError
        Rails.logger.error("Unable to derivatives for asset with ID #{asset.id}, as it was deleted first.")
        return
      end
    end
  end
end
