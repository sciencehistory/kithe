require 'rails_helper'
require 'shrine/plugins/kithe_accept_remote_url'

describe Shrine::Plugins::KitheAcceptRemoteUrl, queue_adapter: :inline do
  temporary_class("RemoteUrlUploader") do
    Class.new(Kithe::AssetUploader) do
      plugin :kithe_accept_remote_url
    end
  end

  temporary_class("MyAsset") do
    Class.new(Kithe::Asset) do
      set_shrine_uploader(RemoteUrlUploader)
    end
  end

  let(:asset) { MyAsset.create!(title: "test") }

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
