require 'traject'

module Kithe
  # A sub-class of Traject::Indexer, set up for kithe use.
  #
  # * It mixes in Kithe::Indexer::ObjExtract for our `obj_extract` macro, useful for
  #   using traject to index plain old ruby objects as source records
  #
  # * it has settings disabling internal threading by setting processing_thread_pool to 0
  #
  # * It sets the traject logger to the current Rails.logger, to get your traject obj
  #   logs going to the right place.
  #
  # * It sets `writer_class_name` to something that will raise if you try to use it,
  #   becuase we don't intend to use an Indexer with a component writer. Kithe's use of
  #   traject decouples Indexers and Writers.
  #
  # * A Kithe::Indexer will automatically index the source record #id to Solr object
  #   #id, and the source record class name to Solr field `model_name_ssi`. (That uses
  #   Blacklight conventions for dynamic field names, if you'd like to change the field name
  #   used, set `Kithe::Indexable.settings.model_name_solr_field=`)
  #
  #   ID and model_name are set, so the AR object can be easily fetched later from Solr results.
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
