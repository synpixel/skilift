local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sessions = require(script.Parent.sessions)
local net = require(ReplicatedStorage.shared.net)
local unlockeable = require(ReplicatedStorage.shared.unlockeable)
local weighted_table = require(ReplicatedStorage.shared.weighted_table)

local function roll_item(player: Player)
    local key = weighted_table.roll(unlockeable)
    local value = unlockeable[key]
    local session = sessions.sessions[player]

    net.obtain_item.fire(player, { obtained = value.name })
    session:patch(sessions.actions.give_item, value.name, 1)
end

net.roll_item.set_callback(roll_item)

return {
    roll_item = roll_item
}