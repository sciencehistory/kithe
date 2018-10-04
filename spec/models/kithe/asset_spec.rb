require 'rails_helper'


RSpec.describe Kithe::Asset, type: :model do
  let(:asset) { FactoryBot.create(:kithe_asset) }
  let(:asset2) { FactoryBot.create(:kithe_asset) }


  it "can create with title" do
    work = Kithe::Asset.create(title: "some title")
    expect(work).to be_present
    expect(work.title).to eq "some title"
  end

  it "requires a title" do
    expect {
      work = Kithe::Asset.create!
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "can not have any members" do
    asset.members << asset2
    expect {
      asset2.save!
    }.to raise_error(ActiveRecord::RecordInvalid)
  end


end
