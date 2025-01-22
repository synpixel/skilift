--!strict

type Set<K> = { [K]: true }
type Map<K, V> = { [K]: V }

type Action<T=any, U...=...any> = (old: T, U...) -> T
type JSON = string | number | boolean | buffer | { JSON } | { [string]: JSON }

type Skilift = {
    --- Allows a function to be used as an action to update data. 
    action: <T, U...>(patcher: Action<T, U...>) -> (),
    --- Allows a function to be used as an action to update data inside a transaction.
    --- Functions marked with taction must never be removed, otherwise you may
    --- cause transactions later on to fail.
    taction: <T, U...>(name: string, patcher: Action<T, U...>) -> (),

    --- Obtains a datastore object with the given name and scope.
    datastore: <T>(name: string, scope: string?) -> Store<T>,

    --- Performs a transaction based on the two-phase commit model.
    --- When called, the function inside will be executed immediately. Any session
    --- that gets edited inside will be marked dirty. The patch functions must
    --- be manually marked for transactions, and will only apply when all operations
    --- have succeeded.
    transaction: (fn: () -> ()) -> ()
}

export type StoreOptions<T> = {
    --- The name of the Data Store
    name: string,
    --- The scope of the Data Store
    scope: string?,
    --- The default data that will automatically be available.
    default_data: () -> T,
}

export type Store<T> = {
    _store: DataStore,
    _options: StoreOptions<T>,

    --- Starts a new safe session that frequently polls for updates.
    load: (Store<T>, key: string) -> Session<T>,
    --- Returns a object used to gain insight into a key without polling for new
    --- data and applying updates.
    view: (Store<T>, key: string) -> View<T>
}

export type View<T> = {
    --- Pulls for the latest version and returns an immutable copy
    --- This may result in a failure.
    latest: (View<T>) -> T?,
    --- Pulls for a version at a given time.
    --- This may fail.
    timestamp: (View<T>, at: number) -> T?,
    --- Pulls for a vesrion with the given key.
    --- This may fail.
    version: (View<T>, version: string) -> T?,
}

export type Session<T> = {
    _store: DataStore,
    _options: StoreOptions<T>,

    key: string,

    --- Patches with the given update function. Fails if the data is locked.
    patch: <U...>(Session<T>, fn: Action<T, U...>, U...) -> (),
    --- Binds a function to whenever the session receives updated data.
    --- This should be reconciled into your own game state. When called, it will
    --- run the function given immediately.
    updated: (Session<T>, (T) -> ()) -> (),
    --- Stops polling the datastore for data, and disables any patching. This
    --- performs one more save. Releases the lock if it was locked.
    stop: (Session<T>) -> (),
    --- Performs a new pull on the datastore, checking for new data and syncing
    --- old data.
    pull: (Session<T>) -> ()

    -- ---- SESSION LOCKING ADDENDUM ----
    -- --- Locks data. This should only be used in cases where session locking is
    -- --- required. When sesion locking, other servers are unable to edit the data.
    -- --- This may error.
    -- lock: (Session<T>, expires: number) -> (),
    -- --- Steals a session from another server (if necessary) 
    -- steal: (Session<T>) -> (),
    -- --- Unlocks the session, allowing other servers to edit the data.
    -- unlock: (Session<T>) -> (),
}

type TransactionId = string

type TransactionInfo = {
    uuid: TransactionId,
    sessions: Set<Session<any>>,
}

type TransactionData = {
    actions: { { JSON } }
}

type StoredData<T> = {
    pending_transactions: { [TransactionId]: TransactionData },
    migrations_performed: { string },
    data: T
}

export type LockError = {
    why: "already_locked" | "fail_write"
}


local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local AUTOSAVE_DELAY = 20
local EXPONENT_BACKOFF = 2
local TRANSACTION_NAME = "SKILIFT_TRANSACTIONS"
local TRANSACTION_SCOPE = "global"
local TRANSACTION_DATASTORE = DataStoreService:GetDataStore(TRANSACTION_NAME, TRANSACTION_SCOPE)

local disable_new_action = false
local processing_transaction: false | TransactionInfo = false
local transaction_actions: Map<Action, string> = {}
local transaction_names: Map<string, Action> = {}
local actions: Set<Action> = {}
local cached_transactions: Map<string, boolean> = {}

local ERRORS = {
    transaction_invalid_action = {
        msg = `Regular action at %s:%s cannot be used inside a transaction for modifying data.`
    },
    transaction_invalid_function = {
        msg = `Unregistered function at %s:%s cannot be used inside a transaction for modifying data.`
    },
    action_invalid_function = {
        msg = `Unregistered function at %s:%s cannot be used for patching data.`
    },
    action_attempt_transaction = {
        msg = `Action at %s:%s can only be used for patching within transactions.`
    },

    cannot_make_action = {
        msg = `Unable to register a new action after the first session has been started.`
    }
}

