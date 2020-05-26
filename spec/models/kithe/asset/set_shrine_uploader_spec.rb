require 'rails_helper'

describe Kithe::Asset::SetShrineUploader do
  temporary_class("MyUploaderSubclass") do
    Class.new(Kithe::AssetUploader) do
      add_metadata :uploader_class_name do |io|
        self.class.name
      end
    end
  end

  temporary_class("AssetSubclass") do
    Class.new(Kithe::Asset) do
      set_shrine_uploader(MyUploaderSubclass)
    end
  end

  let(:asset) { AssetSubclass.create!(title: "test") }
  let(:image_path) { Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg") }

  it "has proper class attacher" do
    expect(AssetSubclass.file_attacher.class).to eq(MyUploaderSubclass::Attacher)
  end

  it "has proper instance attacher" do
    expect(asset.file_attacher.class).to eq(MyUploaderSubclass::Attacher)
  end

  it "can attach file using custom subclass" do
    asset.set_promotion_directives(promote: :inline)
    asset.file = File.open(image_path)
    asset.save!
    asset.reload

    expect(asset.stored?).to eq(true)
    expect(asset.file).to be_present
    expect(asset.file.metadata["uploader_class_name"]).to eq("MyUploaderSubclass")
  end
end
