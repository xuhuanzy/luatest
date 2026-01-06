---@namespace Luatest

local BaseReporter = require("luatest.core.controller.reporters.base").BaseReporter
local SummaryReporter = require("luatest.core.controller.reporters.summary").SummaryReporter
local Class = require("luatest.utils.class")
local colored = require("luatest.utils.colored")

---@class DefaultReporterOptions
---@field windowed boolean?
---@field interval? integer

---@class DefaultReporter: BaseReporter
---@field private summary SummaryReporter?
---@field private options DefaultReporterOptions
local DefaultReporter = Class.class("Luatest.DefaultReporter", BaseReporter)

---@param options? DefaultReporterOptions
function DefaultReporter:__init(options)
    DefaultReporter.super --[[@<BaseReporter> ]](self, options)
    self.options = options or {}
    self.summary = nil
end

---@return boolean
function DefaultReporter:isWindowedEnabled()
    if self.options.windowed == false then
        return false
    end
    if self.ctx and self.ctx.config then
        return false
    end
    return colored.isSupported()
end

---@param ctx ReporterContext
function DefaultReporter:onInit(ctx)
    BaseReporter.onInit(self, ctx)
    if self:isWindowedEnabled() then
        self.summary = SummaryReporter.new({ interval = self.options.interval })
        self.summary:onInit(ctx)
    end
end

---@param files string[]
function DefaultReporter:onTestRunStart(files)
    if self.summary then
        self.summary:onTestRunStart(files)
    end
end

---@param file File
function DefaultReporter:onQueued(file)
    if self.summary then
        self.summary:onQueued(file)
    end
end

---@param files File[]
function DefaultReporter:onCollected(files)
    if self.summary then
        self.summary:onCollected(files)
    end
end

---@param update TaskResultPack[]
---@param events TaskEventPack[]
function DefaultReporter:onTaskUpdate(update, events)
    if self.summary then
        self.summary:onTaskUpdate(update, events)
    end
end

---@param modules any[]
---@param errors any[]
---@param reason "passed"|"failed"
function DefaultReporter:onTestRunEnd(modules, errors, reason)
    if self.summary then
        self.summary:onTestRunEnd(modules, errors, reason)
    end
    BaseReporter.onTestRunEnd(self, modules, errors, reason)
end

return {
    DefaultReporter = DefaultReporter,
}
