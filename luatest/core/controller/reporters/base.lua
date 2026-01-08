---@namespace Luatest

local Class = require("luatest.utils.class")
local renderUtils = require("luatest.core.controller.reporters.renderers.utils")
local colored = require("luatest.utils.colored")
local tty = require("luatest.utils.tty")
local taskUtils = require("luatest.runner.utils.tasks")

---@class BaseReporter: Reporter
---@field protected ctx ReporterContext
---@field protected options table
---@field private _consoleLastKey string?
---@field private _consoleLastType "stdout"|"stderr"|nil
---@field private renderSucceed boolean
local BaseReporter = Class.class("Luatest.BaseReporter")

---@param options? table
function BaseReporter:__init(options)
    self.options = options or {}
    ---@diagnostic disable-next-line: inject-field
    self.ctx = nil
    self._consoleLastKey = nil
    self._consoleLastType = nil
    self.renderSucceed = false
end

---@param ctx ReporterContext
function BaseReporter:onInit(ctx)
    self.ctx = ctx
end

---@param files string[]
function BaseReporter:onTestRunStart(files)
    local ok = false
    local isTty = tty.isTTY()
    if isTty then
        ok = true
    end

    if not ok then
        self.renderSucceed = false
        return
    end

    local count = type(files) == "table" and #files or 0
    self.renderSucceed = count <= 1
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
        logger:write(message, type --[[@as "output"|"error" ]])
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

