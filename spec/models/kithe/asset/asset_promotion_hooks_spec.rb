require 'rails_helper'

describe "Kithe::Asset promotion hooks", queue_adapter: :inline do
  temporary_class("TestAsset") do
    Class.new(Kithe::Asset) do
    end
  end

  let(:unsaved_asset) {
    TestAsset.new(title: "test",
      file: File.open(Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg"))
    )
  }

  describe "before_promotion" do
    temporary_class("TestAsset") do
      Class.new(Kithe::Asset) do
        before_promotion do
          $metadata_in_before_promotion = self.file.metadata
        end
      end
    end
    before do
      $metadata_in_before_promotion = nil
    end

    # we have a built-in before_promotion for metadata extraction,
    # make sure it happens before any additional before_promotions,
    # so they can eg use it to cancel
    it "has access to automatic metadata extraction" do
      unsaved_asset.save!
      expect($metadata_in_before_promotion).to be_present
    end
  end

  describe "with multiple before_promotion and metadata hooks" do
    before do
      $file_paths = {}
    end

    temporary_class("CustomUploader") do
      Class.new(Kithe::AssetUploader) do
        add_metadata do |source_io|
          Shrine.with_file(source_io) do |file|
            $file_paths[:metadata1] = file.path
          end

          nil
        end

        add_metadata do |source_io|
          Shrine.with_file(source_io) do |file|
            $file_paths[:metadata2] = file.path
          end

          nil
        end
      end
    end

    temporary_class("TestAsset") do
      Class.new(Kithe::Asset) do
        set_shrine_uploader(CustomUploader)

        before_promotion do
          Shrine.with_file(self.file) do |file|
            $file_paths[:before_promotion1] = file.path
          end
        end

        before_promotion do
          Shrine.with_file(self.file) do |file|
            $file_paths[:before_promotion2] = file.path
          end
        end
      end
    end

    before do
      # very hacky way to temporarily add :tempfile plugin to `Shrine` global.
      # Hacky but it works!

      new_shrine = Shrine.dup
      new_shrine.plugin :tempfile

      stub_const("Shrine", new_shrine)
    end

    it "they share a tempfile when using Shrine.with_file and tempfile plugin" do
      unsaved_asset # create but don't save yet

      # We want to make sure the internal shrine io is properly closed, but
      # we have really NO way to reach it but this hack.
      allow_any_instance_of(Shrine::UploadedFile).to receive(:open).and_wrap_original do |original_method, *args, &block|
        $opened_io = original_method.call(*args, &block)
      end

      unsaved_asset.save!

      expect($opened_io.closed?).to be true
      expect($file_paths.values.uniq.count).to eq 1
    end

    it "share a tempfile even if previously manually opened file" do
      orig_io = nil

      unsaved_asset.file.open do |file|
        orig_io = unsaved_asset.file.to_io
        unsaved_asset.save!
      end

      expect($file_paths.values.uniq.count).to eq 1
      expect(orig_io.closed?).to be true
    end
  end

  describe "before_promotion cancellation" do
    temporary_class("TestAsset") do
      Class.new(Kithe::Asset) do
        before_promotion do
          throw :abort
        end

        after_promotion do
          raise "Should not get here"
        end
      end
    end

    describe "with inline promotion", queue_adapter: :test do
      before do
        unsaved_asset.file_attacher.set_promotion_directives(promote: :inline)
      end

      it "cancels" do
        expect_any_instance_of(Kithe::AssetUploader::Attacher).not_to receive(:promote)

        unsaved_asset.save!
        unsaved_asset.reload
        expect(unsaved_asset.reload.stored?).to be(false)
      end

      describe "with promotion_directives[:skip_callbacks]" do
        it "doesn't cancel" do
          expect_any_instance_of(Kithe::AssetUploader::Attacher).to receive(:promote).and_call_original

          unsaved_asset.file_attacher.set_promotion_directives(skip_callbacks: true)
          unsaved_asset.save!
          unsaved_asset.reload

          expect(unsaved_asset.stored?).to be(true)
        end
      end
    end

    describe "with backgrounding promotion", queue_adapter: :inline do
      it "cancels" do
        expect_any_instance_of(Kithe::AssetUploader::Attacher).not_to receive(:promote)

        unsaved_asset.save!
        unsaved_asset.reload
        expect(unsaved_asset.stored?).to be(false)
      end

      describe "with promotion_directives[:skip_callbacks]" do
        it "doesn't cancel" do
          expect_any_instance_of(Kithe::AssetUploader::Attacher).to receive(:promote).and_call_original

          unsaved_asset.file_attacher.set_promotion_directives(skip_callbacks: true)
          unsaved_asset.save!
          unsaved_asset.reload

          expect(unsaved_asset.stored?).to be(true)
        end
      end
    end


    describe "assigning directly to store" do
      temporary_class("TestAsset") do
        Class.new(Kithe::Asset) do
          before_promotion do
            raise "Should not call before_promotion"
          end

          after_promotion do
            raise "Should not call after_promotion"
          end
        end
      end

      let(:asset) {
        TestAsset.create(title: "test")
      }

      let(:filepath) { Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg") }

      describe "with inline promoting" do
        before do
          asset.file_attacher.set_promotion_directives(promote: :inline)
        end

        it "should not call callbacks" do
          expect_any_instance_of(Kithe::AssetUploader::Attacher).not_to receive(:promote)

          asset.file_attacher.attach(File.open(filepath))
          asset.save!

          expect(asset.changed?).to be(false)
          asset.reload
          expect(asset.file).to be_present
          expect(asset.stored?).to be(true)
        end
      end

      describe "with background promoting", queue_adapter: :inline do
        before do
          asset.file_attacher.set_promotion_directives(promote: :background)
        end

        it "should not call callbacks" do
          expect_any_instance_of(Kithe::AssetUploader::Attacher).not_to receive(:promote)

          asset.file_attacher.attach(File.open(filepath))
          asset.save!

          expect(asset.changed?).to be(false)
          asset.reload
          expect(asset.file).to be_present
          expect(asset.stored?).to be(true)
        end
      end
    end


    describe "calling Asset#promote directly", queue_adapter: :inline do
      before do
        unsaved_asset.file_attacher.set_promotion_directives(promote: false)
        unsaved_asset.save!
        # precondition
        expect(unsaved_asset.reload.file_attacher.cached?).to be(true)
      end

      it "cancels" do
        expect_any_instance_of(Kithe::AssetUploader::Attacher).not_to receive(:promote)

        unsaved_asset.promote
        unsaved_asset.reload
        expect(unsaved_asset.stored?).to be(false)
      end

      describe "with promotion_directives[:skip_callbacks]" do
        it "doesn't cancel" do
          expect_any_instance_of(Kithe::AssetUploader::Attacher).to receive(:promote).and_call_original

          unsaved_asset.file_attacher.set_promotion_directives(skip_callbacks: true)
          unsaved_asset.promote
          unsaved_asset.reload

          expect(unsaved_asset.stored?).to be(true)
        end
      end
    end
  end

  describe "after_promotion" do
    let(:after_promotion_receiver) { proc {} }

    temporary_class("TestAsset") do
      receiver = after_promotion_receiver
      Class.new(Kithe::Asset) do
        after_promotion do
          receiver.call(self)
        end
      end
    end

    it "is called" do
      expect(after_promotion_receiver).to receive(:call)
      unsaved_asset.save!
    end

    describe "with inline promotion" do
      before do
        unsaved_asset.file_attacher.set_promotion_directives(promote: :inline)
      end

      # this is actually what's checking for following example...
      let(:after_promotion_receiver) do
        proc do |asset|
          expect(asset.changed?).to be(false)

          asset.reload

          expect(asset.stored?).to be(true)
        end
      end

      it "asset has metadata and is finalized" do
        expect(after_promotion_receiver).to receive(:call).and_call_original
        unsaved_asset.save!
      end
    end

    describe "with promotion_directives[:skip_callbacks]" do
      it "doesn't call" do
        expect(after_promotion_receiver).not_to receive(:call)

        unsaved_asset.file_attacher.set_promotion_directives(skip_callbacks: true)
        unsaved_asset.save!
      end
    end
  end

  describe "around_promotion" do
    let(:before_receiver) { proc { expect(self.stored?).to be(false) }}
    let(:after_receiver) { proc { expect(self.stored?).to be(true) }}

    temporary_class("TestAsset") do
      Class.new(Kithe::Asset) do
        around_promotion :my_around_promotion

        def my_around_promotion
          yield
        end
      end
    end

    it "is called" do
      expect_any_instance_of(TestAsset).to receive(:my_around_promotion).once.and_call_original
      unsaved_asset.save!
      unsaved_asset.reload
      expect(unsaved_asset.stored?).to be(true)
    end
  end

  describe "promotion_directive :promote", queue_adapter: :test do
    temporary_class("TestUploader") do
      Class.new(Kithe::AssetUploader) do
        self::Attacher.define_derivative :test do
          # no-op, but we need a definition so will be scheduled
        end
      end
    end

    temporary_class("TestAsset") do
      Class.new(Kithe::Asset) do
        set_shrine_uploader(TestUploader)
      end
    end

    it "can cancel promotion" do
      expect_any_instance_of(Kithe::AssetUploader::Attacher).not_to receive(:promote)

      unsaved_asset.file_attacher.set_promotion_directives(promote: false)

      unsaved_asset.save!
      unsaved_asset.reload

      expect(unsaved_asset.stored?).to be(false)

      expect(Kithe::AssetPromoteJob).not_to have_been_enqueued
      expect(Kithe::CreateDerivativesJob).not_to have_been_enqueued
    end

    it "can force promotion in foreground" do
      unsaved_asset.file_attacher.set_promotion_directives(promote: :inline)

      unsaved_asset.save!
      unsaved_asset.reload

      expect(unsaved_asset.stored?).to be(true)
      expect(Kithe::AssetPromoteJob).not_to have_been_enqueued
      expect(Kithe::CreateDerivativesJob).to have_been_enqueued
      expect(ActiveJob::Base.queue_adapter.performed_jobs.size).to eq(0)
    end

    it "raises on unrecgonized value" do
      unsaved_asset.file_attacher.set_promotion_directives(promote: :something)
      expect {
        unsaved_asset.save!
      }.to raise_error(ArgumentError)
    end

    describe ", create_derivatives: false" do
      it "does not create derivatives" do
        expect_any_instance_of(Kithe::Asset).not_to receive(:create_derivatives)

        unsaved_asset.file_attacher.set_promotion_directives(promote: :inline, create_derivatives: false)

        unsaved_asset.save!
        unsaved_asset.reload

        expect(Kithe::AssetPromoteJob).not_to have_been_enqueued
        expect(Kithe::CreateDerivativesJob).not_to have_been_enqueued
        expect(ActiveJob::Base.queue_adapter.performed_jobs.size).to eq(0)
      end
    end

    describe ", create_derivatives: :inline" do
      it "creates derivatives inline" do
        expect_any_instance_of(Kithe::Asset).to receive(:create_derivatives)

        unsaved_asset.file_attacher.set_promotion_directives(promote: :inline, create_derivatives: :inline)

        unsaved_asset.save!
        unsaved_asset.reload

        expect(Kithe::AssetPromoteJob).not_to have_been_enqueued
        expect(Kithe::CreateDerivativesJob).not_to have_been_enqueued
        expect(ActiveJob::Base.queue_adapter.performed_jobs.size).to eq(0)
      end
    end
  end

  describe "promotion_directive :delete", queue_adapter: :test do
    let(:saved_asset) do
      TestAsset.new(title: "test",
        file: File.open(Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg"))
      ).tap do |asset|
        asset.set_promotion_directives(promote: "inline")
        asset.save!
        asset.reload
        expect(asset.stored?).to be(true)
      end
    end

    let!(:existing_file) {  saved_asset.file }

    it "can cancel deletion" do
      expect_any_instance_of(Kithe::AssetUploader::Attacher).not_to receive(:destroy)


      saved_asset.set_promotion_directives(delete: false)
      saved_asset.destroy!

      expect(Kithe::AssetDeleteJob).not_to have_been_enqueued
      expect(existing_file.exists?).to be(true)
    end

    it "can force deletion in foreground" do
      saved_asset.set_promotion_directives(delete: :inline)
      saved_asset.destroy!

      expect(existing_file.exists?).to be(false)
      expect(Kithe::AssetDeleteJob).not_to have_been_enqueued
      expect(ActiveJob::Base.queue_adapter.performed_jobs.size).to eq(0)
    end
  end

  describe "unrecognized promotion directive" do
    it "raises" do
      expect {
        unsaved_asset.file_attacher.set_promotion_directives(:bad_made_up => true)
      }.to raise_error(ArgumentError)
    end
  end

  describe "delegated from asset" do
    around do |example|
      original_class_settings = Kithe::Asset.promotion_directives
      example.run
      Kithe::Asset.promotion_directives = original_class_settings
    end

    it "can set from class attribute" do
      Kithe::Asset.promotion_directives = { promote: :inline }
      asset = Kithe::Asset.new
      expect(asset.file_attacher.promotion_directives).to eq("promote" => "inline")
    end

    it "can set from instance writer" do
      asset = Kithe::Asset.new
      asset.set_promotion_directives(promote: :inline)
      expect(asset.file_attacher.promotion_directives).to eq("promote" => "inline")
      expect(asset.promotion_directives).to eq("promote" => "inline")
    end

    it "setting from instance writer is aggregative" do
      Kithe::Asset.promotion_directives = { promote: :inline }
      asset = Kithe::Asset.new
      asset.set_promotion_directives(create_derivatives: false)
      expect(asset.file_attacher.promotion_directives).to eq("promote" => "inline", "create_derivatives" => "false")
    end

    it "setting from instance writer survives reload" do
      asset = Kithe::Asset.create(title: "test")
      asset.set_promotion_directives(create_derivatives: false)
      expect(asset.file_attacher.promotion_directives).to eq("create_derivatives" => "false")

      asset.reload

      expect(asset.file_attacher.promotion_directives).to eq("create_derivatives" => "false")
    end

  end
end
