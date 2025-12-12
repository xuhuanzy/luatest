local stringFormat = string.format
local type = type
local tostring = tostring
local pairs = pairs
local tableInsert = table.insert
local tableSort = table.sort
local tableConcat = table.concat
local mathMin = math.min

---@namespace Luatest

---@export
local export = {}

---@readonly
local DEFAULT_OPTIONS = {
    maxDepth = 2147483647,
    maxWidth = 2147483647,
}

local function formatKey(key)
    if type(key) == "string" then
        return key
    end
    return stringFormat("[%s]", tostring(key))
end

local function keyPriority(key)
    local keyType = type(key)
    if keyType == "string" then
        return 1
    elseif keyType == "number" then
        return 2
    elseif keyType == "boolean" then
        return 3
    end
    return 4
end

local function keyComparator(a, b)
    local priorityA = keyPriority(a)
    local priorityB = keyPriority(b)
    if priorityA ~= priorityB then
        return priorityA < priorityB
    end

    local typeA = type(a)
    if typeA == "string" or typeA == "number" then
        return a < b
    elseif typeA == "boolean" then
        return a and not b
    end
    return tostring(a) < tostring(b)
end

---@param value any
---@param options PrettyFormatOptions
---@param seen table<any, boolean>
---@param depth integer
---@return string
local function formatValue(value, options, seen, depth)
    local valueType = type(value)
    if valueType == "table" then
        if seen[value] then
            return stringFormat("[Circular %s]", tostring(value))
        end
        if depth > options.maxDepth then
            return stringFormat("{... %s}", tostring(value))
        end

        seen[value] = true
        local keys = {}
        for key in pairs(value) do
            tableInsert(keys, key)
        end
        tableSort(keys, keyComparator)

        local parts = {}
        local limit = mathMin(#keys, options.maxWidth)
        for index = 1, limit do
            local key = keys[index]
            parts[#parts + 1] = stringFormat("%s = %s", formatKey(key),
                formatValue(value[key], options, seen, depth + 1))
        end
        if #keys > options.maxWidth then
            parts[#parts + 1] = "..."
        end

        seen[value] = nil
        return "{" .. tableConcat(parts, ", ") .. "}"
    elseif valueType == "string" then
        return stringFormat("%q", value)
    end

    return tostring(value)
end


--- 将任意值转换为紧凑的单行字符串
---@param value any
---@param options? PrettyFormatOptions
---@return string
function export.format(value, options)
    options = options or {
        maxDepth = DEFAULT_OPTIONS.maxDepth,
        maxWidth = DEFAULT_OPTIONS.maxWidth,
    }
    return formatValue(value, options, {}, 1)
end

return export
