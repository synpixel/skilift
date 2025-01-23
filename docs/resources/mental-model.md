# Mental Model

Skilift operates on a different mental model from other Datastore libraries. Unlike other libraries, in Skilift the datastore library is considered a source of truth. Your game state should reconcile the data in a session into the game state, not the other way around.

## Why?

This mental model change is important for safety. Because the game reconciles the session into the game state, it becomes possible for sessions to continuously update and receive updates from other servers (if they happen)

In the scenario for example that a player rejoins before their last server finished saving, and the player thus receives stale data. Only after the player data loaded did the other server save the data succesfully. The next time the session pulls the data for the player, it will read new data, and your game will reconcile the new data into it's game state, showing the player their actual data.

You can see when the data is updated through `:updated`. In that callback, you should reconcile all your data into your game state.

For example:

```luau
session:updated(function(new_data)
    world:set(player, Money, new_data.money)
end)
```

Now, whenever another server happens to save just a little bit too late, the player should still receive their new data eventually.

This, combined with atomic operations should result in situations where players don't lose progress (when DataStoreService operations are stable.)