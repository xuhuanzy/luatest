---@namespace Luatest

local BaseReporter = require("luatest.core.controller.reporters.base").BaseReporter
local Class = require("luatest.utils.class")
local WindowRenderer = require("luatest.core.controller.reporters.renderers.windowedRenderer").WindowRenderer
local nowMs = require("luatest.utils.helpers").nowMs
local renderUtils = require("luatest.core.controller.reporters.renderers.utils")
local colored = require("luatest.utils.colored")

---@class SummaryReporterOptions
---@field interval? integer

---@class SummaryReporter: BaseReporter
---@field private renderer WindowRenderer?
---@field private interval integer
---@field private runningModules table<string, { module: TestModule, startedAtMs: number, durationMs: number? }>
local SummaryReporter = Class.class("Luatest.SummaryReporter", BaseReporter)

---@param options? SummaryReporterOptions
function SummaryReporter:__init(options)
    SummaryReporter.super --[[@<BaseReporter> ]](self, options)
    self.renderer = nil
    self.interval = (options and options.interval) or 100
    self.runningModules = {}
end

---@param collection TestCollection
---@return integer total
---@return integer completed
local function countTests(collection)
    local total = 0
    local completed = 0
    for child in collection:iter() do
        if child.type == "test" then
            total = total + 1
            local result = child:result()
            if result and result.state ~= "pending" then
                completed = completed + 1
            end
        elseif child.type == "suite" then
            local childTotal, childCompleted = countTests(child.children)
            total = total + childTotal
            completed = completed + childCompleted
        end
    end
    return total, completed
end

---@param durationMs number
---@return string
function SummaryReporter:formatDuration(durationMs)
    local text = renderUtils.formatTime(durationMs)
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

---@return string[]
function SummaryReporter:createWindow()
    local out = { "" }

    ---@type { module: TestModule, startedAtMs: number, durationMs: number? }[]
    local modules = {}
    for _, entry in pairs(self.runningModules) do
        modules[#modules + 1] = entry
    end

    table.sort(modules, function(a, b)
        local ap = a.module.task.projectName or ""
        local bp = b.module.task.projectName or ""
        if ap ~= bp then
            return ap < bp
        end
        return (a.module.task.name or "") < (b.module.task.name or "")
    end)

    for _, entry in ipairs(modules) do
        local module = entry.module
        local total, completed = countTests(module.children)
        local suffix
        if total == 0 and completed == 0 then
            suffix = colored.dim(" [queued]")
        else
            suffix = colored.dim(string.format(" %d/%d", completed, total))
        end

        local duration = ""
        if entry.startedAtMs and entry.startedAtMs > 0 then
            local ms = entry.durationMs or math.max(0, nowMs() - entry.startedAtMs)
            duration = " " .. self:formatDuration(ms)
        end

        local projectLabel = renderUtils.formatProjectName({ name = module.task.projectName }, " ")
        out[#out + 1] = colored.bold(colored.yellow(" ❯ ")) .. projectLabel .. module.task.name .. suffix .. duration
    end

    if #modules > 0 then
        out[#out + 1] = ""
    end

    local summaryLines = self:getSummaryLines()
    for i = 2, #summaryLines do
        out[#out + 1] = summaryLines[i]
    end

    return out
end

function SummaryReporter:startRenderer()
    local ctx = self.ctx
    local selfRef = self
    self.renderer = WindowRenderer.new({
        outputStream = ctx.outputStream,
        errorStream = ctx.errorStream,
        getColumns = ctx.getColumns,
        interval = self.interval,
        getWindow = function()
            return selfRef:createWindow()
        end,
    })
    self.renderer:start()
    self.renderer:schedule()

    if ctx.logger and type(ctx.logger.attachRenderer) == "function" then
        ctx.logger:attachRenderer(self.renderer)
    end
end

function SummaryReporter:stopRenderer()
    if not self.renderer then
        return
    end

    if self.ctx and self.ctx.logger and type(self.ctx.logger.detachRenderer) == "function" then
        self.ctx.logger:detachRenderer(self.renderer)
    end

    self.renderer:finish()
    self.renderer:stop()
    self.renderer = nil
end

function SummaryReporter:maybeSchedule()
    if self.renderer and self.renderer:shouldRender() then
        self.renderer:schedule()
    end
end

---@param files string[]
function SummaryReporter:onTestRunStart(files)
    ---@diagnostic disable-next-line: unused-local
    local _ = files
    self.runningModules = {}
    self:startRenderer()
end

---@param _file File
function SummaryReporter:onQueued(_file)
    self:maybeSchedule()
end

---@param _files File[]
function SummaryReporter:onCollected(_files)
    self:maybeSchedule()
end

---@param _update TaskResultPack[]
---@param _events TaskEventPack[]
function SummaryReporter:onTaskUpdate(_update, _events)
    self:maybeSchedule()
end

---@param module TestModule
function SummaryReporter:onTestModuleQueued(module)
    if not module or not module.id then
        return
    end
    if not self.runningModules[module.id] then
        self.runningModules[module.id] = { module = module, startedAtMs = nowMs() }
    end
    self:maybeSchedule()
end

---@param module TestModule
function SummaryReporter:onTestModuleCollected(module)
    if not module or not module.id then
        return
    end
    local entry = self.runningModules[module.id]
    if not entry then
        self.runningModules[module.id] = { module = module, startedAtMs = nowMs() }
    else
        entry.module = module
    end
    self:maybeSchedule()
end

---@param test TestCase
function SummaryReporter:onTestCaseResult(test)
    if not test or not test.module or not test.module.id then
        self:maybeSchedule()
        return
    end
    local entry = self.runningModules[test.module.id]
    if entry then
        entry.module = test.module
    end
    self:maybeSchedule()
end

---@param module TestModule
function SummaryReporter:onTestModuleEnd(module)
    if not module or not module.id then
        return
    end
    local entry = self.runningModules[module.id]
    if entry then
        entry.durationMs = math.max(0, nowMs() - entry.startedAtMs)
        self.runningModules[module.id] = nil
    end
    self:maybeSchedule()
end

---@param _modules any[]
---@param _errors any[]
---@param _reason "passed"|"failed"
function SummaryReporter:onTestRunEnd(_modules, _errors, _reason)
    self.runningModules = {}
    self:stopRenderer()
end

return {
    SummaryReporter = SummaryReporter,
}
