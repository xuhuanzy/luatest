---创建可链式调用的函数
---@generic T
---@param keys string[] 可链式的键列表
---@param fn fun(context: table, ...: any): T 最终执行的函数，第一个参数为累积的上下文
---@return any @ 返回可链式调用的函数
local function createChainable(keys, fn)
    -- 创建链式对象
    ---@param context table 当前上下文
    ---@return table @ 链式对象
    local function create(context)
        local chain = {}

        -- 设置元表
        setmetatable(chain, {
            __call = function(self, ...)
                return fn(context, ...)
            end,

            __index = function(self, key)
                -- 检查是否是合法的链式键
                for _, k in ipairs(keys) do
                    if k == key then
                        -- 创建新的上下文并复制当前上下文
                        local newContext = {}
                        for k, v in pairs(context) do
                            newContext[k] = v
                        end
                        newContext[key] = true

                        -- 返回新的链式对象
                        return create(newContext)
                    end
                end
                -- 如果不是链式键, 返回 nil
                return nil
            end
        })
        return chain
    end

    -- 返回初始链
    return create({})
end

return createChainable
