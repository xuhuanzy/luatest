local isLuatestInternalModule = require("luatest.core.runtime.utils").isLuatestInternalModule
---@namespace Luatest

---@class ModuleEvaluatorOptions
---@field evaluatedModules EvaluatedModules

---@class ModuleEvaluator
---@field evaluatedModules EvaluatedModules
---@field fileEnv? IsolatedEnv
local ModuleEvaluator = {}
---@package
ModuleEvaluator.__index = ModuleEvaluator

---@param options ModuleEvaluatorOptions
---@return ModuleEvaluator
function ModuleEvaluator.new(options)
    ---@type ModuleEvaluator
    local self = setmetatable({}, ModuleEvaluator)
    self.evaluatedModules = options.evaluatedModules or {}
    return self
end

local sharedBuiltinModules = {
    -- Lua 标准库/运行时模块
    ["package"] = true,
    ["coroutine"] = true,
    ["string"] = true,
    ["table"] = true,
    ["math"] = true,
    ["io"] = true,
    ["os"] = true,
    ["debug"] = true,
    ["utf8"] = true,
    ["bit32"] = true,
    ["jit"] = true,
    ["ffi"] = true,
}

---@param moduleName string
---@return boolean
local function isSharedModule(moduleName)
    return isLuatestInternalModule(moduleName) or sharedBuiltinModules[moduleName] == true
end

-- 创建隔离的 require 函数
---@param evaluatedModules EvaluatedModules 用户模块缓存
---@param fileEnv IsolatedEnv 文件环境
---@return function
local function createIsolatedRequire(evaluatedModules, fileEnv)
    local originalRequire = require
    local LOADING = {}

    ---@param moduleName string
    ---@return any
    return function(moduleName)
        local cached = evaluatedModules[moduleName]
        if cached ~= nil then
            if cached == LOADING then
                return true
            end
            return cached
        end
        -- 共享模块使用原始 require
        if isSharedModule(moduleName) then
            return originalRequire(moduleName)
        end

        -- 标记为正在加载
        evaluatedModules[moduleName] = LOADING

        local ok, resultOrErr = pcall(function()
            -- preload
            local preload = fileEnv.package.preload
            if preload then
                local loader = preload[moduleName]
                if loader ~= nil then
                    return loader(moduleName)
                end
            end

            -- Lua 文件
            local path = fileEnv.package.searchpath(moduleName, fileEnv.package.path)
            if path then
                local chunk, err = fileEnv.loadfile(path, "bt")
                if not chunk then
                    error(string.format("error loading module '%s' from file '%s':\n\t%s", moduleName, path, err))
                end
                return chunk(moduleName)
            end

            -- C 模块
            local cpath = fileEnv.package.searchpath(moduleName, fileEnv.package.cpath)
            if cpath then
                local openName = "luaopen_" .. moduleName:gsub("[^%w]", "_")
                local loader, err = fileEnv.package.loadlib(cpath, openName)
                if not loader then
                    error(string.format("error loading module '%s' from file '%s':\n\t%s", moduleName, cpath, err))
                end
                ---@diagnostic disable-next-line: redundant-parameter
                return loader(moduleName)
            end

            error(string.format("module '%s' not found", moduleName))
        end)

        if not ok then
            evaluatedModules[moduleName] = nil
            error(resultOrErr, 2)
        end

        if resultOrErr ~= nil then
            evaluatedModules[moduleName] = resultOrErr
        elseif evaluatedModules[moduleName] == LOADING then
            evaluatedModules[moduleName] = true
        end

        return evaluatedModules[moduleName]
    end
end

-- 创建隔离的 package.loaded 代理表
---@param evaluatedModules EvaluatedModules
---@return table
local function createIsolatedPackageLoaded(evaluatedModules)
    local originalLoaded = package.loaded

    local proxy = {}
    setmetatable(proxy, {
        __index = function(_, key)
            if isSharedModule(key) then
                return originalLoaded[key]
            end
            return evaluatedModules[key]
        end,
        __newindex = function(_, key, value)
            if isSharedModule(key) then
                originalLoaded[key] = value
            else
                evaluatedModules[key] = value
            end
        end,
        __pairs = function(_)
            local merged = {}
            for k, v in pairs(originalLoaded) do
                if isSharedModule(k) then
                    merged[k] = v
                end
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
---@return IsolatedEnv
local function createIsolatedEnv(evaluatedModules)
    local isolatedLoaded = createIsolatedPackageLoaded(evaluatedModules)

    ---@class IsolatedEnv
    local fileEnv = {}

    fileEnv._VERSION = _VERSION
    fileEnv.assert = assert
    fileEnv.error = error
    fileEnv.ipairs = ipairs
    fileEnv.pairs = pairs
    fileEnv.next = next
    fileEnv.pcall = pcall
    fileEnv.xpcall = xpcall
    fileEnv.select = select
    fileEnv.tonumber = tonumber
    fileEnv.tostring = tostring
    fileEnv.type = type
    fileEnv.print = print
    fileEnv.rawequal = rawequal
    fileEnv.rawget = rawget
    fileEnv.rawset = rawset
    fileEnv.getmetatable = getmetatable
    fileEnv.setmetatable = setmetatable
    fileEnv.collectgarbage = collectgarbage
    fileEnv.coroutine = coroutine
    fileEnv.string = string
    fileEnv.table = table
    fileEnv.math = math
    fileEnv.io = io
    fileEnv.os = os
    fileEnv.debug = debug
    fileEnv.utf8 = utf8
    fileEnv.arg = rawget(_G, "arg")
    fileEnv.bit32 = rawget(_G, "bit32")
    fileEnv.jit = rawget(_G, "jit")

    fileEnv._G = fileEnv

    fileEnv.load = function(ld, chunkname, mode, env)
        if env == nil then env = fileEnv end
        return load(ld, chunkname, mode, env)
    end
    fileEnv.loadfile = function(filename, mode, env)
        if env == nil then env = fileEnv end
        return loadfile(filename, mode, env)
    end
    fileEnv.dofile = function(filename)
        local chunk, err = fileEnv.loadfile(filename)
        if not chunk then
            error(err, 2)
        end
        return chunk()
    end

    fileEnv.package = setmetatable({
        loaded = isolatedLoaded,
        preload = package.preload,
        path = package.path,
        cpath = package.cpath,
    }, { __index = package })

    fileEnv.require = createIsolatedRequire(evaluatedModules, fileEnv)
    return fileEnv
end

---@return IsolatedEnv
function ModuleEvaluator:getFileEnv()
    if not self.fileEnv then
        self.fileEnv = createIsolatedEnv(self.evaluatedModules)
    end
    return self.fileEnv
end

function ModuleEvaluator:resetFileEnv()
    self.fileEnv = nil
end

-- 运行模块
---@param path string
---@return any
function ModuleEvaluator:runModule(path)
    local fileEnv = self:getFileEnv()

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

    return chunk()
end

return ModuleEvaluator
