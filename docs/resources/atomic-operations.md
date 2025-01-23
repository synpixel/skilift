# Atomic Operations

Skilift only allows editing data through so-called atomic operations or Actions. This changes the mental-model on how you have to approach updates, as you're unable to mutate the data traditionally. It's also not recommended to write operations that mutate data traditionally. An atomic operation is a pure function, that operates on the data.

## Motivation

Atomic operations allow data to be updated gracefully. Each session keeps a queue of atomic operations it applied to the data, until the next time it checks and performs an update. When it updates, it reads the currently stored data, and then performs all queued actions. If the data hasn't been updated, it should result in the same output, but if another server updated the data it should result in a merged result.

## Why split into normal and transaction?

Skilift splits actions into normal and transaction actions. The idea is that you explicitly mark these functions as an action, acknowledging them that they are **pure**. Transactions are separated from normal actions, as actions used in transactions are permanent. They must never be removed.

## Writing good actions

Your actions should never be relegated to just setting a new value. Actions should represent something that happened, not you trying to set something to a new value.

```luau
-- bad!

local function set_money(data, amount)
    data.money = amount
end

skilift.action.normal(set_money)

session:patch(set_money, game_state.session.money + 10)

-- good!
local function increment_money(data, amount)
    data.money += amount
end

skilift.action.normal(increment_money)

session:patch(set_money 10)
```

Of course, there are some cases where this can be ignored, for example when a user edits some text. This should be up to your own judgement, but actions that don't overwrite are considered better.