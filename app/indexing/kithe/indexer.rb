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
  #   used, set `Kithe.indexable_settings.model_name_solr_field=`)
  #
  # *  ID and model_name are set, so the AR object can be easily fetched later from Solr results.
  #   * You can customize what Solr field the model_name is sent to with
  #     `Kithe.indexable_settings.model_name_solr_field=`, by default `model_name_ssi`, using
  #     a blacklight dynamic field template `*_ssi`.
  #   * You can customize what ActiveRecord model property is sent to Solr `id` field with
  #     `Kithe.indexable_settings.solr_id_value_attribute=`, by default the AR pk in model#id.
  #
  # Note that there are no built-in facilities for automatically sending every field of your model
  # to Solr, round-trippable or not. The expected usage pattern is sending to Solr only
  # what you need for your use of Solr for searching.
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
      to_field "id", obj_extract(Kithe.indexable_settings.solr_id_value_attribute)
      to_field Kithe.indexable_settings.model_name_solr_field, obj_extract("class", "name")
    end
  end
end
