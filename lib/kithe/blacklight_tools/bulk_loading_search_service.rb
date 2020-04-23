require 'kithe/blacklight_tools/search_service_bulk_load'

module Kithe
  module BlacklightTools
    # A convenience sub-class of Blacklight::SearchService that
    # _just_ includes Kithe::BlacklightTools::SearchServiceBulkLoad.
    #
    # So if you just need a stock Blacklight::SearchService with this
    # functionality, in your CatalogController you can conveniently simply:
    #
    #     require 'kithe/blacklight_tools/bulk_loading_search_service'
    #     class CatalogController < ApplicationController
    #       include Blacklight::Catalog
    #       # ...
    #
    #       self.search_service_class = Kithe::BlacklightTools::BulkLoadingSearchService
    #
    #       # ...
    #     end
    #
    # Do NOT sub-class this BulkLoadingSearchService in a local app or gem.
    # If you need more things in a SearchService, instead make your own
    # SearchService subclass and
    # `include Kithe::BlacklightTools::SearchServiceBulkLoad` directly.
    # This class is simply a convenience for when you need nothing else.
    #
    # Kithe devs: Don't add anything to this class beyond
    # `include Kithe::BlacklightTools::SearchServiceBulkLoad`, so that remains true!
    #
    # Note: This is in `./lib` rather than `./app` so it should never get
    # auto-loaded by the app, as kithe does not require Blacklight and loading
    # this file without Blacklight would produce an error. Thus the need
    # for the explicit "require"
    class BulkLoadingSearchService < ::Blacklight::SearchService
      include Kithe::BlacklightTools::SearchServiceBulkLoad
    end
  end
end
