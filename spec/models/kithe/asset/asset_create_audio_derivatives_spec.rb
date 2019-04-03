require 'rails_helper'

describe "Kithe::Asset derivative definitions", queue_adapter: :test do
  let(:a_webm_deriv_file) { Kithe::Engine.root.join("spec/test_support/audio/webm_deriv.webm") }

  temporary_class("TestAssetSubclass") do
    deriv_src_path = a_webm_deriv_file
    Class.new(Kithe::Asset) do


      define_derivative(:a_webm_file) do |original_file|
        FileUtils.cp(deriv_src_path,
             Kithe::Engine.root.join("spec/test_support/audio/webm_deriv-TEMP.webm"))
        File.open(Kithe::Engine.root.join("spec/test_support/audio/webm_deriv-TEMP.webm"))
      end
    end
  end

  let(:asset) do
    TestAssetSubclass.create(title: "test",
      file: File.open(Kithe::Engine.root.join("spec/test_support/audio/mp3_sample.mp3"))
    ).tap do |a|
      # We want to promote without create_derivatives being automatically called
      # as usual, so we can test create_derivatives manually.
      a.file_attacher.set_promotion_directives(skip_callbacks: true)
      a.promote
    end
  end

  it "builds derivatives" do
    asset.create_derivatives

    webm_deriv = asset.derivatives.find {|d| d.key == "a_webm_file"}
    expect(webm_deriv.file.read).to eq(File.read(a_webm_deriv_file, encoding: "BINARY"))
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
        file: File.open(Kithe::Engine.root.join("spec/test_support/audio/mp3_sample.mp3")))
    end
    it "automatically creates derivatives" do
      expect(asset.derivatives.count).to eq(1)
    end
  end

  it "extracts limited metadata from derivative" do
    asset.create_derivatives
    webm_deriv = asset.derivatives.find {|d| d.key == "a_webm_file"}
    expect(webm_deriv.size).to eq(File.size(Kithe::Engine.root.join("spec/test_support/audio/webm_deriv.webm")))
    # TODO: fix this: the code currently saves the mimetype as video/webm.
    #expect(webm_deriv.content_type).to eq("audio/webm")
  end


  it "by default saves in :kithe_derivatives storage" do
    asset.create_derivatives
    webm_deriv = asset.derivatives.find {|d| d.key == "a_webm_file"}
    expect(webm_deriv.file.storage_key).to eq("kithe_derivatives")
  end

end
