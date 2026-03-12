---@namespace Luatest

local deepCopy = require("luatest.utils.helpers").deepCopy
local defaults = require("luatest.core.defaults")
local fs = require("luatest.core.utils.fs")

---@export namespace
local export = {}

---@class LuatestConfigError
---@field code string
---@field message string
---@field path string
---@field expected string
---@field actual string
---@field source string

---@param path string
---@param expected string
---@param actual any
---@param source string
---@param message? string
---@return LuatestConfigError
local function configError(path, expected, actual, source, message)
    return {
        code = "LUATEST_CONFIG_INVALID",
        message = message or
        string.format("Invalid config field '%s': expected %s, got %s", path, expected, type(actual)),
        path = path,
        expected = expected,
        actual = type(actual),
        source = source,
    }
end

---@param path string
---@param source string
---@param message string
---@return LuatestConfigError
local function loadError(path, source, message)
    return {
        code = "LUATEST_CONFIG_LOAD",
        message = message,
        path = path,
        expected = "valid lua chunk returning table",
        actual = "error",
        source = source,
    }
end

---@param path string
---@return table|nil, LuatestConfigError?
local function loadRootConfig(path)
    local env = setmetatable({}, { __index = _G })
    local chunk, err = loadfile(path, "t", env)
    if not chunk then
        return nil, loadError("rootConfig", "rootConfig", tostring(err))
    end
    local ok, result = pcall(chunk)
    if not ok then
        return nil, loadError("rootConfig", "rootConfig", tostring(result))
    end
    if result == nil then
        return {}, nil
    end
    if type(result) ~= "table" then
        return nil, configError("rootConfig", "table", result, "rootConfig", "root config file must return a table")
    end
    return result, nil
end

---@param t table
---@return boolean
local function isArray(t)
    if type(t) ~= "table" then
        return false
    end
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
            return false
        end
        if k > n then
            ---@diagnostic disable-next-line: assign-type-mismatch
            n = k
        end
    end
    for i = 1, n do
        if rawget(t, i) == nil then
            return false
        end
    end
    return true
end

---@param path string
---@param key any
---@return string
local function childPath(path, key)
    if type(key) == "string" and key:match("^[%a_][%w_]*$") then
        return path == "" and key or (path .. "." .. key)
    end
    return path .. "[" .. tostring(key) .. "]"
end

---@param dst table
---@param src table
---@param sources table<string, string>
---@param path string
---@param sourceName string
local function mergeInto(dst, src, sources, path, sourceName)
    for k, v in pairs(src) do
        local p = childPath(path, k)
        if type(v) == "table" and type(dst[k]) == "table" and not isArray(v) and not isArray(dst[k]) then
            mergeInto(dst[k], v, sources, p, sourceName)
        else
            dst[k] = deepCopy(v)
            sources[p] = sourceName
        end
    end
end

---@param path string
---@return string?  -- nil when ok
local function validateHookOrder(path)
    if path == "stack" or path == "list" then
        return nil
    end
    return "must be 'stack' or 'list'"
end

