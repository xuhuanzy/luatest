---@namespace Luatest

---@export namespace
local export = {}

---@param value any
---@return boolean?
local function parseBoolean(value)
    if value == nil then
        return nil
    end
    value = tostring(value):lower()
    if value == "1" or value == "true" or value == "yes" or value == "on" then
        return true
    end
    if value == "0" or value == "false" or value == "no" or value == "off" then
        return false
    end
    return nil
end

---@param value any
---@return integer?
local function parseInteger(value)
    local n = tonumber(value)
    if type(n) ~= "number" or n ~= n or n <= 0 then
        return nil
    end
    return math.floor(n)
end

---@param cmd string
---@return string?
local function runCommand(cmd)
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

    out = out:gsub("%s+$", "")
    if out == "" then
        return nil
    end

    return out
end

---@class TTYDetectResult
---@field isTTY boolean
---@field reason string

---@param getenv? fun(name: string): string?
---@return TTYDetectResult
function export.detect(getenv)
    getenv = getenv or os.getenv

    local forced = parseBoolean(getenv("FORCE_TTY"))
    if forced ~= nil then
        return { isTTY = forced, reason = "FORCE_TTY" }
    end

    if getenv("CI") ~= nil then
        return { isTTY = false, reason = "CI" }
    end

    local term = getenv("TERM")
    if type(term) == "string" and term:lower() == "dumb" then
        return { isTTY = false, reason = "TERM=dumb" }
    end

    return { isTTY = true, reason = "default" }
end

---@param getenv? fun(name: string): string?
---@return boolean
function export.isTTY(getenv)
    return export.detect(getenv).isTTY
end

---@param getenv? fun(name: string): string?
---@return boolean
function export.isNonTTY(getenv)
    return not export.isTTY(getenv)
end

---@class ColumnsDetectResult
---@field columns integer
---@field reason string

local isWindows = package.config:sub(1, 1) == "\\"
local columnsCacheTtlMs = 5000
local columnsCacheAt = -math.huge
local columnsCacheValue = 80
local columnsCacheReason = "default"

---@return integer
local function nowMs()
    ---@diagnostic disable-next-line: return-type-mismatch
    return os.clock() * 1000
end

---@param getenv? fun(name: string): string?
---@return ColumnsDetectResult
function export.detectColumns(getenv)
    getenv = getenv or os.getenv

    local forced = parseInteger(getenv("FORCE_COLUMNS"))
    if forced then
        return { columns = forced, reason = "FORCE_COLUMNS" }
    end

    local fromEnv = parseInteger(getenv("COLUMNS"))
    if fromEnv then
        return { columns = fromEnv, reason = "COLUMNS" }
    end

    local now = nowMs()
    if getenv == os.getenv and now - columnsCacheAt < columnsCacheTtlMs then
        return { columns = columnsCacheValue, reason = columnsCacheReason }
    end

    local columns = nil
    local reason = nil

    if export.isNonTTY(getenv) then
        columns = 80
        reason = "nonTTY-default"
    elseif isWindows then
        local out = runCommand('powershell -NoProfile -NonInteractive -Command "$Host.UI.RawUI.WindowSize.Width" 2>nul')
        columns = parseInteger(out)
        reason = columns and "powershell" or nil
    else
        local out = runCommand("tput cols 2>/dev/null")
        columns = parseInteger(out)
        reason = columns and "tput" or nil

        if not columns then
            out = runCommand("stty size < /dev/tty 2>/dev/null")
            local colsText = out and out:match("^%s*%d+%s+(%d+)%s*$") or nil
            columns = parseInteger(colsText)
            reason = columns and "stty" or nil
        end
    end

    if not columns then
        columns = 80
        reason = "default"
    end

    if getenv == os.getenv then
        columnsCacheAt = now
        columnsCacheValue = columns
        ---@diagnostic disable-next-line: assign-type-mismatch
        columnsCacheReason = reason
    end

    ---@diagnostic disable-next-line: assign-type-mismatch
    return { columns = columns, reason = reason }
end

---@param getenv? fun(name: string): string?
---@return integer
function export.getColumns(getenv)
    return export.detectColumns(getenv).columns
end

return export
