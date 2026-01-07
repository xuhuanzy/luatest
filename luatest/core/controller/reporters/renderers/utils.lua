---@namespace Luatest

local colored = require("luatest.utils.colored")
local tty = require("luatest.utils.tty")
local figures = require("luatest.core.controller.reporters.renderers.figures")
local stripVTControlCharacters =
    require("luatest.core.controller.reporters.renderers.windowedRenderer").stripVTControlCharacters

local c = colored

---@export namespace
local export = {}

export.pointer = c.yellow(figures.F_POINTER)
export.skipped = c.dim(c.gray(figures.F_DOWN))
export.benchmarkPass = c.green(figures.F_DOT)
export.testPass = c.green(figures.F_CHECK)
export.taskFail = c.red(figures.F_CROSS)
export.suiteFail = c.red(figures.F_POINTER)
export.pending = c.gray("·")
export.separator = c.dim(" > ")

local labelDefaultColors = { c.bgYellow, c.bgCyan, c.bgGreen, c.bgMagenta }

---@param text string
---@return string
local function capitalize(text)
    if text == "" then
        return text
    end
    return text:sub(1, 1):upper() .. text:sub(2)
end

---@param str string
---@param prefix string
---@return boolean
local function startsWith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

---@param delta? integer
---@return integer
local function getCols(delta)
    local length = tty.getColumns()
    return math.max(length + (delta or 0), 0)
end

---@param message string
---@param columns? integer
---@return string
function export.errorBanner(message, columns)
    return export.divider(c.bold(c.bgRed(" " .. message .. " ")), nil, nil, c.red, columns)
end

---@param text? string
---@param left? integer?
---@param right? integer?
---@param color? Formatter
---@param columns? integer
---@return string
function export.divider(text, left, right, color, columns)
    local cols = columns or getCols()
    ---@type fun(input: any): string
    local fmt = color or function(input)
        return tostring(input)
    end

    if text then
        local textLength = #stripVTControlCharacters(text)
        if left == nil and right ~= nil then
            left = cols - textLength - right
        else
            left = left or math.floor((cols - textLength) / 2)
            right = cols - textLength - left
        end
        left = math.max(0, left)
        right = math.max(0, right)
        return fmt(string.rep(figures.F_LONG_DASH, left)) .. text .. fmt(string.rep(figures.F_LONG_DASH, right))
    end

    return string.rep(figures.F_LONG_DASH, cols)
end

---@param path string
---@return string
local function slash(path)
    return (path:gsub("\\", "/"))
end

---@param path string
---@return boolean
local function isAbsolute(path)
    path = path or ""
    return startsWith(path, "/") or path:match("^%a:[/\\]") ~= nil or startsWith(path, "\\\\")
end

---@param path string
---@return string
local function dirname(path)
    path = slash(path)
    local dir = path:match("^(.*)/[^/]*$") or ""
    if dir == "" then
        return "."
    end
    return dir
end

