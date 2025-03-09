---
previous: false
next: false
---

# Store

## Methods

### load

Loads a key and returns a new session actively pulling that key.

- Type

    ```luau
    function store<T>:load(key: string): Session<T>
    ```

- Details

    Multiple sessions for the same key may exist at the same time.

### view

Views a key and returns an object to read the latest version of that key or the value of the key in the past.

- Type

    ```luau
    function store<T>:view(key: string): View<T>
    ```

### action()

Registers the given function as an action, allowing it to be used for patching data.

- **Type**

    ```luau
    function store<T>:action(fn: (T, ...unknown) -> T): (T, ...unknown) -> T
    ```

### transaction()

Registers the given function as an action, allowing it to be used for patching within a transaction. These actions are deferred and not applied immediately. Unlike regular actions, these actions must be provided with a **unique** name.

- **Type**

    ```luau
    function skilift.action.transaction(fn: () -> (), name: string)
    ```

- **Details**

    The name must be unique.

    > [!WARNING]
    > Actions registered as a transaction should never be removed from your codebase. Removing a transaction may result in player data becoming corrupted and unreadable.
