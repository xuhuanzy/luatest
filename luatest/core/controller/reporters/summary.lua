---@namespace Luatest

local BaseReporter = require("luatest.core.controller.reporters.base").BaseReporter
local Class = require("luatest.utils.class")
local WindowRenderer = require("luatest.core.controller.reporters.renderers.windowedRenderer").WindowRenderer

---@class SummaryReporterOptions
---@field interval? integer

---@class SummaryReporter: BaseReporter
---@field private renderer WindowRenderer?
---@field private interval integer
local SummaryReporter = Class.class("Luatest.SummaryReporter", BaseReporter)

---@param options? SummaryReporterOptions
function SummaryReporter:__init(options)
    SummaryReporter.super --[[@<BaseReporter> ]](self, options)
    self.renderer = nil
    self.interval = (options and options.interval) or 100
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
            return selfRef:getSummaryLines()
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

---@param _modules any[]
---@param _errors any[]
---@param _reason "passed"|"failed"
function SummaryReporter:onTestRunEnd(_modules, _errors, _reason)
    self:stopRenderer()
end

return {
    SummaryReporter = SummaryReporter,
}
