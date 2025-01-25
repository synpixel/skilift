local ReplicatedStorage = game:GetService("ReplicatedStorage")

local state = require(script.Parent.state)
local net = require(ReplicatedStorage.shared.net)
return {

    roll_item = function()
        net.roll_item.fire()
    end,

    start_trade = function(player)
        print("requesting to trade with", player)
        net.request_trade.fire(player)
    end,

    reject_trade = function()
        net.reject_trade.fire()
        state.trading_with(false)
        state.trading_ready(false)
        state.trading_cooldown(false)
        state.trading_finalized(false)
        state.trading_my_offer({})
        state.trading_their_offer({})
        state.trading_they_finalized(false)
    end,

    add = function(item: string)
        local offer = state.trading_my_offer()
        local n = state.inventory()[item] or -1

        offer[item] = offer[item] or 0
        offer[item] = math.clamp(offer[item] + 1, 0, n)
        
        net.set_item.fire({ amount = offer[item], item = item })
        state.trading_my_offer(offer)
    end,

    remove = function(item: string)
        local offer = state.trading_my_offer()
        local n = state.inventory()[item] or -1

        offer[item] = offer[item] or 0
        offer[item] = math.clamp(offer[item] - 1, 0, n)

        net.set_item.fire({ amount = offer[item], item = item })
        state.trading_my_offer(offer)
    end,

    ready = function()
        net.trade_ready.fire()
    end

}