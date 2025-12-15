local provideWorkerState = require("luatest.core.runtime.utils").provideWorkerState
local startModuleRunner = require("luatest.core.runtime.moduleRunner.startModuleRunner")
local run = require("luatest.core.runtime.runBaseTests")
---@namespace Luatest

---@export namespace
local export = {}

---@param method "run" | "collect"
---@param state WorkerGlobalState
function export.runBaseTests(method, state)
    local ctx = state.ctx
    -- 注入全局状态
    provideWorkerState(_G, state)

    local moduleRunner = startModuleRunner({
        evaluatedModules = state.evaluatedModules
    })
    if not moduleRunner then
        error("moduleRunner is not provided")
    end

    -- 执行测试
    run(method, ctx.files, ctx.config, moduleRunner)
end

return export
