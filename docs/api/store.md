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