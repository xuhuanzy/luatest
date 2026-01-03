--[[ 目前整个架构为单线程, 这里只是为了可能的扩展 ]]

---@namespace Luatest

---@class RuntimeRPC
---@field onQueued fun(file: File)
---@field onCollected fun(files: File[])
---@field onTaskUpdate fun(update: TaskResultPack[], events: TaskEventPack[])

---@param luatest Luatest
---@return RuntimeRPC
local function createMethodsRPC(luatest)
    return {
        onQueued = function(file)
            luatest.testRun:enqueued(file)
        end,
        onCollected = function(files)
            luatest.testRun:collected(files)
        end,
        onTaskUpdate = function(update, events)
            luatest.testRun:updated(update, events)
        end,
    }
end


return createMethodsRPC
