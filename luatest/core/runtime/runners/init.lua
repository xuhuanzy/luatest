local LuatestTestRunner = require("luatest.core.runtime.runners.test")
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

    -- TODO: hook onCollected 记录准备文件环境的耗时

    -- TODO: hook onAfterRunTask 添加对 config.bail 的检查以中止测试执行
    return testRunner
end

---@export namespace
return {
    resolveTestRunner = resolveTestRunner,
}
