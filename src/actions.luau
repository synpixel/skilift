local flags = require("./flags")
local THROW = require("./throw")

local actions: { [Action]: true } = {}

type Action<T=any, U...=...any> = (old: T, U...) -> T

local transaction_actions: { [Action]: string } = {}
local transaction_names: { [string]: Action } = {}

local function ASSERT_ACTION(action: Action)
    if flags.processing_transaction and not transaction_actions[action] and actions[action] then
        THROW("transaction_invalid_action", debug.info(action, "sl"))
    elseif flags.processing_transaction and not transaction_actions[action] then
        THROW("transaction_invalid_function", debug.info(action, "sl"))
    elseif not flags.processing_transaction and transaction_actions[action] and not actions[action] then
        THROW("action_attempt_transaction", debug.info(action, "sl"))
    elseif not flags.processing_transaction and not actions[action] then
        THROW("action_invalid_function", debug.info(action, "sl"))
    end
end


local function register_action(action: Action)
    if flags.disable_new_actions then THROW("cannot_make_action") end
    actions[action] = true
end

local function register_transaction_action(action: Action, name: string)
    if flags.disable_new_actions then THROW("cannot_make_action") end
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

local function obtain_transaction_action(name: string)
    local action = transaction_names[name]
    if not action then THROW("unknown_transaction_action", name) end
    return action
end

return {
    ASSERT_ACTION = ASSERT_ACTION,
    
    register_action = register_action,
    register_transaction_action = register_transaction_action,

    create_record = create_record,
    create_transaction_record = create_transaction_record,

    obtain_transaction_action = obtain_transaction_action

}