---@namespace Luatest

---@class TestRun
---@field private luatest Luatest
local TestRun = {}
---@package
TestRun.__index = TestRun



---@param luatest Luatest
---@return TestRun
function TestRun.new(luatest)
    ---@type TestRun
    local self = setmetatable({ luatest = luatest }, TestRun)
    return self
end

---@param update TaskResultPack[]
---@param events TaskEventPack[]
function TestRun:updated(update, events)
    self.luatest.state:updateTasks(update)
    self.luatest.state:recordTaskEvents(events)

    local reporterManager = self.luatest.reporterManager
    if reporterManager then
        reporterManager:onTaskUpdate(update, events)
    end
end

---@param files string[]
function TestRun:start(files)
    local state = self.luatest.state
    state:startRun()
    state:collectPaths(files)

    local reporterManager = self.luatest.reporterManager
    if reporterManager then
        reporterManager:report("onTestRunStart", files)
    end
end

function TestRun:finish()
    local state = self.luatest.state
    state:finishRun()

    local modules = state:getTestModules()
    local errors = state:getUnhandledErrors()

    local reason = "passed"
    if #errors > 0 or state:getCountOfFailedTests() > 0 then
        reason = "failed"
    end

    local reporterManager = self.luatest.reporterManager
    if reporterManager then
        reporterManager:report("onTestRunEnd", modules, errors, reason)
        reporterManager:report("onTestRunFinished")
    end
end

---@param file File
function TestRun:enqueued(file)
    self.luatest.state:collectFiles({ file })

    local reporterManager = self.luatest.reporterManager
    if reporterManager then
        reporterManager:report("onQueued", file)
        local moduleEntity = self.luatest.state:getReportedEntity(file)
        if moduleEntity then
            reporterManager:report("onTestModuleQueued", moduleEntity)
        end
    end
end

---@param files File[]
function TestRun:collected(files)
    self.luatest.state:collectFiles(files)

    local reporterManager = self.luatest.reporterManager
    if reporterManager then
        reporterManager:report("onCollected", files)
        for _, file in ipairs(files or {}) do
            local moduleEntity = self.luatest.state:getReportedEntity(file)
            if moduleEntity then
                reporterManager:report("onTestModuleCollected", moduleEntity)
            end
        end
    end
end

return TestRun
