local testkit = require("./testkit")
local ds = require("./mock")
local skilift = require("../src/lib")
local task = require("../src/task")

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
    
    print()
    do CASE "load"
        local session = store:load("load")
        CHECK(session)
        session:stop()
    end
    print()
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
    print()
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
    print()
    do CASE "patch"
        local session = store:load("patch-1")
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

    do CASE "patch"
        local session = store:load("patch")
        local expected = 0
        local n = 0

        local function increment_money(data: PlayerData, n: number)
            expected += n
            data.money += n
            return data
        end

        skilift.action.normal(increment_money)

        local function fn(value)
            print(debug.traceback())
            n += 1
            print(n)
            CHECK(value.money == expected)
        end
        
        session:updated(fn)

        CHECK(n == 1)
        print("step")
        task.step(1)
        CHECK(n == 1)
        print("step")
        task.step(100)
        CHECK(n == 2)

        session:stop()
    end
    print()
    

end)

FINISH()