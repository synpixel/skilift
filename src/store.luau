local types = require("./types")
local view = require("./view")
local session = require("./session")
local flags = require("./flags")

type StoreOptions<T> = types.StoreOptions<T>
type Store<T> = types.Store<T>

local function get_store<T>(options: StoreOptions<T>): Store<T>
    local store = {
        _options = options,
        _store = flags.datastoreservice:GetDataStore(options.name, options.scope)
    }

    store.load = session.load_session
    store.view = view.view_key

    return store
end

return get_store