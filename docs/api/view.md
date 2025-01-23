# View

Views are used to read the value of a key right now, or in the past.

## Methods

### latest

Fetches the latest version of the key.

- Type

    ```luau
    function view<T>:latest(): T
    ```
- Details

    Always performs a GetAsync request.

### version

Fetches a specific version of the key.

- Type

    ```luau
    function view<T>:version(version: string): T
    ```

- Details

    Always performs a GetVersionAsync request.

### timestamp

Fetches  verstheion of the key at the given timestamp.

- Type

    ```luau
    function view<T>:timestamp(unix: number): T
    ```

- Details

    Always performs a GetVersionAtTimestampAsync request.
