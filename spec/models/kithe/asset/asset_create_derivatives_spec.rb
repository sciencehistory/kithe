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
    ).tap do |a|
      # We want to promote without create_derivatives being automatically called
      # as usual, so we can test create_derivatives manually.
      a.file_attacher.set_promotion_directives(skip_callbacks: true)
      a.promote
    end
  end

  it "builds derivatives" do
    asset.create_derivatives

    one_deriv = asset.derivatives.find { |d| d.key == "some_data" }
    expect(one_deriv).to be_present
    expect(one_deriv.file.read).to eq("some one data")

    jpg_deriv = asset.derivatives.find {|d| d.key == "a_jpg"}
    expect(jpg_deriv.file.read).to eq(File.read(a_jpg_deriv_file, encoding: "BINARY"))
  end

  it "sets #derivatives_created?" do
    expect(asset.derivatives_created?).to be(false)
    asset.create_derivatives
    asset.reload
    expect(asset.derivatives_created?).to be(true)
  end

  describe "under normal operation", queue_adapter: :inline do
    let(:asset) do
      TestAssetSubclass.create!(title: "test",
        file: File.open(Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg")))
    end
    it "automatically creates derivatives" do
      expect(asset.derivatives.count).to eq(2)
    end
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
    expect(jpg_deriv.file.storage_key).to eq(:kithe_derivatives)
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
      expect(deriv.file.storage_key).to eq(:store)
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

  describe "only/except" do
    let(:monitoring_proc1) { proc { |asset| StringIO.new("one") } }
    let(:monitoring_proc2) { proc { |asset| StringIO.new("two") } }
    let(:monitoring_proc3) { proc { |asset| StringIO.new("three") } }

    temporary_class("TestAssetSubclass") do
      p1, p2, p3 = monitoring_proc1, monitoring_proc2, monitoring_proc3
      Class.new(Kithe::Asset) do
        define_derivative(:one, default_create: false, &p1)
        define_derivative(:two, &p2)
        define_derivative(:three, &p3)
      end
    end

    it "can call with only" do
      expect(monitoring_proc1).to receive(:call).and_call_original
      expect(monitoring_proc2).to receive(:call).and_call_original
      expect(monitoring_proc3).not_to receive(:call)

      asset.create_derivatives(only: [:one, :two])

      expect(asset.derivatives.collect(&:key)).to eq(["one", "two"])
    end

    it "can call with except" do
      expect(monitoring_proc1).not_to receive(:call)
      expect(monitoring_proc2).to receive(:call).and_call_original
      expect(monitoring_proc3).not_to receive(:call)

      asset.create_derivatives(except: [:three])

      expect(asset.derivatives.collect(&:key)).to eq(["two"])
    end

    it "can call with only and except" do
      expect(monitoring_proc1).to receive(:call).and_call_original
      expect(monitoring_proc2).not_to receive(:call)
      expect(monitoring_proc3).not_to receive(:call)

      asset.create_derivatives(only: [:one, :two], except: :two)

      expect(asset.derivatives.collect(&:key)).to eq(["one"])
    end
  end

  describe "content_type filters" do
    temporary_class("TestAssetSubclass") do
      Class.new(Kithe::Asset) do
        define_derivative(:never_called, content_type: "nothing/nothing") { |o| StringIO.new("never") }
        define_derivative(:gated_positive, content_type: "image/jpeg") { |o| StringIO.new("gated positive") }
        define_derivative(:gated_positive_main_type, content_type: "image") { |o| StringIO.new("gated positive") }
      end
    end

    it "does not call if content type does not match" do
      asset.create_derivatives
      expect(asset.derivatives.collect(&:key)).not_to include("never_called")
    end

    it "calls for exact content type match" do
      asset.create_derivatives
      expect(asset.derivatives.collect(&:key)).to include("gated_positive")
    end

    it "calls for main content type match" do
      asset.create_derivatives
      expect(asset.derivatives.collect(&:key)).to include("gated_positive_main_type")
    end

    describe "as array" do
      temporary_class("TestAssetSubclass") do
        Class.new(Kithe::Asset) do
          define_derivative(:never_called, content_type: ["nothing/nothing", "also/nothing"]) { |o| StringIO.new("never") }
          define_derivative(:gated_positive, content_type: ["image/jpeg", "something/else"]) { |o| StringIO.new("gated positive") }
        end
      end
      it "calls for one match" do
        asset.create_derivatives
        expect(asset.derivatives.collect(&:key)).to eq(["gated_positive"])
      end
    end

    describe "conflicting types" do
      let(:unfiltered) { proc { |asset| StringIO.new("unfiltered") } }
      let(:image) { proc { |asset| StringIO.new("image") } }
      let(:image_jpeg) { proc { |asset| StringIO.new("image/jpeg") } }


      temporary_class("TestAssetSubclass") do
        u, i, ij = unfiltered, image, image_jpeg
        Class.new(Kithe::Asset) do
          define_derivative(:key, &u)
          define_derivative(:key, content_type: "image/jpeg", &ij)
          define_derivative(:key, content_type: "image", &i)
        end
      end

      it "takes most specific" do
        expect(unfiltered).not_to receive(:call)
        expect(image).not_to receive(:call)
        expect(image_jpeg).to receive(:call).and_call_original

        asset.create_derivatives
        expect(asset.derivatives.count).to eq(1)

        deriv = asset.derivatives.first
        expect(deriv.key).to eq("key")
        expect(deriv.file.read). to eq("image/jpeg")
      end
    end
  end

  describe "lazy creation" do
    before do
      asset.class.derivative_definitions.collect(&:key).each do |key|
        asset.update_derivative(key, StringIO.new("#{key} original"))
      end
    end

    it "does not re-create" do
      derivatives_pre_creation = asset.derivatives.collect(&:attributes)

      asset.create_derivatives(lazy: true)
      derivatives_post_creation = asset.derivatives.reload.collect(&:attributes)

      expect(derivatives_post_creation).to eq(derivatives_pre_creation)
    end
  end

  describe "#remove_derivative_definition!" do
    it "can remove by string" do
      original_keys = TestAssetSubclass.defined_derivative_keys
      TestAssetSubclass.remove_derivative_definition!(original_keys.first.to_s)
      expect(TestAssetSubclass.defined_derivative_keys).to eq(original_keys.slice(1..original_keys.length))
    end
    it "can remove by symbol" do
      original_keys = TestAssetSubclass.defined_derivative_keys
      TestAssetSubclass.remove_derivative_definition!(original_keys.first.to_sym)
      expect(TestAssetSubclass.defined_derivative_keys).to eq(original_keys.slice(1..original_keys.length))
    end
    it "can remove multiple args" do
      original_keys = TestAssetSubclass.defined_derivative_keys
      TestAssetSubclass.remove_derivative_definition!(*original_keys)
      expect(TestAssetSubclass.defined_derivative_keys).to eq([])
    end
  end
end
