#!/usr/bin/env lua
---@namespace Luatest

local core = require("luatest.core")
local bootstrap = require("luatest.core.bootstrap-state")
local fs = require("luatest.core.utils.fs")

---@export namespace
local export = {}

---@param out file
local function printUsage(out)
    out:write([[
luatest - Lua 测试框架（原型）

用法:
  luatest [选项] [targets...]

说明:
  - targets 支持：文件 / 目录 / glob（可混用）。
  - 如果未提供 targets，则使用 include/exclude 进行项目级测试文件发现。
  - watch 模式永远不会实现（不支持 --watch）。

选项:
  -r, --root <path>          项目根目录（默认：当前工作目录）
  -c, --config <path>        配置文件路径（默认：<root>/luatest.config.lua）
  -i, --include <glob>       添加一个 include glob（可重复）
  -x, --exclude <glob>       添加一个 exclude glob（可重复）
      --reporter <name>      reporter（default|summary 或自定义 module），可重复
  -h, --help                 显示帮助
  -v, --version              显示版本
]])
end

---@param message string
local function eprintln(message)
    io.stderr:write(message .. "\n")
end

---@param path string
---@return string
local function dirname(path)
    path = tostring(path or ""):gsub("\\", "/")
    local dir = path:match("^(.*)/[^/]*$") or ""
    if dir == "" then
        if path:sub(1, 1) == "/" then
            return "/"
        end
        return "."
    end
    if dir:match("^%a:$") then
        dir = dir .. "/"
    end
    return dir
end

---@class CliParseResult
---@field help boolean?
---@field version boolean?
---@field root string?
---@field configFile string?
---@field include string[]?
---@field exclude string[]?
---@field reporters string[]?
---@field targets string[]?

---@param argv string[]?
---@return CliParseResult?, string? -- result, error
function export.parse(argv)
    argv = argv or {}

    ---@type CliParseResult
    local result = {
        help = false,
        version = false,
        include = {},
        exclude = {},
        reporters = {},
        targets = {},
    }

    local i = 1
    while i <= #argv do
        local a = argv[i]

        if a == "--" then
            for j = i + 1, #argv do
                result.targets[#result.targets + 1] = argv[j]
            end
            break
        end

        if a == "-h" or a == "--help" then
            result.help = true
            return result, nil
        end
        if a == "-v" or a == "--version" then
            result.version = true
            return result, nil
        end

        if a == "--watch" or a == "-w" then
            return nil, "watch 模式不受支持，并且永远不会实现"
        end

        local function requireValue(flag)
            i = i + 1
            local v = argv[i]
            if type(v) ~= "string" or v == "" then
                return nil, "缺少参数值: " .. flag
            end
            return v, nil
        end

        if a == "-r" or a == "--root" then
            local v, err = requireValue(a)
            if err then
                return nil, err
            end
            result.root = v
        elseif a == "-c" or a == "--config" then
            local v, err = requireValue(a)
            if err then
                return nil, err
            end
            result.configFile = v
        elseif a == "-i" or a == "--include" then
            local v, err = requireValue(a)
            if err then
                return nil, err
            end
            result.include[#result.include + 1] = v
        elseif a == "-x" or a == "--exclude" then
            local v, err = requireValue(a)
            if err then
                return nil, err
            end
            result.exclude[#result.exclude + 1] = v
        elseif a == "--reporter" then
            local v, err = requireValue(a)
            if err then
                return nil, err
            end
            result.reporters[#result.reporters + 1] = v
        elseif type(a) == "string" and a:sub(1, 1) == "-" then
            return nil, "未知选项: " .. a
        else
            result.targets[#result.targets + 1] = a
        end

        i = i + 1
    end

    if result.include and #result.include == 0 then
        result.include = nil
    end
    if result.exclude and #result.exclude == 0 then
        result.exclude = nil
    end
    if result.reporters and #result.reporters == 0 then
        result.reporters = nil
    end
    if result.targets and #result.targets == 0 then
        result.targets = nil
    end

    return result, nil
end

---@param argv string[]?
---@return integer
function export.main(argv)
    local parsed, err = export.parse(argv)
    if not parsed then
        eprintln(err or "解析命令行参数失败")
        printUsage(io.stderr)
        return 1
    end

    if parsed.help then
        printUsage(io.stdout)
        return 0
    end

    if parsed.version then
        print("luatest (dev)")
        return 0
    end

    local cwd = fs.getCwd()

    local root = parsed.root
    if type(root) == "string" and root ~= "" and not fs.isAbsolutePath(root) then
        root = fs.toAbsolutePath(cwd, root)
    end

    local configFile = parsed.configFile
    if type(configFile) == "string" and configFile ~= "" then
        if root and not fs.isAbsolutePath(configFile) then
            configFile = fs.toAbsolutePath(root, configFile)
        elseif not fs.isAbsolutePath(configFile) then
            configFile = fs.toAbsolutePath(cwd, configFile)
        end
        if not root then
            root = dirname(configFile)
            if root == "." then
                root = cwd
            end
        end
    end

    local overrides = {}
    if parsed.reporters ~= nil then
        overrides.reporters = parsed.reporters
    end

    bootstrap.setCliMode(true)
    local result = core.run({
        cwd = cwd,
        root = root,
        configFile = configFile,
        targets = parsed.targets,
        include = parsed.include,
        exclude = parsed.exclude,
        configOverrides = overrides,
    })

    return (result and result.exitCode) or 1
end

---@return boolean
local function isMainScript()
    if type(arg) ~= "table" or type(arg[0]) ~= "string" or arg[0] == "" then
        return false
    end

    local cwd = fs.getCwd()
    local src = debug.getinfo(1, "S").source or ""
    src = tostring(src):gsub("^@", "")

    local function normalize(p)
        p = tostring(p or "")
        if p == "" then
            return ""
        end
        if not fs.isAbsolutePath(p) then
            p = fs.toAbsolutePath(cwd, p)
        end
        p = fs.toPosixPath(p)
        if fs.isWindows then
            p = p:lower()
        end
        return p
    end

    local a0 = normalize(arg[0])
    local s0 = normalize(src)
    if a0 ~= "" and s0 ~= "" and a0 == s0 then
        return true
    end

    local function basename(p)
        p = tostring(p or ""):gsub("\\", "/")
        return p:match("([^/]+)$") or p
    end

    return basename(arg[0]) == basename(src)
end

-- If required as a module, do not auto-run.
if isMainScript() then
    os.exit(export.main(arg))
end

return export
