---@namespace Luatest

local export = {}

local isWindows = package.config:sub(1, 1) == "\\"
export.isWindows = isWindows

---@param s string?
---@return string?
local function trimRight(s)
    if type(s) ~= "string" then
        return nil
    end
    return (s:gsub("%s+$", ""))
end

---@return string
function export.getCwd()
    local cmd = isWindows and "cd" or "pwd"
    local ok, handle = pcall(io.popen, cmd)
    if not ok or not handle then
        return "."
    end
    local okRead, out = pcall(function ()
        ---@diagnostic disable-next-line: need-check-nil
        return handle:read("*a")
    end)
    pcall(function ()
        ---@diagnostic disable-next-line: need-check-nil
        handle:close()
    end)
    if not okRead then
        return "."
    end
    return trimRight(out) or "."
end

---@param path string
---@return boolean
function export.fileExists(path)
    if type(path) ~= "string" or path == "" then
        return false
    end
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

---@param path string
---@return string
function export.readFile(path)
    local f, err = io.open(path, "rb")
    if not f then
        error(err or ("failed to open file: " .. tostring(path)), 2)
    end
    local content = f:read("*a")
    f:close()
    return content
end

---@param path string
---@param content string
function export.writeFile(path, content)
    local f, err = io.open(path, "wb")
    if not f then
        error(err or ("failed to write file: " .. tostring(path)), 2)
    end
    f:write(content)
    f:close()
end

---@param path string
---@return string
function export.toPosixPath(path)
    if type(path) ~= "string" then
        return tostring(path)
    end
    ---@diagnostic disable-next-line: incomplete-signature-doc, redundant-return-value
    return path:gsub("\\", "/")
end

---@param a string
---@param b string
---@return string
local function join2(a, b)
    if a == "" then
        return b
    end
    if b == "" then
        return a
    end
    local sep = isWindows and "\\" or "/"
    local left = a
    local right = b
    if left:sub(-1) == "/" or left:sub(-1) == "\\" then
        left = left:sub(1, -2)
    end
    if right:sub(1, 1) == "/" or right:sub(1, 1) == "\\" then
        right = right:sub(2)
    end
    return left .. sep .. right
end

---@param ... string
---@return string
function export.joinPath(...)
    local parts = { ... }
    local out = ""
    for _, p in ipairs(parts) do
        if type(p) == "string" and p ~= "" then
            out = join2(out, p)
        end
    end
    if out == "" then
        return "."
    end
    return out
end

---@param path string
---@return boolean
function export.isAbsolutePath(path)
    if type(path) ~= "string" or path == "" then
        return false
    end
    if isWindows then
        if path:match("^%a:[/\\]") then
            return true
        end
        if path:sub(1, 2) == "\\\\" then
            return true
        end
        return false
    end
    return path:sub(1, 1) == "/"
end

---@param root string
---@param path string
---@return string
function export.toAbsolutePath(root, path)
    if export.isAbsolutePath(path) then
        return path
    end
    return export.joinPath(root, path)
end

return export
