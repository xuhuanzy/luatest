---@namespace Luatest


local export = {}

---@class Class
---@field __name string
---@field package __super? Class
---@field package __index any
---@field super fun<Super>(obj: table, ...: ConstructorParameters<Super>...)
---@field new fun(...: ConstructorParameters<self>...): self

---@type table<string, Class>
local classes = {}

---@param class Class
---@param obj table
---@param ... any
local function runInitDefault(class, obj, ...)
    local init = rawget(class, "__init")
    if type(init) == "function" then
        init(obj, ...)
        return
    end

    ---@diagnostic disable-next-line: assign-type-mismatch
    local superClass = rawget(class, "__super")
    if superClass then
        runInitDefault(superClass, obj, ...)
    end
end

---@param name string
---@return Class
local function resolveClass(name)
    local class = classes[name]
    if not class then
        error(("class %q not found"):format(name), 3)
    end
    return class
end

---@param nameOrClass string|Class
---@return Class
local function normalizeClass(nameOrClass)
    if type(nameOrClass) == "string" then
        return resolveClass(nameOrClass)
    end
    return nameOrClass
end

-- 定义一个类
---@generic T, Super
---@[constructor("__init", "Luatest.Class")]
---@param name `T` 类名
---@param super? `Super` | Class 父类
---@return Class
function export.class(name, super)
    if classes[name] then
        error(("class %q already exists"):format(name), 2)
    end

    local superClass = super and normalizeClass(super) or nil

    ---@diagnostic disable-next-line: missing-fields
    ---@type Class
    local class = {
        __name = name,
        __super = superClass,
    }

    class.__index = class

    if superClass then
        setmetatable(class, { __index = superClass })
    end

    -- 调用父类构造
    ---@param obj table
    ---@param ... any
    function class.super(obj, ...)
        if not superClass then
            error(("class %q has no super"):format(name), 2)
        end
        runInitDefault(superClass, obj, ...)
    end

    -- 创建实例并调用构造函数
    function class.new(...)
        ---@type table
        local obj = setmetatable({ __class__ = name }, class)
        runInitDefault(class, obj, ...)
        return obj
    end

    classes[name] = class
    return class
end

-- 实例化一个类
---@generic T
---@param name `T`|T 类名
---@param ... ConstructorParameters<T>... 构造函数参数
---@return T
function export.new(name, ...)
    local class = normalizeClass(name)
    ---@diagnostic disable-next-line: param-type-mismatch
    return class.new(...)
end

-- 获取一个类
---@param name string
---@return Class
function export.get(name)
    return resolveClass(name)
end

return export
