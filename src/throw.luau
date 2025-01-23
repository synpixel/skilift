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

return THROW