

if not task then
    return require("../test/task")
else
    return {
        spawn = task.wait,
        wait = task.wait,
        cancel = task.cancel,
        step = function() end
    }
end