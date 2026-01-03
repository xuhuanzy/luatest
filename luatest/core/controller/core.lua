---@namespace Luatest

local StateManager = require("luatest.core.controller.state")
local TestRun = require("luatest.core.controller.test-run")
local resolveConfig = require("luatest.core.controller.config.resolveConfig").resolveConfig

---@class Luatest
---@field state StateManager
---@field testRun TestRun
local Luatest = {}
Luatest.__index = Luatest ---@package

---@return Luatest
function Luatest.new()
    ---@type Partial<Luatest>
    local self = {
        state = StateManager.new(),
    }
    ---@cast self Luatest
    local testRun = TestRun.new(self)
    self.testRun = testRun

    return setmetatable(self, Luatest)
end

---@param ctx WorkerExecuteContext
function Luatest:start(ctx)
    local init = require("luatest.core.runtime.workers")
    local workerInit = init(self)
    local config = resolveConfig(self)
    workerInit.start(config)
    workerInit.run(ctx)
end

return Luatest
