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
        asset.create_derivatives(
          only: options[:derivative_keys],
          lazy: !!options[:lazy]
        )
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
end

