require 'rails_helper'

RSpec.describe Kithe::Derivative, type: :model do
  let(:key) { "some_thumb" }
  let(:asset) { FactoryBot.create(:kithe_asset, :with_faked_metadata, faked_metadata: { sha512: "fakesha512" }) }
  let(:derivative) { Kithe::Derivative.new }

  describe "for referential integrity" do
    it "needs an asset" do
      expect { derivative.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end
    it "needs a key" do
      derivative.asset = asset
      expect { derivative.save! }.to raise_error(ActiveRecord::NotNullViolation)
    end
    it "can save with key and asset" do
      derivative.asset = asset
      derivative.key = key
      derivative.save!
      expect(derivative).to be_persisted
    end
    it "can't save duplicate key/asset" do
      existing_derivative = Kithe::Derivative.create!(asset: asset, key: key)

      derivative.asset = asset
      derivative.key = key
      expect { derivative.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "asset without a sha256" do
    let(:asset) { FactoryBot.create(:kithe_asset) }
    it "won't create derivative" do
      expect {
        asset.add_derivative(key, StringIO.new("something"))
      }.to raise_error(ArgumentError)
    end
  end

  describe "Asset#add_derivative", queue_adapter: :test do
    let(:key) { "some_derivative" }
    let(:dummy_content) { File.read(Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg"), encoding: "BINARY") }
    let(:dummy_io) { File.open(Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg"), encoding: "BINARY") }
    let(:asset) { FactoryBot.create(:kithe_asset, :with_faked_metadata, faked_metadata: { sha512: "fakesha512" })}

    it "can add a derivative" do
      derivative = asset.add_derivative(key, dummy_io)

      expect(derivative).to be_present
      derivative.reload

      # file is stored
      expect(derivative.key).to eq(key)
      expect(derivative.file).to be_present
      expect(derivative.file.storage_key).to eq("kithe_derivatives")
      expect(derivative.file.read).to eq(dummy_content)

      # some metadata we got
      expect(derivative.size).to eq(dummy_content.length)
      expect(derivative.content_type).to eq("image/jpeg")
      expect(derivative.height).to eq(1)
      expect(derivative.width).to eq(1)

      # path on storage is nice and pretty
      expect(derivative.file.id).to match %r{\A#{asset.id}/#{key}/[a-f0-9]+\.jpg\Z}
    end

    it "can add a derivative with custom storage location" do
      derivative = asset.add_derivative(key, dummy_io, storage_key: :store)

      expect(derivative).to be_present
      derivative.reload
      expect(derivative.file).to be_present
      expect(derivative.file.storage_key).to eq("store")
    end

    it "can add a derivative with custom metadata" do
      derivative = asset.add_derivative(key, dummy_io, metadata: { foo: "bar" })
      expect(derivative).to be_present
      expect(derivative.file.metadata["size"]).to eq(dummy_content.length)
      expect(derivative.file.metadata["foo"]).to eq("bar")
    end

    it "deletes stored file when model is deleted" do
      derivative = asset.add_derivative(key, dummy_io, metadata: { foo: "bar" })
      stored_file = derivative.file
      expect(stored_file.exists?).to be(true)

      derivative.destroy
      expect(stored_file.exists?).to be(false)
    end

    describe "with an existing derivative" do
      let!(:existing) { asset.add_derivative(key, StringIO.new("something else")) }

      it "will replace an existing derivative" do
        expect(existing).to be_persisted
        original_shrine_file = existing.file

        replacement = asset.add_derivative(key, dummy_io)

        expect(original_shrine_file.exists?).to be(false)
      end

      it "can remove with #remove_derivative" do
        expect(Kithe::Derivative.where(id: existing.id).count).to be(1)
        stored_file = existing.file
        expect(stored_file.exists?).to be(true)

        asset.remove_derivative(key)

        expect(stored_file.exists?).to be(false)
        expect(Kithe::Derivative.where(id: existing.id).count).to be(0)
      end
    end

    describe "with asset changed concurrently" do
      before do
        data_with_new_sha = asset.file.data.deep_dup.tap do |d|
          d["metadata"]["sha512"] = "new_fake_sha512"
        end
        Kithe::Asset.where(id: asset.id).update_all(file_data: data_with_new_sha)
      end
      it "does not add derivative" do
        expect {
          result = asset.add_derivative(key, StringIO.new("something else"))
          expect(result).to be_nil
        }.to_not change{ [Kithe::Derivative.count, Kithe::DerivativeUploader.storages[:kithe_derivatives].store.count]}

        expect(asset.derivatives.reload.count).to be(0)
      end
    end

    describe "existing asset" do
      let!(:existing_asset) do
        FactoryBot.create(:kithe_asset, :with_file).tap do |asset|
          asset.promote
        end
      end
      it "deletes existing derivatives on new file assignment" do
        deriv = existing_asset.add_derivative(key, StringIO.new("something"))
        deriv_uploaded_file = deriv.file

        existing_asset.file = File.open(Kithe::Engine.root.join("spec/test_support/images/2x2_pixel.jpg"))
        existing_asset.save!

        expect(Kithe::Derivative.where(id: deriv.id).exists?).to be(false)
        expect(deriv_uploaded_file.exists?).to be(false)
        expect(existing_asset.derivatives.reload.count).to be(0)
      end
    end
  end
end

