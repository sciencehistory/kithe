require 'ruby-progressbar'

namespace :kithe do
  # This one gives you lots of options, but is kinda confusing.
  # What you probably want to do most of all is kithe:create_derivatives:all_default_lazy
  desc "bulk create derivatives. Uses command line options run `rake kithe:create_derivatives -- -h` for options"
  task :create_derivatives => :environment do
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: ./bin/rake kithe:create_derivatives -- [options]"
      opts.on("--derivatives=TYPES", "comma-seperated list of type keys") { |ids| options[:derivative_keys] = ids.split(",")}
      opts.on("--lazy", "Lazy create") { options[:lazy] = true }
      opts.on("--asset-id=FRIENDLIER_IDS", "comma-seperated list of asset (friendlier) ids") { |ids| options[:asset_ids] = ids.split(",") }
      opts.on("--work-id=FRIENDLIER_IDS", "comma-seperated list of work (friendlier) ids") { |ids| options[:work_ids] = ids.split(",") }
      opts.on("--bg[=QUEUE_NAME]", "queue up ActiveJob per asset to create, with optional queue name") { |queue| options[:bg] = queue || true}
    end.tap do |parser|
      parser.parse!(parser.order(ARGV) {})
    end

    scope = Kithe::Asset.all
    if options[:work_ids]
      scope = scope.joins(:parent).where("parents_kithe_models.friendlier_id":  options[:work_ids])
    end
    scope = scope.where(friendlier_id: options[:asset_ids]) if options[:asset_ids]

    progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

    scope.find_each do |asset|
      begin
        progress_bar.title = asset.friendlier_id

        if options[:bg]
          job_scope = Kithe::CreateDerivativesJob

          if options[:bg].kind_of?(String)
            job_scope = job_scope.set(queue: options[:bg])
          end

          job_scope.perform_later(
            asset,
            only: options[:derivative_keys],
            lazy: !!options[:lazy]
          )
        else
          asset.create_derivatives(
            only: options[:derivative_keys],
            lazy: !!options[:lazy]
          )
        end
      rescue Shrine::FileNotFound => e
        progress_bar.log("original missing for #{asset.friendlier_id}")
        # it's cool, skip it
      end
      progress_bar.increment
    end
  end

  namespace :create_derivatives do
    # See also kithe:create_derivatives task for being able to specify lots of params
    desc "Create all default definitions only if not already existing. Most common task."
    task :lazy_defaults => :environment do
      progress_bar = ProgressBar.create(total: Kithe::Asset.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      Kithe::Asset.find_each do |asset|
        begin
          progress_bar.title = asset.friendlier_id
          asset.create_derivatives(lazy: true)
        rescue Shrine::FileNotFound => e
          progress_bar.log("original missing for #{asset.friendlier_id}")
          # it's cool, skip it
        end
        progress_bar.increment
      end
    end
  end



  namespace :migrate do
    # Migrate kithe 1 derivatives to kithe 2 derivatives.
    #
    # Recommend your app is disabled or READ-ONLY when running this.
    #
    # You can run this with your app on a kithe 2 alpha release, in which
    # case the Kithe::Derivative model and association from Asset still exists,
    # so we can use it to migrate.
    #
    # If you are running on a Kithe 2.0 release past alpha, this rake task
    # hackily creates a Kithe::Derivative class and association to it from
    # Asset, so it can be used for fetching data for migration.
    #
    # After runnig this, before swictching out of read-only mode, the app
    # should be upgraded to a full Kithe 2.0 release, using new shrine 3.0
    # style derivatives, that we have migrated over.
    #
    # At a later point, it's up to you to remove the now un-used
    # :kithe_derivatives table in a local migration
    #
    #         drop_table :kithe_derivatives
    #
    desc "Migrate derivatives from kithe 1 to kithe 2"
    task :derivatives_to_2 => :environment do
      # If we're on Kithe 2 past alpha, the :derivatives association is
      # already missing, we're going to hackily add it back in for
      # the purpose of this rake task.
      #
      # This is hacky, but good enough.
      unless defined?(Kithe::Derivative)
        class Kithe::Derivative < ApplicationRecord
        end
      end

      unless Kithe::Asset.reflect_on_association(:derivatives)
        Kithe::Asset.has_many :derivatives, foreign_key: "asset_id"
      end

      progress_bar = ProgressBar.create(total: Kithe::Asset.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      Kithe::Asset.includes(:derivatives).find_each do |asset|
        progress_bar.increment

        next unless asset.file_data.present?

        # Make a hash with { key_as_string => shrine_json_for_derivative }
        # ...key for each existing old-style derivative
        new_deriv_json = asset.derivatives.collect do |old_style_deriv|
          [old_style_deriv.key.to_s, old_style_deriv.file_data]
        end.to_h

        # If there were no old-style derivatives nothing to do
        next unless new_deriv_json.present?

        # Take old-style derivatives and save them in the original file JSON
        # structure, where shrine 3 derivatives feature expeects them.
        asset.file_data["derivatives"] ||= {}
        asset.file_data["derivatives"].merge!(new_deriv_json)

        asset.save!
      end
      progress_bar.finish
    end
  end
end

