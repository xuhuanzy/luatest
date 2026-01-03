local createMethodsRPC = require("luatest.core.controller.rpc")
local run = require("luatest.core.runtime.worker").run
local runBaseTests = require("luatest.core.runtime.workers.base").runBaseTests
---@namespace Luatest

---@type LuatestWorker
local defaultWorker = {
    runTests = function(state)
        runBaseTests("run", state)
    end,
    collectTests = function(state)
        runBaseTests("collect", state)
    end
}

---@class WorkerSetupContext
---@field config SerializedConfig
---@field rpc RuntimeRPC

---@class WorkerInit
---@field start fun(config: SerializedConfig)
---@field run fun(ctx: WorkerExecuteContext)
---@field collect fun(ctx: WorkerExecuteContext)


---@param luatest Luatest
---@return WorkerInit
local function init(luatest)
    ---@type WorkerSetupContext
    local setupContext
    return {
        ---@param config SerializedConfig
        start = function(config)
            local rpc = createMethodsRPC(luatest)
            setupContext = {
                config = config,
                rpc = rpc,
            }
        end,
        ---@param ctx WorkerExecuteContext
        run = function(ctx)
            run({
                config = setupContext.config,
                files = ctx.files,
                rpc = setupContext.rpc,
            }, defaultWorker)
        end,
        ---@param ctx WorkerExecuteContext
        collect = function(ctx)
            run({
                files = ctx.files,
                config = setupContext.config,
                rpc = setupContext.rpc,
            }, defaultWorker)
        end,
    }
end

return init
