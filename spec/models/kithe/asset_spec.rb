require 'rails_helper'
require 'digest'


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
  # to make it straightforward. Maybe better way(s) to test, or not.
  # https://github.com/shrinerb/shrine/blob/master/doc/testing.md
  describe "file attachment", queue_adapter: :inline do
    let(:source_path) { Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg") }
    let(:source) { File.open(source_path) }
    let(:asset) { Kithe::Asset.new(title: "foo") }

    it "can attach file correctly" do
      asset.file = source

      asset.save!
      # since it happened in a job, after commit, we gotta reload, even though :inline queue for some reason
      asset.reload

      expect(asset.file).to be_present
      expect(asset.stored?).to be true
      expect(asset.content_type).to eq("image/jpeg")
      expect(asset.size).to eq(File.open(source_path).size)
      expect(asset.height).to eq(1)
      expect(asset.width).to eq(1)

      # This is the file location/storage path, currently under UUID pk.
      expect(asset.file.id).to match %r{\Aasset/#{asset.id}/.*\.jpg}
    end

    describe "pdf file" do

      it "extracts page count" do

      end
    end
  end

  describe "direct uploads", queue_adapter: :inline do
    let(:sample_file_path) { Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg") }
    let(:cached_file) { asset.file_attacher.cache.upload(File.open(sample_file_path)) }
    it "can attach json hash" do
      asset.file = {
        id: cached_file.id,
        storage: cached_file.storage_key,
        metadata: {
          filename: "echidna.jpg"
        }
      }.to_json

      asset.save!
      asset.reload

      expect(asset.file).to be_present
      expect(asset.stored?).to be true
      expect(asset.content_type).to eq("image/jpeg")
      expect(asset.size).to eq(File.open(sample_file_path).size)
      expect(asset.height).to eq(1)
      expect(asset.width).to eq(1)

      # This is the file location/storage path, currently under UUID pk.
      expect(asset.file.id).to match %r{\Aasset/#{asset.id}/.*\.jpg}
    end
  end

  describe "remote urls", queue_adapter: :inline do
    it "can assign and promote" do
      stub_request(:any, "www.example.com/bar.html?foo=bar").
        to_return(body: "Example Response" )

      asset.file = {"id" => "http://www.example.com/bar.html?foo=bar", "storage" => "remote_url"}
      asset.save!
      asset.reload

      expect(asset.file.storage_key).to eq(asset.file_attacher.store.storage_key.to_sym)
      expect(asset.stored?).to be true
      expect(asset.file.read).to include("Example Response")
      expect(asset.file.id).to end_with(".html") # no query params
    end

    it "will fetch headers" do
      stubbed = stub_request(:any, "www.example.com/bar.html?foo=bar").
                  to_return(body: "Example Response" )

      asset.file = {"id" => "http://www.example.com/bar.html?foo=bar",
                    "storage" => "remote_url",
                    "headers" => {"Authorization" => "Bearer TestToken"}}

      asset.save!

      expect(
        a_request(:get, "www.example.com/bar.html?foo=bar").with(
          headers: {'Authorization'=>'Bearer TestToken', 'User-Agent' => /.+/}
        )
      ).to have_been_made.times(1)
    end
  end

  describe "#promote", queue_adapter: :test do
    let(:asset) { FactoryBot.create(:kithe_asset, :with_file) }
    before do
      # pre-condition
      expect(asset.file_attacher.cached?).to be(true)
    end

    it "can promote" do
      asset.promote

      expect(asset.stored?).to be(true)
      expect(asset.file_attacher.stored?).to be(true)
      expect(asset.file.exists?).to be(true)
      expect(asset.file.metadata.keys).to include("filename", "size", "mime_type", "width", "height")
    end

    it "does not do anything for already promoted file", queue_adapter: :inline do
      promoted_asset = FactoryBot.create(:kithe_asset, :with_file).reload

      original_id = promoted_asset.file.id

      expect(promoted_asset.file_attacher).not_to receive(:promote)
      promoted_asset.promote
      expect(promoted_asset.file.id).to eq(original_id)
    end
  end

  describe "removes derivatives", queue_adapter: :inline do
    let(:asset_with_derivatives) do
      Kithe::Asset.create(title: "test",
        file: File.open(Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg"))
      ).tap do |a|
        a.file_attacher.set_promotion_directives(skip_callbacks: true)
        #a.promote
        a.reload
        a.update_derivative(:existing, StringIO.new("content"))
      end
    end

    let!(:existing_stored_file) { asset_with_derivatives.file_derivatives.values.first }

    it "deletes derivatives on delete" do
      asset_with_derivatives.destroy
      expect(existing_stored_file.exists?).to be(false)
    end

    it "deletes derivatives on new asset assigned" do
      asset_with_derivatives.file = StringIO.new("some new thing")
      asset_with_derivatives.save!
      expect(existing_stored_file.exists?).to be(false)
    end

    it "allows derivative to be set on un-promoted file though" do
      # mostly needed for testing scenarios, not otherwise expected.
      filepath = Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg")
      asset = Kithe::Asset.new(file: File.open(filepath), title: "test").tap do |a|
        a.file_attacher.set_promotion_directives(promote: false, skip_callbacks: true)
      end
      asset.save!
      asset.reload

      expect(asset.stored?).to eq(false)
      asset.update_derivative("test", File.open(filepath), delete: false)

      expect(asset.file_derivatives.count).to eq 1
    end
  end
end
