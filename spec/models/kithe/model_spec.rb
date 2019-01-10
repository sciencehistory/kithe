require 'rails_helper'

module Kithe
  RSpec.describe Model, type: :model do
    it "is abstract, can not be instantiated itself" do
      expect {
        Kithe::Model.new
      }.to raise_error(TypeError)

      expect {
        Kithe::Model.create
      }.to raise_error(TypeError)
    end

    describe "friendlier_ids" do
      # We can't instantiate Kithe::Models directly, let's use work instead
      let(:work) { FactoryBot.create(:kithe_work) }

      it "has friendlier_id assigned by db on insert" do
        expect(work.friendlier_id).to be_present
        expect(work.friendlier_id.length).to eq(9)
      end

      it "uses friendlier_id for to_param for routing" do
        expect(work.to_param).to eq(work.friendlier_id)
      end

      it "has indexed friendlier_ids column" do
        expect(
          ActiveRecord::Base.connection.index_exists?(:kithe_models, :friendlier_id, unique: true)
        ).to be(true)
      end
    end

    describe "eager-loading derivatives" do
      let!(:work) { FactoryBot.create(:kithe_work) }
      let!(:collection) { FactoryBot.create(:kithe_collection) }
      let!(:asset) { FactoryBot.create(:kithe_asset) }

      it "work from hetereogeous collections" do
        results = Kithe::Model.all.includes(:derivatives)
        asset = results.to_a.find { |a| a.kind_of? Kithe::Asset }
        expect(asset.derivatives.loaded?).to be(true)
      end
    end

    describe "contains association" do
      let(:collection1) { FactoryBot.create(:kithe_collection)}
      let(:collection2) { FactoryBot.create(:kithe_collection)}
      let(:work) { FactoryBot.create(:kithe_work)}
      let(:work2) { FactoryBot.create(:kithe_work)}

      it "associates" do
        collection1.contains << work

        expect(collection1.contains).to include(work)
        expect(work.contained_by).to include(collection1)

        work.contained_by << collection2
        expect(collection2.contains.to_a).to eq([work])
        expect(work.contained_by.to_a).to match([collection1, collection2])

        work.destroy!
        collection1.reload
        collection2.reload
        expect(collection1.contains.count).to eq(0)
        expect(collection2.contains.count).to eq(0)

        collection1.contains << work2
        collection1.destroy!
        work2.reload
        expect(work2.contained_by.count).to eq(0)
      end
    end

  end
end