---@param path string
---@param ext? string
---@return string
local function basename(path, ext)
    path = slash(path)
    local base = path:match("([^/]+)$") or path
    if ext and ext ~= "" and base:sub(- #ext) == ext then
        return base:sub(1, #base - #ext)
    end
    return base
end

---@param root string
---@param path string
---@return string
local function relative(root, path)
    root = slash(root or "")
    path = slash(path or "")
    if root ~= "" then
        if root:sub(-1) == "/" then
            root = root:sub(1, -2)
        end
        if path:sub(1, #root):lower() == root:lower() then
            local rest = path:sub(#root + 1)
            if rest:sub(1, 1) == "/" then
                rest = rest:sub(2)
            end
            if rest == "" then
                return "."
            end
            return rest
        end
    end
    return path
end

---@param root string
---@param path string
---@return string
function export.formatTestPath(root, path)
    if isAbsolute(path) then
        path = relative(root, path)
    end

    path = slash(path)
    local dir = dirname(path)

    local ext = path:match("(%.[Ss][Pp][Ee][Cc]%.[^/]+)$")
        or path:match("(%.[Tt][Ee][Ss][Tt]%.[^/]+)$")
        or path:match("(%.[^/]+)$")
        or ""

    local base = basename(path, ext)

    return slash(c.dim(dir .. "/") .. c.bold(base)) .. c.dim(ext)
end

---@param rootDir string
---@param snapshots table
---@return string[]
function export.renderSnapshotSummary(rootDir, snapshots)
    local summary = {}
    snapshots = snapshots or {}

    if snapshots.added and snapshots.added ~= 0 then
        summary[#summary + 1] = c.bold(c.green(tostring(snapshots.added) .. " written"))
    end
    if snapshots.unmatched and snapshots.unmatched ~= 0 then
        summary[#summary + 1] = c.bold(c.red(tostring(snapshots.unmatched) .. " failed"))
    end
    if snapshots.updated and snapshots.updated ~= 0 then
        summary[#summary + 1] = c.bold(c.green(tostring(snapshots.updated) .. " updated "))
    end

    if snapshots.filesRemoved and snapshots.filesRemoved ~= 0 then
        if snapshots.didUpdate then
            summary[#summary + 1] = c.bold(c.green(tostring(snapshots.filesRemoved) .. " files removed "))
        else
            summary[#summary + 1] = c.bold(c.yellow(tostring(snapshots.filesRemoved) .. " files obsolete "))
        end
    end

    if type(snapshots.filesRemovedList) == "table" and snapshots.filesRemovedList[1] then
        local head = snapshots.filesRemovedList[1]
        summary[#summary + 1] = c.gray(figures.F_DOWN_RIGHT) .. " " .. export.formatTestPath(rootDir, head)
        for i = 2, #snapshots.filesRemovedList do
            local key = snapshots.filesRemovedList[i]
            summary[#summary + 1] = "  " .. c.gray(figures.F_DOT) .. " " .. export.formatTestPath(rootDir, key)
        end
    end

    if snapshots.unchecked and snapshots.unchecked ~= 0 then
        if snapshots.didUpdate then
            summary[#summary + 1] = c.bold(c.green(tostring(snapshots.unchecked) .. " removed"))
        else
            summary[#summary + 1] = c.bold(c.yellow(tostring(snapshots.unchecked) .. " obsolete"))
        end

        if type(snapshots.uncheckedKeysByFile) == "table" then
            for _, uncheckedFile in ipairs(snapshots.uncheckedKeysByFile) do
                summary[#summary + 1] = c.gray(figures.F_DOWN_RIGHT)
                    .. " "
                    .. export.formatTestPath(rootDir, uncheckedFile.filePath)
                for _, key in ipairs(uncheckedFile.keys or {}) do
                    summary[#summary + 1] = "  " .. c.gray(figures.F_DOT) .. " " .. tostring(key)
                end
            end
        end
    end

    return summary
end

---@param tasks Task[]
---@return integer
function export.countTestErrors(tasks)
    local count = 0
    for _, task in ipairs(tasks or {}) do
        local errors = task and task.result and task.result.errors or nil
        if type(errors) == "table" then
            count = count + #errors
        end
    end
    return count
end

---@param tasks Task[]
---@param name? string
---@param showTotal? boolean
---@return string
function export.getStateString(tasks, name, showTotal)
    name = name or "tests"
    if not tasks or #tasks == 0 then
        return c.dim("no " .. name)
    end

    local passed, failed, skipped, todo = 0, 0, 0, 0
    for _, task in ipairs(tasks) do
        local resultState = task and task.result and task.result.state or nil
        local mode = task and task.mode or nil

        if resultState == "pass" then
            passed = passed + 1
        elseif resultState == "fail" then
            failed = failed + 1
        end

        if mode == "skip" then
            skipped = skipped + 1
        elseif mode == "todo" then
            todo = todo + 1
        end
    end

    local parts = {}
    if failed > 0 then
        parts[#parts + 1] = c.bold(c.red(tostring(failed) .. " failed"))
    end
    if passed > 0 then
        parts[#parts + 1] = c.bold(c.green(tostring(passed) .. " passed"))
    end
    if skipped > 0 then
        parts[#parts + 1] = c.yellow(tostring(skipped) .. " skipped")
    end
    if todo > 0 then
        parts[#parts + 1] = c.gray(tostring(todo) .. " todo")
    end

    local state = table.concat(parts, c.dim(" | "))
    if showTotal ~= false then
        state = state .. c.gray(" (" .. tostring(#tasks) .. ")")
    end

    return state
end

---@param task Task
---@return string
function export.getStateSymbol(task)
    if not task then
        return " "
    end

    if task.mode == "skip" or task.mode == "todo" then
        return export.skipped
    end

    if not task.result then
        return export.pending
    end

    if task.result.state == "run" or task.result.state == "queued" then
        if task.type == "suite" then
            return export.pointer
        end
    end

    if task.result.state == "pass" then
        if task.meta and task.meta.benchmark then
            return export.benchmarkPass
        end
        return export.testPass
    end

    if task.result.state == "fail" then
        if task.type == "suite" then
            return export.suiteFail
        end
        return export.taskFail
    end

    return " "
end

---@param time number
---@return string
function export.duration(time)
    if time < 1 then
        return string.format("%.2f ps", time * 1e3)
    end
    if time < 1e3 then
        return string.format("%.2f ns", time)
    end
    if time < 1e6 then
        return string.format("%.2f µs", time / 1e3)
    end
    if time < 1e9 then
        return string.format("%.2f ms", time / 1e6)
    end
    if time < 1e12 then
        return string.format("%.2f s", time / 1e9)
    end
    if time < 36e11 then
        return string.format("%.2f m", time / 60e9)
    end
    return string.format("%.2f h", time / 36e11)
end

---@param date? number|table
---@return string
function export.formatTimeString(date)
    if type(date) == "table" then
        return os.date("%H:%M:%S", os.time(date))
    end
    if type(date) == "number" then
        return os.date("%H:%M:%S", date)
    end
    return os.date("%H:%M:%S")
end

---@param timeMs number
---@return string
function export.formatTime(timeMs)
    if timeMs > 1000 then
        return string.format("%.2fs", timeMs / 1000)
    end
    return tostring(math.floor(timeMs + 0.5)) .. "ms"
end

---@param project? { name?: string, color?: string }
---@param suffix? string
---@return string
function export.formatProjectName(project, suffix)
    suffix = suffix or " "
    if not project or not project.name or project.name == "" then
        return ""
    end

    if not c.isColorSupported then
        return "|" .. tostring(project.name) .. "|" .. suffix
    end

    local background = nil
    if project.color and project.color ~= "" then
        background = c["bg" .. capitalize(project.color)]
    end

    if not background then
        local index = 0
        for i = 1, #project.name do
            index = index + project.name:byte(i) + (i - 1)
        end
        background = labelDefaultColors[(index % #labelDefaultColors) + 1]
    end

    return c.black(background(" " .. tostring(project.name) .. " ")) .. suffix
end

---@param color "red"|"green"|"blue"|"cyan"|"yellow"
---@param label string
---@param message? string
---@return string
function export.withLabel(color, label, message)
    local bgColor = "bg" .. color:sub(1, 1):upper() .. color:sub(2)
    local bgFormatter = c[bgColor] or function(input)
        return tostring(input)
    end
    local fgFormatter = c[color] or function(input)
        return tostring(input)
    end

    local out = c.bold(bgFormatter(" " .. label .. " "))
    if message and message ~= "" then
        out = out .. " " .. fgFormatter(message)
    end
    return out
end

---@param str string
---@return string
function export.padSummaryTitle(str)
    local padding = 11 - #str
    local prefix = ""
    if padding > 0 then
        prefix = string.rep(" ", padding)
    end
    return c.dim(prefix .. str .. " ")
end

---@param text string
---@param maxLength integer
---@return string
function export.truncateString(text, maxLength)
    local plainText = stripVTControlCharacters(text)
    if #plainText <= maxLength then
        return text
    end
    return plainText:sub(1, maxLength - 1) .. "…"
end

export.stripVTControlCharacters = stripVTControlCharacters

return export
