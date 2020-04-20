module Kithe
  # From: https://guides.rubyonrails.org/v6.0/autoloading_and_reloading_constants.html#single-table-inheritance
  #       https://edgeguides.rubyonrails.org/autoloading_and_reloading_constants.html#single-table-inheritance
  #
  # While this is recommended starting with Rails6 and zeitwerk, it will work
  # fine under Rails 5.2 and previous also, to make sure all sub-classes in
  # db are loaded, so ActiveRecord knows how to create SQL WHERE clauses
  # on particular inheritance hieararchies.
  #
  # We include in our Kithe::Model, which uses Single-Table Inheritance
  module StiPreload
    unless Rails.application.config.eager_load
      extend ActiveSupport::Concern

      included do
        cattr_accessor :preloaded, instance_accessor: false
      end

      class_methods do
        def descendants
          preload_sti unless preloaded
          super
        end

        # Constantizes all types present in the database. There might be more on
        # disk, but that does not matter in practice as far as the STI API is
        # concerned.
        #
        # Assumes store_full_sti_class is true, the default.
        def preload_sti
          types_in_db = \
            base_class.
              unscoped.
              select(inheritance_column).
              distinct.
              pluck(inheritance_column).
              compact

          types_in_db.each do |type|
            logger.debug("Preloading Single-Table Inheritance type #{type} for #{base_class.name}")
            type.constantize
          end

          self.preloaded = true
        end
      end
    end
  end
end
