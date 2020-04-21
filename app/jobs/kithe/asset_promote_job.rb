module Kithe
  class AssetPromoteJob < Job
    # note we add a `promotion_directives` arg on the end, differing from standard
    # shrine. It is a hash.
    def perform(attacher_class, record_class, record_id, name, file_data, promotion_directives)
      attacher_class = Object.const_get(attacher_class)
      record         = Object.const_get(record_class).find(record_id) # if using Active Record

      attacher = attacher_class.retrieve(model: record, name: name, file: file_data)
      attacher.set_promotion_directives(promotion_directives)

      Kithe::PromotionCallbacks.with_promotion_callbacks(record) do
        attacher.atomic_promote
      end
    rescue Shrine::AttachmentChanged, ActiveRecord::RecordNotFound
      # attachment has changed or record has been deleted, nothing to do
    end
  end
end
