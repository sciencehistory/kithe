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

  it "can create new with collection id" do
    work = FactoryBot.build(:kithe_work, contained_by_ids: [collection.id])
    work.save!
    expect(work.contained_by).to include(collection)
  end

  describe "sub-class with attr_json" do
    let(:subclass_name) { "TestWorkSubclass" }
    let(:subclass) do
      # ordinary tricky ruby Class.new(Kithe::Work) breaks Rails STI since it
      # needs a name to put in the db, so we need to assign it to const
      stub_const(subclass_name, Class.new(Kithe::Work)  do
        attr_json :authors, :string, array: true
      end)
    end

    let(:instance) { subclass.new }

    it "works and persists" do
      instance.assign_attributes(title: "title", authors: ["Bob", "Joe"])

      instance.tap(&:save!).tap(&:reload)

      expect(instance.type).to eq(subclass_name)
      expect(instance.title).to eq("title")
      expect(instance.authors).to eq(["Bob", "Joe"])
    end
  end
end
