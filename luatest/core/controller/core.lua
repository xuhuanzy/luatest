---@namespace Luatest

local StateManager = require("luatest.core.controller.state")
local TestRun = require("luatest.core.controller.test-run")
local createReporterManager = require("luatest.core.controller.reporters").createReporterManager
local Logger = require("luatest.core.controller.logger")
local tty = require("luatest.utils.tty")


---@class ControllerStartContext
---@field files string[]
---@field config SerializedConfig
---@field outputStream? file
---@field errorStream? file

---@class ControllerOptions
---@field root? string
---@field projectName? string

---@class Luatest
---@field state StateManager
---@field testRun TestRun
---@field reporterManager ReporterManager?
---@field config SerializedConfig?
local Luatest = {}
Luatest.__index = Luatest ---@package

---@return Luatest
---@param options? ControllerOptions
function Luatest.new(options)
    options = options or {}
    ---@type Partial<Luatest>
    local self = {
        state = StateManager.new({
            root = options.root,
            projectName = options.projectName,
        }),
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

---@param logger Logger
---@param reporterManager ReporterManager?
---@return fun()
local function installPrintHook(logger, reporterManager)
    local testState = require("luatest.runner.test-state")
    local getCurrentTest = testState.getCurrentTest

    local originalPrint = rawget(_G, "print")
    local restored = false
    local function restore()
        if restored then
            return
        end
        rawset(_G, "print", originalPrint)
        restored = true
    end

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

        local current = getCurrentTest() or nil
        -- local currentSuite = getCurrentSuite() or nil
        local currentTask = current

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

    return restore
end

---@param ctx ControllerStartContext
function Luatest:start(ctx)
    ctx = ctx or {} ---@type ControllerStartContext
    local config = ctx.config
    if type(config) ~= "table" then
        error("Luatest:start(ctx) requires a resolved config table at ctx.config", 2)
    end
    self.config = config
    if type(config.root) == "string" and config.root ~= "" then
        self.state.root = config.root
    end
    if type(config.name) == "string" and config.name ~= "" then
        self.state.projectName = config.name
    end

    local outputStream = ctx.outputStream or io.stdout
    local errorStream = ctx.errorStream or io.stderr

    local files = ctx.files or {}

    local init = require("luatest.core.runtime.workers")
    local workerInit = init(self)

    ---@type Logger?
    local logger
    ---@type fun()?
    local restorePrint
    local runStarted = false

    local ok, err = pcall(function()
        logger = Logger.new({
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
                ---@diagnostic disable-next-line: need-check-nil
                return logger:getColumns()
            end,
        }

        self.reporterManager = createReporterManager(reporterCtx, config.reporters)

        self.testRun:start(files)
        runStarted = true

        workerInit.start(config)
        restorePrint = installPrintHook(logger, self.reporterManager)
        workerInit.run({ files = files })
    end)

    if restorePrint then
        pcall(restorePrint)
    end

    if not ok then
        self.state:catchError(err, "Unhandled Error")
    end

    pcall(function()
        require("luatest.core.runtime.worker").teardown()
    end)

    if runStarted then
        pcall(function()
            self.testRun:finish()
        end)
    end

    if logger then
        pcall(function()
            logger:cleanup()
        end)
    end

    if not ok then
        error(err)
    end
end

return Luatest
