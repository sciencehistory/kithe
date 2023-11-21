require 'rails_helper'

describe "Kithe::Asset#kithe_earlier_after_commit" do
  let(:sample_image_path) { Kithe::Engine.root + "spec/test_support/images/1x1_pixel.jpg" }

  describe "ordering against shrine's activerecord after_commit" do
    before do
      $called_before_promotion = false
    end

    temporary_class("CustomAsset") do
      Class.new(Kithe::Asset) do
        kithe_earlier_after_commit :my_earlier_after_commit

        def my_earlier_after_commit
        end
      end
    end

    let!(:asset) { CustomAsset.create!(title: "test") }

    it "calls my_earlier_after_commit before promotion" do
      asset.set_promotion_directives(promote: :inline)

      called_pre_promotion = false

      # our hook gets called lots of times, but as long as it was called at least
      # once before promotion... that fails with just `after_commit`, `kithe_earlier_after_commit`
      # is needed to make sure we're getting called first.
      allow(asset).to receive(:my_earlier_after_commit) do
        if !asset.file_attacher.stored?
          called_pre_promotion = true
        end
      end

      asset.file = File.open(Kithe::Engine.root + "spec/test_support/images/1x1_pixel.jpg")
      asset.save!

      expect(called_pre_promotion).to be true
    end
  end

  describe "ordering of custom after_commits" do
    temporary_class("ParentAsset") do
      Class.new(Kithe::Asset) do
        after_commit :parent_after_commit

        def parent_after_commit
        end
      end
    end

    temporary_class("ChildAsset") do
      Class.new(ParentAsset) do
        kithe_earlier_after_commit :child_earlier_after_commit

        def child_earlier_after_commit
        end
      end
    end

    let!(:child_asset) { ChildAsset.create(title: "child")}

    it "calls earlier_after_commit first" do
      expect(child_asset).to receive(:child_earlier_after_commit).ordered
      expect(child_asset).to receive(:parent_after_commit).ordered

      child_asset.title = "new title"
      child_asset.save!
    end
  end
end
