local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local skilift = require(ServerScriptService.packages.skilift)
local net = require(ReplicatedStorage.shared.net)

export type PlayerData = {
    items: { [string]: number }
}

local player_data_store = skilift.store {
    name = "player-data",
    migrations = {},
    default_data = function(): PlayerData
        return {
            items = {}
        }
    end
}

local sessions: {[Player]: skilift.Session<PlayerData>} = {}
local player_data = {}

do
    local function reconcile_data(player: Player)
        return function(data: PlayerData)
            player_data[player] = data
            net.update_inventory.fire(player, data.items)
        end
    end

    local function player_added(player: Player)
        local key = `player-{player.UserId}`
        local session = player_data_store:load(key)

        sessions[player] = session
        session:updated(reconcile_data(player))
    end

    local function player_removing(player: Player)
        if sessions[player] == nil then return end
        sessions[player]:stop()
        sessions[player] = nil
    end

    local function bind_to_close()
        for key, session in sessions do
            session:stop()
            sessions[key] = nil
        end
    end

    for _, player in Players:GetPlayers() do
        player_added(player)
    end

    Players.PlayerAdded:Connect(player_added)
    Players.PlayerRemoving:Connect(player_removing)
    game:BindToClose(bind_to_close)
end

local function give_item(data: PlayerData, item: string, n: number?)
    local amount = n or 1
    local current = data.items[item] or 0

    data.items[item] = current + amount

    return data
end

local function remove_item(data: PlayerData, item: string, n: number?)
    local amount = n or 1
    local current = data.items[item] or 0

    data.items[item] = current - amount

    return data
end

skilift.action.normal(give_item)
skilift.action.normal(remove_item)
skilift.action.transaction(give_item, "give_item")
skilift.action.transaction(remove_item, "remove_item")

return {
    player_data = player_data,
    sessions = sessions,
    actions = {
        give_item = give_item,
        remove_item = remove_item
    }
}