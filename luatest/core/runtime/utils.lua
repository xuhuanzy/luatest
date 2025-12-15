---@namespace Luatest

local NAME_WORKER_STATE = {}

---@export namespace
local export = {}

-- 获取当前工作状态
---@return WorkerGlobalState
function export.getWorkerState()
    local workerState = _G[NAME_WORKER_STATE]
    if not workerState then
        local errorMsg = "Luatest 无法访问其内部状态"
        error(errorMsg)
    end
    return workerState
end

-- 设置工作状态
---@param context table
---@param state WorkerGlobalState
---@return WorkerGlobalState
function export.provideWorkerState(context, state)
    context[NAME_WORKER_STATE] = state
    return state
end

local luatestPrefixes = {
    "luatest",
    "luatest.",
}
-- 判断模块名是否属于 luatest 内部模块
---@param moduleName string
---@return boolean
function export.isLuatestInternalModule(moduleName)
    for _, prefix in ipairs(luatestPrefixes) do
        if moduleName == prefix or moduleName:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

-- 清理用户模块缓存
---@param modules EvaluatedModules
function export.resetModules(modules)
    for k, v in pairs(modules) do
        modules[k] = nil
    end
end

return export
