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
    end
  end
end
