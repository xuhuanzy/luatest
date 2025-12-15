local getWorkerState = require("luatest.core.runtime.utils").getWorkerState
local resolveTestRunner = require("luatest.core.runtime.runners").resolveTestRunner
local resetModules = require("luatest.core.runtime.utils").resetModules
local startTests = require("luatest.runner.run").startTests
local collectTests = require("luatest.runner.collect").collectTests
local tu = require("luatest.core.integrations.luatest-utils").tu
---@namespace Luatest

---@param method "run" | "collect"
---@param files string[]
---@param config SerializedConfig
---@param moduleRunner ModuleRunner
local function run(method, files, config, moduleRunner)
    local workerState = getWorkerState()
    local testRunner = resolveTestRunner(config, moduleRunner)
    for _, file in ipairs(files) do
        -- 清理环境
        if config.isolate then
            resetModules(workerState.evaluatedModules)
        end
        workerState.filepath = file
        if method == "run" then
            startTests({ file }, testRunner)
        else
            collectTests({ file }, testRunner)
        end
        -- 清理
        tu.restoreAllMocks()
    end
end

return run
