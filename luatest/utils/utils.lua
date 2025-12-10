---@namespace Luatest

---@export namespace
local exprot = {}

--- 合并多个表到目标表, 然后返回目标表.
---
--- target 表中已存在的键不会被覆盖. 合并表的顺序是后者的值会覆盖前者的值.
---@param target table 目标表, 其中已有的键不会被覆盖
---@param ... table 要合并的表, 后者的值会覆盖前者的值
---@return table target 合并后的表
local function defaultsTable(target, ...)
    local args = { ... }
    -- 反转遍历顺序, 使后者优先级高于前者
    for i = #args, 1, -1 do
        for k, v in pairs(args[i]) do
            if target[k] == nil then
                target[k] = v
            end
        end
    end
    return target
end
exprot.defaultsTable = defaultsTable

--- 选择值.
--- 
--- 如果第一个值存在(即不为`nil`), 则返回第一个值, 否则返回第二个值
---@generic T, U
---@param v1 T
---@param ... U...
---@return T | U
local function selectValue(v1, ...)
    if v1 ~= nil then
        return v1
    end
    return selectValue(...)
end
exprot.selectValue = selectValue

return exprot
