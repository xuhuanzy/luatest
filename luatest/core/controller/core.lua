---@namespace Luatest

local StateManager = require("luatest.core.controller.state")
local TestRun = require("luatest.core.controller.test-run")
local resolveConfig = require("luatest.core.controller.config.resolveConfig").resolveConfig
local createReporterManager = require("luatest.core.controller.reporters").createReporterManager
local Logger = require("luatest.core.controller.logger")
local tty = require("luatest.utils.tty")
local testState = require("luatest.runner.test-state")

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
    return tty.getColumns()
end

---@param ctx WorkerExecuteContext
function Luatest:start(ctx)
    ctx = ctx or {} ---@type WorkerExecuteContext
    local init = require("luatest.core.runtime.workers")
    local workerInit = init(self)
    local config = resolveConfig(self)
    self.config = config

    local outputStream = ctx.outputStream or io.stdout
    local errorStream = ctx.errorStream or io.stderr
    local logger = Logger.new({
        outputStream = outputStream,
        errorStream = errorStream,
        getColumns = defaultGetColumns,
        clearScreen = config and config.clearScreen == true,
    })

    ---@type ReporterContext
    local reporterCtx = {
        state = self.state,
        config = config,
        logger = logger,
        outputStream = outputStream,
        errorStream = errorStream,
        getColumns = function()
            return logger:getColumns()
        end,
    }

    self.reporterManager = createReporterManager(reporterCtx, config.reporters)
    local reporterManager = self.reporterManager

    self.testRun:start(ctx.files or {})

    workerInit.start(config)
    local originalPrint = rawget(_G, "print")
    rawset(_G, "print", function(...)
        local args = { ... }

        local message
        if #args == 0 then
            message = "\n"
        else
            for i = 1, #args do
                args[i] = tostring(args[i])
            end
            message = table.concat(args, "\t") .. "\n"
        end

        local current = testState.getCurrentTest and testState.getCurrentTest() or nil
        local currentSuite = testState.getCurrentSuite and testState.getCurrentSuite() or nil
        local currentTask = current or currentSuite

        if currentTask and currentTask.id and reporterManager then
            reporterManager:report("onUserConsoleLog", {
                type = "stdout",
                content = message,
                taskId = currentTask.id,
            })
            return
        end

        logger:log(message)
    end)

    local ok, err = pcall(function()
        workerInit.run(ctx)
    end)

    rawset(_G, "print", originalPrint)

    if not ok then
        self.state:catchError(err, "Unhandled Error")
    end

    self.testRun:finish()
    logger:cleanup()

    if not ok then
        error(err)
    end
end

return Luatest
