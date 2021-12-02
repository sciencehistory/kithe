module Kithe
  class IndexableSettings
    attr_accessor :solr_url, :writer_class_name, :writer_settings,
                  :model_name_solr_field, :solr_id_value_attribute, :disable_callbacks,
                  :batching_mode_batch_size
    def initialize(solr_url:, writer_class_name:, writer_settings:,
                   model_name_solr_field:, solr_id_value_attribute:, disable_callbacks: false,
                   batching_mode_batch_size: 100)
      @solr_url = solr_url
      @writer_class_name = writer_class_name
      @writer_settings = writer_settings
      @model_name_solr_field = model_name_solr_field
      @solr_id_value_attribute = solr_id_value_attribute || 'id'
      @batching_mode_batch_size = batching_mode_batch_size
    end

    # Use configured solr_url, and merge together with configured
    # writer_settings
    def writer_settings
      if solr_url
        { "solr.url" => solr_url }.merge(@writer_settings)
      else
        @writer_settings
      end
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
