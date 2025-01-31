local types = require("./types")
local budget = require("./budget")
local retry = require("./retry")
local LOG = require("./log")
local actions = require("./actions")
local flags = require("./flags")
local task = require("./task")
local transaction = require("./checktransaction")
local util = require("./util")
local THROW = require("./throw")

local AUTOSAVE_DELAY = 15

local profilebegin = debug.profilebegin or function() end :: never
local profileend = debug.profileend or function() end :: never

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

        local result = migration.migrate(stored.data)
        if result == nil then THROW("migration_does_not_return", migration.step) end
        stored.data = result

        table.insert(stored.migrations_performed, migration.step)
    end
end

local function perform_transaction<T>(stored: StoredData<T>, action: TransactionAction)
    local fn = actions.obtain_transaction_action(action.fn)
    local values = action.values

    local result = fn(util.clone(stored.data), unpack(values))
    if result == nil then THROW("action_does_not_return", action.fn) end
    stored.data = result
end

local function create_migrations_table(session: Session<any>)
    local migrations = {}
    for i, migration in session._options.migrations do
        table.insert(migrations, migration.step)
    end
    return migrations
end

local function check_transaction<T>(session: Session<T>, data: StoredData<T>)
    for _, info in data.pending_transactions do
        for _, value in info.success do
            if actions._.transaction_names[value.fn] then continue end
            session._why_bad = "unrecognized_transaction"
            return false
        end
    end
    return true
end

local function check_migrations<T>(session: Session<T>, data: StoredData<T>)
    local t = create_migrations_table(session)
    for _, migration in data.migrations_performed do
        if table.find(t, migration) then continue end
        session._why_bad = "unknown_migration"
        return false
    end
    return true
end

local function run_updated<T>(session: Session<T>)
    local data = session._cached.data
    local fn = session._updated
    local copy = util.deep_freeze(util.clone(data))

    return fn(copy)
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

    if not check_migrations(session, stored) then session._finished = "done"; return nil end
    if not check_transaction(session, stored) then session._finished = "done"; return nil end

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
        LOG("Applying action with", unpack(action, 2))
        local result = fn(stored.data, unpack(action, 2))
        if result == nil then THROW("action_does_not_return", debug.info(fn, "n")) end
        stored.data = result
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

    session._next_save_opportunity = session._pull_delay

    if not ok then
        error(`Failed to pull {result}`)
    end
    
    session._first_request_succeeded = true

    for _, fn in session._waiting_for_saved do
        fn()
    end
    table.clear(session._waiting_for_saved)

    if result == nil then 
        error(`Failed to pull as the server has encountered some error: {session._why_bad}`)
    end

    session._cached = result
    LOG(`{session._name} calling updated -`, debug.info(session._updated, "sl"))
    run_updated(session)
end

local function force_pull<T>(session: Session<T>)
    local swap = session._changes
    local store, key = session._store, session.key

    session._next_save_opportunity = math.huge

    local result: StoredData<T> = retry.regular_retry(function()
        budget.delay_until_meets_budget("update", 5)
        return store:UpdateAsync(key, function(value, keyinfo)
            return update(session, swap, {}, value, keyinfo)
        end)
    end, 1)
    session._first_request_succeeded = true

    for _, fn in session._waiting_for_saved do
        fn()
    end
    table.clear(session._waiting_for_saved)

    session._next_save_opportunity = session._pull_delay
    session._cached = result
    LOG(`{session._name} calling updated on force`, debug.info(session._updated, "sl"))
    run_updated(session)
end

local function thread<T>(session: Session<T>)
    while true do
        LOG("performing auto-save in", session._next_save_opportunity, "for", session._name)
        if session._next_save_opportunity > 0 then 
            local dt = task.wait()
            session._next_save_opportunity -= dt
            continue
        end
        LOG("triggering auto-save for", session._name)
        local ok, err = pcall(pull_auto, session, {}) -- silence autosave error if emitted
        -- if not ok then print(err) end
        if session._why_bad then return end
    end
end

local function patch_transaction<T, U...>(session: Session<T>, fn: Action<T, U...>, ...: U...)

    if flags.strict then
        for i = 1, select("#", ...) do
            local ok, err: util.JSONError = pcall(util.check_json_valid, select(i, ...))

            if ok == false then
                THROW("strict_pass_not_json_into_action", tostring(err))
            end
        end

        profilebegin("strict mode")
        local start = session._cached.data
        local a = util.clone(start)
        a = fn(a, ...)

        local b = util.clone(start)
        b = fn(b, ...)

        -- check if it's valid json in strict mode
        local ok, err: util.JSONError = pcall(util.check_json_valid, a)

        if ok == false then
            THROW("strict_not_json_from_action", debug.info(fn, "s"), tostring(err))
        end
        -- it's valid json, but we have to make sure it's pure
        if not util.delta_eq(a, b) then
            THROW("strict_impure_action", debug.info(fn, "sl"))
        end
        profileend()

        if session._options.schema and not session._options.schema(a) then
            THROW("schema_validation_error", session._name, debug.info(fn, "n"))
        end
    else
        local result = fn(util.clone(session._cached.data), ...)

        if session._options.schema and not session._options.schema(result) then
            THROW("schema_validation_error", session._name, debug.info(fn, "n"))
        end
    end

    local transaction = flags.processing_transaction :: TransactionInfo
    local records = transaction.sessions[session] or { success = {}, failure = {} }
    local record = actions.create_transaction_record(fn, ...)

    if transaction.state == "failure" then
        LOG(`Adding transaction action on failure "{record.fn}" for {session._name}`)
        table.insert(records.failure, record)
    elseif transaction.state == "success" then
        LOG(`Adding transaction action on success "{record.fn}" for {session._name}`)
        table.insert(records.success, record)
    end

    transaction.sessions[session] = records
