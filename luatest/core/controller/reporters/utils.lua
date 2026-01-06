---@namespace Luatest

local DefaultReporter = require("luatest.core.controller.reporters.default").DefaultReporter

---@param value any
---@return boolean
local function isReporterInstance(value)
    if type(value) ~= "table" then
        return false
    end

    -- class.lua 的类表不是实例：需要调用 `.new(...)`
    if type(rawget(value, "__name")) == "string"
        and type(rawget(value, "new")) == "function"
        and rawget(value, "__index") == value
    then
        return false
    end

    -- class.lua 的实例会携带 `__class__`
    if rawget(value, "__class__") ~= nil then
        return true
    end

    return type(value.onTaskUpdate) == "function"
        or type(value.onTestRunStart) == "function"
        or type(value.onTestRunEnd) == "function"
        or type(value.onQueued) == "function"
        or type(value.onCollected) == "function"
end

---@param module any
---@param options any
---@return Reporter
local function instantiateReporterModule(module, options)
    if isReporterInstance(module) then
        return module
    end
    if type(module) == "table" and type(module.new) == "function" then
        return module.new(options)
    end
    if type(module) == "function" then
        return module(options)
    end
    error("Custom reporter module must return a reporter instance, a constructor function, or a table with .new(options)", 3)
end

---@type table<string, fun(options?: any): Reporter>
local builtinReporters = {
    default = function(options)
        return DefaultReporter.new(options)
    end,
    summary = function(options)
        options = type(options) == "table" and options or {}
        options.windowed = false
        return DefaultReporter.new(options)
    end,
}

---@param reference any
---@return Reporter
local function resolveReporter(reference)
    -- tuple: { "name", options }
    if type(reference) == "table" and type(reference[1]) == "string" then
        local name = reference[1]
        local options = reference[2]
        local builtin = builtinReporters[name]
        if builtin then
            return builtin(options)
        end
        local mod = require(name)
        return instantiateReporterModule(mod, options)
    end

    -- built-in or custom module path
    if type(reference) == "string" then
        local builtin = builtinReporters[reference]
        if builtin then
            return builtin(nil)
        end
        local mod = require(reference)
        return instantiateReporterModule(mod, nil)
    end

    -- instance
    if isReporterInstance(reference) then
        ---@cast reference Reporter
        return reference
    end

    error("Unsupported reporter reference: " .. type(reference), 2)
end

---@param reporterReferences any[]?
---@return Reporter[]
local function createReporters(reporterReferences)
    if reporterReferences == nil or (type(reporterReferences) == "table" and #reporterReferences == 0) then
        return { builtinReporters.default(nil) }
    end

    local out = {}
    for _, reference in ipairs(reporterReferences) do
        out[#out + 1] = resolveReporter(reference)
    end

    if #out == 0 then
        out[1] = builtinReporters.default(nil)
    end

    return out
end

---@export namespace
return {
    createReporters = createReporters,
    resolveReporter = resolveReporter,
    builtinReporters = builtinReporters,
}
