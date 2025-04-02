require 'spec_helper'
require 'shrine/plugins/kithe_storage_location'
require 'ostruct'

describe Shrine::Plugins::KitheStorageLocation do
  let(:uploader) { test_uploader { plugin :kithe_storage_location } }

  describe "for main file" do
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

  describe "for shrine derivatives" do
    let(:image_path) { Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg") }

    let(:uploader) do
      test_uploader do
        plugin :kithe_storage_location
      end
    end

    it "uses good path for derivative" do
      uploaded_file = uploader.upload(fakeio("foo.jpg"), derivative: :fixed, record: OpenStruct.new(id: "81060886-4f93-42e7-ace7-ab51399f4808"), name: :file)

      expect(uploaded_file.id).to match %r{\A81060886-4f93-42e7-ace7-ab51399f4808/fixed/[0-9a-f]+}
    end

    it "raises with no record" do
      expect {
        uploader.upload(fakeio("foo.jpg"), record: nil, derivative: :fixed, name: :file)
      }.to raise_error(TypeError)
    end

    it "raises with record with no id" do
      expect {
        uploader.upload(fakeio("foo.jpg"), record: OpenStruct.new, derivative: :fixed, name: :file)
      }.to raise_error(TypeError)
    end
  end
end
