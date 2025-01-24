local pending = {}

local function spawn<T...>(fn: (T...) -> (...any), ...: T...): thread
    local thread = coroutine.create(fn)
    coroutine.resume(thread, ...)
    return thread
end

local function wait(t: number?): number
    table.insert(pending, { time_left = t or 0, time_waited = 0, thread = coroutine.running() })
    return coroutine.yield()
end

local function close(thread: thread)
    coroutine.close(thread)
end

local function step(dt: number?)
    for i = #pending, 1, -1 do
        local data = pending[i]

        data.time_left -= dt
        data.time_waited += dt

        if data.time_left <= 0 then
            pending[i] = pending[#pending]
            pending[#pending] = nil
            coroutine.resume(data.thread, data.time_waited)
        end
    end
end

return {
    spawn = spawn,
    wait = wait,
    cancel = close,
    step = step
}