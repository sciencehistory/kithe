require "kithe/engine"
require 'kithe/indexable_settings'

module Kithe
  # for ruby-progressbar
  STANDARD_PROGRESS_BAR_FORMAT = "%a %t: |%B| %R/s %c/%u %p%% %e"

  # ActiveRecord will automatically pick this up for all our models.
  # We don't want an isolated engine, but we do want this, part of what isolated engines do.
  def self.table_name_prefix
    'kithe_'
  end

  # We don't want an isolated engine, but we do want this, part of what isolated engines do.
  # Will make generators use namespace scope, among other things.
  def self.railtie_namespace
    Kithe::Engine
  end

  # Global Kithe::Indexable settings, actually a Kithe::IndexableSettings
  # object, but you will generally use it as a simple value object with getters
  # and setters.
  #
  # * solr_url: Where to send to Solr when indexing, the base url
  #
  #     Kithe.indexable_settings.solr_url = "http://localhost:8983/solr/collection_name"
  #
  # * model_name_solr_field: If you'd like a custom solr field to store model class name in.
  #
  #     Kithe.indexable_settings.model_name_solr_field = "my_model_name_field"
  #
  # * solr_id_value_attribute: What attribute from your AR models to send to Solr
  #   `id` uniqueKey field, default the AR `id` pk, you may wish to set to `friendlier_id`.
  #
  # * writer_settings: Settings to be passed to the Traject writer, by default a
  #   Traject::SolrJsonWriter. To maintain the default settings, best to merge
  #   your new ones into defaults.
  #
  #       Kithe.indexable_settings.writer_settings.merge!(
  #         # by default we send a softCommit on every update, maybe you
  #         # want not to?
  #         "solr_writer.solr_update_args" => {}
  #         # extra long timeout?
  #         "solr_writer.http_timeout" => 100
  #       )
  #
  # * writer_class_name: By default Traject::SolrJsonWriter, but maybe
  #   you want to set to some other Traject::Writer. The writer Kithe::Indexable
  #   will send index add/remove requests to.
  #
  #       Kithe.indexable_settings.writer_class_name = "Traject::SomeOtherWriter"
  #
  # * disable_callbacks: set to true to globally disable automatic after_commit
  #
  #
  # The settings need to live here not in Kithe::Indexable, to avoid terrible
  # Rails dev-mode class-reloading weirdnesses. This module is not reloaded.
  mattr_accessor :indexable_settings do
  # set up default settings
  IndexableSettings.new(
    solr_url: "http://localhost:8983/solr/default",
    model_name_solr_field: "model_name_ssi",
    solr_id_value_attribute: "id",
    writer_class_name: "Traject::SolrJsonWriter",
    writer_settings: {
      # as default we tell the solrjsonwriter to use no threads,
      # no batching. softCommit on every update. Least surprising
      # default configuration.
      "solr_writer.thread_pool" => 0,
      "solr_writer.batch_size" => 1,
      "solr_writer.solr_update_args" => { softCommit: true },
      "solr_writer.http_timeout" => 3,
      "logger" => Rails.logger,

      # MAYBE? no skippable exceptions please
      # "solr_writer.skippable_exceptions" => []
    },
    disable_callbacks: false
  )
end

end
