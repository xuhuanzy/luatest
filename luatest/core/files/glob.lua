---@namespace Luatest

---@export namespace
local export = {}

---@param path string
---@return string[]
local function splitPath(path)
    path = path:gsub("\\", "/")
    local out = {}
    for part in path:gmatch("[^/]+") do
        if part ~= "" and part ~= "." then
            out[#out + 1] = part
        end
    end
    return out
end

---@param globSeg string
---@param text string
---@return boolean
local function matchSegment(globSeg, text)
    if globSeg == "*" then
        return true
    end

    local pattern = "^"
    local i = 1
    while i <= #globSeg do
        local c = globSeg:sub(i, i)
        if c == "*" then
            pattern = pattern .. ".*"
        elseif c == "?" then
            pattern = pattern .. "."
        else
            if c:match("[%^%$%(%)%%%.%[%]%+%-%?]") then
                pattern = pattern .. "%" .. c
            else
                pattern = pattern .. c
            end
        end
        i = i + 1
    end
    pattern = pattern .. "$"
    return text:match(pattern) ~= nil
end

---@param globSegs string[]
---@param pathSegs string[]
---@param gi integer
---@param pi integer
---@return boolean
local function matchSegments(globSegs, pathSegs, gi, pi)
    if gi > #globSegs then
        return pi > #pathSegs
    end

    local g = globSegs[gi]
    if g == "**" then
        -- ** matches zero or more segments
        if gi == #globSegs then
            return true
        end
        for k = pi, #pathSegs + 1 do
            if matchSegments(globSegs, pathSegs, gi + 1, k) then
                return true
            end
        end
        return false
    end

    if pi > #pathSegs then
        return false
    end

    if not matchSegment(g, pathSegs[pi]) then
        return false
    end

    return matchSegments(globSegs, pathSegs, gi + 1, pi + 1)
end

---@param glob string
---@param path string
---@return boolean
function export.match(glob, path)
    if type(glob) ~= "string" or glob == "" then
        return false
    end
    if type(path) ~= "string" or path == "" then
        return false
    end

    local globSegs = splitPath(glob)
    local pathSegs = splitPath(path)
    return matchSegments(globSegs, pathSegs, 1, 1)
end

return export