type Errors = 
    | "transaction_invalid_action"
    | "transaction_invalid_function"
    | "action_invalid_function"
    | "action_attempt_transaction"
    | "cannot_make_action"

local function THROW(err: Errors, ...: string)
    error(string.format(ERRORS[err].msg, ...), 3)
end

local function LOG(...)
    print("[SKYLIFT]:", ...)
end

local function ASSERT_ACTION(action: Action)
    if processing_transaction and not transaction_actions[action] and actions[action] then
        THROW("transaction_invalid_action", debug.info(action, "sl"))
    elseif processing_transaction and not transaction_actions[action] then
        THROW("transaction_invalid_function", debug.info(action, "sl"))
    elseif not processing_transaction and transaction_actions[action] and not actions[action] then
        THROW("action_attempt_transaction", debug.info(action, "sl"))
    elseif not processing_transaction and not actions[action] then
        THROW("action_invalid_function", debug.info(action, "sl"))
    end
end

local function NOOP() end

--- Returns a function that repeats the given function every n seconds.
local function repeats(n: number, fn: () -> any)
    return function()
        while true do
            fn()
            task.wait(n)
        end
    end
end

--- Repeatedly calls fn until it succeeds using exponential back-off.
local function exponential_backoff<T...>(fn: () -> T..., start: number?, limit: number?): T...
    local delay = start or 3
    local result

    while true do
        local ok = pcall(function()
            result = { fn() }
        end)

        if not ok then
            task.wait(delay)
            delay *= EXPONENT_BACKOFF
        else
            break
        end
    end

    return unpack(result)
end

local function register_action(action: Action)
    if disable_new_action then THROW("cannot_make_action") end
    actions[action] = true
end

local function register_transaction_action(action: Action, name: string)
    if disable_new_action then THROW("cannot_make_action") end
    transaction_actions[action] = name
    transaction_names[name] = action
end

local function create_record(action: Action, ...: any)
    ASSERT_ACTION(action)
    return { action, ... }
end

local function create_transaction_record(action: Action, ...: any)
    ASSERT_ACTION(action)
    return { transaction_actions[action], ... }
end

local function already_known_version(a: DataStoreKeyInfo?, b: DataStoreKeyInfo?)
    if a == nil or b == nil then return false end
    if a.Version == b.Version then return true end
    return false
end

local function obtain_transaction_status(id: TransactionId)
    exponential_backoff(function()
        local value = TRANSACTION_DATASTORE:GetAsync(id)
        cached_transactions[id] = value or false
    end)
end

