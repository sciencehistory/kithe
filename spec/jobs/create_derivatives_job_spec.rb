require "rails_helper"

describe Kithe::CreateDerivativesJob, type: :job do
  let(:asset) { FactoryBot.create(:kithe_asset) }

  describe "with only asset arg" do
    it "calls #create_derivatives with args" do
      expect(asset).to receive(:create_derivatives).with(lazy: false, only: nil, except: nil)

      Kithe::CreateDerivativesJob.perform_now(asset)
    end
  end

  describe "with other args" do
    it "calls #create_derivatives with other args" do
      expect(asset).to receive(:create_derivatives).with(
        lazy: true, only: :only_deriv, except: [:except_deriv1, :except_deriv2]
      )

      Kithe::CreateDerivativesJob.perform_now(asset, lazy: true, only: :only_deriv, except: [:except_deriv1, :except_deriv2])
    end
  end
end
