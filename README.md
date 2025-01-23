# Skilift

Skilift is an immutable lockless data store library for Roblox. Due to how the library works, it supports writing from multiple servers to a single key safely without complicated messaging or locks. It's best used for data that does not need to be owned by a single server, eg player data. This also partly motivates most of it's API design.

## Core Goals

Skilift aims to allow developers to process data safely even in more unstable scenarios when Roblox's DataStoreService may go down without using session locking. This guarantees player data is nearly always up-to-date while being safe to write from other servers without losing data. Other goals are providing transactions and providing a simple API.

## Example

```lua
local skilift = require(script.skilift)

type PlayerData = {
 money: number
}

local function increase_money(value: PlayerData, n: number)
 value.money += n
 return value
end

local function decrease_money(value: PlayerData, n: number)
 value.money -= n
 return value
end

skilift.action.regular(increase_money)
skilift.action.regular(decrease_money)
skilift.action.transaction(increase_money, "increase_money")
skilift.action.transaction(decrease_money, "decrease_money")

local store = skilift.store {
 name = "test",
 default_data = function()
  return {
   money = 100
  }
  end
}

local session1 = store:load("key7")
local session2 = store:load("key8")

session1:updated(function(value)
    print(session1.key, "now has", value.money, "money")
end)
session2:updated(function(value)
    print(session2.key, "now has", value.money, "money")
end)

task.wait(1)

skilift.transaction(function()
    session1:patch(increase_money, 10)
    session2:patch(decrease_money, 10)
end)
```
