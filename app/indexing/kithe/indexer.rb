require 'traject'

module Kithe
  class Indexer < Traject::Indexer
    include Kithe::Indexer::ObjExtract

    # TODO We might not actually want to do these automatically....
    class_attribute :model_name_solr_field, instance_writer: false, default: "model_name_ssi"
    class_attribute :solr_id_value_attribute, instance_writer: false, default: "friendlier_id"

    def self.default_settings
      # We don't plan to use this for writing, no instance-level writer. 0 threads.
      @default_settings ||= super.merge(
        "processing_thread_pool" => 0,
        "writer_class_name" => "NoWriterSet"
      )
    end

    # Automatically index model name and friendlier_id
    # TODO We might not actually want to do these automatically....
    configure do
      to_field "id", obj_extract(solr_id_value_attribute)
      to_field model_name_solr_field, obj_extract("class", "name")
    end
  end
end
