---@namespace Luatest

---@class StateManager
---@field idMap table<string, Task> # 记录了所有任务
local StateManager = {}

StateManager.__index = StateManager ---@package

---@return StateManager
function StateManager.new()
    ---@type Partial<StateManager>
    local self = {
        idMap = {},
    }
    return setmetatable(self, StateManager)
end

---@param task Task
function StateManager:updateId(task)

end

---@param files File[]
function StateManager:collectFiles(files)

end

---@param packs TaskResultPack[]
function StateManager:updateTasks(packs)

end

return StateManager