local function load_session<T>(self: Store<T>, key: string): Session<T>
    local store = self._store
    local options = self._options
    local session = { _store = store, _options = options, key = key }

    local local_key_info: DataStoreKeyInfo
    local cached = options.default_data()
    local pending_changes: { { Action } } = {}
    local updated: (data: T) -> () = NOOP
    local pulling = false

    local pending_transactions: { TransactionId } = {}
    local pending_actions_for_transactions: { { JSON } } = {}
    local transaction_status_bad = false

    --- Processes the given transaction
    local function process_transaction_id(stored: StoredData<T>, id: TransactionId)
        LOG("Checking transaction", id, "for session", store.Name, key)
        local value = cached_transactions[id]

        if value == nil then
            LOG("TRANSACTION STATUS UNKNOWN, OBTAINING")
            transaction_status_bad = true
            task.spawn(function()
                obtain_transaction_status(id)
                session:pull()
            end)
            return false
        end

        -- transaction failed, remove.
        if value == false then
            LOG("TRANSACTION FAILED", id)
            stored.pending_transactions[id] = nil
            return true
        -- transaction success
        elseif value == true then
            LOG("TRANSACTION SUCCESS", id)
            local transaction = stored.pending_transactions[id]
            LOG(`Applying {#transaction.actions} actions for session {store.Name}:{key} due to success`)
            
            for _, action in transaction.actions do
                local name = action[1] :: string
                local fn = transaction_names[name]
                ASSERT_ACTION(fn)
                LOG("Applying action", debug.info(fn, "n"), "with", unpack(action, 2))
                stored.data = fn(stored.data, unpack(action, 2))
            end

            LOG("Completed transaction", id)
            stored.pending_transactions[id] = nil
            return true
        end
    end

    local function update(stored: StoredData<T>, db_key_info: DataStoreKeyInfo?): StoredData<T>
        transaction_status_bad = false
        LOG("Performing pull and updating data")
        -- when db_key_info is nil, the data was never written to before.
        -- in that case, we overwrite it with our currently cached value.
        if db_key_info == nil then
            stored = {
                pending_transactions = {},
                migrations_performed = {},
                data = cached,
            }
        end

        -- process and commit each transaction that succeeded
        for transaction_id, transaction in stored.pending_transactions do
            process_transaction_id(stored, transaction_id)
        end
        
        -- add pending transaction
        for _, transaction in pending_transactions do
            LOG(`Added transaction id {transaction} to session {store.Name}:{key}`)
            stored.pending_transactions[transaction] = { actions = pending_actions_for_transactions }
        end

        pending_transactions = {}
        pending_actions_for_transactions = {}

        -- apply all changes we've made since the last auto-save onto the key.
        LOG(`Applying {#pending_changes} changes to {store.Name}:{key}`)
        for _, action in pending_changes do
            local fn = action[1]
            LOG("Applying action", debug.info(fn, "n"), "with", unpack(action, 2))
            stored.data = fn(stored.data, unpack(action, 2))
        end

        LOG(`Returning updated data for {store.Name}:{key}`)
        return stored
    end
    
    local function pull()
        pulling = true
        LOG(`Starting pull for {store.Name}:{key}`)
        local value: StoredData<T>, db_key_info: DataStoreKeyInfo = exponential_backoff(function()
            return store:UpdateAsync(key, update)
        end, 3, 30)

        if transaction_status_bad then return end
        LOG(`Finished pull for {store.Name}:{key}`)
        pulling = false
        -- update was succesful and all the pending changes have been reconciled
        -- into the data store.
        cached = value.data
        table.clear(pending_changes)
        
        -- the datastore was updated by the same server, so avoid unnecessarily
        -- reconciling changes.
        -- if not already_known_version(local_key_info, db_key_info) then
            local_key_info = db_key_info
            LOG(`Running update for {store.Name}:{key}`)
            updated(cached)
        -- end
    end

    local thread = task.spawn(repeats(AUTOSAVE_DELAY, pull))

    function session:updated(new: (data: T) -> ())
        new(cached)
        updated = new
    end

    function session:stop()
        updated = NOOP

        if pulling then
            -- if we're pulling, wait until it finished.
            while pulling do task.wait() end
            task.cancel(thread)
        else
            task.cancel(thread)
            exponential_backoff(function()
                store:UpdateAsync(key, update)
            end, 1, 60)
        end
    end

    local function patch_transaction<U...>(fn: Action<T, U...>, ...: U...)
        ASSERT_ACTION(fn)
        LOG(`Adding transaction action for {store.Name}:{key}`)
        local transaction = processing_transaction :: TransactionInfo
        transaction.sessions[session] = true
        table.insert(pending_transactions, transaction.uuid)
        table.insert(pending_actions_for_transactions, create_transaction_record(fn, ...))
    end

    function session:patch<U...>(fn: Action<T, U...>, ...: U...)
        if processing_transaction then
            return patch_transaction(fn, ...)
        end

        LOG(`Performing action for {store.Name}:{key}`)
        table.insert(pending_changes, create_record(fn, ...) )
        cached = fn(cached, ...)

        updated(cached)
    end

    function session:pull()
        LOG(`Manually pulling {store.Name}:{key}`)
        if pulling then
            -- if we're already pulling, wait until it finished.
            while pulling do task.wait() end
        else
            pull()
        end
    end

    return session :: any
end

local function view_key<T>(self: Store<T>, key: string): View<T>
    local view = {}
    local datastore = self._store

    function view:latest()
        local value: StoredData<T> = exponential_backoff(function()
            return datastore:GetAsync(key)
        end)

        return value.data
    end

    function view:version(version: string)
        local value: StoredData<T> = exponential_backoff(function()
            return datastore:GetVersionAsync(key, version)
        end)

        return value.data
    end

    function view:timestamp(timestamp: number)
        local value: StoredData<T> = exponential_backoff(function()
            return datastore:GetVersionAtTimeAsync(key, timestamp)
        end)

        return value.data
    end

    return view
end

local function get_store<T>(options: StoreOptions<T>): Store<T>
    local name = options.name
    local scope = options.scope or "global"

    local store = { _options = options, _store = DataStoreService:GetDataStore(name, scope) }

    store.load = load_session
    store.view = view_key

    return store
end

local function initiate_transaction(fn: () -> ())
    local uuid = HttpService:GenerateGUID(false)
    local transaction = { uuid = uuid, sessions = {} }
    processing_transaction = transaction
    LOG("Start transaction Id", uuid)
    
    local ok, err = pcall(fn :: any)

    LOG("Finished running transaction changes for", uuid)

    processing_transaction = false
    if not ok then error(err) end

    -- each session should save
    local success = true
    for session: any in transaction.sessions do
        local ok = pcall(function()
            session:pull()
        end)
        if not ok then success = false; break end
    end

    LOG(`Finished transaction {uuid} initial apply: {success}`)

    if success then
        success = pcall(function()
            TRANSACTION_DATASTORE:SetAsync(uuid, true)
        end)
        LOG("Applied transaction status", uuid)

        for session: any in transaction.sessions do
            local ok = pcall(function()
                session:pull()
            end)
            if not ok then success = false; break end
        end
    end

    LOG(`Transaction status {uuid}: {success}`)
    return success
end

return {
    action = {
        regular = register_action,
        transaction = register_transaction_action
    },

    store = get_store,

    transaction = initiate_transaction
}