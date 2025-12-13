---@namespace Luatest

local select = select


---@export namespace
local util = {}

--- 内部使用的标志位键
---@alias InternalFlagKey
---| "message" 自定义错误消息, 将会附加到断言错误头部
---| "negate" 取反标记
---| "luatest-test" 当前测试


--- 设置或获取对象的标志位.
---
--- 如果提供了值, 则设置该标志位为指定值; 否则返回该标志位的值.
---@param obj table 目标对象
---@param key InternalFlagKey|string 标志位键名
---@param ... any 标志位值, 仅支持传入单个值.
---@return any
local function flag(obj, key, ...)
    local flags = obj.__flags
    if not flags then
        flags = {}
        obj.__flags = flags
    end
    if select("#", ...) > 0 then
        local value = select(1, ...)
        flags[key] = value
    else
        return flags[key]
    end
end
util.flag = flag

--- 将一个方法添加到表
---@param ctx table 目标表
---@param name string 方法名
---@param fn function 方法实现
function util.addMethod(ctx, name, fn)
    ctx[name] = fn
end

return util
