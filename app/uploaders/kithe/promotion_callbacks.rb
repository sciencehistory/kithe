module Kithe

  # We want ActiveSupport-style callbacks around "promotion" -- the shrine process of finalizing
  # a file by moving it from 'cache' storage to 'store' storage.
  #
  # We want to suport after_promotion hooks, and before_promotion hooks, the before_promotion hooks
  # should be able to cancel promotion. (A convenient way to do validation even with backgrounding promotion,
  # although you'd want to record the validation fail somewhere)
  #
  # For now, the actual hooks are registered in the `Asset` activerecord model. This works because
  # our Asset model only has ONE shrine attachment, it is backwards compatible with kithe 1.
  # It might make more sense to have the callbacks on the Uploader itself, in the future though.
  #
  # We want to be able to register these callbacks, and have them invoked regardless of how
  # promotion happens -- inline; in a background job; or even explicitly calling Asset#promote
  #
  # ## Weird implementation
  #
  # The implementation ends up a bit split between different files. Asset defines promotion callbacks.
  # The kithe_promotion_directives plugin on AssetUploader gives it promotion directives, that Asset
  # has too. One of those promotion directives is :skip_callbacks, to DISABLE this functionality.
  #
  # This module provides a helper method that can wrap the actual promotion logic, and apply callbacks
  # (unless directive :skip_callbacks). The actual promotion logic differs depending on whether it's
  # inline, bg job, or in Asset#promote; we need to call PromotionCallbacks.with_promotion_callbacks
  # in each of those places, because the way shrine is currently architected doens't give us a single
  # place we can hook in. Which is why we DRY the logic we can DRY here.
  module PromotionCallbacks

    # Eg, in our Kithe::AssetPromoteJob
    #
    #     Kithe::PromotionCallbacks.with_promotion_callbacks(record) do
    #        attacher.atomic_promote
    #     end
    #
    def self.with_promotion_callbacks(model)
      # If callbacks haven't been skipped, and we have a model that implements
      # callbacks, wrap yield in callbacks.
      #
      # Otherwise, just do it.
      if (  !model.file_attacher.promotion_directives["skip_callbacks"] &&
            model &&
            model.class.respond_to?(:_promotion_callbacks) )
        model.run_callbacks(:promotion) do
          yield
        end
      else
        yield
      end
    end
  end
end
