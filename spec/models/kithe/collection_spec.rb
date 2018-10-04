require 'rails_helper'


RSpec.describe Kithe::Collection, type: :model do
  let(:collection) { FactoryBot.create(:kithe_collection) }
  let(:asset) { FactoryBot.create(:kithe_asset) }


  it "can create with title" do
    work = Kithe::Collection.create(title: "some title")
    expect(work).to be_present
    expect(work.title).to eq "some title"
  end

  it "requires a title" do
    expect {
      work = Kithe::Collection.create!
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "can not have any members" do
    collection.members << asset
    expect {
      asset.save!
    }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
