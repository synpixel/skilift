---
previous: false
next: false
---

# skilift

## Functions

### store()

Creates a new store.

- **Type**

    ```luau
    function skilift.store<T>(options: {
        name: string,
        scope: string?,
        default_data: () -> T
        migrations: { {step: string, migrate: (old: any) -> any} },
        schema: ((unknown) -> boolean)?,
        pull_delay: number?
    }): Session<T>
    ```

- **Details**

    default_data should always return unique data. When returning a table, make sure it's not referenced anywhere else. Schema validation through `t` or some other library can be added using the schema property. It's possible to manually change the delay between auto-saves / pulls with the pull_delay property.

### transaction()

Initiates a transaction

- **Type**

    ```luau
    function skilift.transaction(
        success: () -> (),
        failure: (() -> ())?
    ): boolean
    ```

- **Details**

    Returns a boolean indicating if the transaction was succesful or not. View the transaction article in advanced concepts for more information about how to properly handle transactions.

### strict()

Sets or reads the currently stored value for strict mode.

- **Type**

    ```luau
    function skilift.strict(value: boolean?): boolean
    ```

- **Details**

    View the [strict mode](../resources/advanced-concepts/strict-mode.md) resource for more information on what strict mode does.

### action.normal()

Registers a function as a pure function, allowing it to be used for patching sessions.

- **Type**

    ```luau
    function skilift.action.normal(fn: () -> ())
    ```

### action.transaction()

Registers a function as a pure function, allowing it to be used for patching within a transaction. These actions are deferred and not applied immediately. Unlike regular actions, these actions must be provided with a **unique** name.

- **Type**

    ```luau
    function skilift.action.transaction(fn: () -> (), name: string)
    ```

- **Details**

    Name must be unique. It's key that when ensuring compatbility, to NEVER remove, or modify a function marked as a transaction. It may corrupt or leave player saves in a bad state. Once this is pushed to production, it should never be removed.
