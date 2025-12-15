local isLuatestInternalModule = require("luatest.core.runtime.utils").isLuatestInternalModule
---@namespace Luatest

---@class ModuleEvaluatorOptions
---@field evaluatedModules EvaluatedModules


---@class ModuleEvaluator
---@field runModule fun(self: self, path: string): any 运行模块


---@class LuatestModuleEvaluator: ModuleEvaluator
---@field _evaluatedModules EvaluatedModules
local ModuleEvaluator = {}
---@package
ModuleEvaluator.__index = ModuleEvaluator

---@param options ModuleEvaluatorOptions
---@return ModuleEvaluator
function ModuleEvaluator.new(options)
    ---@type LuatestModuleEvaluator
    local self = setmetatable({}, ModuleEvaluator)
    self._evaluatedModules = options.evaluatedModules
    return self
end

--- 创建隔离的 require 函数
---@param isolatedPackageLoaded table 隔离的 package.loaded 代理表
---@return function
local function createIsolatedRequire(isolatedPackageLoaded)
    local originalRequire = require

    ---@param moduleName string
    ---@return any
    return function(moduleName)
        -- 先检查隔离的 package.loaded
        local cached = isolatedPackageLoaded[moduleName]
        if cached ~= nil then
            return cached
        end

        -- 加载模块
        local result = originalRequire(moduleName)

        -- luatest 内部模块不做额外处理
        if not isLuatestInternalModule(moduleName) then
            -- 将模块存入隔离表
            isolatedPackageLoaded[moduleName] = result
            -- 从全局 package.loaded 移除, 保持隔离
            package.loaded[moduleName] = nil
        end

        return result
    end
end

--- 创建隔离的 package.loaded 代理表
---@param evaluatedModules EvaluatedModules
---@return table
local function createIsolatedPackageLoaded(evaluatedModules)
    local originalLoaded = package.loaded

    local proxy = {}
    setmetatable(proxy, {
        __index = function(_, key)
            -- 优先从隔离缓存获取
            if evaluatedModules[key] ~= nil then
                return evaluatedModules[key]
            end
            return originalLoaded[key]
        end,
        __newindex = function(_, key, value)
            -- luatest 内部模块写入原始 package.loaded
            if isLuatestInternalModule(key) then
                originalLoaded[key] = value
            else
                -- 用户模块写入隔离缓存
                evaluatedModules[key] = value
            end
        end,
        __pairs = function(_)
            -- 合并两个表的迭代
            local merged = {}
            for k, v in pairs(originalLoaded) do
                merged[k] = v
            end
            for k, v in pairs(evaluatedModules) do
                merged[k] = v
            end
            return pairs(merged)
        end,
    })
    return proxy
end

-- 创建隔离的环境
---@param evaluatedModules EvaluatedModules
---@return table
local function createIsolatedEnv(evaluatedModules)
    -- TODO: 我们需要更严格环境隔离

    -- 为每个文件创建独立的环境
    local fileEnv = {}

    -- 先创建隔离的 package.loaded 代理
    local isolatedLoaded = createIsolatedPackageLoaded(evaluatedModules)

    -- 注入隔离的 package 表
    fileEnv.package = setmetatable({
        loaded = isolatedLoaded,
        path = package.path,
        cpath = package.cpath,
    }, { __index = package })

    -- 注入隔离的 require 函数
    fileEnv.require = createIsolatedRequire(isolatedLoaded)
    -- 让 _G 指向 fileEnv 自身
    fileEnv._G = fileEnv

    -- 其他全局变量从真实 _G 继承
    setmetatable(fileEnv, { __index = _G })
    return fileEnv
end

-- 运行模块
---@param path string
---@return any
function ModuleEvaluator:runModule(path)
    local fileEnv = createIsolatedEnv(self._evaluatedModules)
    local file, err = io.open(path, "rb")
    if not file then
        error(err)
    end
    local content = file:read("*a")
    file:close()

    local chunk, err = load(content, "@" .. path, "t", fileEnv)
    if not chunk then
        error(err)
    end

    -- 直接执行
    return chunk()
end

return ModuleEvaluator
