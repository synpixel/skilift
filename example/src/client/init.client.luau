local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local hud = require(script.ui.components.hud)
local vide = require(ReplicatedStorage.packages.vide)
local net = require(ReplicatedStorage.shared.net)
local state = require(script.ui.state)

vide.mount(hud, Players.LocalPlayer.PlayerGui)

net.obtain_item.set_callback(function(data)
    state.obtained(data.obtained)
end)

net.update_inventory.set_callback(function(data)
    print("update inventory")
    state.inventory(data)
end)

net.set_item_offer.set_callback(function(offer)
    print("update offer")
    state.trading_their_offer()[offer.item] = offer.amount
    state.trading_their_offer(state.trading_their_offer())
end)

net.trade_rejected.set_callback(function(data)
    state.trading_with(false)
    state.trading_ready(false)
    state.trading_cooldown(false)
    state.trading_finalized(false)
    state.trading_my_offer({})
    state.trading_their_offer({})
    state.trading_they_finalized(false)

end)

net.start_trade.set_callback(function(data)
    state.trading_with(data.who)
    state.trading_ready(false)
    state.trading_cooldown(false)
    state.trading_finalized(false)
    state.trading_my_offer({})
    state.trading_their_offer({})
    state.trading_they_finalized(false)
end)

while task.wait() do
    state.players(Players:GetPlayers())
end