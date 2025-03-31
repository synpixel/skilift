local testkit = require("./testkit")
local ds = require("./mock")
local skilift = require("../src/lib")
local task = require("../src/task")

local TEST, CASE, CHECK, FINISH, SKIP = testkit.test()

type PlayerData = {
    money: number
}

skilift.strict(false)
skilift.mock(ds.DataStoreService)

local function schema(t)
    if typeof(t) ~= "table" then return false end
    if typeof(t.money) ~= "number" then return false end
    return true
end

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

    local store = skilift.store {
        name = "test",
        migrations = {},
        default_data = function()
            return {
                money = 0
            }
        end
    }

    do CASE "register action"
        local function increment_money(data: PlayerData, n: number)
            data.money += n
            return data
        end

        store:action(increment_money)

        CHECK(store._allowed_actions[increment_money])
    end

    do CASE "register transaction action"
        local function increment_money(data: PlayerData, n: number)
            data.money += n
            return data
        end

        store:transaction("increment_money_1", increment_money)

        CHECK(store._transaction_actions[increment_money] == "increment_money_1")
        CHECK(store._transaction_names["increment_money_1"] == increment_money)
    end

end)

TEST("session", function()
    local store = skilift.store {
        name = "test",
        migrations = {},
        default_data = function()
            return {
                money = 0,
                nested = { money = 0 }
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

        CHECK(session._.updated == fn)
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

        CHECK(session._.updated == fn)

        CHECK(n == 1)
        task.step(100)
        CHECK(n == 2)
        -- trigger a change
        session._.datastore:SetAsync("auto-save", {
            pending_transactions = {},
            migrations_performed = {},
            data = { money = 0 }
        })
        task.step(100)
        CHECK(n == 3)
        
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

        store:action(increment_money)

        local function fn(value)
            n += 1
            print("expected", expected, value.money)
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
        CHECK(session._.datastore:GetAsync("patch").data.money == expected)
    end

    do CASE "patch nested"
        local session = store:load("patch")
        
        local function patch(data, n: number)
            data.nested.money += n
            return data
        end

        store:action(patch)

        session:patch(patch, 10)

        session:stop()
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
    
        store:transaction("success-0", success_action)
    
        local session2 = store:load("key-2")
        local session1 = store:load("key-1")

        local status = skilift.transaction(function()
            session1:patch(success_action)
            session2:patch(success_action)
        end)

        CHECK(status)
        CHECK(session1._.cached.data.ok == 1)
        CHECK(session2._.cached.data.ok == 1)
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
    
        store:transaction("success-1", success_action)
        store:transaction("failure-1", fail_action)
    
        local session2 = store:load("key-2")
        local session1 = store:load("key-1")
        
        -- we need to simulate a failure within the ds library.
        ds.deny_requests(2)
        print(session1:bad())
        local status = skilift.transaction(function()
            session1:patch(success_action)
            session2:patch(success_action)
        end, function()
            session1:patch(fail_action)
            session2:patch(fail_action)
        end)

        CHECK(not status)
        CHECK(session1._.cached.data.fail == 1)
        CHECK(session2._.cached.data.fail == 1)
    end

end)

TEST("view", function()
    local store = skilift.store {
        name = "test",
        migrations = {},
        default_data = function()
            return {
                money = 0
            }
        end
    }
    
    do CASE "create view"
        local view = store:view("key")
        CHECK(view)
    end

    do CASE "latest"
        store._store:SetAsync("read-latest", { data = { money = 100 } })
        local view = store:view("read-latest")
        local value = view:latest()
        CHECK(value.money == 100)
    end

    do CASE "latest no data"
        local view = store:view("read-latest-no-data")
        local value = view:latest()
        CHECK(value == nil)
    end

    do CASE "get version"
        local view = store:view("read-version")
        local version = store._store:SetAsync("read-version", { data = { money = 100 } })
        local version2 = store._store:SetAsync("read-version", { data = { money = 200 } })

        local data = view:version(version)
        CHECK(data.money == 100)
        local data = view:version(version2)
        CHECK(data.money == 200)
    end

end)

TEST("strict mode", function()
    skilift.strict(true)

    local store = skilift.store {
        name = "test",
        migrations = {},
        default_data = function()
            return {
                money = 0,
                test = nil :: any
            }
        end
    }

    local function impure_action(data)
        data.money = math.random()
        return data
    end

    local function non_real_number(data)
        data.money = math.huge
        return data
    end

    local function non_string_key(data)
        data[true] = true
        return data
    end

    local function recursive_table(data)
        data.money = data :: any
        return data
    end

    local function bad_type(data)
        data.test = vector.create(0, 0, 0)
        return data
    end

    local function invalid_utf8(data)
        data.test = "\237\190\140"
        return data
    end

    store:action(impure_action)
    store:action(non_real_number)
    store:action(non_string_key)
    store:action(recursive_table)
    store:action(bad_type)
    store:action(invalid_utf8)
    store:transaction("recursive-table", recursive_table)

    local function update(data: PlayerData)
        data.money += 1
        return data
    end
    store:action(update)
    store:transaction('increment', update)

    do CASE "multiple updates only update once"
        local session = store:load("key")
        local expected = 0
        local first = false

        session:updated(function(data)
            if first then first = false; return end
            print(data.money, expected)
            CHECK(data.money == expected)
        end)

        expected += 1
        session:patch(update)

        expected += 1
        session:patch(update)

        expected += 1
        first = true
        skilift.transaction(function()
            session:patch(update)
        end)
    end

    do CASE "fail impure function"
        local session = store:load("impure")

        local ok = pcall(function()
            session:patch(impure_action)
        end)

        CHECK(ok == false)
    end

    do CASE "fail invalid json utf8"
        local session = store:load("impure")

        local ok = pcall(function()
            session:patch(invalid_utf8)
        end)

        CHECK(ok == false)
    end

    do CASE "fail invalid json non-real number"
        local session = store:load("impure")

        local ok, err: string = pcall(function()
            session:patch(non_real_number)
        end)

        CHECK(ok == false)
        CHECK(err:find("not a real number"))
    end

    do CASE "fail invalid json string key"
        local session = store:load("impure")

        local ok, err: string = pcall(function()
            session:patch(non_string_key)
        end)

        CHECK(ok == false)
        CHECK(err:find("keys are string"))
    end
    
    do CASE "fail invalid json recursive"
        local session = store:load("impure")

        local ok, err: string = pcall(function()
            session:patch(recursive_table)
        end)

        CHECK(ok == false)
        CHECK(err:find("recursive"))
    end

    do CASE "fail invalid json bad type"
        local session = store:load("impure")

        local ok, err: string = pcall(function()
            session:patch(bad_type)
        end)

        CHECK(ok == false)
        CHECK(err:find("valid json"))
    end

    do CASE "fail invalid json transaction"
        local session = store:load("transaction")

        local ok, err = pcall(function()
            skilift.transaction(function()
                session:patch(recursive_table, { vector.create(0, 0, 0) })
            end)
        end)

        CHECK(ok == false)
        CHECK(err:find("only accept valid JSON"))
    end

    skilift.strict(false)
end)

TEST("schema", function()

    local store = skilift.store {
        name = "test-schema",
        migrations = {},
        schema = schema,
        default_data = function()
            return {
                money = 0,
                nested = { money = 0 }
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

        CHECK(session._.updated == fn)
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

        CHECK(session._.updated == fn)

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

        store:action(increment_money)

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

        CHECK(store._store:GetAsync("patch").data.money ~= expected)
        session:stop()
        CHECK(store._store:GetAsync("patch").data.money == expected)
    end

    do CASE "fail bad patch"
        local session = store:load("patch-schema-fail")

        local function bad_money(data: PlayerData)
            data.money = nil :: any
            return data
        end

        store:action(bad_money)

        local ok = pcall(function()
            session:patch(bad_money)
        end)

        CHECK(ok == false)

        session:stop()
    end

end)

TEST("reliability tests", function()

    local store = skilift.store {
        name = "test",
        migrations = {},
        default_data = function()
            return {
                money = 0
            }
        end
    }

    local function increment_money(data: PlayerData, n: number)
        data.money += n
        return data
    end

    store:action(increment_money)
    store:transaction(increment_money, "increment-money")

    local datastore = ds.DataStoreService:GetDataStore("test")

    do CASE "obtain data after request failure"
        datastore:SetAsync("test-failure", { pending_transactions = {}, migrations_performed = {}, data = { money = 1000 } })

        ds.simulate_outage(true)
        local session = store:load("test-failure")
        local down = true
        
        session:updated(function(data)
            CHECK(data.money == (if down then 0 else 1000))
        end)

        task.step(100)
        task.step(100)
        ds.simulate_outage(false)
        down = false
        task.step(100)

        session:stop()
    end

    do CASE "concurrent writing to same key"
        datastore:SetAsync("test-concurrent", { pending_transactions = {}, migrations_performed = {}, data = { money = 1000 } })

        local session = store:load("test-concurrent")
        local expected_money = 1000

        
        session:updated(function(data)
            CHECK(data.money == expected_money)
        end)

        expected_money += 10
        session:patch(increment_money, 10)

        task.step(100)
        datastore:SetAsync("test-concurrent", { pending_transactions = {}, migrations_performed = {}, data = { money = 10000 } })
        expected_money = 10000
        task.step(100)
        datastore:SetAsync("test-concurrent", { pending_transactions = {}, migrations_performed = {}, data = { money = 3000 } })
        expected_money += 10
        session:patch(increment_money, 10)
        expected_money += 10
        session:patch(increment_money, 10)
        expected_money += 10
        session:patch(increment_money, 10)
        expected_money += 10
        session:patch(increment_money, 10)
        expected_money = 3040
        task.step(100)
        session:stop()
    end

    do CASE "transaction failure write transaction fail"

        local session_a = store:load("session-a")
        local session_b = store:load("session-b")
        local session_c = store:load("session-c")

        ds.requests.freeze()
        
        local thread = coroutine.create(function()
            local ok = skilift.transaction(
                function()
                    session_a:patch(increment_money, 15)
                    session_b:patch(increment_money, -10)
                    session_c:patch(increment_money, -5)
                    print("done")
                end
            )

            print("aaa")
            CHECK(ok == false)
        end)

        coroutine.resume(thread)

        ds.requests.pop()
        ds.requests.pop()
        ds.deny_requests(1)
        ds.requests.unfreeze()
        task.step(1)

    end

    do CASE "transaction failure write session 3 fail"

        local session_a = store:load("session-a")
        local session_b = store:load("session-b")
        local session_c = store:load("session-c")

        ds.requests.freeze()
        
        local thread = coroutine.create(function()
            local ok = skilift.transaction(
                function()
                    session_a:patch(increment_money, 15)
                    session_b:patch(increment_money, -10)
                    session_c:patch(increment_money, -5)
                    print("done")
                end
            )

            print("aaa")
            CHECK(ok == false)
        end)

        coroutine.resume(thread)

        ds.requests.pop()
        ds.requests.pop()
        ds.deny_requests(1)
        ds.requests.pop()
        ds.requests.pop()
        ds.requests.pop()
        task.step(1)
        ds.requests.unfreeze()

    end

end)

FINISH()