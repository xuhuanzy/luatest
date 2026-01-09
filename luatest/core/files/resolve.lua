---@namespace Luatest

local fs = require("luatest.core.utils.fs")
local glob = require("luatest.core.files.glob")
local scan = require("luatest.core.files.scan")

---@export namespace
local export = {}

---@class ResolveFilesError
---@field code string
---@field message string

---@class ResolveFilesResult
---@field ok boolean
---@field files? string[]
---@field errors? ResolveFilesError[]

---@param rootPosix string
---@param filePosix string
---@return string
local function toRelativePosix(rootPosix, filePosix)
    local root = rootPosix:gsub("/+$", "")
    local file = filePosix
    local rootCmp = root
    local fileCmp = file
    if fs.isWindows then
        rootCmp = root:lower()
        fileCmp = file:lower()
    end
    if fileCmp:sub(1, #rootCmp) == rootCmp then
        local rest = file:sub(#root + 1)
        if rest:sub(1, 1) == "/" then
            rest = rest:sub(2)
        end
        return rest
    end
    return file
end

---@param patterns string[]
---@param relPosix string
---@return boolean
local function matchesAny(patterns, relPosix)
    for _, p in ipairs(patterns) do
        if glob.match(p, relPosix) then
            return true
        end
    end
    return false
end

---@param root string
---@param rawPatterns any
---@return string[]
local function normalizePatterns(root, rawPatterns)
    local list = {}
    if type(rawPatterns) == "string" then
        list = { rawPatterns }
    elseif type(rawPatterns) == "table" then
        for _, v in ipairs(rawPatterns) do
            if type(v) == "string" and v ~= "" then
                list[#list + 1] = v
            end
        end
    end

    -- normalize to posix, relative to root
    local out = {}
    for _, p in ipairs(list) do
        p = fs.toPosixPath(p)
        if p:sub(1, 2) == "./" then
            p = p:sub(3)
        end
        out[#out + 1] = p
    end
    return out
end

---@class ResolveFilesOptions
---@field root string
---@field files? string[] -- explicit file list (bypass discovery)
---@field targets? string[] -- CLI positional: files/dirs/globs
---@field include? string[]|string
---@field exclude? string[]|string

---@param message string
---@return ResolveFilesError
local function resolveError(message)
    return {
        code = "LUATEST_FILES_RESOLVE",
        message = message,
    }
end

---@param path string
---@return boolean
local function containsGlobMagic(path)
    return type(path) == "string" and (path:find("*", 1, true) ~= nil or path:find("?", 1, true) ~= nil)
end

---@param dir string
---@param pattern string
---@return string
local function joinPosix(dir, pattern)
    dir = fs.toPosixPath(dir or "")
    if dir:sub(1, 2) == "./" then
        dir = dir:sub(3)
    end
    dir = dir:gsub("/+$", "")
    if dir == "" or dir == "." then
        return pattern
    end
    return dir .. "/" .. pattern
end

---@param root string
---@param patterns string[]
---@param exclude string[]
---@return string[]
local function resolveByPatterns(root, patterns, exclude)
    if #patterns == 0 then
        return {}
    end

    local fast = scan.listFilesByGlobs(root, patterns, exclude)
    if type(fast) == "table" then
        return fast
    end

    local rootPosix = fs.toPosixPath(root)
    local all = scan.listFilesRecursive(root)
    local matched = {}
    for _, abs in ipairs(all) do
        local absPosix = fs.toPosixPath(abs)
        local relPosix = toRelativePosix(rootPosix, absPosix)
        if matchesAny(patterns, relPosix) and not matchesAny(exclude, relPosix) then
            matched[#matched + 1] = abs
        end
    end
    return matched
end

---@param options ResolveFilesOptions
---@return ResolveFilesResult
function export.resolve(options)
    options = options or {}
    local root = options.root or fs.getCwd()
    if type(root) ~= "string" or root == "" then
        root = fs.getCwd()
    end
    if not fs.isAbsolutePath(root) then
        root = fs.toAbsolutePath(fs.getCwd(), root)
    end

    local rootPosix = fs.toPosixPath(root)

    -- explicit file list wins
    if type(options.files) == "table" and options.files[1] ~= nil then
        local errors = {}
        local out = {}
        for _, p in ipairs(options.files) do
            if type(p) == "string" and p ~= "" then
                local abs = fs.toAbsolutePath(root, p)
                if not abs:match("%.lua$") then
                    errors[#errors + 1] = resolveError("Invalid test file (expected .lua): " .. abs)
                elseif not fs.fileExists(abs) then
                    errors[#errors + 1] = resolveError("Test file not found: " .. abs)
                else
                    out[#out + 1] = abs
                end
            end
        end
        if errors[1] then
            return { ok = false, errors = errors }
        end
        table.sort(out)
        return { ok = true, files = out }
    end

    local include = normalizePatterns(root, options.include)
    local exclude = normalizePatterns(root, options.exclude)

    -- targets: files/dirs/globs (CLI positional)
    if type(options.targets) == "table" and options.targets[1] ~= nil then
        local errors = {}
        local explicitFiles = {}
        local patterns = {}

        for _, t in ipairs(options.targets) do
            if type(t) == "string" and t ~= "" then
                if containsGlobMagic(t) then
                    local absPatternPosix = fs.toPosixPath(fs.toAbsolutePath(root, t))
                    local rel = toRelativePosix(rootPosix, absPatternPosix)
                    if rel == absPatternPosix and fs.isAbsolutePath(absPatternPosix) then
                        errors[#errors + 1] = resolveError("Glob pattern must be under root: " .. absPatternPosix)
                    else
                        if rel:sub(1, 2) == "./" then
                            rel = rel:sub(3)
                        end
                        patterns[#patterns + 1] = rel
                    end
                else
                    local abs = fs.toAbsolutePath(root, t)
                    if fs.fileExists(abs) then
                        explicitFiles[#explicitFiles + 1] = abs
                    elseif t:match("%.lua$") then
                        errors[#errors + 1] = resolveError("Test file not found: " .. abs)
                    else
                        -- treat as directory-like target: prefix base include patterns
                        local absDirPosix = fs.toPosixPath(abs)
                        local relDir = toRelativePosix(rootPosix, absDirPosix)
                        if relDir == absDirPosix and fs.isAbsolutePath(absDirPosix) then
                            errors[#errors + 1] = resolveError("Target directory must be under root: " .. absDirPosix)
                        else
                            if relDir:sub(1, 2) == "./" then
                                relDir = relDir:sub(3)
                            end
                        end
                        for _, base in ipairs(include) do
                            patterns[#patterns + 1] = joinPosix(relDir, base)
                        end
                    end
                end
            end
        end

        if errors[1] then
            return { ok = false, errors = errors }
        end

        local discovered = resolveByPatterns(root, patterns, exclude)
        local uniq = {}
        local out = {}
        for _, p in ipairs(explicitFiles) do
            if type(p) == "string" and p ~= "" and not uniq[p] then
                uniq[p] = true
                out[#out + 1] = p
            end
        end
        for _, p in ipairs(discovered) do
            if type(p) == "string" and p ~= "" and not uniq[p] then
                uniq[p] = true
                out[#out + 1] = p
            end
        end
        table.sort(out)
        return { ok = true, files = out }
    end

    if #include == 0 then
        return { ok = true, files = {} }
    end

    local matched = resolveByPatterns(root, include, exclude)
    local uniq = {}
    local out = {}
    for _, p in ipairs(matched) do
        if type(p) == "string" and p ~= "" and not uniq[p] then
            uniq[p] = true
            out[#out + 1] = p
        end
    end

    table.sort(out)
    return { ok = true, files = out }
end

return export