end

local function patch_regular<T, U...>(session: Session<T>, fn: Action<T, U...>, ...: U...)
    LOG(`Performing "{debug.info(fn, "n")}" for {session._name}`)

    if flags.strict then
        profilebegin("strict mode")
        local start = session._cached.data
        local a = util.clone(start)
        a = fn(a, ...)

        local b = util.clone(start)
        b = fn(b, ...)

        -- check if it's valid json in strict mode
        local ok, err: util.JSONError = pcall(util.check_json_valid, a)

        if ok == false then
            THROW("strict_not_json_from_action", debug.info(fn, "s"), tostring(err))
        end
        -- it's valid json, but we have to make sure it's pure
        if not util.delta_eq(a, b) then
            THROW("strict_impure_action", debug.info(fn, "sl"))
        end
        profileend()

        if session._options.schema and not session._options.schema(a) then
            THROW("schema_validation_error", session._name, debug.info(fn, "n"))
        end

        table.insert(session._changes, actions.create_record(fn, ...) )
        session._cached.data = a
        run_updated(session)
    else
        local result = fn(session._cached.data, ...)

        if session._options.schema and not session._options.schema(result) then
            THROW("schema_validation_error", session._name, debug.info(fn, "n"))
        end

        table.insert(session._changes, actions.create_record(fn, ...) )
        session._cached.data = result
        run_updated(session)
    end
end

local function commit_transaction_early<T, U...>(session: Session<T>, fn: Action<T, U...>, ...: U...)
    LOG(`Performing "{debug.info(fn, "n")}" for {session._name}`)

    if flags.strict then
        profilebegin("strict mode")
        local start = session._cached.data
        local a = util.clone(start)
        a = fn(a, ...)

        local b = util.clone(start)
        b = fn(b, ...)

        -- check if it's valid json in strict mode
        local ok, err: util.JSONError = pcall(util.check_json_valid, a)

        if ok == false then
            THROW("strict_not_json_from_action", debug.info(fn, "s"), tostring(err))
        end
        -- it's valid json, but we have to make sure it's pure
        if not util.delta_eq(a, b) then
            THROW("strict_impure_action", debug.info(fn, "sl"))
        end
        profileend()

        if session._options.schema and not session._options.schema(a) then
            THROW("schema_validation_error", session._name, debug.info(fn, "n"))
        end

        session._cached.data = a
        run_updated(session)
    else
        local result = fn(session._cached.data, ...)

        if session._options.schema and not session._options.schema(result) then
            THROW("schema_validation_error", session._name, debug.info(fn, "n"))
        end

        session._cached.data = result
    end
end

local function patch<T, U...>(session: Session<T>, fn: Action<T, U...>, ...: U...)
    if session._finished then THROW("session_already_stopped") end

    actions.ASSERT_ACTION(fn)
    if flags.processing_transaction then
        patch_transaction(session, fn, ...)
    else
        patch_regular(session, fn, ...)
    end
end

local function updated<T>(session: Session<T>, new: (data: T) -> ())
    if session._finished then THROW("session_already_stopped") end
    
    session._updated = new
    LOG(`{session._name} calling updated register`, debug.info(new, "sl"))
    run_updated(session)
end

local function stop<T>(session: Session<T>)
    if session._finished ~= false then return end
    session._finished = "saving"
    session._updated = NOOP
    task.cancel(session._thread)
    task.spawn(function()
       force_pull(session)
       session._finished = "done"
    end)
end

local function await<T>(session: Session<T>)
    if session._finished == "done" then return end

    local ok = false
    table.insert(session._waiting_for_saved, function()
        ok = true
    end)
    while not ok do task.wait() end
end

local function bad(session: Session<any>)
    return session._why_bad
end

local function add_userid<T>(session: Session<T>, user_id: number)
    if session._finished then THROW("session_already_stopped") end
    table.insert(session._user_ids, user_id)
end

local function loaded(session: Session<any>)
    return session._first_request_succeeded
end

local function load_session<T>(self: Store<T>, key: string): Session<T>
    local session = {
        _name = `{self._store.Name}:{key}`,
        _store = self._store,
        _options = self._options,
        _changes = {},
        _pending_transactions = {},
        _waiting_for_saved = {},
        _next_save_opportunity = 0,
        _updated = NOOP,
        _user_ids = {},
        _pull_delay = self._options.pull_delay or AUTOSAVE_DELAY,
        _cached = {
            pending_transactions = {},
            migrations_performed = {},
            data = self._options.default_data()
        },
        _first_request_succeeded = false,
        _finished = false,
        key = key
    }

    session.patch = patch
    session.updated = updated
    session.stop = stop
    session.userid = add_userid
    session.loaded = loaded
    session.bad = bad
    session.await = await

    session._thread = task.spawn(thread, session :: any)

    return session :: any
end

return {
    load_session = load_session,
    pull_auto = pull_auto,
    force_pull = force_pull,
    perform_transaction = perform_transaction,
    commit_transaction_early = commit_transaction_early
}