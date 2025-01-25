---
prev:
    text: Installation
    link: ./2-installation/
next:
    text: Transactions
    link: ../advanced-concepts/transactions/
---

# Setting Up

## Obtaining a session

You have to specify the default data. Stores allow you to obtain a session.

```luau
local store = skilift.store {
    name = "player-data",
    migrations = {},
    default_data = function()
        return { money = 0 }
    end
}
```

## Reconciling data from a session

Skilift reconciles data frequently every 15 seconds. Your game state should never act as the source of truth for your data when using skilift.

```luau

store:updated(function(new_data)
    player_data.money = new_data.money
end)

```

## Updating the data

Your data is updated by atomic operations or actions as skilift refers to them. They are pure functions that operate on your data. The more specific an action is, the better. For example, it's better to use an `add_money` action for giving somoeone money than a `set_money` action as it's more specific.

Actions need to be registered before they can be used.

```luau
--- You don't want to use actions like this ideally. It's way too general and
--- isn't as easily transferrable to new data.
local function set_money(data: PlayerData, n: number)
    data.money = n
    return data
end

--- This is more specific and can easily be transferred to new data when pulled.
local function add_money(data: PlayerData, n: number)
    data.money += n
    return data
end

skilift.action.normal(set_money)
skilift.action.normal(add_money)

store:patch(add_money, 100)
```

It's recommended to use `:patch` to update your data, as whenever your data is patched it also immediately fires the `:updated` function.
