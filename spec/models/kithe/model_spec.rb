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
        expect(work.friendlier_id.length).to eq(7)
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
  end
end
