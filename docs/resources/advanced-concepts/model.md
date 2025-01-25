---
previous: false
next: false
---

# Model

Skilift operates on a different model compared to other Datastore libraries. This model allows skilift to have better safety features compared to other libraries. The model is based around the writings of [Jack's very cool blog post](https://blog.jmdev.space/posts/datastores/).

## Session Locking

Session locking has for a while been the golden standard when it comes to managing data safely. It works well for cases where the library does not work as a source of truth, and is only used to read the initial data. While session locks prevents issues like new player data being overwritten by old player data, it comes with a couple flaws that need to be overcome, primarily:

- Session locks prevent different servers from editing data at the same time
- Players may be locked out of their data when the last server they were in has crashed, preventing players from loading their data.
- Session locks cause complexity on how to handle data when loading (stealing)

## The Model

Skilift operates on a different model that doesn't require session locks. This works because skilift is the source of truth for your save data. Furthermore, you are required to use actions in order to update.

### Source of truth

Skilift operates as a source of truth for your save data. It frequently pulls from DataStoreService new data, which is then used in your game. The data that is pulled will then receive all the actions you applied on the key since last pull and that will be reconciled into your game with `:updated`.

This allows other servers to update player data at the same time, without any issues. The data stored in the database will receive all the actions that have been applied since the last pull, which will then be saved again.

The final part of the equation to making it a source of truth is the API, which is built so that the only way to read and update the data is through `:updated` and `:patch`. Since you can only receive new data through `:updated`, it's encouraged to write code that constantly reconciles the new data into your game state, and because the tables sent from `:updated` are frozen, the only way to write new data to the session is through `:patch`.

### Atomic operations

You are only allowed to use atomic operations to update your data. Each operation is recorded until they can be applied the next time your data is pulled.

The data in the database doesn't have all the actions applied that we have. When data is pulled, the actions are applied onto the pulled data so that we have new accurate data, which is then pushed back onto the database.

### What this means for you

The way how you design your datastore code is going to be different than normal. You'll need to operate on the data directly, rather than being able to operate on your game state and push the game state into the session. This comes with the benefit though of being able to freely edit keys in multiple servers.
