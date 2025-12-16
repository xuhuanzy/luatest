---@namespace Luatest

---@class ModuleRunner
---@field evaluatedModules EvaluatedModules
---@field evaluator ModuleEvaluator
local ModuleRunner = {}
---@package
ModuleRunner.__index = ModuleRunner

---@class ModuleRunnerOptions
---@field evaluatedModules EvaluatedModules
---@field evaluator ModuleEvaluator

---@param options ModuleRunnerOptions
---@return ModuleRunner
function ModuleRunner.new(options)
    ---@type Partial<ModuleRunner>
    local obj = {
        options = options,
        evaluator = options.evaluator,
        evaluatedModules = options.evaluatedModules,
    }
    return setmetatable(obj, ModuleRunner)
end

---@param path string
---@return any
function ModuleRunner:import(path)
    return self.evaluator:runModule(path)
end

function ModuleRunner:resetFileEnv()
    local evaluator = self.evaluator
    if evaluator and evaluator.resetFileEnv then
        evaluator:resetFileEnv()
    end
end

return ModuleRunner
