require 'rails_helper'
require 'attr_json'

describe "Indexer end-to-end" do
  # a work class and indexer based on science history institute's use case
  temporary_class("CategoryAndValue") do
    Class.new do
      include AttrJson::Model
      attr_json :category, :string
      attr_json :value, :string
    end
  end
  temporary_class("PhysicalContainer") do
    Class.new do
      include AttrJson::Model

      attr_json :box, :string
      attr_json :folder, :string
      attr_json :volume, :string
      attr_json :part, :string
      attr_json :page, :string
      attr_json :shelfmark, :string
    end
  end
  temporary_class("DateOfWork") do
    Class.new do
      include AttrJson::Model

      attr_json :start, :string
      attr_json :start_qualifier, :string

      attr_json :finish, :string
      attr_json :finish_qualifier, :string

      attr_json :note, :string
    end
  end
  temporary_class("TestWork") do
    Class.new(Kithe::Work) do
        attr_json :additional_title, :string, array: true, default: -> { [] }
        attr_json :external_id, CategoryAndValue.to_type, array: true, default: -> { [] }
        attr_json :creator, CategoryAndValue.to_type, array: true, default: -> { [] }
        attr_json :date_of_work, DateOfWork.to_type, array: true, default: -> { [] }
        attr_json :place, CategoryAndValue.to_type, array: true, default: -> { [] }
        attr_json :format, :string, array: true, default: -> { [] }
        attr_json :genre, :string, array: true, default: -> { [] }
        attr_json :medium, :string, array: true, default: -> { [] }
        attr_json :extent, :string, array: true, default: -> { [] }
        attr_json :language, :string, array: true, default: -> { [] }
        attr_json :description, :text
        attr_json :inscription, CategoryAndValue.to_type, array: true, default: -> { [] }

        # eventually keep vocab id?
        attr_json :subject, :string, array: true, default: -> { [] }

        attr_json :department, :string
        attr_json :exhibition, :string, array: true, default: -> { [] }
        attr_json :source, :string
        attr_json :series_arrangement, :string, array: true, default: -> { [] }
        attr_json :physical_container, PhysicalContainer.to_type

        # Turn into type of url and value?
        attr_json :related_url, :string, array: true, default: -> { [] }
        attr_json :rights, :string
        attr_json :rights_holder, :string
        attr_json :additional_credit, CategoryAndValue.to_type, array: true, default: -> { [] }

        attr_json :file_creator, :string
        attr_json :admin_note, :text
    end
  end

  let(:work) do
    TestWork.create(
      id: "my_pk",
      title: "a title",
      additional_title: ["additional title 1", "additional title 2"],
      external_id: [{category: "bib", value: "bib1"}, {category: "object", value: "object1"}],
      creator: [{category: "author", value: "Emiliano Zapata"}],
      date_of_work: [{start: "1950-01-01", start_qualifier: "circa", finish: "1990-01-01"}, {start: "1970-01-01"}],
      place: [{category: "place_of_creation", value: "Baltimore"}],
      format: ["image", "text"],
      genre: ["rare books"],
      medium: nil,
      extent: ["2x4"],
      language: ["English", "Spanish"],
      description: "Lots of\n\nthings.",
      inscription: [{category: "cover page", value:"to my friend"}],
      subject: ["Things", "More things"],
      department: "Library",
      exhibition: ["Things we like"],
      related_url: ["http://example.com/somewhere"],
      rights: "http://rightsstatements.org/vocab/InC/1.0/",
      admin_note: "this is a note"
    )
  end

  let(:indexer_subclass) do
    Class.new(Kithe::Indexer) do
      configure do
        to_field "search1", obj_extract("title")
        to_field "search1", obj_extract("additional_title")

        to_field "search2", obj_extract("creator", "value")

        to_field "search5", obj_extract("external_id", "value")

        to_field "rights_facet", obj_extract("rights"), translation_map("http://rightsstatements.org/vocab/InC/1.0/" => "In Copyright")

        # not sure if this makes sense as a way to do this, but let's make sure it's possible
        to_field "max_year",
          obj_extract("date_of_work"),
          transform(->(date_obj) {
            [ date_obj.start ? date_obj.start.slice(0..4).to_i : nil,
              date_obj.finish ? date_obj.finish.slice(0..4).to_i : nil]
          }) do |record, accumulator|
          accumulator.flatten!.compact!
          accumulator.replace([accumulator.max])
        end
      end
    end
  end


  let(:indexer) { indexer_subclass.new }

  it "indexes" do
    result = indexer.map_record(work)
    expect(result).to match(
      "search1" => [work.title] + work.additional_title,
      "search2" => work.creator.collect(&:value),
      "search5" => work.external_id.collect(&:value),
      "rights_facet" => ["In Copyright"],
      "max_year" => [1990],
      "model_name_ssi" => ["TestWork"],
      "id" => [work.friendlier_id]
    )
  end

  it "can process_with" do
    writer = indexer.process_with([work], Traject::ArrayWriter.new)
    expect(writer.contexts.length).to eq(1)
    expect(indexer.settings["processing_thread_pool"]).to eq(0)
  end

  it "has no default writer so can't process_record" do
    expect {
      indexer.process_record(work)
    }.to raise_error(NameError)
  end
end
