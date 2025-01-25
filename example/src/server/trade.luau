local ReplicatedStorage = game:GetService("ReplicatedStorage")

local skilift = require(ReplicatedStorage.packages.skilift)
local sessions = require(script.Parent.sessions)
local net = require(ReplicatedStorage.shared.net)

type TradingInfo = {
    a: Player,
    b: Player,

    offer_a: { [string]: number },
    offer_b: { [string]: number },

    a_ready: boolean,
    b_ready: boolean
}

local trading_requested = {}
local trading_info: {[Player]: TradingInfo} = {}

local function start_trade(a: Player, b: Player)
    trading_requested[a] = nil
    trading_requested[b] = nil

    local info = {
        a = a,
        b = b,

        offer_a = {},
        offer_b = {},

        a_ready = false,
        b_ready = false,
    }

    trading_info[a] = info
    trading_info[b] = info
    
    net.start_trade.fire(a, { who = b })
    net.start_trade.fire(b, { who = a })
end

local function set_offer(player: Player, item: string, amount: number)
    local info = trading_info[player]
    if not info then return end
    local offer = if info.a == player then info.offer_a else info.offer_b
    local other = if info.a == player then info.b else info.a

    local n = sessions.player_data[player].items[item] or -1
    if n > amount then return end
    if n == -1 then return end

    offer[item] = amount

    net.set_item_offer.fire(other, { item = item, amount = amount })
end

local function finish_trade(info: TradingInfo)

    local a = sessions.sessions[info.a]
    local b = sessions.sessions[info.b]

    for key, value in info.offer_a do
        a:patch(sessions.actions.remove_item, key, value)
    end
    for key, value in info.offer_b do
        b:patch(sessions.actions.remove_item, key, value)
    end
    skilift.transaction(
        function() 
            for key, value in info.offer_a do
                b:patch(sessions.actions.give_item, key, value)
            end
            for key, value in info.offer_b do
                a:patch(sessions.actions.give_item, key, value)
            end
        end,
        function()
            for key, value in info.offer_a do
                a:patch(sessions.actions.give_item, key, value)
            end
            for key, value in info.offer_b do
                b:patch(sessions.actions.give_item, key, value)
            end
        end
    )

    trading_info[info.a] = nil
    trading_info[info.b] = nil

    net.trade_rejected.fire(info.a)
    net.trade_rejected.fire(info.b)
end

net.set_item.set_callback(function(from, data)
    set_offer(from, data.item, data.amount)
end)

net.request_trade.set_callback(function(from, to)
    if trading_info[from] then return end
    if trading_requested[to] == from then return start_trade(from, to) end

    trading_requested[from] = to
    return
end)

net.reject_trade.set_callback(function(from)
    local data = trading_info[from]

    if not data then return end

    trading_info[data.a] = nil
    trading_info[data.b] = nil

    net.trade_rejected.fire(data.a)
    net.trade_rejected.fire(data.b)
end)

net.trade_ready.set_callback(function(from)
    local data = trading_info[from]

    if not data then return end

    if data.a == from then
        data.a_ready = true
    else
        data.b_ready = true
    end

    if data.a_ready and data.b_ready then
        finish_trade(data)
    end
end)

return {
    start_trade = start_trade,
}