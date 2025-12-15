local ModuleRunner = require("luatest.core.runtime.moduleRunner.moduleRunner")
local LuatestModuleEvaluator = require("luatest.core.runtime.moduleRunner.moduleEvaluator")
---@namespace Luatest

---@class ContextModuleRunnerOptions
---@field evaluatedModules EvaluatedModules 已加载的模块

---@export namespace
---@param options ContextModuleRunnerOptions
---@return ModuleRunner
local function startModuleRunner(options)
    local evaluator = LuatestModuleEvaluator.new({
        evaluatedModules = options.evaluatedModules
    })

    local runner = ModuleRunner.new({
        evaluatedModules = options.evaluatedModules,
        evaluator = evaluator
    })
    return runner
end

return startModuleRunner