---@param config table
---@param sources table<string, string>
---@return LuatestConfigError[]?
local function validateConfig(config, sources)
    ---@type LuatestConfigError[]
    local errors = {}

    local function expectType(path, value, expected, extraMessage)
        if expected == "boolean" then
            if type(value) ~= "boolean" then
                errors[#errors + 1] = configError(path, expected, value, sources[path] or "unknown", extraMessage)
            end
            return
        end
        if expected == "number" then
            if type(value) ~= "number" then
                errors[#errors + 1] = configError(path, expected, value, sources[path] or "unknown", extraMessage)
            end
            return
        end
        if expected == "string" then
            if type(value) ~= "string" then
                errors[#errors + 1] = configError(path, expected, value, sources[path] or "unknown", extraMessage)
            end
            return
        end
        if expected == "table" then
            if type(value) ~= "table" then
                errors[#errors + 1] = configError(path, expected, value, sources[path] or "unknown", extraMessage)
            end
            return
        end
    end

    -- required by runner/runtime
    expectType("root", config.root, "string")
    if config.name ~= nil then
        expectType("name", config.name, "string")
    end
    expectType("retry", config.retry, "number")
    expectType("testTimeout", config.testTimeout, "number")
    if config.testNamePattern ~= nil then
        expectType("testNamePattern", config.testNamePattern, "string")
    end
    if config.includeTaskLocation ~= nil then
        expectType("includeTaskLocation", config.includeTaskLocation, "boolean")
    end
    if config.passWithNoTests ~= nil then
        expectType("passWithNoTests", config.passWithNoTests, "boolean")
    end
    if config.allowOnly ~= nil then
        expectType("allowOnly", config.allowOnly, "boolean")
    end

    -- core/runtime
    expectType("isolate", config.isolate, "boolean")
    expectType("windowed", config.windowed, "boolean")
    if config.clearScreen ~= nil then
        expectType("clearScreen", config.clearScreen, "boolean")
    end
    if config.mockReset ~= nil then
        expectType("mockReset", config.mockReset, "boolean")
    end
    if config.clearMocks ~= nil then
        expectType("clearMocks", config.clearMocks, "boolean")
    end
    if config.restoreMocks ~= nil then
        expectType("restoreMocks", config.restoreMocks, "boolean")
    end
    if config.unstubGlobals ~= nil then
        expectType("unstubGlobals", config.unstubGlobals, "boolean")
    end
    if config.bail ~= nil then
        expectType("bail", config.bail, "number")
        if type(config.bail) == "number" then
            if config.bail <= 0 or math.floor(config.bail) ~= config.bail then
                errors[#errors + 1] = configError("bail", "positive integer", config.bail, sources["bail"] or "unknown")
            end
        end
    end
    if config.logHeapUsage ~= nil then
        expectType("logHeapUsage", config.logHeapUsage, "number")
    end

    if config.reporters ~= nil then
        expectType("reporters", config.reporters, "table")
    end

    -- sequence
    expectType("sequence", config.sequence, "table")
    if type(config.sequence) == "table" then
        if config.sequence.shuffle ~= nil then
            expectType("sequence.shuffle", config.sequence.shuffle, "boolean")
        end
        expectType("sequence.seed", config.sequence.seed, "number")
        expectType("sequence.hooks", config.sequence.hooks, "string")
        if type(config.sequence.hooks) == "string" then
            local msg = validateHookOrder(config.sequence.hooks)
            if msg then
                errors[#errors + 1] = configError("sequence.hooks", "stack|list", config.sequence.hooks,
                    sources["sequence.hooks"] or "unknown", msg)
            end
        end
    end

    -- discovery patterns
    if config.include ~= nil and type(config.include) ~= "string" then
        expectType("include", config.include, "table")
    end
    if config.exclude ~= nil and type(config.exclude) ~= "string" then
        expectType("exclude", config.exclude, "table")
    end

    if errors[1] then
        return errors
    end
    return nil
end

---@param list any
---@return string[]
local function normalizeStringList(list)
    if type(list) == "string" then
        return { list }
    end
    if type(list) ~= "table" then
        return {}
    end
    local out = {}
    for _, v in ipairs(list) do
        if type(v) == "string" and v ~= "" then
            out[#out + 1] = v
        end
    end
    return out
end

---@param config table
---@param root string
local function normalizeConfig(config, root)
    config.root = root

    config.retry = config.retry or 0
    config.testTimeout = config.testTimeout or 5000
    if config.includeTaskLocation == nil then
        config.includeTaskLocation = false
    end
    if config.passWithNoTests == nil then
        config.passWithNoTests = false
    end
    if config.allowOnly == nil then
        config.allowOnly = false
    end

    if config.sequence == nil or type(config.sequence) ~= "table" then
        config.sequence = {}
    end
    if config.sequence.shuffle == nil then
        config.sequence.shuffle = false
    end
    if config.sequence.seed == nil then
        config.sequence.seed = 0
    end
    if config.sequence.hooks == nil then
        config.sequence.hooks = "stack"
    end

    if config.isolate == nil then
        config.isolate = true
    end
    if config.windowed == nil then
        config.windowed = true
    end
    if config.clearScreen == nil then
        config.clearScreen = false
    end

    if config.reporters == nil then
        config.reporters = { "default" }
    end

    config.include = normalizeStringList(config.include)
    config.exclude = normalizeStringList(config.exclude)
end

---@class ResolveConfigOptions
---@field cwd? string
---@field root? string
---@field cliOverrides? table
---@field configOverrides? table

---@class ResolveConfigResult
---@field ok boolean
---@field root string
---@field rootConfigPath string
---@field config? table
---@field errors? LuatestConfigError[]
---@field sources? table<string,string>

---@param options ResolveConfigOptions?
---@return ResolveConfigResult
function export.resolve(options)
    options = options or {}

    local cwd = options.cwd or fs.getCwd()
    if type(cwd) ~= "string" or cwd == "" then
        cwd = fs.getCwd()
    end
    local root = options.root or cwd
    if type(root) ~= "string" or root == "" then
        root = cwd
    end
    if not fs.isAbsolutePath(root) then
        root = fs.toAbsolutePath(cwd, root)
    end

    local rootConfigPath = fs.joinPath(root, "luatest.config.lua")

    local runtimeOverrides = options.cliOverrides
    if type(runtimeOverrides) ~= "table" and type(options.configOverrides) == "table" then
        runtimeOverrides = options.configOverrides
    end

    ---@type table
    local rootConfig = {}
    if fs.fileExists(rootConfigPath) then
        local cfg, err = loadRootConfig(rootConfigPath)
        if err then
            return { ok = false, root = root, rootConfigPath = rootConfigPath, errors = { err } }
        end
        rootConfig = cfg or {}
    end

    local resolved = deepCopy(defaults)
    ---@type table<string,string>
    local sources = {}

    mergeInto(resolved, rootConfig, sources, "", "rootConfig")
    if type(runtimeOverrides) == "table" then
        mergeInto(resolved, runtimeOverrides, sources, "", "cliOverrides")
    end

    -- root is always taken from run options (not from root config file) to keep IO predictable
    resolved.root = root
    sources["root"] = options.root and "options.root" or "cwd"

    local validationErrors = validateConfig(resolved, sources)
    if validationErrors then
        return {
            ok = false,
            root = root,
            rootConfigPath = rootConfigPath,
            config = resolved,
            errors = validationErrors,
            sources = sources,
        }
    end

    normalizeConfig(resolved, root)

    return {
        ok = true,
        root = root,
        rootConfigPath = rootConfigPath,
        config = resolved,
        sources = sources,
    }
end

return export
