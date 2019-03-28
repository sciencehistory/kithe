require 'traject'

module Kithe
  class Indexer < Traject::Indexer
    include Kithe::Indexer::ObjExtract

    # TODO We might not actually want to do these automatically....
    class_attribute :model_name_solr_field, instance_writer: false, default: "model_name_ssi"

    def self.default_settings
      # We don't plan to use this for writing, no instance-level writer. 0 threads.
      @default_settings ||= super.merge(
        "processing_thread_pool" => 0,
        "writer_class_name" => "NoWriterSet",

        # for now we tell the solrjsonwriter to use no threads
        # no batching.
        "solr_writer.thread_pool" => 0,
        "solr_writer.batch_size" => 1,

      )
    end

    # Automatically index model name and friendlier_id
    # TODO We might not actually want to do these automatically....
    configure do
      # hard-coded id -> id for now. id is a UUID.
      to_field "id", obj_extract("id")
      to_field model_name_solr_field, obj_extract("class", "name")
    end
  end
end