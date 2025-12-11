---@namespace Luatest

---@export namespace
local export = {}


-- 合并hooks
---@param baseHooks SuiteHooks
---@param hooks SuiteHooks
---@return SuiteHooks
local function mergeHooks(baseHooks, hooks)
    for key, hookList in pairs(hooks) do
        for _, hook in ipairs(hookList) do
            table.insert(baseHooks[key], hook)
        end
    end
    return baseHooks
end

return export
