local testkit = require("./testkit")
local ds = require("./mock")
local skilift = require("../../skilift/src/lib")
local task = require("../../skilift/src/task")

local TEST, CASE, CHECK, FINISH, SKIP = testkit.test()

type PlayerData = {
    money: number
}

TEST("registering actions", function()
    local actions = require("../src/actions")

    do CASE "register action"
        local function increment_money(data: PlayerData, n: number)
            data.money += n
            return data
        end

        skilift.action.normal(increment_money)

        CHECK(actions._.actions[increment_money])
    end

    do CASE "register transaction action"
        local function increment_money(data: PlayerData, n: number)
            data.money += n
            return data
        end

        skilift.action.transaction(increment_money, "increment_money_1")

        CHECK(actions._.transaction_actions[increment_money] == "increment_money_1")
        CHECK(actions._.transaction_names["increment_money_1"] == increment_money)
    end
end)

TEST("store", function()
    
    do CASE "create store"
        local store = skilift.store {
            name = "test",
            migrations = {},
            default_data = function()
                return {
                    money = 0
                }
            end
        }

        CHECK(store)
        CHECK(store._store.Name)
    end

end)

TEST("session", function()
    local store = skilift.store {
        name = "test",
        migrations = {},
        default_data = function()
            return {
                money = 0
            }
        end
    }
    
    do CASE "load"
        local session = store:load("load")
        CHECK(session)
        session:stop()
    end

    do CASE "updated"
        -- updated should always fire once
        local session = store:load("updated")
        local n = 0
        
        
        local function fn(value)
            n += 1
            CHECK(value.money)
        end
        
        session:updated(fn)

        CHECK(session._updated == fn)
        task.step(1)
        CHECK(n > 0)
        session:stop()
    end
    
    do CASE "auto-pull"
        local session = store:load("auto-save")
        local n = 0

        local function fn(value)
            n += 1
            CHECK(value.money == 0)
        end
        
        session:updated(fn)

        CHECK(session._updated == fn)

        CHECK(n == 1)
        task.step(1)
        CHECK(n == 1)
        task.step(100)
        CHECK(n == 2)
        
        session:stop()
    end

    do CASE "patch & stop"
        local session = store:load("patch")
        local expected = 0
        local n = 0

        local function increment_money(data: PlayerData, n: number)
            data.money += n
            return data
        end

        skilift.action.normal(increment_money)

        local function fn(value)
            n += 1
            CHECK(value.money == expected)
        end
        
        session:updated(fn)

        CHECK(n == 1)
        task.step(100)
        CHECK(n == 2)
        expected += 10
        session:patch(increment_money, 10)
        CHECK(n == 3)
        task.step(100)
        CHECK(n == 4)
        expected += 10
        session:patch(increment_money, 10)
        CHECK(n == 5)

        session:stop()
        CHECK(store._store:GetAsync("patch").data.money == expected)
    end
end)

TEST("transaction", function()

    local store = skilift.store {
        name = "test",
        migrations = {},
        default_data = function()
            return {
                money = 0,
                ok = 0,
                fail = 0
            }
        end
    }

    do CASE "call success action"
        local function success_action(data)
            data.ok += 1
            return data
        end
    
        skilift.action.transaction(success_action, "success-0")
    
        local session2 = store:load("key-2")
        local session1 = store:load("key-1")

        local status = skilift.transaction(function()
            session1:patch(success_action)
            session2:patch(success_action)
        end)

        CHECK(status)
        CHECK(session1._cached.data.ok == 1)
        CHECK(session2._cached.data.ok == 1)
    end

    do CASE "call failure action"
        local function success_action(data)
            data.ok += 1
            return data
        end

        local function fail_action(data)
            data.fail += 1
            return data
        end
    
        skilift.action.transaction(success_action, "success-1")
        skilift.action.transaction(fail_action, "failure-1")
    
        local session2 = store:load("key-2")
        local session1 = store:load("key-1")
        
        -- we need to simulate a failure within the ds library.
        ds.deny_requests(2)
        local status = skilift.transaction(function()
            session1:patch(success_action)
            session2:patch(success_action)
        end, function()
            session1:patch(fail_action)
            session2:patch(fail_action)
        end)

        CHECK(not status)
        CHECK(session1._cached.data.fail== 1)
        CHECK(session2._cached.data.fail == 1)
    end

end)

FINISH()