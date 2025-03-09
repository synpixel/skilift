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

    Returns a boolean indicating if the transaction was successful or not. View the transaction article in advanced concepts for more information about how to properly handle transactions.

### strict()

Sets or reads the currently stored value for strict mode.

- **Type**

    ```luau
    function skilift.strict(value: boolean?): boolean
    ```

- **Details**

    View the [strict mode](../resources/advanced-concepts/strict-mode.md) resource for more information on what strict mode does.
