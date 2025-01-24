local types = require("./types")
local budget = require("./budget")
local retry = require("./retry")
local LOG = require("./log")
local actions = require("./actions")
local flags = require("./flags")
local transaction = require("./checktransaction")

local AUTOSAVE_DELAY = 10

local NOOP = function() end

type JSON = types.JSON
type Action<T=any, U...=...any> = types.Action<T, U...>
type Store<T> = types.Store<T>
type Session<T> = types.Session<T>
type StoredData<T> = types.StoredData<T>
type TransactionId = types.TransactionId
type TransactionInfo = types.TransactionInfo
type TransactionAction = types.TransactionAction
type TransactionData = types.TransactionData

local function migrate<T>(session: Session<T>, stored: StoredData<T>)
    local migrations = session._options.migrations

    if #migrations == #stored.migrations_performed then return end
    LOG(`{session._name}: Performing Migration`)
    for i, migration in migrations do
        if table.find(stored.migrations_performed, migration) then continue end
        LOG(`{session._name}: Migration Step {migration.step}`)
        stored.data = migration.migrate(stored.data)
        table.insert(stored.migrations_performed, migration.step)
    end
end

local function perform_transaction<T>(stored: StoredData<T>, action: TransactionAction)
    local fn = actions.obtain_transaction_action(action.fn)
    local values = action.values

    stored.data = fn(stored.data, unpack(values))
end

local function create_migrations_table(session: Session<any>)
    local migrations = {}
    for i, migration in session._options.migrations do
        table.insert(migrations, migration.step)
    end
    return migrations
end

local function update<T>(
    session: Session<T>,
    changes: { Action },
    pending_transactions: { [TransactionId]: TransactionData },
    stored: StoredData<T>,
    db_key_info: DataStoreKeyInfo?
): StoredData<T>?
    if db_key_info == nil then
        stored = {
            pending_transactions = {},
            migrations_performed = create_migrations_table(session),
            data = session._options.default_data()
        }
    end

    LOG(`Applying {#changes} changes to {session._name}`)

    for id, data in stored.pending_transactions do
        local status: "completed" | "failed" | "unknown" = transaction.is_transaction_complete(id)
        LOG(`{session._name}: Pending Transaction Status {id}: {status}`)
        
        if status == "completed" then
            for _, action in data.success do
                perform_transaction(stored, action)
            end
            stored.pending_transactions[id] = nil
        elseif status == "failed" then
            for _, action in data.failure do
                perform_transaction(stored, action)
            end
            stored.pending_transactions[id] = nil
        elseif status == "unknown" then
            -- transaction status is unknown. nothing happens
        else
            error("unhandled case")
        end
    end

    migrate(session, stored)

    for id, data in pending_transactions do
        LOG(`Added transaction {id} to {session._name}`)
        stored.pending_transactions[id] = data
    end

    for _, action in changes do
        local fn = action[1]
        LOG("Applying action", debug.info(fn, "n"), "with", unpack(action, 2))
        stored.data = fn(stored.data, unpack(action, 2))
    end

    LOG(`Returning updated data for {session._name}`)

    table.clear(changes)
    return stored, session._user_ids
end

local function pull_auto<T>(session: Session<T>, transactions: { [TransactionId]: TransactionData })
    local swap = session._changes
    local store, key = session._store, session.key

    session._next_save_opportunity = math.huge
    budget.delay_until_meets_budget("update", 5)

    local ok, result: StoredData<T> = pcall(function()
        return store:UpdateAsync(key, function(value, keyinfo)
            return update(session, swap, transactions, value, keyinfo)
        end)
    end)

    session._next_save_opportunity = os.clock() + AUTOSAVE_DELAY

    if not ok then
        error(`Failed to auto-save {result}`)
    end

    session._cached = result
    session._updated(result.data)
end

local function force_pull<T>(session: Session<T>)
    local swap = session._changes
    local store, key = session._store, session.key

    session._next_save_opportunity = math.huge

    local result: StoredData<T> = retry.regular_retry(function()
        budget.delay_until_meets_budget("update", 5)
        return store:UpdateAsync(key, function(value, keyinfo)
            return update(session, swap, value, keyinfo)
        end)
    end)

    session._next_save_opportunity = os.clock() + AUTOSAVE_DELAY
    session._cached = result
    session._updated(result.data)
end

local function thread<T>(session: Session<T>)
    while true do
        if session._next_save_opportunity - os.clock() > 0 then task.wait(); continue end
        pcall(pull_auto, session, {}) -- silence autosave error if emitted
    end
end

local function patch_transaction<T, U...>(session: Session<T>, fn: Action<T, U...>, ...: U...)
    LOG(`Adding transaction action for {session._name}`)
    local transaction = flags.processing_transaction :: TransactionInfo
    local records = transaction.sessions[session] or { success = {}, failure = {} }
    local record = actions.create_transaction_record(fn, ...)

    if transaction.state == "failure" then
        table.insert(records.failure, record)
    elseif transaction.state == "success" then
        table.insert(records.success, record)
    end

    transaction.sessions[session] = records
end

local function patch_regular<T, U...>(session: Session<T>, fn: Action<T, U...>, ...: U...)
    LOG(`Performing action for {session._name}`)
    table.insert(session._changes, actions.create_record(fn, ...) )
    session._cached.data = fn(session._cached.data, ...)
    session._updated(session._cached.data)
end

local function patch<T, U...>(session: Session<T>, fn: Action<T, U...>, ...: U...)
    actions.ASSERT_ACTION(fn)
    if flags.processing_transaction then
        patch_transaction(session, fn, ...)
    else
        patch_regular(session, fn, ...)
    end
end

local function updated<T>(session: Session<T>, new: (data: T) -> ())
    if coroutine.status(session._thread) == "dead" then return end
    new(session._cached.data)
    session._updated = new
end

local function stop<T>(session: Session<T>)
    updated = NOOP
    task.cancel(session._thread)
    force_pull(session)
end

local function add_userid<T>(session: Session<T>, user_id: number)
    table.insert(session._user_ids, user_id)
end

local function load_session<T>(self: Store<T>, key: string): Session<T>
    local session = {
        _name = `{self._store.Name}:{key}`,
        _store = self._store,
        _options = self._options,
        _changes = {},
        _pending_transactions = {},
        _next_save_opportunity = 0,
        _updated = NOOP,
        _user_ids = {},
        _cached = {
            pending_transactions = {},
            migrations_performed = {},
            data = self._options.default_data()
        },
        key = key
    }

    session.patch = patch
    session.updated = updated
    session.stop = stop
    session.gdpr = add_userid

    session._thread = task.spawn(thread, session :: any)

    return session :: any
end

return {
    load_session = load_session,
    pull_auto = pull_auto,
    force_pull = force_pull,
}