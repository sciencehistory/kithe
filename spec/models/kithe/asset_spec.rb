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

  # should we be testing the uploader directly instead/in addition?
  # We're doing it "integration" style here, but fixing queue adapter to inline
  # to make it straightforward. Maybe better way(s) to test.
  # https://github.com/shrinerb/shrine/blob/master/doc/testing.md
  describe "file attachment", queue_adapter: :inline do
    let(:source) { File.open(Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg")) }
    let(:asset) { Kithe::Asset.new(title: "foo") }

    it "can attach file correctly" do
      asset.file = source

      asset.save!
      # since it happened in a job, after commit, we gotta reload, even though :inline queue for some reason
      asset.reload

      expect(asset.file).to be_present
      expect(asset.stored?).to be true
      expect(asset.content_type).to eq("image/jpeg")
      expect(asset.size).to eq(File.open(Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg")).size)
      expect(asset.height).to eq(1)
      expect(asset.width).to eq(1)

      # This is the file location/storage path, currently under UUID pk.
      expect(asset.file.id).to match %r{\Aasset/#{asset.id}/.*\.jpg}
    end
  end


end
