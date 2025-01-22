type Action<T=any, U...=...any> = (old: T, U...) -> T

type Skylift = {
    --- Allows a function to be used as an action to update data. 
    action: <T, U...>(patcher: Action<T, U...>) -> (),
    --- Allows a function to be used as an action to update data inside a transaction.
    --- Functions marked with taction must never be removed, otherwise you may
    --- cause transactions later on to fail.
    taction: <T, U...>(name: string, patcher: Action<T, U...>) -> (),

    --- Obtains a datastore object with the given name and scope.
    datastore: <T>(name: string, scope: string?) -> Datastore<T>,

    --- Performs a transaction based on the two-phase commit model.
    --- When called, the function inside will be executed immediately. Any session
    --- that gets edited inside will be marked dirty. The patch functions must
    --- be manually marked for transactions, and will only apply when all operations
    --- have succeeded.
    transaction: (fn: () -> ()) -> ()
}

export type Datastore<T> = {
    --- Starts a new safe session that frequently polls for updates.
    load: (key: string) -> Session<T>,
    --- Returns a object used to gain insight into a key without polling for new
    --- data and applying updates.
    view: (key: string) -> View<T>
}

export type View<T> = {
    --- Pulls for the latest version and returns an immutable copy
    latest: (View<T>) -> T,
    --- Pulls for a version at a given time.
    at: (View<T>, at: number) -> T,
    --- Pulls for a vesrion with the given key.
    version: (View<T>, version: string) -> T,
}

export type Session<T> = {
    --- Patches with the given update function. Fails if the data is locked.
    patch: <U...>(Session<T>, fn: Action<T, U...>, U...) -> (),
    --- Binds a function to whenever the session receives updated data.
    --- This should be reconciled into your own game state. When called, it will
    --- run the function given immediately.
    updated: (Session<T>, T) -> (),
    --- Stops polling the datastore for data, and disables any patching. This
    --- performs one more save. Releases the lock if it was locked.
    stop: (Session<T>) -> (),

    ---- SESSION LOCKING ADDENDUM ----
    --- Locks data. This should only be used in cases where session locking is
    --- required. When sesion locking, other servers are unable to edit the data.
    --- This may error.
    lock: (Session<T>, expires: number) -> (),
    --- Steals a session from another server (if necessary) 
    steal: (Session<T>) -> (),
    --- Unlocks the session, allowing other servers to edit the data.
    unlock: (Session<T>) -> (),
}

export type LockError = {
    why: "already_locked" | "fail_write"
}

type Map<K, V> = { [K]: V }
type Array<T> = { T }
type Set<K> = Map<K, true>

local processing_transaction = false
local transaction_actions: Map<Action, string> = {}
local transaction_names: Map<string, Action> = {}
local actions: Set<Action> = {}

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

}

local function THROW(err: keyof<typeof(ERRORS)>, ...: string)
    error(string.format(ERRORS[err], ...), 3)
end

local function ASSERT_ACTION(action: Action)
    if processing_transaction and not transaction_actions[action] and actions[action] then
        THROW("transaction_invalid_action", debug.info(action, "sl"))
    elseif processing_transaction and not transaction_actions[action] then
        THROW("transaction_invalid_function", debug.info(action, "sl"))
    elseif not processing_transaction and transaction_actions[action] then
        THROW("action_attempt_transaction", debug.info(action, "sl"))
    elseif not processing_transaction and not actions[action] then
        THROW("action_invalid_function", debug.info(action, "sl"))
    end
end