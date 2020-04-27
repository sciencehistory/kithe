class Shrine
  module Plugins

    # Set up shrine `backgrounding`, where promotion and deletion can happen in a background job.
    #
    # https://shrinerb.com/docs/getting-started#backgrounding
    # https://shrinerb.com/docs/plugins/backgrounding
    #
    # By default, kithe does promotion and deletion in kithe-provided ActiveJob classes.
    #
    # But this plugin implements code to let you use kithe_promotion_directives to make them happen
    # inline instead, or disable them.
    #
    #     asset.file_attacher.set_promotion_directives(promote: false)
    #     asset.file_attacher.set_promotion_directives(promote: :inline)
    #     asset.file_attacher.set_promotion_directives(promote: "inline")
    #
    #     asset.file_attacher.set_promotion_directives(delete: :inline)
    class KitheControllableBackgrounding
      def self.load_dependencies(uploader, *)
        uploader.plugin :backgrounding
      end

      def self.configure(uploader, options = {})

        # promote using shrine backgrounding, but can be effected by promotion_directives[:promote]
        uploader::Attacher.promote_block do
          Kithe::TimingPromotionDirective.new(key: :promote, directives: self.promotion_directives) do |directive|
            if directive.inline?
              promote
            elsif directive.background?
              # What shrine normally expects for backgrounding, plus promotion_directives
              Kithe::AssetPromoteJob.perform_later(self.class.name, record.class.name, record.id, name.to_s, file_data, self.promotion_directives)
            end
          end
        end

        uploader::Attacher.destroy_block do
          Kithe::TimingPromotionDirective.new(key: :delete, directives: self.promotion_directives) do |directive|
            if directive.inline?
              destroy
            elsif directive.background?
              # What shrine normally expects for backgrounding
              Kithe::AssetDeleteJob.perform_later(self.class.name, data)
            end
          end
        end
      end
    end
    register_plugin(:kithe_controllable_backgrounding, KitheControllableBackgrounding)
  end
end
