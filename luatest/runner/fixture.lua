---@namespace Luatest

---@export namespace
local export = {}

---@param runner Runner
---@param fn function
---@param testContext? TestContext
---@return fun(hookContext?: TestContext)
function export.withFixtures(runner, fn, testContext)
    ---@param hookContext? TestContext
    return function(hookContext)
        local context = hookContext or testContext
        fn(context)
    end
end

return export
