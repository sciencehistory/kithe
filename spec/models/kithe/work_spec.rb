require 'rails_helper'


RSpec.describe Kithe::Work, type: :model do
  let(:work) { FactoryBot.create(:kithe_work) }
  let(:work2) { FactoryBot.create(:kithe_work) }
  let(:asset) { FactoryBot.create(:kithe_asset) }
  let(:collection) { FactoryBot.create(:kithe_collection) }

  it "can create with title" do
    work = Kithe::Work.create(title: "some title")
    expect(work).to be_present
    expect(work.title).to eq "some title"
  end

  it "requires a title" do
    expect {
      work = Kithe::Work.create!
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "can have an asset as a member" do
    work.members << asset
    expect(asset.reload.parent).to eq(work)
  end

  it "can have an work as a member" do
    work.members << work2
    work2.save!
    expect(work2.reload.parent).to eq(work)
  end

  it "can NOT have a collection as a member" do
    work.members << collection
    expect {
      collection.save!
    }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
