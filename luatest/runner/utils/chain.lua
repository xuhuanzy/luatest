---@namespace Luatest

local meta = {}

-- 创建链式对象
---@param context table 当前上下文
---@param keySet table 可链式的键集合
---@param fn any 可被执行的对象/函数
---@return table @ 链式对象
local function create(context, keySet, fn)
    local chain = {
        context = context,
        keySet = keySet,
        fn = fn,
    }
    -- 设置元表
    setmetatable(chain, meta)
    return chain
end

meta.__index = function(self, key)
    if self.keySet[key] then
        -- 创建新的上下文并复制当前上下文
        local oldContext = self.context
        local newContext = {}
        for k, v in pairs(oldContext) do
            newContext[k] = v
        end
        newContext[key] = true

        -- 返回新的链式对象
        return create(newContext, self.keySet, self.fn)
    end
    return rawget(self, key)
end

meta.__call = function(self, ...)
    return self.fn(self.context, ...)
end

function meta:mergeContext(ctx)
    for k, v in pairs(ctx) do
        self.context[k] = v
    end
end

---创建可链式调用的函数
---@param keys string[] 可链式的键列表
---@param fn any 可被执行的对象/函数
---@return any @ 返回可链式调用的函数
local function createChainable(keys, fn)
    local keySet = {}
    for _, k in ipairs(keys) do
        keySet[k] = true
    end

    local chain = create({}, keySet, fn)
    return chain
end

---@export namespace
return createChainable
