## Migrating Derivatives to Kithe 2.0

Kithe 2.0 upgrades to shrine 3.x, and also switches from a custom Derivatives implementation to one based on shrine 3.x's [standard derivatives](https://shrinerb.com/docs/plugins/derivatives).

In Kithe 1.0, there is a `kithe_derivatives` table in your database; a `Kithe::Derivatives` ActiveRecord model representing it; and a `derivatives` `has_many` association from Asset to `Kithe::Derivatives`.

To migrate to Kithe 2, we don't need to move where the actual derivative files on disk are at all, but we need to move the JSON hash referencing them (and including metadata about them) from the `kithe_derivatives` table, to a key in the `file_data` hash in the Asset model (which is in `kithe_models` table using rails single-table inheritance).

**Because we don't think anyone other than Science History Institute is currently using kithe 1.x in this way and needs to do a migration, we haven't invested in making the migration maximally flexible and easy for all use cases, we've just done what we need for us. But if we don't know about you and you are in this situation and have trouble, please file a GH issue to get in touch.**

1. You will want to have the master branch of your app running on a kithe 2.0.0.alpha release (which still uses `Kithe::Derivatives`, but a branch prepared that runs on 2.0.0 final release (which does not, uses new shrine-style derivatives)

2. You will want to somehow freeze editing in your deployed app. Either take it offline entirely, or if you have a way to just prevent any editing of files/derivatives, that's fine -- we need Asset attachments not to be changing.

3. Then run `./bin/rake kithe:migrate:derivatives_to_2`. This will move over all derivatives references from `kithe_derivatives` table to their new kithe 2.0 location.
  * While this is going on, if the app is running, it can still be using the old derivatives.

4. Now deploy the version of your app that uses kithe 2.0.0 final (not alpha)
  * Now it will be *using* the derivatives you migrated over, and *not* the old ones.
  * Now you can re-enable ingest/mutation of file attachments.

5. At your convenience in the future, remove the `kithe_derivatives` table which is now unused.


**Note** You can run `./bin/rake kithe:migrate:derivatives_to_2` on kithe 2.0.0 final too -- the rake task re-constructs the necessary ActiveRecord modelling to reference the `kithe_derivatives` table. Not sure how you would fit this into a useful migration workflow, but it is available if needed.
