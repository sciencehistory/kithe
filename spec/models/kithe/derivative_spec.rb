require 'rails_helper'

RSpec.describe Kithe::Derivative, type: :model do
  let(:key) { "some_thumb" }
  let(:asset) { FactoryBot.create(:kithe_asset) }
  let(:derivative) { Kithe::Derivative.new }

  describe "for referential integrity" do
    it "needs an asset" do
      expect { derivative.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end
    it "needs a key" do
      derivative.asset = asset
      expect { derivative.save! }.to raise_error(ActiveRecord::NotNullViolation)
    end
    it "can save with key and asset" do
      derivative.asset = asset
      derivative.key = key
      derivative.save!
      expect(derivative).to be_persisted
    end
    it "can't save duplicate key/asset" do
      existing_derivative = Kithe::Derivative.create!(asset: asset, key: key)

      derivative.asset = asset
      derivative.key = key
      expect { derivative.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end

