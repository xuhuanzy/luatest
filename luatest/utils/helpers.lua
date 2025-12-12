local type = type
local debugGetmetatable = debug.getmetatable
local debugSetmetatable = debug.setmetatable
local next = next

---@namespace Luatest

---@export namespace
local export = {}

export.NOOP = function() end


-- 合并多个表到目标表, 然后返回目标表.
--
-- target 表中已存在的键不会被覆盖. 合并表的顺序是后者的值会覆盖前者的值.
---@param target table 目标表, 其中已有的键不会被覆盖
---@param ... table 要合并的表, 后者的值会覆盖前者的值
---@return table target 合并后的表
local function mergeDefaults(target, ...)
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
export.mergeDefaults = mergeDefaults

-- 选择值.
--
-- 如果第一个值存在(即不为`nil`), 则返回第一个值, 否则返回第二个值
---@generic T, U
---@param v1 T
---@param ... U...
---@return T | U
local function selectValue(v1, ...)
    if v1 ~= nil then
        return v1
    end
    if ... == nil then
        return nil
    end
    return selectValue(...)
end
export.selectValue = selectValue


-- 深拷贝. 会处理元表.
---@generic T
---@param source T
---@param deepMate boolean? 是否深拷贝元表
---@param mark table?
---@return T
local function deepCopy(source, deepMate, mark)
    if type(source) ~= "table" then return source end
    local copy = {}

    mark = mark or {}
    if mark[source] then return mark[source] end
    mark[source] = copy

    for k, v in pairs(source) do
        copy[k] = deepCopy(v, deepMate, mark)
    end

    if deepMate then
        debugSetmetatable(copy, deepCopy(debugGetmetatable(source), deepMate, mark))
    else
        -- 设置其元表指向原表的元表
        debugSetmetatable(copy, debugGetmetatable(source))
    end
    return copy
end
export.deepCopy = deepCopy


-- 检查目标是否有tostring方法
---@param object any
---@return boolean
function export.hasToString(object)
    return type(object) == "string" or type(rawget(debugGetmetatable(object) or {}, "__tostring")) == "function"
end

--- 深度比较两个表格是否相等. 会处理元表.
---@param t1 table 表格1
---@param t2 table 表格2
---@param ignoreMeta boolean? 是否忽略元表
---@param pairCache table? 已比较的表对缓存
---@return boolean @ 是否相等
local function deepCompare(t1, t2, ignoreMeta, pairCache)
    -- 非表格类型可以直接进行比较
    if type(t1) ~= 'table' or type(t2) ~= 'table' then
        return t1 == t2
    end
    -- 如果两个表的引用相等, 则直接返回 true
    if rawequal(t1, t2) then return true end
    -- 如果两个表的元表相等, 且元表中定义了 __eq 方法, 则使用该方法进行比较, 除非忽略元表
    if not ignoreMeta then
        local mt1 = debugGetmetatable(t1)
        local mt2 = debugGetmetatable(t2)
        if mt1 and mt1 == mt2 and mt1.__eq then
            return t1 == t2
        end
    end

    -- 使用表对缓存避免无限递归
    pairCache = pairCache or {}
    local seen = pairCache[t1]
    if seen then
        if seen[t2] then
            return true
        end
    else
        seen = {}
        pairCache[t1] = seen
    end
    seen[t2] = true

    for k1, v1 in next, t1 do
        local v2 = t2[k1]
        if v2 == nil then
            return false
        end
        if not deepCompare(v1, v2, ignoreMeta, pairCache) then
            return false
        end
    end
    for k2, _ in next, t2 do
        -- 检查每个元素是否有t1的对应项, 实际比较已经在上面的循环中完成
        if t1[k2] == nil then return false end
    end

    return true
end
export.deepCompare = deepCompare

return export
