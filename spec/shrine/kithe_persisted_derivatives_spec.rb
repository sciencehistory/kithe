require 'rails_helper'
require 'shrine/plugins/kithe_persisted_derivatives'

# We just test with a Kithe::Asset class, too much trouble to try to isolate, not
# worth it I think.
describe Shrine::Plugins::KithePersistedDerivatives, queue_adapter: :test do
  # promotion inline, disable auto derivatives
  around do |example|
    original = Kithe::Asset.promotion_directives
    Kithe::Asset.promotion_directives = { promote: :inline, create_derivatives: false }

    example.run
    Kithe::Asset.promotion_directives = original
  end

  # Need to make a new copy, because shrine likes deleting derivatives!
  def sample_deriv_file!(path = Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg"))
    tempfile = Tempfile.new
    IO.copy_stream(File.open(path), tempfile)

    tempfile
  end

  let(:sample_orig_path) { Kithe::Engine.root.join("spec/test_support/images/2x2_pixel.jpg") }
  let(:another_sample_orig_path) { Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg") }

  let(:asset) { Kithe::Asset.create!(title: "test", file: File.open(sample_orig_path))}

  describe "#add_persisted_derivatives" do
    it "can add and persist" do
      asset.file_attacher.add_persisted_derivatives(sample: sample_deriv_file!)

      expect(asset.changed?).to be(false)
      expect(asset.file_derivatives[:sample]).to be_present
      expect(asset.file_derivatives[:sample].storage_key).to eq(:kithe_derivatives)
      expect(asset.file_derivatives[:sample].exists?).to be(true)

      # sanity check
      asset.reload
      expect(asset.file_derivatives[:sample]).to be_present
    end

    it "can avoid deleting deriv file" do
      file = sample_deriv_file!
      asset.file_attacher.add_persisted_derivatives({sample: file}, delete: false)

      expect(File.exists?(file.path)).to eq(true)
    end

    it "can use custom storage" do
      file = sample_deriv_file!
      asset.file_attacher.add_persisted_derivatives({sample: file}, storage: :cache)

      asset.reload
      expect(asset.file_derivatives[:sample]).to be_present
      expect(asset.file_derivatives[:sample].storage_key).to eq(:cache)
    end

    it "can supply custom metadata" do
      file = sample_deriv_file!
      asset.file_attacher.add_persisted_derivatives({sample: file}, metadata: { extra: "value" })

      asset.reload

      expect(asset.file_derivatives[:sample].metadata["extra"]).to eq("value")
      # and still has default metadata
      expect(asset.file_derivatives[:sample].metadata["size"]).to be_present
    end

    describe "model with unsaved changes" do
      before do
        asset.title = "changed title"
      end

      it "will refuse" do
        expect {
          asset.file_attacher.add_persisted_derivatives(sample: sample_deriv_file!)
        }.to raise_error(TypeError)
      end

      it "can be forced" do
        asset.file_attacher.add_persisted_derivatives({sample: sample_deriv_file!}, allow_other_changes: true)

        expect(asset.changed?).to be(false)
        asset.reload
        expect(asset.title).to eq("changed title")
        expect(asset.file_derivatives[:sample]).to be_present
      end
    end

    describe "unsaved model" do
      let(:asset) { Kithe::Asset.new(title: "test", file: File.open(sample_orig_path)) }

      it "refuses even with other_changes: true" do
        expect {
          asset.file_attacher.add_persisted_derivatives({sample: sample_deriv_file!}, allow_other_changes: true)
        }.to raise_error(TypeError)
      end
    end

    describe "Original deleted before derivatives can be created" do
      before do
        # delete it out from under us
        Kithe::Model.where(id: asset.id).delete_all
      end

      it "doesn't complain and cleans up file" do

        # asset is no longer in the DB.
        # Let's try and create derivatives for it:
        file = sample_deriv_file!
        local_file_path = file.path

        expect(asset.file_attacher.add_persisted_derivatives(sample: file)).to be(false)

        expect(File.exist?(local_file_path)).to be(false)
      end
    end

    describe "Original changed before derivatives can be created" do
      before do
        asset # load

        # Change what's in the db for this asset, without changing the in-memory
        # asset
        another_copy = Kithe::Asset.find(asset.id)
        another_copy.file = File.open(another_sample_orig_path)
        another_copy.save!
      end

      it "doesn't add derivative and cleans up file" do
        # asset in DB has different file attachment
        # Let's try and create derivatives for it:
        file = sample_deriv_file!
        local_file_path = file.path

        expect(asset.file_attacher.add_persisted_derivatives(new_try: file)).to be(false)


        expect(asset.changed?).to be(false)
        expect(asset.file_derivatives[:new_try]).to be_nil
        asset.reload
        expect(asset.file_derivatives[:new_try]).to be_nil

        expect(File.exist?(local_file_path)).to be(false)
      end
    end

    describe "concurrent derivative changes" do
      let(:original_one) { sample_deriv_file!(Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg")) }
      let(:original_two) { sample_deriv_file!(Kithe::Engine.root.join("spec/test_support/images/2x2_pixel.jpg")) }

      let(:new_two) { sample_deriv_file!(Kithe::Engine.root.join("spec/test_support/images/3x3_pixel.jpg")) }
      let(:new_three) { sample_deriv_file!(Kithe::Engine.root.join("spec/test_support/images/3x3_pixel.jpg")) }

      before do
        # make sure our test is setup to test what we want
        original_two.rewind; new_two.rewind
        expect(original_two.read).not_to eq(new_two.read)
        original_two.rewind; new_two.rewind

        asset # load

        # change what derivatives are in db for this asset, without changing
        # the in-memory asset
        another_copy = Kithe::Asset.find(asset.id)
        another_copy.file_attacher.add_derivatives({
          one: original_one,
          two: original_two
        }, delete: false)
        another_copy.save!

        # Make sure we set up what we expected
        another_copy.reload
        expect(another_copy.file_derivatives[:one]).to be_present
        expect(another_copy.file_derivatives[:two]).to be_present
      end

      it "merges changes in safely" do
        expect(asset.file_derivatives.keys).to be_empty

        asset.file_attacher.add_persisted_derivatives({two: new_two, three: new_three}, delete: false)

        expect(asset.changed?).to be(false)
        expect(asset.file_derivatives.keys).to match([:one, :two, :three])
        expect(asset.file_derivatives[:two].read).to eq(File.binread(new_two.path))
        expect(asset.file_derivatives[:three].read).to eq(File.binread(new_three.path))
      end
    end
  end

  describe "#create_persisted_derivatives" do
    temporary_class("AssetSubclassUploader") do
      call_fakeio = method(:fakeio) # weird closure issue

      Class.new(Kithe::AssetUploader) do
        self::Attacher.derivatives do |original, **options|
          {
            one: call_fakeio.("one"),
            two: call_fakeio.("two")
          }
        end

        self::Attacher.derivatives(:options) do |original, **options|
          {
            options_one: call_fakeio.("one"),
            options_reflected: call_fakeio.(options.to_s)
          }
        end
      end
    end

    temporary_class("AssetSubclass") do
      Class.new(Kithe::Asset) do
        set_shrine_uploader(AssetSubclassUploader)
      end
    end

    let(:asset) { AssetSubclass.create!(title: "test", file: File.open(sample_orig_path))}

    it "creates derivatives" do
      # we're not gonna test concurrency safety, counting on add_persisted_derivatives
      # for that, but let's make sure
      expect(asset.file_attacher).to receive(:add_persisted_derivatives).and_call_original

      asset.file_attacher.create_persisted_derivatives

      expect(asset.changed?).to be(false)
      expect(asset.file_derivatives.keys).to match([:one, :two])
      asset.reload
      expect(asset.file_derivatives[:one].read).to eq("one")
      expect(asset.file_derivatives[:one].storage_key).to eq(:kithe_derivatives)
      expect(asset.file_derivatives[:two].read).to eq("two")
      expect(asset.file_derivatives[:two].storage_key).to eq(:kithe_derivatives)
    end

    it "can call custom processor" do
      asset.file_attacher.create_persisted_derivatives(:options)

      expect(asset.file_derivatives.keys).to match([:options_one, :options_reflected])
    end

    it "can pass processor options" do
      asset.file_attacher.create_persisted_derivatives(:options, arg1: "value1", arg2: "value2")

      expect(asset.file_derivatives[:options_reflected].read).to eq({arg1: "value1", arg2: "value2"}.to_s)
    end

    it "can customize :storage" do
      asset.file_attacher.create_persisted_derivatives(:options, storage: :cache, arg1: "value1", arg2: "value2")

      expect(asset.file_derivatives[:options_reflected].read).to eq({arg1: "value1", arg2: "value2"}.to_s)
      expect(asset.file_derivatives[:options_reflected].storage_key).to eq(:cache)
    end

    describe "model with unsaved changes" do
      before do
        asset.title = "changed title"
      end

      it "will refuse" do
        expect {
          asset.file_attacher.create_persisted_derivatives
        }.to raise_error(TypeError)
      end

      it "can be forced" do
        asset.file_attacher.create_persisted_derivatives(allow_other_changes: true)

        expect(asset.changed?).to be(false)
        asset.reload
        expect(asset.title).to eq("changed title")
        expect(asset.file_derivatives.keys).to match([:one, :two])
      end
    end
  end

  describe "#remove_persisted_derivatives" do
    before do
      asset.file_attacher.add_persisted_derivatives(
        sample1: fakeio("sample 1"),
        sample2: fakeio("sample 2")
      )
    end

    it "can remove" do
      removed = asset.file_attacher.remove_persisted_derivatives(:sample1)

      expect(asset.changed?).to eq(false)
      expect(asset.file_derivatives.keys).to eq([:sample2])
      asset.reload
      expect(asset.file_derivatives.keys).to eq([:sample2])

      expect(removed).to be_kind_of(Array)
      expect(removed.length).to eq(1)
      expect(removed.first).to be_kind_of(Shrine::UploadedFile)
      expect(removed.first.exists?).to be(false)
    end

    describe "if someone else removed first" do
      before do
        another_copy = asset.class.find(asset.id)
        another_copy.file_attacher.remove_derivative(:sample1)
        another_copy.save!
        another_copy.reload
        expect(another_copy.file_derivatives.keys).to eq([:sample2])

        expect(asset.file_derivatives.keys).to match([:sample1, :sample2])
      end

      it "doesn't complain" do
        asset.file_attacher.remove_persisted_derivatives(:sample1)
        expect(asset.changed?).to eq(false)
        expect(asset.file_derivatives.keys).to eq([:sample2])
      end
    end

    describe "someone else added another derivative" do
      before do
        another_copy = asset.class.find(asset.id)
        another_copy.file_attacher.add_persisted_derivatives({:sample3 => fakeio("sample 3")})
        another_copy.reload
        expect(another_copy.file_derivatives.keys).to match([:sample1, :sample2, :sample3])

        expect(asset.file_derivatives.keys).to match([:sample1, :sample2])
      end

      it "deletes without deleting newly added" do
        asset.file_attacher.remove_persisted_derivatives(:sample1)

        expect(asset.changed?).to eq(false)
        expect(asset.file_derivatives.keys).to eq([:sample2, :sample3])
      end
    end

    describe "model deleted from under us" do
      before do
        another_copy = asset.class.find(asset.id)
        another_copy.destroy!
      end

      it "silently no-ops" do
        result = asset.file_attacher.remove_persisted_derivatives(:sample1)
        expect(result).to eq(false)
      end
    end

    describe "model with unsaved changes" do
      before do
        asset.title = "changed title"
      end

      it "will refuse" do
        expect {
          asset.file_attacher.remove_persisted_derivatives(:sample1)
        }.to raise_error(TypeError)
      end

      it "can be forced" do
        asset.file_attacher.remove_persisted_derivatives(:sample1, allow_other_changes: true)

        expect(asset.changed?).to be(false)
        asset.reload
        expect(asset.title).to eq("changed title")
        expect(asset.file_derivatives.keys).to eq([:sample2])
      end
    end

  end
end
