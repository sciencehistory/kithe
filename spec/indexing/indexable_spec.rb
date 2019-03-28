require 'rails_helper'

describe Kithe::Indexable, type: :model do
  temporary_class("TestWork") do
    Class.new(Kithe::Work) do
      self.kithe_indexable_mapper = Kithe::Indexer.new
    end
  end

  describe "update_index" do
    describe "with something that should be in index" do
      it "sends solr update" do
        stub_request(:post, "http://localhost:8983/update/json")

        work = TestWork.create!(title: "test")
        work.update_index

        expect(WebMock).to have_requested(:post, "http://localhost:8983/update/json").
          with { |req|
            JSON.parse(req.body) == [{"id" => [work.id],"model_name_ssi" => ["TestWork"]}]
          }
      end
    end

    describe "with deleted thing" do
      it "sends delete to Solr" do
        work = TestWork.create!(title: "test")

        stub_request(:post, "http://localhost:8983/update/json")

        work.destroy!
        work.update_index

        expect(WebMock).to have_requested(:post, "http://localhost:8983/update/json").
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
      stub_request(:post, "http://localhost:8983/update/json")
      work = TestWork.create!(title: "test")
      expect(WebMock).to have_requested(:post, "http://localhost:8983/update/json").
        with { |req|
          JSON.parse(req.body) == [{"id" => [work.id],"model_name_ssi" => ["TestWork"]}]
        }

      work.destroy!
      expect(WebMock).to have_requested(:post, "http://localhost:8983/update/json").
        with { |req|
          JSON.parse(req.body) == { "delete" => work.id }
        }
    end

    describe "index_with block" do
      describe "with batching" do
        it "batches solr updates" do
          stub_request(:post, "http://localhost:8983/update/json")

          Kithe::Indexable.index_with(batching: true) do
            TestWork.create!(title: "test1")
            TestWork.create!(title: "test2")
          end

          expect(WebMock).to have_requested(:post, "http://localhost:8983/update/json").once
          expect(WebMock).to have_requested(:post, "http://localhost:8983/update/json").
            with { |req| JSON.parse(req.body).count == 2}
        end
      end
    end

  end



end
