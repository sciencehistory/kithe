require 'rails_helper'

# We just test with a Kithe::Asset class, too much trouble to try to isolate, not
# worth it I think.
describe "Shrine::Plugins::KitheDerivativeDefinitions", queue_adapter: :test do
  # promotion inline, disable auto derivatives
  around do |example|
    original = Kithe::Asset.promotion_directives
    Kithe::Asset.promotion_directives = { promote: :inline, create_derivatives: false }

    example.run
    Kithe::Asset.promotion_directives = original
  end

  let(:a_jpg_deriv_file) { Kithe::Engine.root.join("spec/test_support/images/2x2_pixel.jpg") }

  temporary_class("CustomUploader") do
    deriv_src_path = a_jpg_deriv_file

    Class.new(Kithe::AssetUploader) do
      self::Attacher.define_derivative(:some_data) do |original_file|
        StringIO.new("some one data")
      end

      self::Attacher.define_derivative(:a_jpg) do |original_file|
        FileUtils.cp(deriv_src_path,
             Kithe::Engine.root.join("spec/test_support/images/2x2_pixel-TEMP.jpg"))

        File.open(Kithe::Engine.root.join("spec/test_support/images/2x2_pixel-TEMP.jpg"))
      end
    end
  end

  temporary_class("CustomAsset") do
    Class.new(Kithe::Asset) do
      set_shrine_uploader(CustomUploader)
    end
  end

  let(:asset) do
    CustomAsset.create(title: "test",
      file: File.open(Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg"))
    )
  end

  it "builds derivatives" do
    asset.file_attacher.create_derivatives(:kithe_derivatives)

    one_deriv = asset.file_derivatives[:some_data]
    expect(one_deriv).to be_present
    expect(one_deriv.read).to eq("some one data")

    jpg_deriv = asset.file_derivatives[:a_jpg]
    expect(jpg_deriv.read).to eq(File.binread(a_jpg_deriv_file))
    expect(jpg_deriv.storage_key).to eq(:kithe_derivatives)
  end

  describe "record argument to block" do
    let(:monitoring_proc) do
      proc do |original_file, record:|
        expect(original_file.kind_of?(File) || original_file.kind_of?(Tempfile)).to be(true)
        expect(original_file.path).to be_present
        expect(original_file.read).to eq(asset.file.read)

        expect(record).to eq(asset)

        nil
      end
    end

    before do
      # hacky confusing way to set this up for testing, sorry.
      CustomUploader::Attacher.kithe_derivative_definitions = []
      CustomUploader::Attacher.define_derivative(:some_data, &monitoring_proc)
    end

    it "as expected" do
      expect(monitoring_proc).to receive(:call).and_call_original

      asset.file_attacher.create_derivatives(:kithe_derivatives)
      expect(asset.derivatives.length).to eq(0)
    end

    describe "as **kwargs" do
      let(:monitoring_proc) do
        proc do |original_file, **kwargs|
          expect(original_file.kind_of?(File) || original_file.kind_of?(Tempfile)).to be(true)
          expect(original_file.path).to be_present
          expect(original_file.read).to eq(asset.file.read)

          expect(kwargs[:record]).to eq(asset)

          nil
        end
      end

      it "as expected" do
        expect(monitoring_proc).to receive(:call).and_call_original

        asset.file_attacher.create_derivatives(:kithe_derivatives)
        expect(asset.derivatives.length).to eq(0)
      end
    end
  end


  describe "default_create false" do
    let(:monitoring_proc) { proc { |asset| } }

    before do
      # hacky confusing way to set this up for testing, sorry.
      CustomUploader::Attacher.kithe_derivative_definitions = []
      CustomUploader::Attacher.define_derivative(:some_data, default_create: false, &monitoring_proc)
    end

    it "is not run automatically" do
      expect(monitoring_proc).not_to receive(:call)
      asset.file_attacher.create_derivatives(:kithe_derivatives)
    end
  end

  describe "only/except" do
    let(:monitoring_proc1) { proc { |asset| StringIO.new("one") } }
    let(:monitoring_proc2) { proc { |asset| StringIO.new("two") } }
    let(:monitoring_proc3) { proc { |asset| StringIO.new("three") } }

    before do
      # hacky confusing way to set this up for testing, sorry.
      CustomUploader::Attacher.kithe_derivative_definitions = []
      CustomUploader::Attacher.define_derivative(:one, default_create: false, &monitoring_proc1)
      CustomUploader::Attacher.define_derivative(:two, &monitoring_proc2)
      CustomUploader::Attacher.define_derivative(:three, &monitoring_proc2)
    end

    it "can call with only" do
      expect(monitoring_proc1).to receive(:call).and_call_original
      expect(monitoring_proc2).to receive(:call).and_call_original
      expect(monitoring_proc3).not_to receive(:call)

      asset.file_attacher.create_derivatives(:kithe_derivatives, only: [:one, :two])

      expect(asset.file_derivatives.keys).to match([:one, :two])
    end

    it "can call with except" do
      expect(monitoring_proc1).not_to receive(:call)
      expect(monitoring_proc2).to receive(:call).and_call_original
      expect(monitoring_proc3).not_to receive(:call)

      asset.file_attacher.create_derivatives(:kithe_derivatives, except: [:three])

      expect(asset.file_derivatives.keys).to eq([:two])
    end

    it "can call with only and except" do
      expect(monitoring_proc1).to receive(:call).and_call_original
      expect(monitoring_proc2).not_to receive(:call)
      expect(monitoring_proc3).not_to receive(:call)

      asset.file_attacher.create_derivatives(:kithe_derivatives, only: [:one, :two], except: :two)

      expect(asset.file_derivatives.keys).to eq([:one])
    end
  end


  describe "content_type filters" do
    before do
      # hacky confusing way to set this up for testing, sorry.
      CustomUploader::Attacher.kithe_derivative_definitions = []
      CustomUploader::Attacher.define_derivative(:never_called, content_type: "nothing/nothing") { |o| StringIO.new("never") }
      CustomUploader::Attacher.define_derivative(:gated_positive, content_type: "image/jpeg") { |o| StringIO.new("gated positive") }
      CustomUploader::Attacher.define_derivative(:gated_positive_main_type, content_type: "image") { |o| StringIO.new("gated positive") }
    end

    it "does not call if content type does not match" do
      asset.file_attacher.create_derivatives(:kithe_derivatives)
      expect(asset.file_derivatives.keys).not_to include(:never_called)
    end

    it "calls for exact content type match" do
      asset.file_attacher.create_derivatives(:kithe_derivatives)
      expect(asset.file_derivatives.keys).to include(:gated_positive)
    end

    it "calls for main content type match" do
      asset.file_attacher.create_derivatives(:kithe_derivatives)
      expect(asset.file_derivatives.keys).to include(:gated_positive_main_type)
    end

    describe "as array" do
      before do
        # hacky confusing way to set this up for testing, sorry.
        CustomUploader::Attacher.kithe_derivative_definitions = []
        CustomUploader::Attacher.define_derivative(:never_called, content_type: ["nothing/nothing", "also/nothing"]) { |o| StringIO.new("never") }
        CustomUploader::Attacher.define_derivative(:gated_positive, content_type: ["image/jpeg", "something/else"]) { |o| StringIO.new("gated positive") }
      end

      it "calls for one match" do
        asset.file_attacher.create_derivatives(:kithe_derivatives)
        expect(asset.file_derivatives.keys).to eq([:gated_positive])
      end
    end

    describe "conflicting types" do
      let(:unfiltered) { proc { |asset| StringIO.new("unfiltered") } }
      let(:image) { proc { |asset| StringIO.new("image") } }
      let(:image_jpeg) { proc { |asset| StringIO.new("image/jpeg") } }

      before do
        # hacky confusing way to set this up for testing, sorry.
        CustomUploader::Attacher.kithe_derivative_definitions = []
        CustomUploader::Attacher.define_derivative(:key, &unfiltered)
        CustomUploader::Attacher.define_derivative(:key, content_type: "image/jpeg", &image_jpeg)
        CustomUploader::Attacher.define_derivative(:key, content_type: "image", &image)
      end

      it "takes most specific" do
        expect(unfiltered).not_to receive(:call)
        expect(image).not_to receive(:call)
        expect(image_jpeg).to receive(:call).and_call_original

        asset.file_attacher.create_derivatives(:kithe_derivatives)
        expect(asset.file_derivatives.count).to eq(1)


        expect(asset.file_derivatives.keys).to eq([:key])
        expect(asset.file_derivatives[:key].read). to eq("image/jpeg")
      end
    end
  end

  describe "lazy creation" do
    before do
      # Create existing derivatives for existing definitions, which we assume exist
      expect(CustomUploader::Attacher.kithe_derivative_definitions).to be_present
      CustomUploader::Attacher.kithe_derivative_definitions.collect(&:key).each do |key|
        asset.file_attacher.add_persisted_derivatives({key => StringIO.new("#{key} original")})
      end
    end

    it "does not re-create" do
      derivatives_pre_creation = asset.file_derivatives

      asset.file_attacher.create_derivatives(:kithe_derivatives, lazy: true)
      derivatives_post_creation = asset.file_derivatives

      expect(derivatives_post_creation).to eq(derivatives_pre_creation)
    end
  end

  describe "#remove_derivative_definition!" do
    let(:defined_derivative_key) do
      CustomUploader::Attacher.defined_derivative_keys.first.tap do |key|
        expect(key).to be_present
      end
    end

    it "can remove by string" do
      expect {
        CustomUploader::Attacher.remove_derivative_definition!(defined_derivative_key.to_s)
      }.to change { CustomUploader::Attacher.defined_derivative_keys.count }.from(2).to(1)
    end

    it "can remove by symbol" do
      expect {
        CustomUploader::Attacher.remove_derivative_definition!(defined_derivative_key.to_sym)
      }.to change { CustomUploader::Attacher.defined_derivative_keys.count }.from(2).to(1)
    end

    it "can remove multiple args" do
      CustomUploader::Attacher.remove_derivative_definition!(*CustomUploader::Attacher.defined_derivative_keys)
      expect(CustomUploader::Attacher.defined_derivative_keys).to eq([])
    end
  end
end
