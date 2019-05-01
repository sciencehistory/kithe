# Work Representatives

A Work can contain members which are child works or Assets, but does not itself have an image or other file attached. But one typically wants to show a thumbnail for a work.

Kithe, after samvera, provides a `representative` association from Work, that can point to an asset or child work, to act as a representative and be used as a thumbnail. (Unlike samvera, we don't currently provide a separate "thumbnail" association, just the one "representative").

```ruby
work.reprentative = asset
work.save!

# or, as with any active record association
work.representative_id = asset.id
work.save!
```

You can also set the representative to another work. In which case we'd need to go find _that_ works representative (possibly repeated if another child work) in order to ultimately find an Asset. To handle this, kithe *automatically* (using ActiveRecord callbacks) sets a `leaf_representative` association that will always point to an Asset, after following the chain. leaf_representative is calculated efficiently using Postgres Recursive Common Table Expressions, and set on *save*.

```ruby
work, secondary_work, asset # assume exist

secondary_work.update(representative: asset)
secondary_work.leaf_representative # == asset

work.update(representative: secondary_work)
work.representative # == secondary_work
work.leaf_representative # == asset
```

Collections can have representatives too. Assets can not, or rather have `representative` and `leaf_representative` methods that always return themselves.

```ruby
asset.representative == asset # always
asset.leaf_representative == asset # always
```

## Automatically kept in sync

You **set** the `representative` association, but **read from** the `leaf_representative` association, to get an Asset to use as a thumbnail/representative. You never need to, or should, set the `leaf_representative` association yourself, it's automatically set in ActiveRecord callbacks. You never need to iterate to find a leaf representative yourself, just look at `leaf_representative`.

We can imagine a chain of representatives: W1 -> W2 -> W3 -> Asset

If something in the middle changes it's representative -- say W2 changes it's representative to AssetPrime -- all leaf_representatives are still kept in sync, automatically.

Same if you delete something. If you delete W3 from the db entirely, W1 and W2 will both have `representative_id` and `leaf_representative_id` set to nil. If you delete Asset, that applies to all works in chain.

All of this automatic sync'ing relies on ActiveRecord callbacks, so of course doesn't function if you directly change the DB in a way that doesn't call AR callbacks. If for some reason it has gotten out of sync, you can call `work.set_leaf_representative; work.save!` to re-calculate the proper leaf representative and save the value.

There is no automatic _setting_ of a representative though. For instance, adding an initial member of a Work does _not_ automatically set that member as the work's representative. It is up to your application code to set representatives.

<a name="eagerLoading"></a>
## Eager-loading of representatives and derivatives

If you are fetching a list of Kithe::Model objects to show, you will probably want the `leaf_representative` for all of them. You _may_ also want the full list of derivatives for all of them.

You may be fetching a hetereogenous list that includes Assets, Works, and maybe Collections too. The Assets don't have representatives other than themselves, but need their derivatives eager-loaded. Everything else needs a representative loaded, and that representatives derivatives loaded.

No problem, like so:

```ruby
results = Kithe::Model.all.includes(:derivatives, leaf_representative: :derivatives)
```

All "leaf" representatives and derivatives will be eager-loaded by ActiveRecord, and for anything in your results list you can ask for `thing.representative` or `thing.representative.derivatives` without triggering additional db fetches (you are avoiding the "n+1 problem").

So you might then get the actual "derivative" object to display for any hit, with eg `some_model.leaf_representative.derivative_for(:thumbnail)`, without accidentally triggering n+1 queries.
