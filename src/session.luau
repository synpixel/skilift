local types = require("./types")
local budget = require("./budget")
local retry = require("./retry")
local LOG = require("./log")
local action = require("./actions")
local flags = require("./flags")

local AUTOSAVE_DELAY = 20

local NOOP = function() end

type JSON = types.JSON
type Action<T=any, U...=...any> = types.Action<T, U...>
type Store<T> = types.Store<T>
type Session<T> = types.Session<T>
type StoredData<T> = types.StoredData<T>
type TransactionId = types.TransactionId
type TransactionInfo = types.TransactionInfo

local function update<T>(
    session: Session<T>,
    changes: { Action },
    stored: StoredData<T>,
    db_key_info: DataStoreKeyInfo?
): StoredData<T>?
    if db_key_info == nil then
        stored = session._cached
    end

    LOG(`Applying {#changes} changes to {session._name}`)

    for _, action in changes do
        local fn = action[1]
        LOG("Applying action", debug.info(fn, "n"), "with", unpack(action, 2))
        stored.data = fn(stored.data, unpack(action, 2))
    end

    LOG(`Returning updated data for {session._name}`)

    table.clear(changes)
    return stored
end

local function pull_auto<T>(session: Session<T>)
    local swap = session._changes
    local store, key = session._store, session.key

    budget.delay_until_meets_budget("update", 5)

    local ok, result = pcall(function()
        return store:UpdateAsync(key, function(value, keyinfo)
            return update(session, swap, value, keyinfo)
        end)
    end)

    if not ok then
        warn("Failed to auto-save", result)
        return
    end

    session._cached = result
    session._updated(result)
end

local function force_pull<T>(session: Session<T>)
    local swap = session._changes
    local next_opportunity = session._next_save_opportunity
    local store, key = session._store, session.key

    session._next_save_opportunity = math.huge

    local result = retry.regular_retry(function()
        budget.delay_until_meets_budget("update", 5)
        return store:UpdateAsync(key, function(value, keyinfo)
            return update(session, swap, value, keyinfo)
        end)
    end)

    session._next_save_opportunity = next_opportunity
    session._cached = result
    session._updated(result)
end

local function thread<T>(session: Session<T>)
    while true do
        if session._next_save_opportunity - os.clock() > 0 then task.wait(); continue end
        pull_auto(session)
        session._next_save_opportunity = os.clock() + AUTOSAVE_DELAY
    end
end

local function patch_transaction<T, U...>(session: Session<T>, fn: Action<T, U...>, ...: U...)
    LOG(`Adding transaction action for {session._name}`)
    local transaction = flags.processing_transaction :: TransactionInfo
    local records = session._pending_transactions[transaction.uuid] or {}
    transaction.sessions[session] = true
    table.insert(records, action.create_transaction_record(fn, ...))
    session._pending_transactions[transaction.uuid] = records
end

local function patch_regular<T, U...>(session: Session<T>, fn: Action<T, U...>, ...: U...)
    LOG(`Performing action for {session._name}`)
    table.insert(session._changes, action.create_record(fn, ...) )
    session._cached.data = fn(session._cached.data, ...)
    session._updated(session._cached.data)
end

local function patch<T, U...>(session: Session<T>, fn: Action<T, U...>, ...: U...)
    action.ASSERT_ACTION(fn)
    if flags.processing_transaction then
        patch_transaction(session, fn, ...)
    else
        patch_regular(session, fn, ...)
    end
end

local function updated<T>(session: Session<T>, new: (data: T) -> ())
    new(session._cached.data)
    session._updated = new
end

local function stop<T>(session: Session<T>)
    updated = NOOP
    task.cancel(session._thread)
    force_pull(session)
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

    session._thread = task.spawn(thread, session)

    return session
end

return load_session