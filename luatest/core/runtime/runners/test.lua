---@namespace Luatest

local getState = require("luatest.expect.state").getState
local setState = require("luatest.expect.state").setState
local GLOBAL_EXPECT = require("luatest.expect.constants").GLOBAL_EXPECT
local getWorkerState = require("luatest.core.runtime.utils").getWorkerState
local getTestName = require("luatest.runner.utils.tasks").getTestName
local restoreAllMocks = require("luatest.spy.mock").restoreAllMocks
local resetAllMocks = require("luatest.spy.mock").resetAllMocks
local clearAllMocks = require("luatest.spy.mock").clearAllMocks
local tu = require("luatest.core.integrations.luatest-utils").tu

local workerContext = {}

---@class SerializedConfig
---@field logHeapUsage number 内存使用情况
---@field restoreMocks boolean 恢复所有 mock
---@field mockReset boolean 重置所有 mock
---@field clearMocks boolean 清空所有 mock
---@field unstubGlobals boolean 恢复所有以`tu.stubGlobal`设置的全局变量

---@class LuatestTestRunner: Runner
---@field private workerState WorkerGlobalState
---@field private assertionsErrors table<Task, Error>
---@field config SerializedConfig
local LuatestTestRunner = {}
LuatestTestRunner.__index = LuatestTestRunner

---@param config SerializedConfig
---@return LuatestTestRunner
function LuatestTestRunner.new(config)
    local self = setmetatable({}, LuatestTestRunner)
    self.workerState = getWorkerState()
    self.assertionsErrors = setmetatable({}, { __mode = "k" })
    self.config = config
    return self
end

---@param filepath string
---@param source string
---@return any
function LuatestTestRunner:importFile(filepath, source)
    return require(filepath)
end

---@param file File
function LuatestTestRunner:onCollectStart(file)
    self.workerState.current = file
end

---@param listener fun()
function LuatestTestRunner:onCleanupWorkerContext(listener)
    self.workerState:onCleanup(listener)
end

function LuatestTestRunner:onAfterRunFiles()
    self.workerState.current = nil
end

---@return table<string, any>
function LuatestTestRunner:getWorkerContext()
    return workerContext
end

---@param suite Suite
function LuatestTestRunner:onAfterRunSuite(suite)
    if self.config.logHeapUsage then
        suite.result = suite.result or {} ---@type TaskResult
        suite.result.heap = collectgarbage("count") * 1024
    end
    self.workerState.current = suite.suite or suite.file
end

---@param test Task
function LuatestTestRunner:onAfterRunTask(test)
    if self.config.logHeapUsage then
        test.result --[[@cast -?]].heap = collectgarbage("count") * 1024
    end
    self.workerState.current = test.suite or test.file
end

---@param test Task
function LuatestTestRunner:onBeforeRunTask(test)
    if test.mode ~= "run" and test.mode ~= "queued" then
        return
    end

    self.workerState.current = test
end

---@param suite Suite
function LuatestTestRunner:onBeforeRunSuite(suite)
    self.workerState.current = suite
end

---@param test Task
function LuatestTestRunner:onBeforeTryTask(test)
    self:clearModuleMocks()
    -- 重置 expect 状态
    setState({
        assertionCalls = 0,
        isExpectingAssertions = false,
        isExpectingAssertionsError = nil,
        expectedAssertionsNumber = nil,
        expectedAssertionsNumberErrorGen = nil,
        currentTestName = getTestName(test),
    }, _G[GLOBAL_EXPECT])
end

---@param test Test
function LuatestTestRunner:onAfterTryTask(test)
    -- TODO: 添加对 assertions 与 hasAssertions 的检查, 但我们现在并不需要
end

---@param context TestContext
---@return TestContext
function LuatestTestRunner:extendTaskContext(context)
    -- TODO: 支持扩展上下文
    return context
end

-- 清理模块 mocks
function LuatestTestRunner:clearModuleMocks()
    local config = self.config
    if not config then return end
    if config.restoreMocks then
        restoreAllMocks()
    end
    if config.mockReset then
        resetAllMocks()
    end
    if config.clearMocks then
        clearAllMocks()
    end

    if config.unstubGlobals then
        tu.unstubAllGlobals()
    end
end

return LuatestTestRunner
