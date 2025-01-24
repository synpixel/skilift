local types = require("./types")

type TransactionInfo = types.TransactionInfo

return {
    processing_transaction = false :: false | TransactionInfo,
    disable_new_actions = false,
    print = false
}