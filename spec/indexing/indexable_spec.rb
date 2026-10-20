require 'rails_helper'

describe Kithe::Indexable, type: :model do
  before do
    @solr_url = "http://localhost:8983/solr/collection1"
    @solr_update_url = "#{@solr_url}/update/json?softCommit=true"

    @original_solr_url = Kithe.indexable_settings.solr_url
    Kithe.indexable_settings.solr_url =@solr_url
  end

  after do
    Kithe.indexable_settings.solr_url = @original_solr_url
  end

  temporary_class("TestWork") do
    Class.new(Kithe::Work) do
      self.kithe_indexable_mapper = Kithe::Indexer.new
      self.kithe_indexable_auto_callbacks = false
    end
  end

  describe "update_index without auto-indexing" do
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
            JSON.parse(req.body) == { "delete" => work.send(Kithe.indexable_settings.solr_id_value_attribute) }
          }
      end
    end

    describe "with explicit mapper" do
      let(:custom_mapper) { Kithe::Indexer.new }
      let(:work) { TestWork.create!(title: "test") }

      it "uses" do
        stub_request(:post, @solr_update_url)

        expect(custom_mapper).to receive(:process_with).with([work])
        expect(work.kithe_indexable_mapper).not_to receive(:process_with)

        work.update_index(mapper: custom_mapper)
      end
    end

    describe "with explicit writer" do
      let(:custom_writer) { double(:custom_writer) }
      let(:work) { TestWork.create!(title: "test") }

      it "uses" do
        expect(custom_writer).to receive(:put)
        work.update_index(writer: custom_writer)
      end
    end

  end

  describe "auto-indexing" do
    temporary_class("TestWork") do
      Class.new(Kithe::Work) do
        self.kithe_indexable_mapper = Kithe::Indexer.new
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

    describe "kithe_indexable_non_indexed_attributes" do
      temporary_class("TestWork") do
        Class.new(Kithe::Work) do
          attr_json :non_indexed_json, :string
          attr_json :indexed_json, :string

          self.kithe_indexable_mapper = Kithe::Indexer.new
          self.kithe_indexable_non_indexed_attributes = [:json_attributes, :non_indexed_json]
        end
      end

      let!(:work) do
        stub_request(:post, @solr_update_url)
        TestWork.create!(title: "test").tap { WebMock.reset_executed_requests! }
      end

      it "does not reindex when only non-indexed attr_json changes" do
        work.update!(non_indexed_json: "new value")
        expect(WebMock).not_to have_requested(:post, @solr_update_url)
      end

      it "reindexes when an indexed attr_json changes too" do
        work.update!(non_indexed_json: "new value", indexed_json: "other")
        expect(WebMock).to have_requested(:post, @solr_update_url)
      end

      it "reindexes when a regular attribute changes" do
        work.update!(title: "new title")
        expect(WebMock).to have_requested(:post, @solr_update_url)
      end

      it "reindexes if indexed change was in an earlier save of the same transaction" do
        TestWork.transaction do
          work.update!(title: "new title")
          work.update!(non_indexed_json: "new value")
        end
        expect(WebMock).to have_requested(:post, @solr_update_url)
      end

      it "does not carry a prior transaction's change into the next" do
        work.update!(title: "new title")
        WebMock.reset_executed_requests!
        work.update!(non_indexed_json: "new value")
        expect(WebMock).not_to have_requested(:post, @solr_update_url)
      end

      it "reindexes if indexed attribute was touched after a non-indexed save in same transaction" do
        TestWork.transaction do
          work.update!(non_indexed_json: "new value")
          work.touch(:created_at)
        end
        expect(WebMock).to have_requested(:post, @solr_update_url)
      end

      it "indexes on create, even if only non-indexed attributes are set" do
        WebMock.reset_executed_requests!
        new_work = TestWork.create!(title: "other", non_indexed_json: "value")
        expect(WebMock).to have_requested(:post, @solr_update_url).
          with { |req| JSON.parse(req.body).first["id"] == [new_work.id] }
      end

      describe "with primary key mistakenly listed as non-indexed" do
        temporary_class("TestWork") do
          Class.new(Kithe::Work) do
            self.kithe_indexable_mapper = Kithe::Indexer.new
            self.kithe_indexable_non_indexed_attributes = Kithe::Work.column_names
          end
        end

        it "still indexes on create" do
          WebMock.reset_executed_requests!
          TestWork.create!(title: "other")
          expect(WebMock).to have_requested(:post, @solr_update_url)
        end
      end

      it "reindexes on destroy" do
        work.destroy!
        expect(WebMock).to have_requested(:post, @solr_update_url).
          with { |req| JSON.parse(req.body) == { "delete" => work.id } }
      end

      it "still indexes on explicit update_index" do
        work.update!(non_indexed_json: "new value")
        work.update_index
        expect(WebMock).to have_requested(:post, @solr_update_url)
      end
    end

    describe "kithe_indexable_only_indexed_attributes" do
      temporary_class("TestWork") do
        Class.new(Kithe::Work) do
          attr_json :other_json, :string

          self.kithe_indexable_mapper = Kithe::Indexer.new
          self.kithe_indexable_only_indexed_attributes = [:title, :json_attributes, :summary]
          self.kithe_indexable_non_indexed_attributes = [:json_attributes]
        end
      end

      let!(:work) do
        stub_request(:post, @solr_update_url)
        TestWork.create!(title: "test").tap { WebMock.reset_executed_requests! }
      end

      it "indexes on change to allowed attribute" do
        work.update!(title: "new title")
        expect(WebMock).to have_requested(:post, @solr_update_url)
      end

      it "does not index on change to attribute not in list" do
        work.update!(other_json: "value")
        expect(WebMock).not_to have_requested(:post, @solr_update_url)
      end

      it "does not index on change to attribute in both lists" do
        work.update!(other_json: "value", json_attributes: work.json_attributes.merge("x" => "y"))
        expect(WebMock).not_to have_requested(:post, @solr_update_url)
      end

      it "does not index on touch" do
        work.touch
        expect(WebMock).not_to have_requested(:post, @solr_update_url)
      end

      it "indexes on create and destroy" do
        new_work = TestWork.create!(title: "other")
        expect(WebMock).to have_requested(:post, @solr_update_url)

        WebMock.reset_executed_requests!
        new_work.destroy!
        expect(WebMock).to have_requested(:post, @solr_update_url).
          with { |req| JSON.parse(req.body) == { "delete" => new_work.id } }
      end

      describe "with primary key not in list" do
        temporary_class("TestWork") do
          Class.new(Kithe::Work) do
            self.kithe_indexable_mapper = Kithe::Indexer.new
            self.kithe_indexable_only_indexed_attributes = [:summary]
          end
        end

        it "still indexes on create" do
          TestWork.create!(title: "other")
          expect(WebMock).to have_requested(:post, @solr_update_url)
        end
      end
    end

    describe "save with no changes" do
      let!(:work) do
        stub_request(:post, @solr_update_url)
        TestWork.create!(title: "test").tap { WebMock.reset_executed_requests! }
      end

      it "does not reindex" do
        work.save!
        expect(WebMock).not_to have_requested(:post, @solr_update_url)
      end

      it "reindexes on touch" do
        work.touch
        expect(WebMock).to have_requested(:post, @solr_update_url)
      end
    end

    describe "with global disable_callbacks" do
      around do |example|
        original = Kithe.indexable_settings.disable_callbacks
        Kithe.indexable_settings.disable_callbacks = true
        example.run
        Kithe.indexable_settings.disable_callbacks = original
      end

      it "does not index" do
        work = TestWork.new(title: "test")

        expect(work).not_to receive(:update_index)
        work.save!

        expect(WebMock).not_to have_requested(:post, @solr_update_url)
      end
    end

    describe "index_with block" do
      describe "with batching" do
        # TODO should this turn off softCommits? do we need a way to specify in index_with
        # whether to do commits on every update, commits at end, and soft/hard? yes.
        #
        thread_settings = nil
        it "batches solr updates" do
          stub_request(:post, @solr_update_url)
          expect(Kithe.indexable_settings.writer_class_name.constantize).to receive(:new).and_call_original

          Kithe::Indexable.index_with(batching: true) do
            TestWork.create!(title: "test1")
            TestWork.create!(title: "test2")

            thread_settings = Kithe::Indexable::ThreadSettings.current
            expect(thread_settings.writer).to be_present
            expect(thread_settings.writer).to receive(:close).and_call_original
          end

          expect(WebMock).to have_requested(:post, @solr_update_url).once
          expect(WebMock).to have_requested(:post, @solr_update_url).
            with { |req| JSON.parse(req.body).count == 2}
        end

        it "creates no writer if no updates happen" do
          expect(Kithe.indexable_settings.writer_class_name.constantize).not_to receive(:new)
          Kithe::Indexable.index_with(batching: true) do
          end
        end

        it "respects non-default on_finish" do
          stub_request(:post, @solr_update_url)
          stub_request(:get, "#{@solr_url}/update/json?commit=true")
          expect(Kithe.indexable_settings.writer_class_name.constantize).to receive(:new).and_call_original

          Kithe::Indexable.index_with(batching: true, on_finish: ->(w){ w.flush; w.commit(commit: true) }) do
            TestWork.create!(title: "test1")
            TestWork.create!(title: "test2")

            thread_settings = Kithe::Indexable::ThreadSettings.current
            expect(thread_settings.writer).to be_present
            expect(thread_settings.writer).to receive(:flush).and_call_original
          end

          expect(WebMock).to have_requested(:post, @solr_update_url).once
          expect(WebMock).to have_requested(:post, @solr_update_url).
            with { |req| JSON.parse(req.body).count == 2}
        end

        it "does not call on-finish if no writer was needed" do
          Kithe::Indexable.index_with(batching: true, on_finish: ->(w){ raise "should not be called" }) do
          end
        end

        describe "custom batching_mode_batch_size" do
          let(:custom_size) { 20 }

          it "can be set globally" do
            stub_request(:post, @solr_update_url)

            # set custom setting
            expect(Kithe.indexable_settings).to receive(:batching_mode_batch_size).and_return(custom_size)

            # expect custom setting to be passed to index writer
            expect(Kithe.indexable_settings.writer_class_name.constantize).to receive(:new).
              with(hash_including("solr_writer.batch_size"=> custom_size)).
              and_call_original

            # exersize
            Kithe::Indexable.index_with(batching: true) do
              TestWork.create!(title: "test1")
              TestWork.create!(title: "test2")
            end
          end

          it "can be set per-call" do
            stub_request(:post, @solr_update_url)

            # expect custom setting to be passed to index writer
            expect(Kithe.indexable_settings.writer_class_name.constantize).to receive(:new).
              with(hash_including("solr_writer.batch_size"=> custom_size)).
              and_call_original

            # exersize
            Kithe::Indexable.index_with(batching: custom_size) do
              TestWork.create!(title: "test1")
              TestWork.create!(title: "test2")
            end
          end
        end
      end

      describe "auto_callbacks" do
        it "happen with no args" do
          stub_request(:post, @solr_update_url)
          Kithe::Indexable.index_with do
            first = TestWork.new(title: "test1")
            expect(first).to receive(:update_index).once.and_call_original
            first.save!

            TestWork.create!(title: "test2")
          end

          expect(WebMock).to have_requested(:post, @solr_update_url).twice

          expect(Thread.current[Kithe::Indexable::ThreadSettings::THREAD_CURRENT_KEY]).to be_nil
        end

        it "can be disabled" do
          stub_request(:post, @solr_update_url)

          Kithe::Indexable.index_with(disable_callbacks: true) do
            first = TestWork.new(title: "test1")
            expect(first).not_to receive(:update_index)

            TestWork.create!(title: "test2")
          end

          expect(WebMock).not_to have_requested(:post, @solr_update_url)

          expect(Thread.current[Kithe::Indexable::ThreadSettings::THREAD_CURRENT_KEY]).to be_nil
        end

        it "can be disabled when there's a nested disable block" do
          stub_request(:post, @solr_update_url)

          Kithe::Indexable.index_with(disable_callbacks: true) do

            Kithe::Indexable.index_with(disable_callbacks: true) do
              TestWork.create!(title: "test_a")
            end

            TestWork.create!(title: "test_b")
          end
          expect(WebMock).not_to have_requested(:post, @solr_update_url)
        end


      end

      describe "specified writer" do
        let(:array_writer) { writer = Traject::ArrayWriter.new }

        it "raises ArgumentError if also batching" do
          expect {
            Kithe::Indexable.index_with(batching: true, writer: array_writer) do
            end
          }.to raise_error(ArgumentError)
        end

        it "uses custom writer, by default without close" do
          expect(array_writer).to receive(:put).twice
          Kithe::Indexable.index_with(writer: array_writer) do
            TestWork.create!(title: "test1")
            TestWork.create!(title: "test2")
          end
        end

        it "uses on_finish if specified" do
          writer = double("writer")

          allow(writer).to receive(:close)
          expect(writer).to receive(:put).twice

          Kithe::Indexable.index_with(writer: writer, on_finish: ->(w) { w.close }) do
            TestWork.create!(title: "test1")
            TestWork.create!(title: "test2")
          end
        end
      end
    end
  end
end
