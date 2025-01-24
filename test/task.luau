local pending = {}
local time = 0

local function spawn<T...>(fn: (T...) -> (...any), ...: T...): thread
    local thread = coroutine.create(fn)
    coroutine.resume(thread, ...)
    return thread
end

local function wait(t: number?): number
    local t = t or 1/60
    pending[coroutine.running()] = time + t
    local dt = coroutine.yield()
    return t - dt
end

local function close(thread: thread)
    coroutine.close(thread)
end

local function step(dt: number?)
    local dt = dt or 10
    time += dt
    for thread, when in pending do
        if coroutine.status(thread) ~= "suspended" then pending[thread] = nil; return end
        pending[thread] -= dt
        if when - dt > 0 then continue end
        local n = pending[thread]
        pending[thread] = nil
        coroutine.resume(thread, n)
    end
end

return {
    spawn = spawn,
    wait = wait,
    cancel = close,
    step = step
}