# Make a new test file cause it's a buncha func
require 'rails_helper'

# Not sure how to get our
describe "Kithe::Asset derivative definitions", queue_adapter: :test do
  let(:a_jpg_deriv_file) { Kithe::Engine.root.join("spec/test_support/images/2x2_pixel.jpg") }

  temporary_class("TestAssetSubclass") do
    deriv_src_path = a_jpg_deriv_file
    Class.new(Kithe::Asset) do
      define_derivative(:some_data) do |original_file|
        StringIO.new("some one data")
      end

      define_derivative(:a_jpg) do |original_file|
        FileUtils.cp(deriv_src_path,
             Kithe::Engine.root.join("spec/test_support/images/2x2_pixel-TEMP.jpg"))

        File.open(Kithe::Engine.root.join("spec/test_support/images/2x2_pixel-TEMP.jpg"))
      end
    end
  end

  let(:asset) do
    TestAssetSubclass.create(title: "test",
      file: File.open(Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg"))
    ).tap { |a| a.promote }
  end

  it "builds derivatives" do
    asset.create_derivatives

    one_deriv = asset.derivatives.find { |d| d.key == "some_data" }
    expect(one_deriv).to be_present
    expect(one_deriv.file.read).to eq("some one data")

    jpg_deriv = asset.derivatives.find {|d| d.key == "a_jpg"}
    expect(jpg_deriv.file.read).to eq(File.read(a_jpg_deriv_file, encoding: "BINARY"))
  end

  it "extracts limited metadata from derivative" do
    asset.create_derivatives

    jpg_deriv = asset.derivatives.find {|d| d.key == "a_jpg"}
    expect(jpg_deriv.size).to eq(File.size(Kithe::Engine.root.join("spec/test_support/images/2x2_pixel.jpg")))
    expect(jpg_deriv.width).to eq(2)
    expect(jpg_deriv.height).to eq(2)
    expect(jpg_deriv.content_type).to eq("image/jpeg")
  end

  it "deletes derivative file returned by block" do
    asset.create_derivatives

    expect(File.exist?(Kithe::Engine.root.join("spec/test_support/images/2x2_pixel-TEMP.jpg"))).not_to be(true)
  end

  it "by default saves in :kithe_derivatives storage" do
    asset.create_derivatives

    jpg_deriv = asset.derivatives.find {|d| d.key == "a_jpg"}
    expect(jpg_deriv.file.storage_key).to eq("kithe_derivatives")
  end


  describe "block arguments" do
    let(:monitoring_proc) do
      proc do |original_file, record:|
        expect(original_file.kind_of?(File) || original_file.kind_of?(Tempfile)).to be(true)
        expect(original_file.path).to be_present
        expect(original_file.read).to eq(asset.file.read)

        expect(record).to eq(asset)

        nil
      end
    end

    temporary_class("TestAssetSubclass") do
      our_proc = monitoring_proc
      Class.new(Kithe::Asset) do
        define_derivative(:some_data, &our_proc)
      end
    end

    it "as expected" do
      expect(monitoring_proc).to receive(:call).and_call_original

      asset.create_derivatives
      expect(asset.derivatives.length).to eq(0)
    end
  end

  describe "custom storage_key" do
    temporary_class("TestAssetSubclass") do
      Class.new(Kithe::Asset) do
        define_derivative(:some_data, storage_key: :store) do |original_file|
          StringIO.new("some one data")
        end
      end
    end
    it "saves appropriately" do
      asset.create_derivatives

      deriv = asset.derivatives.first

      expect(deriv).to be_present
      expect(deriv.file.storage_key).to eq("store")
    end
  end

  describe "default_create false" do
    let(:monitoring_proc) { proc { |asset| } }

    temporary_class("TestAssetSubclass") do
      p = monitoring_proc
      Class.new(Kithe::Asset) do
        define_derivative(:some_data, default_create: false, &p)
      end
    end

    it "is not run automatically" do
      expect(monitoring_proc).not_to receive(:call)
      asset.create_derivatives
    end
  end

end
