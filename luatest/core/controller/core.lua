---@namespace Luatest

local StateManager = require("luatest.core.controller.state")
local TestRun = require("luatest.core.controller.test-run")
local resolveConfig = require("luatest.core.controller.config.resolveConfig").resolveConfig
local createReporterManager = require("luatest.core.controller.reporters").createReporterManager

---@class Luatest
---@field state StateManager
---@field testRun TestRun
---@field reporterManager ReporterManager?
---@field config SerializedConfig?
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

---@return integer
local function defaultGetColumns()
    local env = os.getenv("COLUMNS")
    local n = env and tonumber(env) or nil
    if n and n > 0 then
        return math.floor(n)
    end
    return 80
end

---@param ctx WorkerExecuteContext
function Luatest:start(ctx)
    ctx = ctx or {} ---@type WorkerExecuteContext
    local init = require("luatest.core.runtime.workers")
    local workerInit = init(self)
    local config = resolveConfig(self)
    self.config = config

    ---@type ReporterContext
    local reporterCtx = {
        state = self.state,
        config = config,
        outputStream = ctx.outputStream or io.stdout,
        errorStream = ctx.errorStream or io.stderr,
        getColumns = defaultGetColumns,
    }

    self.reporterManager = createReporterManager(reporterCtx, config.reporters)

    self.testRun:start(ctx.files or {})

    workerInit.start(config)
    local ok, err = pcall(function()
        workerInit.run(ctx)
    end)

    if not ok then
        self.state:catchError(err, "Unhandled Error")
    end

    self.testRun:finish()

    if not ok then
        error(err)
    end
end

return Luatest
