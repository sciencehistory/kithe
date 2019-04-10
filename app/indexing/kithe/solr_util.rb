require 'json'
require 'rsolr'

module Kithe
  # This is all somewhat hacky code, but it gets the job done. Some convenienceutilities for dealing
  # with your Solr index, including issuing a query to delete_all; and finding and deleting "orphaned"
  # Kithe::Indexable Solr objects that no longer exist in the rdbms.
  #
  # Unlike other parts of Kithe's indexing support, this stuff IS very solr-specific, and generally
  # implemented with [rsolr](https://github.com/rsolr/rsolr).
  module SolrUtil
    # based on sunspot, does not depend on Blacklight.
    # https://github.com/sunspot/sunspot/blob/3328212da79178319e98699d408f14513855d3c0/sunspot_rails/lib/sunspot/rails/searchable.rb#L332
    #
    #     solr_index_orphans do |orphaned_id|
    #        delete(id)
    #     end
    #
    # It is searching for any Solr object with a `Kithe::Indexable.settings.model_name_solr_field`
    # field (default `model_name_ssi`). Then, it takes the ID and makes sure it exists in
    # the database using Kithe::Model. At the moment we are assuming everything is in Kithe::Model,
    # rather than trying to use the `model_name_ssi` to fetch from different tables. Could
    # maybe be enhanced to not.
    #
    # This is intended mostly for use by .delete_solr_orphans
    #
    # A bit hacky implementation, it might be nice to support a progress bar, we
    # don't now.
    def self.solr_orphan_ids(batch_size: 100, solr_url: Kithe::Indexable.settings.solr_url)
      return enum_for(:solr_index_orphan_ids) unless block_given?

      model_name_solr_field = Kithe::Indexable.settings.model_name_solr_field
      solr_page = -1

      rsolr = RSolr.connect :url => solr_url

      while (solr_page = solr_page.next)
        response = rsolr.get 'select', params: {
          rows: batch_size,
          start: (batch_size * solr_page),
          fl: "id",
          q: "#{model_name_solr_field}:[* TO *]"
        }

        solr_ids = response["response"]["docs"].collect { |h| h["id"] }

        break if solr_ids.empty?

        (solr_ids - Kithe::Model.where(id: solr_ids).pluck(:id)).each do |orphaned_id|
          yield orphaned_id
        end
      end
    end

    # Finds any Solr objects that have a `model_name_ssi` field
    # (or `Kithe::Indexable.settings.model_name_solr_field` if non-default), but don't
    # exist in the rdbms, and deletes them from Solr, then issues a commit.
    #
    # Under normal use, you shouldn't have to do this, but can if your Solr index
    # has gotten out of sync and you don't want to delete it and reindex from
    # scratch.
    #
    # Implemented in terms of .solr_orphan_ids.
    #
    # A bit hacky implementation, it might be nice to have a progress bar, we don't now.
    #
    # Does return an array of any IDs deleted.
    def self.delete_solr_orphans(batch_size: 100, solr_url: Kithe::Indexable.settings.solr_url)
      rsolr = RSolr.connect :url => solr_url
      deleted_ids = []

      solr_orphan_ids(batch_size: batch_size, solr_url: solr_url) do |orphan_id|
        deleted_ids << orphan_id
        rsolr.delete_by_id(orphan_id)
      end

      rsolr.commit

      return deleted_ids
    end

    # Just a utility method to delete everything from Solr, and then issue a commit,
    # using Rsolr. Pretty trivial.
    #
    # Intended for dev/test instances, not really production.
    def self.delete_all(solr_url: Kithe::Indexable.settings.solr_url)
      rsolr = RSolr.connect :url => solr_url
      rsolr.delete_by_query("*:*")
      rsolr.commit
    end
  end
end
