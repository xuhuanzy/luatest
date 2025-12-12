---@namespace Luatest

local stringFormat = string.format
local deepCompare = require("luatest.utils.helpers").deepCompare
local colored = require('luatest.utils.colored')
local i18n = require("luatest.i18n")
local normalizeDiffOptions = require("luatest.utils.diff.normalizeDiffOptions")
local stringify = require("luatest.utils.display").stringify
local tostring = tostring
local type = type
local tableInsert = table.insert
local tableSort = table.sort
local pairs = pairs
local ipairs = ipairs
local tableConcat = table.concat
local stringRep = string.rep

local EXPECTED_COLOR = colored.green
local RECEIVED_COLOR = colored.red
local DIM_COLOR = colored.dim

local MAX_DIFF_STRING_LENGTH = 20000 ---@readonly 最大差异字符串长度
local DEFAULT_MAX_DEPTH = 20 ---@readonly 默认最大递归深度

---@export namespace
local export = {}

local SPACE_SYMBOL = '·'

--- 替换字符串末尾的空格为中间点符号
---@param text string 输入字符串
---@return string @替换后的字符串
local function replaceTrailingSpaces(text)
    local result = text:gsub("[\t ]+$", function(spaces)
        return SPACE_SYMBOL:rep(#spaces)
    end)
    return result
end

export.printReceived = function(object)
    return RECEIVED_COLOR(replaceTrailingSpaces(stringify(object)))
end

export.printExpected = function(value)
    return EXPECTED_COLOR(replaceTrailingSpaces(stringify(value)))
end
local printReceived = export.printReceived
local printExpected = export.printExpected


--- 生成标签打印函数, 用于对齐多列文本
---@param ... string 字符串参数列表
---@return fun(string: string): string @返回格式化函数
function export.getLabelPrinter(...)
    local strings = { ... }

    -- 找到最大长度
    local maxLength = 0
    for _, str in ipairs(strings) do
        if #str > maxLength then
            maxLength = #str
        end
    end

    return function(inputString)
        local padding = maxLength - #inputString
        local spaces = stringRep(' ', padding)
        return stringFormat('%s: %s', inputString, spaces)
    end
end

local getLabelPrinter = export.getLabelPrinter

--- 渲染差异行
---@param marker string|nil -- "+" / "-" / nil
---@param indent integer
---@param text string
---@return string
local function renderLine(marker, indent, text)
    local prefix = marker and (marker .. " ") or "  "
    local colorize = marker == "+" and RECEIVED_COLOR
        or marker == "-" and EXPECTED_COLOR
        or DIM_COLOR
    return colorize(prefix .. stringRep("  ", indent) .. text)
end

local function formatKey(key)
    local ty = type(key)
    if ty == "string" then
        if key:match("^[%a_][%w_]*$") then
            return key
        end
        return stringFormat("[%q]", key)
    elseif ty == "number" then
        return stringFormat("[%s]", tostring(key))
    end
    return stringFormat("[%s]", tostring(key))
end

local function formatPrimitive(value)
    local ty = type(value)
    if ty == "string" then
        return stringFormat("%q", value)
    elseif ty == "number" or ty == "boolean" or ty == "nil" then
        return tostring(value)
    end
    return stringFormat("<%s>", ty)
end

local function compareKeys(a, b)
    return tostring(a) < tostring(b)
end

local function sortedKeys(obj)
    local keys = {}
    for k, _ in pairs(obj) do
        tableInsert(keys, k)
    end
    tableSort(keys, compareKeys)
    return keys
end

local function applyMarker(marker, minusCount, plusCount)
    if marker == "-" then
        minusCount = minusCount + 1
    elseif marker == "+" then
        plusCount = plusCount + 1
    end
    return minusCount, plusCount
end

---@param entries table[] 差异行表
---@param marker string|nil 差异标记
---@param indent integer 缩进级别
---@param prefix string 前缀字符串
---@param value any 值
---@param includeComma boolean? 是否包含逗号
---@param visited table<any, boolean>? 已访问表
---@return integer minusCount, integer plusCount
local function appendValueLines(entries, marker, indent, prefix, value, includeComma, visited)
    local suffix = includeComma and "," or ""
    local minusCount = 0
    local plusCount = 0
    local valueType = type(value)
    if valueType ~= "table" then
        tableInsert(entries, {
            marker = marker,
            indent = indent,
            text = prefix .. formatPrimitive(value) .. suffix,
        })
        minusCount, plusCount = applyMarker(marker, minusCount, plusCount)
        return minusCount, plusCount
    end

    -- 展开表为逐行结构，标记每个字段的 +/-，保证行数统计准确，同时处理循环引用
    visited = visited or {}
    if visited[value] then
        tableInsert(entries, {
            marker = marker,
            indent = indent,
            text = prefix .. "[Circular]" .. suffix,
        })
        minusCount, plusCount = applyMarker(marker, minusCount, plusCount)
        return minusCount, plusCount
    end

    visited[value] = true
    tableInsert(entries, { marker = marker, indent = indent, text = prefix .. "{" })
    minusCount, plusCount = applyMarker(marker, minusCount, plusCount)
    local keys = sortedKeys(value)
    for _, key in ipairs(keys) do
        local childMinus, childPlus = appendValueLines(
            entries,
            marker,
            indent + 1,
            formatKey(key) .. ": ",
            value[key],
            true,
            visited
        )
        minusCount = minusCount + childMinus
        plusCount = plusCount + childPlus
    end
    tableInsert(entries, { marker = marker, indent = indent, text = "}" .. suffix })
    minusCount, plusCount = applyMarker(marker, minusCount, plusCount)
    visited[value] = nil
    return minusCount, plusCount
end

--- 构建对象差异
---@param expected any
---@param received any
---@param depth integer
---@param maxDepth integer? 最大递归深度
---@return table[], integer, integer
local function buildDiff(expected, received, depth, maxDepth)
    depth = depth or 0
    maxDepth = maxDepth or DEFAULT_MAX_DEPTH
    local entries = {}
    local minusCount, plusCount = 0, 0

    -- 超过最大深度时停止递归
    if depth > maxDepth then
        tableInsert(entries, { marker = nil, indent = depth, text = "..." })
        return entries, 0, 0
    end

    if type(expected) ~= "table" or type(received) ~= "table" then
        local minus, plus = appendValueLines(entries, "-", depth, "", expected, false)
        minusCount = minusCount + minus
        plusCount = plusCount + plus
        minus, plus = appendValueLines(entries, "+", depth, "", received, false)
        minusCount = minusCount + minus
        plusCount = plusCount + plus
        return entries, minusCount, plusCount
    end

    tableInsert(entries, { marker = nil, indent = depth, text = "{" })

    local keys = {}
    local seenKeys = {}
    for k, _ in pairs(expected) do
        keys[#keys + 1] = k
        seenKeys[k] = true
    end
    for k, _ in pairs(received) do
        if not seenKeys[k] then
            keys[#keys + 1] = k
        end
    end
    tableSort(keys, compareKeys)

    for _, key in ipairs(keys) do
        local expVal = expected[key]
        local recVal = received[key]
        local linePrefix = formatKey(key) .. " = "
        if expVal == nil then
            local minus, plus = appendValueLines(entries, "+", depth + 1, linePrefix, recVal, true)
            minusCount = minusCount + minus
            plusCount = plusCount + plus
        elseif recVal == nil then
            local minus, plus = appendValueLines(entries, "-", depth + 1, linePrefix, expVal, true)
            minusCount = minusCount + minus
            plusCount = plusCount + plus
        elseif expVal == recVal then
            appendValueLines(entries, nil, depth + 1, linePrefix, expVal, true)
        else
            local same = deepCompare(expVal, recVal, true)
            if same then
                appendValueLines(entries, nil, depth + 1, linePrefix, expVal, true)
            elseif type(expVal) == "table" and type(recVal) == "table" then
                local childEntries, childMinus, childPlus = buildDiff(expVal, recVal, depth + 1, maxDepth)
                if #childEntries > 0 then
                    childEntries[1].text = linePrefix .. childEntries[1].text
                    ---@diagnostic disable-next-line: need-check-nil
                    childEntries[#childEntries].text = childEntries[#childEntries].text .. ","
                    for _, entry in ipairs(childEntries) do
                        tableInsert(entries, entry)
                    end
                    minusCount = minusCount + childMinus
                    plusCount = plusCount + childPlus
                end
            else
                local minus, plus = appendValueLines(entries, "-", depth + 1, linePrefix, expVal, true)
                minusCount = minusCount + minus
                plusCount = plusCount + plus
                minus, plus = appendValueLines(entries, "+", depth + 1, linePrefix, recVal, true)
                minusCount = minusCount + minus
                plusCount = plusCount + plus
            end
        end
    end

    tableInsert(entries, { marker = nil, indent = depth, text = "}" })
    return entries, minusCount, plusCount
end

--- 生成一个字符串用于突出两个值之间的差异.
---@param a any 期望值
---@param b any 接收值
---@param options DiffOptions? 差异选项
---@return string
function export.diff(a, b, options)
    options = options or {}
    local maxDepth = options.maxDepth or DEFAULT_MAX_DEPTH
    local diffEntries, minusCount, plusCount = buildDiff(a, b, 0, maxDepth)
    if minusCount == 0 and plusCount == 0 then
        return DIM_COLOR(i18n("比较值在视觉上没有差异"))
    end
    local lines = {
        EXPECTED_COLOR(stringFormat("- Expected  - %d", minusCount)),
        RECEIVED_COLOR(stringFormat("+ Received  + %d", plusCount)),
        "",
    }
    for _, entry in ipairs(diffEntries) do
        tableInsert(lines, renderLine(entry.marker, entry.indent, entry.text))
    end

    return tableConcat(lines, "\n")
end

--- 打印差异或字符串化
---@param received any 实际接受值
---@param expected any 期望值
---@param options? DiffOptions 差异选项
---@return string
function export.printDiffOrStringify(received, expected, options)
    -- 如果两个值相等, 则无需展示差异
    if expected == received then
        return ""
    end
    options = normalizeDiffOptions(options)
    -- TODO: 对于均为字符串的情况, 我们需要区分出两个字符串的具体差异

    -- 只要有一侧不是表, 则不需要详尽的差异展示
    if not (type(expected) == "table") or not (type(received) == "table") then
        local printLabel = getLabelPrinter(options.aAnnotation, options.bAnnotation)
        local expectedLine = printLabel(options.aAnnotation) .. printExpected(expected)
        local receivedLine = printLabel(options.bAnnotation) .. printReceived(received)
        return expectedLine .. "\n" .. receivedLine
    end

    local difference = export.diff(expected, received)

    if difference and difference:find("- " .. options.aAnnotation, 1, true) and difference:find("+ " .. options.bAnnotation, 1, true) then
        return difference
    end

    local printLabel = getLabelPrinter(options.aAnnotation, options.bAnnotation)


    local expectedLine = printLabel(options.aAnnotation) .. printExpected(expected)
    local receivedLine = printLabel(options.bAnnotation) .. (stringify(expected) == stringify(received)
        and i18n("序列化为相同字符串")
        or printReceived(received))

    return expectedLine .. "\n" .. receivedLine
end

return export
