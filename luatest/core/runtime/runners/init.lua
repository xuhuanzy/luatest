local LuatestTestRunner = require("luatest.core.runtime.runners.test")
local getWorkerState = require("luatest.core.runtime.utils").getWorkerState
local rpc = require("luatest.core.runtime.utils").rpc
---@namespace Luatest


---@param config SerializedConfig
---@param moduleRunner ModuleRunner
---@return Runner
local function resolveTestRunner(config, moduleRunner)
    local testRunner = LuatestTestRunner.new(config)
    testRunner.moduleRunner = moduleRunner
    if not testRunner.config then
        testRunner.config = config
    end
    if not testRunner.importFile then
        error("Runner must implement 'importFile' method.")
    end
    ---@cast testRunner Runner

    -- 为自定义的测试运行器添加 rpc 回调
    do
        local originalOnTaskUpdate = testRunner.onTaskUpdate
        testRunner.onTaskUpdate = function(self, update, events)
            rpc().onTaskUpdate(update, events)
            if originalOnTaskUpdate then
                originalOnTaskUpdate(self, update, events)
            end
        end
    end

    do
        local originalOnCollectStart = testRunner.onCollectStart
        testRunner.onCollectStart = function(self, file)
            rpc().onQueued(file)
            if originalOnCollectStart then
                originalOnCollectStart(self, file)
            end
        end
    end

    do
        local originalOnCollected = testRunner.onCollected
        testRunner.onCollected = function(self, files)
            local state = getWorkerState()
            for _, file in ipairs(files or {}) do
                file.prepareDuration = state.durations.prepare
                file.environmentLoad = state.durations.environment
                -- 应仅针对批次中的单个测试文件进行收集
                state.durations.prepare = 0
                state.durations.environment = 0
            end
            rpc().onCollected(files)
            if originalOnCollected then
                originalOnCollected(self, files)
            end
        end
    end

    -- TODO: hook onAfterRunTask 添加对 config.bail 的检查以中止测试执行
    return testRunner
end

---@export namespace
return {
    resolveTestRunner = resolveTestRunner,
}
