---@namespace Luatest

---@class ReporterContext
---@field state StateManager
---@field config SerializedConfig
---@field outputStream file
---@field errorStream file
---@field getColumns? fun(): integer

---@class ReporterManager
---@field private reporters Reporter[]
---@field private ctx ReporterContext
local ReporterManager = {}
ReporterManager.__index = ReporterManager

---@param ctx ReporterContext
---@param reporter Reporter
---@param method string
---@param ... any
local function safeCall(ctx, reporter, method, ...)
    if type(reporter) ~= "table" then
        return
    end
    local fn = reporter[method]
    if type(fn) ~= "function" then
        return
    end
    local ok, err = pcall(fn, reporter, ...)
    if ok then
        return
    end

    -- reporter 错误不应中止测试运行
    local state = ctx and ctx.state
    if state and state.catchError then
        state:catchError(err, "Unhandled Reporter Error")
        return
    end

    local errorStream = ctx and ctx.errorStream or io.stderr
    errorStream:write("[Unhandled Reporter Error] " .. tostring(err) .. "\n")
    errorStream:flush()
end

---@param reporters Reporter[]?
---@param ctx ReporterContext
---@return ReporterManager
function ReporterManager.new(reporters, ctx)
    ---@type ReporterManager
    local self = setmetatable({}, ReporterManager)
    self.reporters = reporters or {}
    self.ctx = ctx
    return self
end

---@param ctx ReporterContext
function ReporterManager:init(ctx)
    self.ctx = ctx
    for _, reporter in ipairs(self.reporters) do
        safeCall(ctx, reporter, "onInit", ctx)
    end
end

---@param method string
---@param ... any
function ReporterManager:report(method, ...)
    local ctx = self.ctx
    for _, reporter in ipairs(self.reporters) do
        safeCall(ctx, reporter, method, ...)
    end
end

---@param str string
---@param prefix string
---@return boolean
local function startsWith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

---@param str string
---@param suffix string
---@return boolean
local function endsWith(str, suffix)
    return str:sub(-#suffix) == suffix
end

---@param event TaskUpdateEvent
---@param entity any
---@return { name: string, entity: any }?
local function buildHookContext(event, entity)
    if not (startsWith(event, "before-hook") or startsWith(event, "after-hook")) then
        return nil
    end

    local isBefore = startsWith(event, "before-hook")
    local name
    if entity.type == "test" then
        name = isBefore and "beforeEach" or "afterEach"
    else
        name = isBefore and "beforeAll" or "afterAll"
    end

    return { name = name, entity = entity }
end

---@param taskId string
---@param event TaskUpdateEvent
---@param data any
---@return any
function ReporterManager:reportTaskEvent(taskId, event, data)
    local state = self.ctx.state
    local entity = state:getReportedEntityById(taskId)
    if not entity then
        return
    end

    if event == "suite-prepare" then
        if entity.type == "module" then
            return self:report("onTestModuleStart", entity)
        end
        if entity.type == "suite" then
            return self:report("onTestSuiteReady", entity)
        end
        return
    end

    if event == "suite-finished" then
        if entity.type == "module" then
            return self:report("onTestModuleEnd", entity)
        end
        if entity.type == "suite" then
            return self:report("onTestSuiteResult", entity)
        end
        return
    end

    if event == "test-prepare" and entity.type == "test" then
        return self:report("onTestCaseReady", entity)
    end

    if event == "test-finished" and entity.type == "test" then
        return self:report("onTestCaseResult", entity)
    end

    local hook = buildHookContext(event, entity)
    if hook then
        if endsWith(event, "-start") then
            return self:report("onHookStart", hook, data)
        end
        return self:report("onHookEnd", hook, data)
    end
end

---@param events TaskEventPack[]?
function ReporterManager:reportTaskEvents(events)
    for _, pack in ipairs(events or {}) do
        ---@type string
        local id = pack[1]
        ---@type TaskUpdateEvent
        local event = pack[2]
        local data = pack[3]
        if type(id) == "string" and type(event) == "string" then
            self:reportTaskEvent(id, event, data)
        end
    end
end

---@param update TaskResultPack[]?
---@param events TaskEventPack[]?
function ReporterManager:onTaskUpdate(update, events)
    self:reportTaskEvents(events)
    self:report("onTaskUpdate", update or {}, events or {})
end

return ReporterManager
