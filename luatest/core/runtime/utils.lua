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

return export