---@param entity any
---@param separator string
---@return string
local function formatEntityName(entity, separator)
    separator = separator or " > "

    if not entity then
        return "unknown test"
    end

    if entity.type == "module" then
        return tostring(entity.relativeModuleId or entity.moduleId or entity.name or "<unknown>")
    end

    local parts = {}
    local module = entity.module
    if module and module.relativeModuleId then
        parts[#parts + 1] = module.relativeModuleId
    elseif module and module.moduleId then
        parts[#parts + 1] = module.moduleId
    end

    local stack = {}
    local parent = entity.parent
    while parent and parent.type ~= "module" do
        if parent.name and parent.name ~= "" then
            table.insert(stack, 1, parent.name)
        end
        parent = parent.parent
    end
    for _, name in ipairs(stack) do
        parts[#parts + 1] = name
    end

    if entity.name and entity.name ~= "" then
        parts[#parts + 1] = entity.name
    end

    if #parts == 0 then
        return "unknown test"
    end

    return table.concat(parts, separator)
end

function BaseReporter:flushUserConsoleLog()
    if not self._consoleLastKey then
        return
    end

    if self._consoleLastType == "stderr" then
        self:error("\n")
    else
        self:log("\n")
    end

    self._consoleLastKey = nil
    self._consoleLastType = nil
end

---@param log any
function BaseReporter:onUserConsoleLog(log)
    if type(log) ~= "table" then
        return
    end

    local logType = log.type == "stderr" and "stderr" or "stdout"
    local content = log.content
    if type(content) ~= "string" then
        content = tostring(content or "")
    end

    local taskId = log.taskId
    local state = self.ctx and self.ctx.state or nil

    local headerText = "unknown test"
    local headerTextPlain = "unknown test"

    if state and type(state.getReportedEntityById) == "function" and type(taskId) == "string" and taskId ~= "" then
        local entity = state:getReportedEntityById(taskId)
        if entity then
            headerText = formatEntityName(entity, renderUtils.separator)
            headerTextPlain = formatEntityName(entity, " > ")
        else
            headerText = taskId
            headerTextPlain = taskId
        end
    elseif type(taskId) == "string" and taskId ~= "" then
        headerText = taskId
        headerTextPlain = taskId
    end

    local headerKey = logType .. "|" .. headerTextPlain
    local isNewHeader = headerKey ~= self._consoleLastKey
    if self._consoleLastKey and isNewHeader then
        if self._consoleLastType == "stderr" then
            self:error("\n")
        else
            self:log("\n")
        end
    end

    local header
    if colored.isSupported() then
        header = colored.gray(logType .. colored.dim(" | " .. headerText .. "\n"))
    else
        header = logType .. " | " .. headerTextPlain .. "\n"
    end

    local out
    if isNewHeader then
        out = header .. content
    else
        out = content
    end
    if out:sub(-1) ~= "\n" then
        out = out .. "\n"
    end

    if logType == "stderr" then
        self:error(out)
    else
        self:log(out)
    end

    self._consoleLastKey = headerKey
    self._consoleLastType = logType
end

---@param durationMs number?
---@return string
local function formatMs(durationMs)
    durationMs = tonumber(durationMs) or 0
    return string.format("%dms", math.floor(durationMs + 0.5))
end

---@param durationMs number?
---@return string
local function formatColoredMs(durationMs)
    durationMs = tonumber(durationMs) or 0
    local text = formatMs(durationMs)
    if not colored.isSupported() then
        return text
    end
    if durationMs >= 5000 then
        return colored.bold(colored.red(text))
    end
    if durationMs >= 1000 then
        return colored.bold(colored.yellow(text))
    end
    return colored.dim(text)
end

---@param collection TestCollection
---@param out TestCase[]
local function collectTestCases(collection, out)
    if not collection or type(collection.iter) ~= "function" then
        return
    end

    for child in collection:iter() do
        if child and child.type == "test" then
            out[#out + 1] = child
        elseif child and child.type == "suite" then
            collectTestCases(child.children, out)
        end
    end
end

---@param test TestCase
---@return integer
local function getTestListIndent(test)
    local depth = 0
    local parent = test and test.parent or nil
    while parent and parent.type == "suite" do
        depth = depth + 1
        parent = parent.parent
    end
    if depth <= 1 then
        return 0
    end
    return (depth - 1) * 2
end

---@param task File|Suite|nil
---@return "queued"|"pending"|"passed"|"failed"|"skipped"|nil
local function getReportedState(task)
    if not task then
        return nil
    end

    local mode = task.mode
    local state = task.result and task.result.state or nil

    if state == "queued" or (state == nil and mode == "queued") then
        return "queued"
    end

    if mode == "skip" or mode == "todo" or state == "skip" or state == "todo" then
        return "skipped"
    end

    if state == nil or state == "run" or state == "only" then
        return "pending"
    end

    if state == "fail" then
        return "failed"
    end

    if state == "pass" then
        return "passed"
    end

    return nil
end

---@param module TestModule
---@param counts { tests: integer, failed: integer, skipped: integer }
---@return string
function BaseReporter:formatTestModule(module, counts)
    local task = module and module.task or nil
    local name = task and (task.name or task.filepath) or "<unknown>"

    local state = getReportedState(task)

    local prefix = " · "
    if colored.isSupported() then
        if state == "failed" then
            prefix = colored.bold(colored.red(" ❯ "))
        elseif state == "passed" then
            prefix = colored.bold(colored.green(" ✓ "))
        elseif state == "skipped" then
            prefix = colored.dim(colored.gray(" ↓ "))
        else
            prefix = colored.gray(prefix)
        end
    else
        if state == "failed" then
            prefix = " ❯ "
        elseif state == "passed" then
            prefix = " ✓ "
        elseif state == "skipped" then
            prefix = " ↓ "
        end
    end

    local stateText
    if colored.isSupported() then
        stateText = colored.dim(string.format("%d tests", counts.tests))
        if counts.failed > 0 then
            stateText = stateText .. colored.dim(" | ") .. colored.red(string.format("%d failed", counts.failed))
        end
        if counts.skipped > 0 then
            stateText = stateText .. colored.dim(" | ") .. colored.yellow(string.format("%d skipped", counts.skipped))
        end
        stateText = colored.dim("(") .. stateText .. colored.dim(")")
    else
        stateText = string.format("(%d tests", counts.tests)
        if counts.failed > 0 then
            stateText = stateText .. string.format(" | %d failed", counts.failed)
        end
        if counts.skipped > 0 then
            stateText = stateText .. string.format(" | %d skipped", counts.skipped)
        end
        stateText = stateText .. ")"
    end

    local duration = task and task.result and task.result.duration or 0
    local suffix = stateText .. " " .. formatColoredMs(duration)

    local projectLabel = renderUtils.formatProjectName({ name = task and task.projectName or nil }, " ")
    return prefix .. projectLabel .. tostring(name) .. " " .. suffix
end

---@param module TestModule
function BaseReporter:onTestModuleEnd(module)
    if not module or not module.task then
        return
    end

    local moduleState = getReportedState(module.task)
    if moduleState == "queued" then
        return
    end

    ---@type TestCase[]
    local tests = {}
    collectTestCases(module.children, tests)

    local failedCount = 0
    local skippedCount = 0
    for _, test in ipairs(tests) do
        local result = test:result()
        if result and result.state == "failed" then
            failedCount = failedCount + 1
        elseif result and result.state == "skipped" then
            skippedCount = skippedCount + 1
        end
    end

    local lines = { "", self:formatTestModule(module, { tests = #tests, failed = failedCount, skipped = skippedCount }) }

    local shouldRenderTests = self.renderSucceed or moduleState == "failed"
    if shouldRenderTests and #tests > 0 then
        local nameMaxLen = 0
        for _, test in ipairs(tests) do
            local name = tostring(test.name or "<anonymous>")
            local indent = getTestListIndent(test)
            local len = indent + #name
            if len > nameMaxLen then
                nameMaxLen = len
            end
        end

        for _, test in ipairs(tests) do
            local name = tostring(test.name or "<anonymous>")
            local indent = getTestListIndent(test)
            local padding = string.rep(" ", math.max(2, nameMaxLen - (indent + #name) + 2))

            local icon = renderUtils.getStateSymbol(test.task)
            local duration = test.task and test.task.result and test.task.result.duration or 0
            lines[#lines + 1] = "     " ..
                string.rep(" ", indent) .. icon .. " " .. name .. padding .. formatColoredMs(duration)
        end
    end

    lines[#lines + 1] = ""

    self:log(table.concat(lines, "\n") .. "\n")
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
---@param files? File[]
function BaseReporter:getSummaryLines(files)
    local state = self.ctx.state
    files = files or state:getFiles()
    local tests = taskUtils.getTests(files)
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

---@param err any
---@return string
local function formatTaskError(err)
    if err == nil then
        return ""
    end

    if type(err) == "string" then
        ---@diagnostic disable-next-line: incomplete-signature-doc, redundant-return-value
        -- Lua中的断言错误可能带有位置前缀, 并且可能以额外的换行符开头
        return err:gsub("\r\n", "\n"):gsub(":%s*\n\n", ":\n")
    end

    if type(err) == "table" then
        local parts = {}
        if type(err.message) == "string" and err.message ~= "" then
            parts[#parts + 1] = err.message
        end
        if type(err.diff) == "string" and err.diff ~= "" then
            parts[#parts + 1] = err.diff
        end
        if type(err.stack) == "string" and err.stack ~= "" then
            parts[#parts + 1] = err.stack
        end
        if #parts > 0 then
            ---@diagnostic disable-next-line: incomplete-signature-doc, redundant-return-value
            return table.concat(parts, "\n"):gsub("\r\n", "\n")
        end
    end

    return tostring(err)
end

---@param task Task
---@return string
function BaseReporter:formatFailLabel(task)
    local header = self:formatFailedTestHeader(task)
    if colored.isSupported() then
        return colored.bgRed(colored.bold(" FAIL ")) .. " " .. header
    end
    return " FAIL  " .. header
end

---@param tasks Task[]
---@param errorDivider fun()
function BaseReporter:printTaskErrors(tasks, errorDivider)
    for _, task in ipairs(tasks or {}) do
        local errorsList = task and task.result and task.result.errors or {}
        if type(errorsList) ~= "table" or errorsList[1] == nil then
            -- keep the behavior minimal: if a task has no explicit errors, don't print details
        else
            for _, err in ipairs(errorsList) do
                self:error(self:formatFailLabel(task) .. "\n")

                local body = formatTaskError(err)
                if body ~= "" then
                    if body:sub(-1) ~= "\n" then
                        body = body .. "\n"
                    end
                    self:error(body)
                end

                errorDivider()
            end
        end
    end
end

---@param files File[]
---@return Task[]
local function collectFailedSuites(files)
    ---@type Task[]
    local out = {}
    for _, suite in ipairs(taskUtils.getSuites(files)) do
        local errorsList = suite.result and suite.result.errors or nil
        if type(errorsList) == "table" and errorsList[1] ~= nil then
            out[#out + 1] = suite
        end
    end
    return out
end

---@param files File[]
---@return Task[]
local function collectFailedTests(files)
    ---@type Task[]
    local out = {}
    for _, test in ipairs(taskUtils.getTests(files)) do
        if test.result and test.result.state == "fail" then
            out[#out + 1] = test
        end
    end
    return out
end

---@param errors any[]
function BaseReporter:printUnhandledErrors(errors)
    if type(errors) ~= "table" or #errors == 0 then
        return
    end

    local ctx = self.ctx
    local errorStream = ctx.errorStream
    local cols = ctx.getColumns and ctx.getColumns() or nil

    self:write(errorStream, "\n" .. renderUtils.errorBanner("Unhandled Errors", cols) .. "\n")
    for _, err in ipairs(errors) do
        local body = formatTaskError(err)
        if body ~= "" then
            if body:sub(-1) ~= "\n" then
                body = body .. "\n"
            end
            self:write(errorStream, body)
        end
    end
    self:write(errorStream, renderUtils.divider(nil, nil, nil, nil, cols) .. "\n")
end

---@param suites Task[]
---@param tests Task[]
function BaseReporter:printFailedTasks(suites, tests)
    local ctx = self.ctx
    local errorStream = ctx.errorStream
    local cols = ctx.getColumns and ctx.getColumns() or nil

    local function countErrors(tasks)
        local total = 0
        for _, task in ipairs(tasks or {}) do
            local errorsList = task and task.result and task.result.errors or nil
            if type(errorsList) == "table" then
                total = total + #errorsList
            end
        end
        return total
    end

    local totalErrors = countErrors(suites) + countErrors(tests)
    local current = 1

    local function errorDivider()
        if totalErrors <= 0 then
            return
        end

        local label = string.format("[%d/%d]", current, totalErrors)
        current = current + 1

        local line = renderUtils.divider(label, nil, 1, nil, cols)
        if colored.isSupported() then
            line = colored.red(colored.dim(line))
        end
        self:write(errorStream, line .. "\n")
    end

    if type(suites) == "table" and #suites > 0 then
        self:write(errorStream, "\n" .. renderUtils.errorBanner("Failed Suites " .. #suites, cols) .. "\n\n")
        self:printTaskErrors(suites, errorDivider)
    end

    if type(tests) == "table" and #tests > 0 then
        self:write(errorStream, "\n" .. renderUtils.errorBanner("Failed Tests " .. #tests, cols) .. "\n\n")
        self:printTaskErrors(tests, errorDivider)
    end
end

---@param files File[]
---@param errors any[]
---@param reason "passed"|"failed"
function BaseReporter:reportSummary(files, errors, reason)
    -- Align with Vitest's reporter collection:
    -- - Failed Suites: suites that have own errors (hooks/collection/runtime), not parent suites of failed tests.
    -- - Failed Tests: tests with result.state == "fail".
    -- (Vitest does this via @vitest/runner/utils getSuites/getTests and filtering.)
    local failedSuites = collectFailedSuites(files)
    local failedTests = collectFailedTests(files)
    local hasUnhandledErrors = type(errors) == "table" and #errors > 0
    local hasFailures = (#failedSuites > 0) or (#failedTests > 0)
    if hasFailures or hasUnhandledErrors or reason ~= "passed" then
        self:printFailedTasks(failedSuites, failedTests)
        self:printUnhandledErrors(errors)
    end

    local output = self.ctx.outputStream
    for _, line in ipairs(self:getSummaryLines(files)) do
        self:write(output, line .. "\n")
    end
end

---@param modules any[]
---@param errors any[]
---@param reason "passed"|"failed"
function BaseReporter:onTestRunEnd(modules, errors, reason)
    local output = self.ctx.outputStream
    local state = self.ctx.state

    self:flushUserConsoleLog()

    ---@type File[]
    local files = {}
    for _, testModule in ipairs(modules or {}) do
        if testModule and testModule.task then
            files[#files + 1] = testModule.task
        end
    end
    if #files == 0 then
        files = state:getFiles()
    end

    if #files == 0 and (type(errors) ~= "table" or #errors == 0) then
        self:write(output, "No test files found\n")
        return
    end

    self:reportSummary(files, errors, reason)
end

return {
    BaseReporter = BaseReporter,
}
