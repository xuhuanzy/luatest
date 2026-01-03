local throw = require("luatest.utils.error").throw
local defaultWorker = require("luatest.core.runtime.workers")
local nowMs = require("luatest.utils.helpers").nowMs
---@namespace Luatest

---@export namespace
local export = {}

---@type fun()[]
local globalListeners = {}


---@param method "run" | "collect"
---@param ctx WorkerContext
---@param worker LuatestWorker
local function execute(method, ctx, worker)
    -- 此时可以加载一些内部库避免未初始化

    ---@type WorkerGlobalState
    local state = {
        ctx = ctx,
        rpc = ctx.rpc,
        evaluatedModules = {},
        durations = {
            prepare = 0,
            environment = 0,
        },
        collectStartTime = 0,
        onCleanup = function(listener)
            globalListeners[#globalListeners + 1] = listener
        end
    }
    local methodName = method == "collect" and "collectTests" or "runTests"
    local workerRun = worker[methodName]
    if (not workerRun) or (type(workerRun) ~= "function") then
        throw("Test worker should expose \"" .. methodName .. "\" method. Received \"" .. type(workerRun) .. "\".")
    end
end

---@param ctx WorkerContext
---@param worker LuatestWorker
function export.run(ctx, worker)
    execute("run", ctx, worker)
end

---@param ctx WorkerContext
---@param worker LuatestWorker
function export.collect(ctx, worker)
    execute("collect", ctx, worker)
end

-- 清理全局注册的清理函数
function export.teardown()
    for _, listener in ipairs(globalListeners) do
        listener()
    end
end

return export
