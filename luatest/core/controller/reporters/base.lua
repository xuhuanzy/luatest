---@namespace Luatest

local Class = require("luatest.utils.class")
local renderUtils = require("luatest.core.controller.reporters.renderers.utils")

---@class BaseReporter: Reporter
---@field protected ctx ReporterContext
---@field protected options table
local BaseReporter = Class.class("Luatest.BaseReporter")

---@param options? table
function BaseReporter:__init(options)
    self.options = options or {}
    ---@diagnostic disable-next-line: inject-field
    self.ctx = nil
end

---@param ctx ReporterContext
function BaseReporter:onInit(ctx)
    self.ctx = ctx
end

---@param stream file
---@param message string
function BaseReporter:write(stream, message)
    local ctx = self.ctx
    local logger = ctx and ctx.logger or nil
    if logger and type(logger.write) == "function" then
        local type = "output"
        if ctx and ctx.errorStream == stream then
            type = "error"
        end
        logger:write(message, type)
        return
    end

    stream:write(message)
    stream:flush()
end

---@param message string
function BaseReporter:log(message)
    self:write(self.ctx.outputStream, message)
end

---@param message string
function BaseReporter:error(message)
    self:write(self.ctx.errorStream, message)
end

---@param str string
---@return string
function BaseReporter:padSummaryTitle(str)
    local padding = 11 - #str
    if padding > 0 then
        return string.rep(" ", padding) .. str .. " "
    end
    return str .. " "
end

---@param counts { failed: integer, passed: integer, skipped: integer, pending: integer, total: integer }
---@return string
function BaseReporter:formatCounts(counts)
    local parts = {}
    if counts.failed > 0 then
        parts[#parts + 1] = counts.failed .. " failed"
    end
    if counts.skipped > 0 then
        parts[#parts + 1] = counts.skipped .. " skipped"
    end
    if counts.pending > 0 then
        parts[#parts + 1] = counts.pending .. " pending"
    end
    parts[#parts + 1] = counts.passed .. " passed"
    return table.concat(parts, " | ") .. " (" .. counts.total .. ")"
end

---@param timeMs number
---@return string
function BaseReporter:formatTime(timeMs)
    if timeMs >= 1000 then
        return string.format("%.2fs", timeMs / 1000)
    end
    return string.format("%dms", math.floor(timeMs))
end

---@param state StateManager
---@return { failed: integer, passed: integer, skipped: integer, pending: integer, total: integer }
function BaseReporter:collectFileCounts(state)
    local failed, passed, skipped, pending = 0, 0, 0, 0
    local files = state:getFiles()
    for _, file in ipairs(files) do
        local st = (file.result and file.result.state) or file.mode
        if st == "fail" then
            failed = failed + 1
        elseif st == "pass" then
            passed = passed + 1
        elseif st == "skip" or st == "todo" then
            skipped = skipped + 1
        else
            pending = pending + 1
        end
    end
    return {
        failed = failed,
        passed = passed,
        skipped = skipped,
        pending = pending,
        total = #files,
    }
end

---@param state StateManager
---@return { failed: integer, passed: integer, skipped: integer, pending: integer, total: integer }
function BaseReporter:collectTestCounts(state)
    local failed, passed, skipped, pending = 0, 0, 0, 0
    local total = 0
    for _, task in pairs(state.idMap) do
        if task and task.type == "test" then
            total = total + 1
            local st = (task.result and task.result.state) or task.mode
            if st == "fail" then
                failed = failed + 1
            elseif st == "pass" then
                passed = passed + 1
            elseif st == "skip" or st == "todo" then
                skipped = skipped + 1
            else
                pending = pending + 1
            end
        end
    end
    return {
        failed = failed,
        passed = passed,
        skipped = skipped,
        pending = pending,
        total = total,
    }
end

---@return string[]
function BaseReporter:getSummaryLines()
    local state = self.ctx.state
    local files = state:getFiles()
    local tests = {}
    for _, task in pairs(state.idMap) do
        if task and task.type == "test" then
            tests[#tests + 1] = task
        end
    end
    local duration = state:getRunDurationMs()
    return {
        "",
        renderUtils.padSummaryTitle("Test Files") .. renderUtils.getStateString(files),
        renderUtils.padSummaryTitle("Tests") .. renderUtils.getStateString(tests),
        renderUtils.padSummaryTitle("Start at") .. (state.runStartAt or ""),
        renderUtils.padSummaryTitle("Duration") .. renderUtils.formatTime(duration),
        "",
    }
end

---@param task Task
---@return string
function BaseReporter:formatFailedTestHeader(task)
    local state = self.ctx.state
    local entity = state:getReportedEntity(task)
    local header = task.name or "<anonymous>"
    if entity and entity.module and entity.module.relativeModuleId then
        header = entity.module.relativeModuleId .. " > " .. (entity.fullName or task.name)
    elseif entity and entity.fullName then
        header = entity.fullName
    end
    return header
end

---@return Task[]
function BaseReporter:getFailedTests()
    local state = self.ctx.state
    local out = {}
    for _, task in pairs(state.idMap) do
        if task and task.type == "test" and task.result and task.result.state == "fail" then
            out[#out + 1] = task
        end
    end
    return out
end

---@param _modules any[]
---@param errors any[]
---@param reason "passed"|"failed"
function BaseReporter:onTestRunEnd(_modules, errors, reason)
    local output = self.ctx.outputStream
    local errorStream = self.ctx.errorStream

    for _, line in ipairs(self:getSummaryLines()) do
        self:write(output, line .. "\n")
    end

    if type(errors) == "table" and #errors > 0 then
        self:write(errorStream, "Unhandled Errors (" .. #errors .. ")\n")
        for _, err in ipairs(errors) do
            self:write(errorStream, tostring(err) .. "\n")
        end
        self:write(errorStream, "\n")
    end

    if reason ~= "passed" then
        local failedTests = self:getFailedTests()
        if #failedTests > 0 then
            self:write(errorStream, "Failed Tests (" .. #failedTests .. ")\n")
            for _, task in ipairs(failedTests) do
                self:write(errorStream, "- " .. self:formatFailedTestHeader(task) .. "\n")
                local errorsList = task.result and task.result.errors or {}
                if type(errorsList) == "table" and errorsList[1] ~= nil then
                    self:write(errorStream, tostring(errorsList[1]) .. "\n")
                end
            end
            self:write(errorStream, "\n")
        end
    end
end

return {
    BaseReporter = BaseReporter,
}
