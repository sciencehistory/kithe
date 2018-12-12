require 'ruby-progressbar'

namespace :kithe do
  desc "bulk create derivatives. Uses command line options run `rake kithe:create_derivatives -- -h` for options"
  task :create_derivatives => :environment do
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: ./bin/rake kithe:create_derivatives -- [options]"
      opts.on("--derivatives TYPES", "Comma-seperated list of type keys") { |ids| options[:derivative_keys] = ids.split(",")}
      opts.on("--lazy","Lazy create") { options[:lazy] = true }
      opts.on("--asset-id FRIENDLIER_IDS", "Comma-seperated list of asset (friendlier) ids") { |ids| options[:asset_ids] = ids.split(",") }
      opts.on("--work-id FRIENDLIER_IDS", "Comma-seperated list of work (friendlier) ids") { |ids| options[:work_ids] = ids.split(",") }
    end.tap do |parser|
      parser.parse!(parser.order(ARGV) {})
    end

    scope = Kithe::Asset.all
    if options[:work_ids]
      scope = scope.joins(:parent).where("parents_kithe_models.friendlier_id":  options[:work_ids])
    end
    scope = scope.where(friendlier_id: options[:asset_ids]) if options[:asset_ids]
    scope = scope.includes(:derivatives) if options[:lazy]

    progress_bar = ProgressBar.create(total: scope.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")

    scope.find_each do |asset|
      asset.create_derivatives(only: options[:derivative_keys], lazy: !!options[:lazy])
      progress_bar.increment
    end
  end
end

