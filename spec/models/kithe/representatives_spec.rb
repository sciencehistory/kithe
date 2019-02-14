require 'rails_helper'


RSpec.describe "Model representatives", type: :model do
  let(:work) { FactoryBot.create(:kithe_work) }
  let(:asset) { FactoryBot.create(:kithe_asset) }

  it "can assign" do
    work.representative = asset
    work.save!
    work.reload

    expect(work.representative_id).to eq(asset.id)
    expect(work.representative).to eq(asset)
  end

  describe "on an asset" do
    it "is it's own representative" do
      expect(asset.representative).to eq(asset)
      expect(asset.representative_id).to eq(asset.id)
    end
  end

  describe "leaf_representative" do
    let(:work) { FactoryBot.create(:kithe_work, title: "top", representative: intermediate_work)}
    let(:intermediate_work) { FactoryBot.create(:kithe_work, title: "intermediate", representative: asset)}

    it "is set" do
      expect(intermediate_work.leaf_representative).to eq(asset)
      expect(work.leaf_representative).to eq(asset)

      work.representative = nil
      work.save!
      expect(work.leaf_representative).to be(nil)
    end

    describe "with accidental cycle" do
      let(:work) { FactoryBot.create(:kithe_work) }
      let(:work2) { FactoryBot.create(:kithe_work) }

      it "handles sanely" do
        work.update(representative_id: work2.id)
        work2.update(representative_id: work.id)

        # mainly we care that it didn't infinite loop or raise, don't care
        # too much what it is, it's a mess.
        expect(work.leaf_representative_id).to eq(work.representative_id)
        expect(work2.leaf_representative_id).to eq(work2.id)
      end
    end

    describe "changing intermediate representatives" do
      let!(:asset2) { FactoryBot.create(:kithe_asset) }
      let!(:child1) { FactoryBot.create(:kithe_work, title: "child1", representative: asset) }
      let!(:child2) { FactoryBot.create(:kithe_work, title: "child1", representative: asset2) }
      let!(:parent) { FactoryBot.create(:kithe_work, title: "parent", representative: child1) }
      let!(:parent_alt) { FactoryBot.create(:kithe_work, title: "parent", representative: child1) }
      let!(:parent2) { FactoryBot.create(:kithe_work, title: "parent", representative: child2) }
      let!(:grandparent) { FactoryBot.create(:kithe_work, title: "grandparent", representative: parent) }
      let!(:great_grandparent) { FactoryBot.create(:kithe_work, title: "great-grandparent", representative: grandparent) }
      let!(:great_grandparent2) { FactoryBot.create(:kithe_work, title: "great-grandparent", representative: grandparent) }

      it "changes references with intermediate change" do
        parent.representative = child2
        parent.save!

        expect(parent.reload.leaf_representative_id).to eq(asset2.id)
        expect(grandparent.reload.leaf_representative_id).to eq(asset2.id)
        expect(great_grandparent.reload.leaf_representative_id).to eq(asset2.id)
        expect(great_grandparent2.reload.leaf_representative_id).to eq(asset2.id)

        # unchanged
        expect(parent_alt.reload.leaf_representative_id).to eq(asset.id)
        expect(child1.reload.leaf_representative_id).to eq(asset.id)
      end

      it "changes references with terminal change" do
        child1.update(representative: asset2)

        expect(parent.reload.leaf_representative_id).to eq(asset2.id)
        expect(parent_alt.reload.leaf_representative_id).to eq(asset2.id)
        expect(grandparent.reload.leaf_representative_id).to eq(asset2.id)
        expect(great_grandparent.reload.leaf_representative_id).to eq(asset2.id)
        expect(great_grandparent2.reload.leaf_representative_id).to eq(asset2.id)
      end
    end

    describe "hetereogenous fetch" do
      let!(:asset) { FactoryBot.create(:kithe_asset) }
      let!(:work) { FactoryBot.create(:kithe_work, representative: asset) }
      let!(:collection) { FactoryBot.create(:kithe_collection, representative: work) }

      it "can eager load" do
        all = Kithe::Model.includes(:leaf_representative).all.to_a
        all.each do |model|
          expect(model.association(:leaf_representative).loaded?).to be(true)
          expect(model.leaf_representative).to eq(asset)
        end
      end
    end
  end

  describe "on destroy" do
    let(:work) { FactoryBot.create(:kithe_work, representative: asset) }
    let(:asset) { FactoryBot.create(:kithe_asset) }

    it "allows and nullifies references" do
      expect(work.representative).to eq(asset)
      expect(work.leaf_representative).to eq(asset)

      asset.destroy
      work.reload

      expect(work.representative).to be(nil)
      expect(work.leaf_representative).to be(nil)
    end

    describe "intermediate chain" do
      let!(:work) { FactoryBot.create(:kithe_work, representative: intermediate_work) }
      let!(:intermediate_work) { FactoryBot.create(:kithe_work, representative: asset) }
      let!(:asset) { FactoryBot.create(:kithe_asset) }

      it "nullifies references on destroy intermediate" do
        intermediate_work.destroy
        work.reload

        expect(work.representative).to be(nil)
        expect(work.leaf_representative).to be(nil)
      end

      it "nullifies all references on destroy leaf" do
        asset.destroy
        work.reload
        intermediate_work.reload

        expect(intermediate_work.representative).to be(nil)
        expect(intermediate_work.leaf_representative).to be(nil)

        expect(work.representative).to be(nil)
        expect(work.leaf_representative).to be(nil)
      end
    end
  end

end
