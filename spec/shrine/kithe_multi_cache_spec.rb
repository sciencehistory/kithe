require 'spec_helper'
require 'shrine/plugins/kithe_multi_cache'
require 'webmock/rspec'

describe Shrine::Plugins::KitheMultiCache do
  let(:extra_storage) { Shrine::Storage::Memory.new }

  let(:attacher) do
    s = extra_storage
    test_attacher! do
      storages[:additional_one] = s
      plugin :kithe_multi_cache, additional_cache: :additional_one
    end
  end

  it "can assign from additional cache" do
    attacher.assign({"id" => "test_id", "storage" => "additional_one"}.to_json)
    expect(attacher.get).not_to be_nil
    expect(attacher.get.data).to include({"id" => "test_id", "storage" => "additional_one"})
  end

  it "can promote from additional cache" do
    extra_storage.upload(fakeio("test_content"), "test_id")
    attacher.assign({"id" => "test_id", "storage" => "additional_one"}.to_json)
    attacher.promote(attacher.get)

    uploaded_file = attacher.get
    expect(uploaded_file).not_to be_nil
    expect(uploaded_file.data["storage"]).to eq(attacher.store.storage_key.to_s)
    expect(uploaded_file.data["id"]).not_to be_nil
    expect(uploaded_file.read).to eq("test_content")
  end
end
