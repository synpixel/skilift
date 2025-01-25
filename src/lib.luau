local types = require("./types")
local store = require("./store")
local actions = require("./actions")
local transaction = require("./transaction")
local flags = require("./flags")

export type Store<T> = types.Store<T>
export type View<T> = types.View<T>
export type Session<T> = types.Session<T>       

return {

    action = {
        normal = actions.register_action,
        transaction = actions.register_transaction_action
    },

    store = store,

    transaction = transaction.create_transaction,

    strict = function(value: boolean?)
        if value ~= nil then
            flags.strict = value
        end
        
        return flags.strict
    end

}