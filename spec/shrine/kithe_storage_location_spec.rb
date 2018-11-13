require 'spec_helper'
require 'shrine/plugins/kithe_storage_location'

describe Shrine::Plugins::KitheStorageLocation do
  let(:uploader) { test_uploader { plugin :kithe_storage_location } }

  it "uploads with a record with id" do
    uploaded_file = uploader.upload(fakeio, record: OpenStruct.new(id: "81060886-4f93-42e7-ace7-ab51399f4808"), name: :file)

    expect(uploaded_file.id).to match %r{\Aasset/81060886-4f93-42e7-ace7-ab51399f4808/[0-9a-f]+}
  end

  it "has suffix with a record id and filename" do
    uploaded_file = uploader.upload(fakeio(filename: "foo.jpg"), record: OpenStruct.new(id: "81060886-4f93-42e7-ace7-ab51399f4808"), name: :file)

    expect(uploaded_file.id).to match %r{\Aasset/81060886-4f93-42e7-ace7-ab51399f4808/[0-9a-f]+\.jpg}
  end

  it "uploads with no record" do
    uploaded_file = uploader.upload(fakeio, record: OpenStruct.new(id: "81060886-4f93-42e7-ace7-ab51399f4808"), name: :file)

    expect(uploaded_file.id).to match %r{\Aasset/[0-9a-f]+}
  end

  it "uploads with record with no id" do
    uploaded_file = uploader.upload(fakeio, record: OpenStruct.new(), name: :file)

    expect(uploaded_file.id).to match %r{\Aasset/[0-9a-f]+}
  end


end
