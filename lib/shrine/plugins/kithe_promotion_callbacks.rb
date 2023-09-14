class Shrine
  module Plugins
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
    # It's a bit hard to get this to happen in shrine architecture. We end up needing to assume
    # activerecord and wrap the activerecord_after_save method (for inline promotion). And then also
    # overwrite atomic_promote to get background promotion and other cases.
    #
    # Because getting this right required some shuffling around of where the wrapping happened, it
    # was convenient and avoided confusion to isolate wrapping in a class method that can be used
    # anywhere, and only depends on args passed in, no implicit state anywhere.
    #
    # ## Sharing same tempfile for processing
    #
    # If we have maybe multiple before_promotion hooks that all need an on-disk file,
    # PLUS maybe multiple `add_metadata` hooks that need an on-desk file -- we
    # ABSOLUTELY do NOT each to do a separate copy/download from possibly remote cloud source!
    #
    # The default shrine implementation using Down::ChunkedIO may avoid that (not necessarily
    # as a contract!), BUT still makes multiple local copies, which can still be a performance issue
    # for large files.
    #
    # The solution is the [Shrine tempfile plugin](https://shrinerb.com/docs/plugins/tempfile), which
    # requires the UploadedFile to be opened *around* all uses of `Shrine.with_file`.
    #
    # We include some pretty kludgey code to make this a thing.
    #
    # To take advantage of it, you DO need to add `Shrine.plugin :tempfile` in your app, we don't
    # want to force this global on apps!
    #
    # Note *after_promotion* hooks won't share the common tempfile, since the UploadedFile location
    # has been changed from the one we opened!
    class KithePromotionCallbacks
      def self.load_dependencies(uploader, *)
        uploader.plugin :kithe_promotion_directives
      end

      # promotion logic differs somewhat in different modes of use (bg or inline promotion),
      # so we extract the wrapping logic here. Exactly what the logic wrapped is can
      # differ.
      #
      #     Kithe::PromotionCallbacks.with_promotion_callbacks(record) do
      #        promotion_logic # sometimes `super`
      #     end
      #
      # This also contains some pretty kludgey code to open the underlying Shrine::UploadedFile
      # *around* the before_promotion hooks AND promotion.  When combined with Shrine tempfile plugin,
      # this means all `before_promotion` hooks and `add_metadata` hooks can use `Shrine.with_file`
      # to get the
      def self.with_promotion_callbacks(model)
        # only if Shrine::UploadedFile isn't *already* open we definitely want
        # to open it and keep it open -- so WITH Shrine tempfile plugin, we can have
        # various hooks sharing the same tempfile instead of making multiple copies.
        unless model.file_attacher.file.opened?
          model.file_attacher.file.open
          self_opened_file = model.file_attacher.file
        end


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
      ensure
        # only if we DID open the Shrine::UploadedFile ourselves, for the purpose of
        # using a common tempfile with Shrine tempfile plugin,
        # make sure to clean up after ourselves by closing it.
        self_opened_file.close if self_opened_file && self_opened_file.opened?
      end

      module AttacherMethods
        # For INLINE promotion, we need to wrap this one in callbacks, in order to be
        # wrapping enough to a) be able to cancel in `before`, and b) have `after`
        # actually be running after promotion is complete and persisted.
        #
        # But we only want to do it here for 'inline' promotion mode. For 'false'
        # disabled promotion, we don't want to run callbacks at all; and for 'background'
        # this is too early, we want callbacks to run in bg job, not here. AND only
        # if we're actually promoting, otherwise we don't want to run callbacks!
        def activerecord_after_save
          if self.promotion_directives["promote"] == "inline" && promote?
            Shrine::Plugins::KithePromotionCallbacks.with_promotion_callbacks(record) do
              super
            end
          else
            super
          end
        end

        # Wrapping atomic_promote in callbacks gets background promotion, since the shrine pattern
        # for background job for promotion uses atomic_promote. It also gets any 'manual' use of atomic
        # promote, such as from our Asset#promote method.
        def atomic_promote(*args, **kwargs)
          Shrine::Plugins::KithePromotionCallbacks.with_promotion_callbacks(record) do
            super
          end
        end
      end
    end
    register_plugin(:kithe_promotion_callbacks, KithePromotionCallbacks)
  end
end
