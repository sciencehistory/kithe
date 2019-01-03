require 'rails_helper'


RSpec.describe "Model representatives", type: :model do
  let(:work) { FactoryBot.create(:kithe_work) }
  let(:asset) { FactoryBot.create(:kithe_asset) }

  it "can assign" do
    work.representative = asset
    work.save!
    work.reload

    expect(work.representative_id).to eq(asset.id)
    expect(work.representative).to eq(asset)
  end

  describe "on an asset" do
    it "is it's own representative" do
      expect(asset.representative).to eq(asset)
      expect(asset.representative_id).to eq(asset.id)
    end
  end
end
