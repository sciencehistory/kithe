require 'traject'

module Kithe
  class Indexer < Traject::Indexer
    include Kithe::Indexer::ObjExtract

    def self.default_settings
      # We don't plan to use this for writing, no instance-level writer. 0 threads.
      @default_settings ||= super.merge(
        "processing_thread_pool" => 0,
        "writer_class_name" => "NoWriterSet",
        "logger" => Rails.logger
      )
    end

    # Automatically index model name and id.
    # So we can retrieve them later from Solr, which is crucial so we can fetch the
    # actual object from the db.
    #
    # TODO We might not actually want to do these automatically, or allow it to be disabled?
    configure do
      # hard-coded id -> id for now. id is a UUID. Can be made configurable?
      to_field "id", obj_extract("id")
      to_field Kithe::Indexable.settings.model_name_solr_field, obj_extract("class", "name")
    end
  end
end
