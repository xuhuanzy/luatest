---@namespace Luatest

local fs = require("luatest.core.utils.fs")

---@export namespace
local export = {}

---@type boolean?
local rgAvailable

---@param glob string
---@return boolean
local function isRgGlobSafe(glob)
    if type(glob) ~= "string" or glob == "" then
        return false
    end
    local g = glob
    if g:sub(1, 1) == "!" then
        g = g:sub(2)
    end
    -- Our own glob semantics treat [] literally, but ripgrep's --glob may interpret it.
    if g:find("%[") or g:find("%]") then
        return false
    end
    return true
end

---@param cmd string
---@return string[]?
local function runLines(cmd)
    local ok, handle = pcall(io.popen, cmd)
    if not ok or not handle then
        return nil
    end
    local okRead, out = pcall(function()
        ---@diagnostic disable-next-line: need-check-nil
        return handle:read("*a")
    end)
    pcall(function()
        ---@diagnostic disable-next-line: need-check-nil
        handle:close()
    end)
    if not okRead or type(out) ~= "string" then
        return nil
    end
    local lines = {}
    for line in out:gmatch("[^\r\n]+") do
        if line ~= "" then
            lines[#lines + 1] = line
        end
    end
    return lines
end

---@param s string
---@return string
local function psSingleQuote(s)
    return "'" .. s:gsub("'", "''") .. "'"
end

---@param s string
---@return string
local function shSingleQuote(s)
    -- ' -> '\''
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

---@return boolean
local function hasRg()
    if rgAvailable ~= nil then
        return rgAvailable
    end

    local cmd = fs.isWindows and "rg --version 2>nul" or "rg --version 2>/dev/null"
    local lines = runLines(cmd)
    rgAvailable = type(lines) == "table"
        and type(lines[1]) == "string"
        and lines[1]:find("ripgrep", 1, true) ~= nil
    return rgAvailable
end

---@param root string
---@param include string[]
---@param exclude? string[]
---@return string[]? -- nil means "fast path unavailable"
function export.listFilesByGlobs(root, include, exclude)
    exclude = exclude or {}
    if type(root) ~= "string" or root == "" then
        return nil
    end
    if type(include) ~= "table" then
        return nil
    end
    if #include == 0 then
        return {}
    end
    if type(exclude) ~= "table" then
        exclude = {}
    end

    if not hasRg() then
        return nil
    end

    for _, g in ipairs(include) do
        if type(g) == "string" and g:sub(1, 1) == "!" then
            return nil
        end
        if type(g) == "string" and g ~= "" and not isRgGlobSafe(g) then
            return nil
        end
    end
    for _, g in ipairs(exclude) do
        if type(g) == "string" and g ~= "" and not isRgGlobSafe(g) then
            return nil
        end
    end

    local cmd
    if fs.isWindows then
        local parts = {}
        parts[#parts + 1] = 'powershell -NoProfile -NonInteractive -Command "'
        parts[#parts + 1] = "Set-Location -LiteralPath " .. psSingleQuote(root) .. "; "
        parts[#parts + 1] = "rg --files --hidden --no-ignore --path-separator /"
        for _, g in ipairs(include) do
            if type(g) == "string" and g ~= "" then
                parts[#parts + 1] = " --glob " .. psSingleQuote(g)
            end
        end
        for _, g in ipairs(exclude) do
            if type(g) == "string" and g ~= "" then
                local eg = g
                if eg:sub(1, 1) ~= "!" then
                    eg = "!" .. eg
                end
                parts[#parts + 1] = " --glob " .. psSingleQuote(eg)
            end
        end
        parts[#parts + 1] = ' 2>$null"'
        cmd = table.concat(parts)
    else
        local rootQ = root:gsub('"', '\\"')
        local parts = {}
        parts[#parts + 1] = 'cd "' .. rootQ .. '" && rg --files --hidden --no-ignore --path-separator /'
        for _, g in ipairs(include) do
            if type(g) == "string" and g ~= "" then
                parts[#parts + 1] = " --glob " .. shSingleQuote(g)
            end
        end
        for _, g in ipairs(exclude) do
            if type(g) == "string" and g ~= "" then
                local eg = g
                if eg:sub(1, 1) ~= "!" then
                    eg = "!" .. eg
                end
                parts[#parts + 1] = " --glob " .. shSingleQuote(eg)
            end
        end
        parts[#parts + 1] = " 2>/dev/null"
        cmd = table.concat(parts)
    end

    local rel = runLines(cmd)
    if not rel then
        return nil
    end

    local out = {}
    for _, p in ipairs(rel) do
        if type(p) == "string" and p ~= "" then
            local r = p:gsub("^%./", "")
            if r ~= "" and r ~= "." then
                out[#out + 1] = fs.toAbsolutePath(root, r)
            end
        end
    end
    return out
end

---@param root string
---@return string[]
function export.listFilesRecursive(root)
    if type(root) ~= "string" or root == "" then
        return {}
    end

    local cmd
    if fs.isWindows then
        local quoted = psSingleQuote(root)
        cmd = 'powershell -NoProfile -NonInteractive -Command "Get-ChildItem -LiteralPath ' .. quoted .. ' -Recurse -File | ForEach-Object { $_.FullName }"'
    else
        cmd = 'find "' .. root:gsub('"', '\\"') .. '" -type f'
    end

    return runLines(cmd) or {}
end

return export
