---
previous: false
next: false
---

# Session

Sessions can be obtained from a [Store](./store.md) and represent a key that is actively being loaded by the server.

## Methods

### patch

Patches the currently stored data with a given patcher function. Patches will apply immediately outside of a transaction.

- Type

    ```luau
    function session<T>:patch<U...>(fn: (T, U...) -> T, T...)
    ```

- Details

    When inside a transaction, instead of the patch being applied immediately they are deferred until the next pull.

### updated

Binds a callback to whenever a session is updated. Sessions should serve as a source of truth for your game, so inside the callback you should reconcile all your data into your game state.

- Type

    ```luau
    function session<T>:updated(fn: (T) -> ())
    ```

- Details

    The callback is always called immediately for the first time.

### stop

Stops the session and saves the last data stored.

- Type

    ```luau
    function session<T>:stop()
    ```

### userid

Adds a User Id to an array, which will be used for tracking GDPR metadata.

- Type

    ```luau
    function session<T>:userid(user: number)

- Details

    This isn't saved. You'll have to call this on every server you join.

## Properties

### key

The key the session is reading from.

- Type

    ```luau
    session.key: string
    ```
