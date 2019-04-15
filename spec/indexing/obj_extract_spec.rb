require 'rails_helper'
require 'traject'

# trying to write tests to be easily moved to traject if we extract this to traject itself
describe "ObjExtract traject macro" do
  let(:indexer_class) do
    Class.new(Traject::Indexer) do
      include Kithe::Indexer::ObjExtract
    end
  end

  let(:indexer) { indexer_class.new("log.level": "gt.fatal ") }

  describe "simple string attribute" do
    before do
      indexer.configure do
        to_field "result", obj_extract("title")
      end
    end

    it "indexes" do
      result = indexer.map_record(OpenStruct.new(title: "title value"))
      expect(result["result"]).to eq(["title value"])
    end
  end

  describe "primitive array attribute" do
    before do
      indexer.configure do
        to_field "result", obj_extract("title")
      end
    end

    it "indexes empty value" do
      result = indexer.map_record(OpenStruct.new(title: []))
      expect(result).to eq({})
    end

    it "indexes single value" do
      result = indexer.map_record(OpenStruct.new(title: ["foo"]))
      expect(result).to eq({ "result" => ["foo"] })
    end

    it "indexes multiple values" do
      result = indexer.map_record(OpenStruct.new(title: ["title value1", "title value2"]))
      expect(result["result"]).to eq(["title value1", "title value2"])
    end
  end

  describe "model attribute" do
    before do
      indexer.configure do
        to_field "result", obj_extract(:creator, :name)
      end
    end

    it "indexes single" do
      result = indexer.map_record(OpenStruct.new(creator: OpenStruct.new(type: "engraver", name: "Joe Shmoe")))
      expect(result).to eq({ "result" => ["Joe Shmoe"]})
    end

    it "indexes nil without raising" do
      result = indexer.map_record(OpenStruct.new(creator: nil))
      expect(result).to eq({})
    end

    describe "as array" do
      it "indexes empty" do
        result = indexer.map_record(OpenStruct.new(creator: []))
        expect(result).to eq({})
      end

      it "indexes single element" do
        result = indexer.map_record(OpenStruct.new(creator: [OpenStruct.new(type: "engraver", name: "Joe Shmoe")]))
        expect(result).to eq({ "result" => ["Joe Shmoe"]})
      end

      it "indexes multiple" do
        result = indexer.map_record(OpenStruct.new(
          creator: [
                    OpenStruct.new(type: "engraver", name: "Joe Shmoe"),
                    OpenStruct.new(type: "engraver", name: "Mary Sue"),
          ])
        )
        expect(result).to eq({ "result" => ["Joe Shmoe", "Mary Sue"]})
      end
    end

    describe "does not respond to" do
      it "raises" do
        expect {
          indexer.map_record(Struct.new(:other_attribute).new)
        }.to raise_error(NoMethodError)
      end
    end
  end

  describe "hash" do
    before do
      indexer.configure do
        to_field "result", obj_extract(:creator, :name)
      end
    end

    it "indexes single" do
      result = indexer.map_record(OpenStruct.new(creator: {type: "engraver", name: "Joe Shmoe"}))
      expect(result).to eq({ "result" => ["Joe Shmoe"]})
    end

    it "indexes array value" do
      result = indexer.map_record(OpenStruct.new(creator: [
        {type: "engraver", name: "Joe Shmoe"}, {type: "illustrator", name: "Mary Sue"}])
      )
      expect(result).to eq({ "result" => ["Joe Shmoe", "Mary Sue"]})
    end

    it "indexes nil" do
      result = indexer.map_record(OpenStruct.new(creator: nil))
      expect(result).to eq({})
    end

    it "indexes empty array" do
      result = indexer.map_record(OpenStruct.new(creator: []))
      expect(result).to eq({})
    end
  end

end
