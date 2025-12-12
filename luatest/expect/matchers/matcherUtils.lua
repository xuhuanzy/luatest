local colored = require('luatest.utils.colored')
local stringFormat = string.format
local i18n = require("luatest.i18n")
local prettyFormat = require("luatest.utils.display").stringify
local printExpected = require("luatest.utils.diff").printExpected
local type = type
---@namespace Luatest

---@export namespace
local export = {}

local EXPECTED_COLOR = colored.green
local RECEIVED_COLOR = colored.red
local INVERTED_COLOR = colored.inverse
local BOLD_WEIGHT = colored.bold
local DIM_COLOR = colored.dim
export.EXPECTED_COLOR = EXPECTED_COLOR
export.RECEIVED_COLOR = RECEIVED_COLOR
export.INVERTED_COLOR = INVERTED_COLOR
export.BOLD_WEIGHT = BOLD_WEIGHT
export.DIM_COLOR = DIM_COLOR

--- 生成匹配器错误消息
---@param hint string 提示
---@param genericMessage string 通用提示
---@param specificMessage string? 具体提示
---@return string
function export.matcherErrorMessage(hint, genericMessage, specificMessage)
    local message = stringFormat('%s\n\n%s: %s', hint, BOLD_WEIGHT('Matcher error'), genericMessage)
    if type(specificMessage) == 'string' then
        message = stringFormat('%s\n\n%s', message, specificMessage)
    end
    return message
end

--- 生成匹配器提示
---@param matcherName string 匹配器名称
---@param received? string 实际值名称, 默认为 "received"
---@param expected? string 预期值名称, 默认为 "expected"
---@param options MatcherHintOptions? 选项
---@return string
function export.matcherHint(matcherName, received, expected, options)
    received = received or 'received'
    expected = expected or 'expected'
    local comment = options and options.comment or ''
    local isNot = options and options.isNot or false
    local secondArgument = options and options.secondArgument or ''
    local expectedColor = options and options.expectedColor or EXPECTED_COLOR
    local receivedColor = options and options.receivedColor or RECEIVED_COLOR
    local secondArgumentColor = options and options.secondArgumentColor or EXPECTED_COLOR

    ---@cast expectedColor fun(arg: string): string
    ---@cast receivedColor fun(arg: string): string
    ---@cast secondArgumentColor fun(arg: string): string

    local hint = ''
    -- 暗淡的字符串
    local dimString = 'expect'
    if received ~= '' then
        hint = hint .. DIM_COLOR(stringFormat('%s(', dimString)) .. receivedColor(received);
        dimString = ')';
    end
    if isNot then
        hint = hint .. DIM_COLOR(stringFormat('%s.', dimString)) .. 'not_'
        dimString = ''
    end
    -- 匹配器名称
    hint = hint .. DIM_COLOR(stringFormat('%s:', dimString)) .. matcherName
    dimString = ''
    if expected == "" then
        dimString = dimString .. '()'
    else
        hint = hint .. DIM_COLOR(stringFormat('%s(', dimString)) .. expectedColor(expected)
        if secondArgument ~= "" then
            hint = hint .. DIM_COLOR(', ') .. secondArgumentColor(secondArgument)
        end
        dimString = ')'
    end
    -- 注释
    if comment ~= "" then
        dimString = dimString .. stringFormat(' -- %s', comment)
    end
    -- 最终提示
    hint = hint .. DIM_COLOR(dimString)
    return hint
end

-- 将值压缩成单行文本, 表使用紧凑花括号, 并携带深度/宽度/长度限制以避免爆长
---@param value any
---@param maxDepth? integer
---@param maxWidth? integer
---@return string
local function stringifyInline(value, maxDepth, maxWidth)
    return prettyFormat(value, maxDepth, maxWidth)
end

--- 打印值及其类型, 用于构建详细错误信息
---@param name string 标签
---@param value any 值
---@param printer? fun(value: any): string 打印函数
---@return string
function export.printWithType(name, value, printer)
    local printerFn = printer or stringifyInline
    return stringFormat('%s has type: %s\n%s has value: %s', name, type(value), name, printerFn(value))
end

--- 确保预期长度为非负整数
---@param expected any
---@param matcherName string
---@param options MatcherHintOptions?
function export.ensureExpectedIsNonNegativeInteger(expected, matcherName, options)
    if type(expected) ~= "number" or expected < 0 or math.type(expected) ~= "integer" then
        error(export.matcherErrorMessage(
            export.matcherHint(matcherName, nil, 'expected', options),
            i18n("预期值(expected)必须为非负整数"),
            export.printWithType('Expected', expected, printExpected)
        ))
    end
end

---@class MatcherUtils.PathInfo
---@field traversedPath any[] 已遍历的路径
---@field lastTraversedObject any 最后遍历到的对象
---@field hasEndProp boolean 是否存在最终路径属性
---@field value any 最终路径属性对应的值

--- 获取表对象的路径信息
---@param object any
---@param propertyPath any[]
---@return MatcherUtils.PathInfo
function export.getPath(object, propertyPath)
    if type(propertyPath) ~= "table" then
        error(i18n("propertyPath must be table"))
    end

    local traversedPath = {}
    local current = object
    local lastTraversedObject = object
    local hasEndProp = false
    local value = nil

    for index, segment in ipairs(propertyPath) do
        if type(current) ~= "table" then
            break
        end

        lastTraversedObject = current

        local key = segment
        current = current[key]
        if current == nil then
            break
        end

        traversedPath[index] = segment
        if index == #propertyPath then
            hasEndProp = true
            value = current
        end
    end

    return {
        traversedPath = traversedPath,
        lastTraversedObject = lastTraversedObject,
        hasEndProp = hasEndProp,
        value = value,
    }
end

return export
