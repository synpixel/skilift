local skylift = require("src/init")

type PlayerData = {
    money: number
}

local function increase_money(value: PlayerData, n: number)
    value.money += n
    return value
end

skylift.action.regular(increase_money)

local store = skylift.store {
    name = "test",
    default_data = function()
        return {
            money = 0
        }
    end
}

local session = store:load("blah")

session:patch(increase_money, 10)

session:stop()