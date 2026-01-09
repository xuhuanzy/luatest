---@namespace Luatest

local resolveConfig = require("luatest.core.config.resolve").resolve
local resolveFiles = require("luatest.core.files.resolve").resolve
local bootstrap = require("luatest.core.bootstrap-state")
local fs = require("luatest.core.utils.fs")
local Luatest = require("luatest.core.controller.core")

---@export namespace
local export = {}

---@class RunOptions
---@field cwd? string
---@field root? string
---@field argv? string[]
---@field targets? string[] -- CLI positional inputs: files/dirs/globs
---@field files? string[]
---@field include? string[]|string
---@field exclude? string[]|string
---@field configFile? string
---@field configOverrides? table
---@field outputStream? file
---@field errorStream? file

---@class RunSummary
---@field startAt string?
---@field durationMs number
---@field files integer
---@field tests integer
---@field failedTests integer

---@class RunResult
---@field exitCode integer
---@field config? table
---@field state? StateManager
---@field errors any[]
---@field summary RunSummary

---@param state StateManager
---@return integer
local function countTests(state)
    local count = 0
    for _, task in pairs(state.idMap or {}) do
        if task and task.type == "test" then
            count = count + 1
        end
    end
    return count
end

---@param options RunOptions?
---@return RunResult
function export.run(options)
    options = options or {}
    local outputStream = options.outputStream or io.stdout
    local errorStream = options.errorStream or io.stderr

    local overrides = {}
    if type(options.configOverrides) == "table" then
        for k, v in pairs(options.configOverrides) do
            overrides[k] = v
        end
    end
    if options.include ~= nil then
        overrides.include = options.include
    end
    if options.exclude ~= nil then
        overrides.exclude = options.exclude
    end

    local configResult = resolveConfig({
        cwd = options.cwd,
        root = options.root,
        configFile = options.configFile,
        configOverrides = overrides,
    })

    if not configResult.ok then
        local errors = configResult.errors or {}
        for _, e in ipairs(errors) do
            errorStream:write((e.message or tostring(e)) .. "\n")
        end
        errorStream:flush()
        return {
            exitCode = 1,
            config = configResult.config,
            state = nil,
            errors = errors,
            summary = {
                startAt = nil,
                durationMs = 0,
                files = 0,
                tests = 0,
                failedTests = 0,
            },
        }
    end
    ---@cast configResult.config -?

    local config = configResult.config
    local root = config.root or options.root or options.cwd or fs.getCwd()

    local filesResult = resolveFiles({
        root = root,
        files = options.files,
        targets = options.targets,
        include = config.include,
        exclude = config.exclude,
    })

    if not filesResult.ok then
        local errors = filesResult.errors or {}
        for _, e in ipairs(errors) do
            errorStream:write((e.message or tostring(e)) .. "\n")
        end
        errorStream:flush()
        return {
            exitCode = 1,
            config = config,
            state = nil,
            errors = errors,
            summary = {
                startAt = nil,
                durationMs = 0,
                files = 0,
                tests = 0,
                failedTests = 0,
            },
        }
    end

    local files = filesResult.files or {}

    if #files == 0 then
        if config.passWithNoTests == true then
            return {
                exitCode = 0,
                config = config,
                state = nil,
                errors = {},
                summary = {
                    startAt = nil,
                    durationMs = 0,
                    files = 0,
                    tests = 0,
                    failedTests = 0,
                },
            }
        end
        errorStream:write("No test files found\n")
        errorStream:flush()
        return {
            exitCode = 1,
            config = config,
            state = nil,
            errors = { { message = "No test files found" } },
            summary = {
                startAt = nil,
                durationMs = 0,
                files = 0,
                tests = 0,
                failedTests = 0,
            },
        }
    end

    local luatest = Luatest.new()
    bootstrap.markRunStarted()
    local ok = pcall(function()
        luatest:start({
            files = files,
            config = config,
            outputStream = outputStream,
            errorStream = errorStream,
        })
    end)
    bootstrap.markRunFinished()

    local state = luatest.state
    local unhandledErrors = state:getUnhandledErrors()
    local failedTests = state:getCountOfFailedTests()

    local exitCode = 0
    if failedTests > 0 or #unhandledErrors > 0 or not ok then
        exitCode = 1
    end

    local fileCount = #(state:getFiles() or {})
    local testCount = countTests(state)

    return {
        exitCode = exitCode,
        config = config,
        state = state,
        errors = unhandledErrors,
        summary = {
            startAt = state.runStartAt,
            durationMs = state:getRunDurationMs(),
            files = fileCount,
            tests = testCount,
            failedTests = failedTests,
        },
    }
end

return export
