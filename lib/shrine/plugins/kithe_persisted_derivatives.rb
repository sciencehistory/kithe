class Shrine
  module Plugins
    # Some convenience methods for adding/changing derivatives in
    # concurrency-safe manner:
    #
    #   * Won't make a change if the underlying original has changed
    #     so doesn't match the one you wanted to remove.
    #   * Won't over-write changes made concurrently in the db by other processes
    #   * Will always make sure to clean up any temporary files on all error
    #     and falure conditions.
    #
    # Shrine has some building blocks for this, which we use, but it's a bit tricky
    # to put them together to be generically reliable, as we think we've done here.
    #
    # All these methods will cause your Asset model to be saved, because of how
    # the shrine atomic helpers work. So these methods will by default raise
    # a TypeError if your Asset model has any unrelated outstanding changes,
    # but you can tell it to save anyway with `allow_other_changes: true`.
    #
    # ## Shrine references:
    #
    # https://shrinerb.com/docs/plugins/derivatives
    # https://shrinerb.com/docs/processing
    class KithePersistedDerivatives
      module AttacherMethods
        # Like the shrine `add_derivatives` method, but also *persists* the
        # derivatives (saves to db), in a realiably concurrency-safe way.
        #
        # Generally can take any options that shrine `add_derivatives`
        # can take, including custom `storage` or `metadata` arguments.
        #
        # Like shrine add_derivatives, it will assume the files passed in are
        # temporary, and delete them for you. If you want to disable this behavior:
        #
        #     attacher.add_persisted_derivatives({key: io}, delete: false)
        #
        # In some cases the derivatives can't be persisted because the underlying
        # database has changed such that they would not be applicable. In those
        # cases `false` will be return value, otherwise returns the new derivatives
        # just as shrine `add_derivatives`
        #
        # Because the concurrent-safe persistence method will save the associated model --
        # and save without ActiveRecord validation -- it is not safe to
        # add_persisted_derivatives on a model with other unsaved changes. The
        # method will by default refuse to do so, throwing a TypeError. If you'd
        # like to force it, pass `allow_other_changes: true` as an argument.
        #
        # Also takes care of deleting any replaced derivative files, that are no longer
        # referenced by the model. Shrine by default does not do this:
        # https://github.com/shrinerb/shrine/issues/468
        #
        # All deletions are inline. In general this could be a fairly expensive operation,
        # it can be wise to do it in a bg job.
        def add_persisted_derivatives(local_files, **options)
          other_changes_allowed = !!options.delete(:allow_other_changes)
          if record && !other_changes_allowed && record.changed?
            raise TypeError.new("Can't safely add_persisted_derivatives on model with unsaved changes. Pass `allow_other_changes: true` to force.")
          end

          existing_derivative_files = nil

          # upload to storage
          new_derivatives = upload_derivatives(local_files, **options)

          begin
            atomic_persist do |reloaded_attacher|
              # record so we can delete any replaced ones...
              existing_derivative_files = map_derivative(reloaded_attacher.derivatives).collect { |path, file| file }

              # make sure we don't override derivatives created in other jobs, by
              # first using the current up-to-date derivatives from db,
              # then merging our changes in on top.
              set_derivatives(reloaded_attacher.derivatives)
              merge_derivatives(new_derivatives)
            end
          rescue Shrine::AttachmentChanged, ActiveRecord::RecordNotFound => e
            # underlying file has changed or model has been deleted, inappropriate
            # to add the derivatives, we can just silently drop them, but clean
            # up after ourselves.
            delete_derivatives(local_files) unless options[:delete] == false
            delete_derivatives(new_derivatives)

            return false
          rescue StandardError => e
            # unexpected error, clean up our files and re-raise
            delete_derivatives(local_files) unless options[:delete] == false
            delete_derivatives(new_derivatives)
            raise e
          end

          # Take care of deleting from storage any derivatives that were replaced.
          current_derivative_files = map_derivative(derivatives).collect { |path, file| file }
          replaced_files = existing_derivative_files - current_derivative_files
          delete_derivatives(replaced_files)

          new_derivatives
        end

        # Like the shrine `create_derivatives` method, but persists the created derivatives
        # to the database in a concurrency-safe way.
        #
        # Can take all options that shrine `create_derivatives` can take, including custom
        # processors, custom storage key, and arbitrary custom processor arguments.
        #
        #     asset.file_attacher.create_persisted_derivatives
        #     asset.file_attacher.create_persisted_derivatives(storage: :custom_key)
        #     asset.file_attacher.create_persisted_derivatives(:kithe_derivatives)
        #     asset.file_attacher.create_persisted_derivatives(:kithe_derivatives, some_arg: "value")
        #     asset.file_attacher.create_persisted_derivatives(:kithe_derivatives, alternate_source_file)
        #
        # Also has an `allow_other_changes` argument, see #add_persisted_derivatives.
        def create_persisted_derivatives(*args, storage: nil, allow_other_changes: false, **options)
          return false unless file

          local_files = process_derivatives(*args, **options)
          add_persisted_derivatives(local_files, storage: storage, allow_other_changes: allow_other_changes)
        end

        # Kind of like built-in Shrine #remove_derivatives, but also takes care of
        # persisting AND deleting the removed derivative file from storage --
        # all in concurrency-safe way, including not making sure to overwrite
        # any unrelated derivatives someone else was adding.
        #
        # Can take the same sorts of path arguments as Shrine derivative #remove_derivatives
        #
        #     asset.file_attacher.remove_persisted_derivatives(:small_thumb)
        #     asset.file_attacher.remove_persisted_derivatives(:small_thumb, :large_thumb)
        #     asset.file_attacher.remove_persisted_derivatives(:small_thumb, :large_thumb, allow_other_changes: true)
        def remove_persisted_derivatives(*paths, **options)
          return if paths.empty?

          other_changes_allowed = !!options.delete(:allow_other_changes)
          if record && !other_changes_allowed && record.changed?
            raise TypeError.new("Can't safely add_persisted_derivatives on model with unsaved changes. Pass `allow_other_changes: true` to force.")
          end

          removed_derivatives = nil
          atomic_persist do |reloaded_attacher|
            set_derivatives(reloaded_attacher.derivatives)
            removed_derivatives = remove_derivatives(*paths, delete: false)
          end

          if removed_derivatives
            map_derivative(removed_derivatives) do |_, derivative|
              derivative.delete if derivative
            end
          end

          removed_derivatives
        rescue Shrine::AttachmentChanged, ActiveRecord::RecordNotFound
          # original was already deleted or changed, the derivatives wer'e trying to delete.
          # It should be fine to do nothing, the process that deleted or changed
          # the model should already have deleted all these derivatives.
          # But we'll return false as a signel.
          return false
        end
      end
    end
    register_plugin(:kithe_persisted_derivatives, KithePersistedDerivatives)
  end
end
