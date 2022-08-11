module Kithe
  class IndexableSettings
    attr_accessor :solr_url, :writer_class_name, :writer_settings,
                  :model_name_solr_field, :solr_id_value_attribute, :disable_callbacks,
                  :batching_mode_batch_size
    def initialize(solr_url:, writer_class_name:, writer_settings:,
                   model_name_solr_field:, solr_id_value_attribute:, disable_callbacks: false,
                   batching_mode_batch_size: 100)
      @writer_class_name = writer_class_name
      @writer_settings = writer_settings
      @model_name_solr_field = model_name_solr_field
      @solr_id_value_attribute = solr_id_value_attribute || 'id'
      @batching_mode_batch_size = batching_mode_batch_size

      # use our local setter to set solr_url also in writer_settings
      solr_url = solr_url
    end


    # set solr_url also in writer_settings, cause it's expected there.
    def solr_url=(v)
      @solr_url = v
      writer_settings["solr.url"] = v if writer_settings
    end

    # Turn writer_class_name into an actual Class object.
    def writer_class
      writer_class_name.constantize
    end

    # Instantiate a new writer based on `writer_class_name` and `writer_settings`
    def writer_instance!(additional_settings = {})
      writer_class.new(writer_settings.merge(additional_settings))
    end
  end
end
