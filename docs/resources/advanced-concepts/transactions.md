# Transactions

A problem developers often encounter is safely modifying multiple keys at the same time. A failure on any key should result in a failure for every other write, or you may have a dupe glitch.

In order to perform a transaction, you can use the `skilift.transaction` api. It takes two functions and any patches you perform in these 2 functiosn will be deferred until it either succeeds or fails.

> [!WARNING]
> You're unable to use regular actions within a transaction. Instead, you use the `skilift.action.transaction` API to tell skilift you can use it inside a transaction. This is important since actions used in transactions should NEVER be removed. When you publish a transaction to production, removing it may result in player data becoming invalid. Further, actions for transactions need to receive a name, unlike regular actions.

This demonstrates how to transfer money.

```luau
local store = skilift.store {
    name = "player-data",
    migrations = {},
    default_data = function()
        return { money = 100 }
    end
}

local bob = store:load("bob")
local tom = store:load("tom")

local function give_money(data: PlayerData, n: number)
    data.money += n
    return data
end

local function take_money(data: PlayerData, n: number)
    data.money -= n
    return data
end

skilift.action.normal(give_money)
skilift.action.normal(take_money)

skilift.action.transaction(give_money, "give_money")
skilift.action.transaction(take_money, "take_money")

-- when the transaction succeeds, it takes money from bob and gives money to tom
local ok = skilift.transaction(function()
    bob:patch(take_money, 10)
    tom:patch(add_money, 10)
end)
```

## Escrowing

This code is flawed though. Transactions don't process instantly, and you should escrow resources first to prevent users from still using that data. This prevents Bob from using their 10 coins before Tom receives their 10 coins. If it fails, you can just return the 10 coins to Bob.

```luau
-- this is better, as bob won't be able to use his 10 dollars while it's
-- processing, and tom only gets 10 coins when we're sure the transaction has
-- succeeded.
bob:patch(take_money, 10)
local ok = skilift.transaction(function()
    tom:patch(add_money, 10)
end, function()
    bob:patch(add_money, 10)
end)
```
