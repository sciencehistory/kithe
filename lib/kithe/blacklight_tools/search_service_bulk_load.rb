module Kithe
  module BlacklightTools
    # Mix-in module to a Blacklight::SearchService, that will bulk load actual AR
    # records corresponding to Solr hits, and set them as `model` attribute on each
    # SolrDocument in the results.
    #
    # A very basic rough implementation for basic use cases.
    #
    # * Assumes all documents that come back in the Solr results was indexed Kithe::Model, and
    #   their Solr ID's are the Kithe::Model `id` pk, or from the AR model attribute name
    #   set in `Kithe.indexable_settings.solr_id_value_attribute`
    #
    # * Requires your SolrDocument class to have a `model` attribute, you can just add
    #   `attr_accessor :model` to your local SolrDocument class BL generated in
    #   `./app/models/solr_document.rb`. Loaded models will be stored there on your results.
    #
    # Just `include` this model in a Blacklight::SearchService subclass. If you need no
    # additional SearchService customization, but just the standard Blacklight::SearchService
    # with this functionality, for convenience see the Kithe::BlacklightTools::BulkLoadingSearchServicce
    #
    # SORRY: No automated tests at present, too hard for us at the moment to figure out how
    # to test a Blacklight extension in a reliable and sane way.
    module SearchServiceBulkLoad
      extend ActiveSupport::Concern

      included do
        class_attribute :bulk_load_records, default: true
        class_attribute :bulk_load_scope
      end

      def search_results
        (response, _documents) = super

        if bulk_load_records
          id_hash = response.documents.collect {|r| [r.id, r] }.to_h

          scope = Kithe::Model.where(Kithe.indexable_settings.solr_id_value_attribute => id_hash.keys)
          scope = scope.instance_exec(&bulk_load_scope) if bulk_load_scope

          scope.find_each do |model|
            id_hash[model.send(Kithe.indexable_settings.solr_id_value_attribute)].model = model
          end

          orphaned_solr_docs = id_hash.values.select { |doc| doc.model.nil? }
          if orphaned_solr_docs.present?
            Rails.logger.warn("Kithe::Blacklight::BulkLoading: Missing db records for solr doc id's: #{orphaned_solr_docs.collect(&:id).join(' ')}")
          end
        end

        [response, _documents]
      end
    end
  end
end
