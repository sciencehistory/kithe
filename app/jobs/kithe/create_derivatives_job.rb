module Kithe
  class CreateDerivativesJob < Job
    def perform(asset, mark_created: true)
      asset.create_derivatives(mark_created: mark_created)
    end
  end
end
