module Kithe
  # Can be included in a controller, or usually in ApplicationController for your
  # whole app, to batch solr indexing that takes place in a controller action, into
  # a single or fewer solr index commands.
  #
  # We used to just have implementers write this simple code in thier local app, which
  # works fine, but you wind up with the around filter in all your stack traces, since
  # it's around every action.
  #
  # So instead, just
  #
  #     include Kithe::BatchIndexableAroundAction
  #
  # in eg ApplicationController
  #
  module BatchIndexableAroundAction
    extend ActiveSupport::Concern

    included do
      around_action :_kithe_batch_indexable_around_action
    end

    # Used as a Rails controller around_action to batch any kithe indexing directives
    # in a controller action.
    #
    # As `index_with(batching: true)` only creates a Traject::Writer lazily on demand,
    # this should not add appreciable overhead to actions that don't end up triggering any Solr updates.
    def _kithe_batch_indexable_around_action
      Kithe::Indexable.index_with(batching: true) do
        yield
      end
    end
  end
end
