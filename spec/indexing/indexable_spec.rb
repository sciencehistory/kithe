require 'rails_helper'

describe Kithe::Indexable, type: :model do
  before do
    @solr_url = "http://localhost:8983/solr/collection1"
    @solr_update_url = "#{@solr_url}/update/json?softCommit=true"

    @original_solr_url = Kithe::Indexable.settings.solr_url
    Kithe::Indexable.settings.solr_url =@solr_url
  end

  after do
    Kithe::Indexable.settings.solr_url = @original_solr_url
  end

  temporary_class("TestWork") do
    Class.new(Kithe::Work) do
      self.kithe_indexable_mapper = Kithe::Indexer.new
    end
  end

  describe "update_index" do
    describe "with something that should be in index" do
      it "sends solr update" do
        stub_request(:post, @solr_update_url)

        work = TestWork.create!(title: "test")
        work.update_index

        expect(WebMock).to have_requested(:post, @solr_update_url).
          with { |req|
            JSON.parse(req.body) == [{"id" => [work.id],"model_name_ssi" => ["TestWork"]}]
          }
      end
    end

    describe "with deleted thing" do
      it "sends delete to Solr" do
        work = TestWork.create!(title: "test")

        stub_request(:post, @solr_update_url)

        work.destroy!
        work.update_index

        expect(WebMock).to have_requested(:post, @solr_update_url).
          with { |req|
            JSON.parse(req.body) == { "delete" => work.id }
          }
      end
    end
  end

  describe "auto-indexing" do
    temporary_class("TestWork") do
      Class.new(Kithe::Work) do
        self.kithe_indexable_mapper = Kithe::Indexer.new
        self.kithe_indexable_auto_callbacks = true
      end
    end

    it "adds and deletes automatically" do
      stub_request(:post, @solr_update_url)
      work = TestWork.create!(title: "test")
      expect(WebMock).to have_requested(:post, @solr_update_url).
        with { |req|
          JSON.parse(req.body) == [{"id" => [work.id],"model_name_ssi" => ["TestWork"]}]
        }

      work.destroy!
      expect(WebMock).to have_requested(:post, @solr_update_url).
        with { |req|
          JSON.parse(req.body) == { "delete" => work.id }
        }
    end

    describe "index_with block" do
      describe "with batching" do
        # TODO should this turn off softCommits? do we need a way to specify in index_with
        # whether to do commits on every update, commits at end, and soft/hard? yes.
        it "batches solr updates" do
          stub_request(:post, @solr_update_url)

          Kithe::Indexable.index_with(batching: true) do
            TestWork.create!(title: "test1")
            TestWork.create!(title: "test2")
          end

          expect(WebMock).to have_requested(:post, @solr_update_url).once
          expect(WebMock).to have_requested(:post, @solr_update_url).
            with { |req| JSON.parse(req.body).count == 2}
        end
      end
    end

  end



end
