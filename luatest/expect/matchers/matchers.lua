local i18n = require("luatest.i18n")
local matcherUtils = require("luatest.expect.matchers.matcherUtils")
local matcherHint = matcherUtils.matcherHint
local deepCompare = require("luatest.utils.helpers").deepCompare
local ensureExpectedIsNonNegativeInteger = matcherUtils.ensureExpectedIsNonNegativeInteger
local hasToString = require("luatest.utils.helpers").hasToString
local printDiffOrStringify = require("luatest.utils.diff").printDiffOrStringify
local flag = require("luatest.expect.util").flag
local Assertion = require("luatest.expect.assertion")
local printExpected = require("luatest.utils.diff").printExpected
local printReceived = require("luatest.utils.diff").printReceived
local getLabelPrinter = require("luatest.utils.diff").getLabelPrinter
local printWithType = matcherUtils.printWithType
local matcherErrorMessage = matcherUtils.matcherErrorMessage
local stringFormat = string.format
local type = type
local tableConcat = table.concat

---@namespace Luatest

--- 检查 actual 是否包含 expected 的子集
---@param actual table
---@param expected table
---@return boolean
local function isMatchObject(actual, expected)
    for key, expectedValue in pairs(expected) do
        local actualValue = actual[key]
        if type(expectedValue) == "table" and type(actualValue) == "table" then
            if not isMatchObject(actualValue, expectedValue) then
                return false
            end
        else
            if not deepCompare(actualValue, expectedValue, true) then
                return false
            end
        end
    end
    return true
end

--- 复制 actual 中的子集用于 diff
---@param actual table
---@param expected table
---@return table
local function extractSubset(actual, expected)
    if type(actual) ~= "table" or type(expected) ~= "table" then
        return actual
    end

    local subset = {}
    for key, expectedValue in pairs(expected) do
        subset[key] = extractSubset(actual[key], expectedValue)
    end
    return subset
end

---@param value number
---@return string
local function formatNumber(value)
    if value == math.huge then
        return "Infinity"
    elseif value == -math.huge then
        return "-Infinity"
    elseif value ~= value then
        return "NaN"
    end
    return tostring(value)
end

--- 打印 toBeCloseTo 的差值信息
---@param receivedDiff number
---@param expectedDiff number
---@param precision integer
---@param isNot boolean?
---@return string
local function printCloseTo(receivedDiff, expectedDiff, precision, isNot)
    local receivedDiffString = formatNumber(receivedDiff)

    local expectedDiffString
    if receivedDiffString:find("[eE]") then
        expectedDiffString = stringFormat("%.0e", expectedDiff)
    elseif precision >= 0 and precision < 20 then
        expectedDiffString = stringFormat("%." .. (precision + 1) .. "f", expectedDiff)
    else
        expectedDiffString = formatNumber(expectedDiff)
    end

    local precisionString = formatNumber(precision)
    local prefix = isNot and "    " or ""
    local diffPrefix = isNot and "not " or ""

    local lines = {
        "Expected precision:  " .. prefix .. "  " .. precisionString,
        "Expected difference: " .. diffPrefix .. "< " .. matcherUtils.EXPECTED_COLOR(expectedDiffString),
        "Received difference: " .. prefix .. "  " .. matcherUtils.RECEIVED_COLOR(receivedDiffString),
    }

    return tableConcat(lines, "\n")
end

-- 基本相等匹配器, 使用` == `进行比较
Assertion.addMethod("toBe", function(self, expected)
    local actual = self._obj
    local matcherName = "toBe"
    ---@type MatcherHintOptions
    local options = {
        comment = "a == b",
        isNot = flag(self, "negate"),
    }

    local pass = actual == expected
    local message = pass and function()
        return matcherHint(matcherName, nil, nil, options) ..
            "\n\n" ..
            "Expected: not " .. printExpected(expected)
    end or function()
        return matcherHint(matcherName, nil, nil, options)
            .. "\n\n" ..
            printDiffOrStringify(actual, expected)
    end

    return {
        pass = pass,
        message = message,
    }
end)

-- 检查实际值的类型是否与预期值相等
Assertion.addMethod("toBeTypeOf", function(self, expected)
    local actual = self._obj
    local matcherName = "toBeTypeOf"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }
    local actualType = type(actual)
    return {
        pass = actualType == expected,
        message = function()
            return matcherHint(matcherName, nil, nil, options) ..
                "\n\n" ..
                printDiffOrStringify(actualType, expected)
        end,
    }
end)

-- 检查实际值的类型是否与预期值相等
-- 检查实际值是否为整数
Assertion.addMethod("toBeInteger", function(self)
    local actual = self._obj
    local matcherName = "toBeInteger"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }
    local pass = type(actual) == "number" and math.type(actual) == "integer"
    return {
        pass = pass,
        message = function()
            return matcherHint(matcherName, nil, '', options) ..
                "\n\n" ..
                "Received: " ..
                printReceived(actual)
        end,
    }
end)

-- 检查实际值是否为 nil
Assertion.addMethod("toBeNil", function(self)
    local actual = self._obj
    local matcherName = "toBeNil"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }
    local pass = actual == nil
    return {
        pass = pass,
        message = function()
            return matcherHint(matcherName, nil, '', options) ..
                "\n\n" ..
                "Received: " ..
                printReceived(actual)
        end,
    }
end)

-- 检查实际值是否已定义
Assertion.addMethod("toBeDefined", function(self)
    local actual = self._obj
    local matcherName = "toBeDefined"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }
    local pass = actual ~= nil
    return {
        pass = pass,
        message = function()
            return matcherHint(matcherName, nil, '', options) ..
                "\n\n" ..
                "Received: " ..
                printReceived(actual)
        end,
    }
end)

-- 检查数字是否在给定精度范围内相等
---@param expected number 预期值
---@param precision? integer 精度, 默认值为 `2`
Assertion.addMethod("toBeCloseTo", function(self, expected, precision)
    local actual = self._obj
    local matcherName = "toBeCloseTo"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }
    if precision ~= nil then
        options.secondArgument = "precision"
        options.secondArgumentColor = function(arg)
            return arg
        end
    end

    local decimals ---@type integer
    if precision == nil then
        decimals = 2
    else
        if type(precision) ~= "number" or precision < 0 or precision ~= math.floor(precision) then
            error(matcherErrorMessage(
                matcherHint(matcherName, nil, nil, options),
                matcherUtils.EXPECTED_COLOR("expected") .. " " .. i18n("精度必须是非负整数"),
                printWithType("precision", precision, printExpected)
            ))
        end
        decimals = precision
    end

    local pass = false
    local expectedDiff = 0 ---@type number
    local receivedDiff = 0 ---@type number

    if actual == math.huge and expected == math.huge then
        pass = true
    elseif actual == -math.huge and expected == -math.huge then
        pass = true
    else
        expectedDiff = 0.5 * 10 ^ (-decimals)
        receivedDiff = math.abs(expected - actual)
        pass = receivedDiff < expectedDiff
    end

    local message
    if pass then
        message = function()
            local lines = {
                matcherHint(matcherName, nil, nil, options),
                "",
                "Expected: not " .. printExpected(expected),
            }
            if receivedDiff ~= 0 then
                lines[#lines + 1] = "Received:     " .. printReceived(actual)
                lines[#lines + 1] = ""
                lines[#lines + 1] = printCloseTo(receivedDiff, expectedDiff, decimals, options.isNot)
            end
            return tableConcat(lines, "\n")
        end
    else
        message = function()
            return matcherHint(matcherName, nil, nil, options)
                .. "\n\n"
                .. "Expected: " .. printExpected(expected) .. "\n"
                .. "Received: " .. printReceived(actual) .. "\n"
                .. "\n"
                .. printCloseTo(receivedDiff, expectedDiff, decimals, options.isNot)
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)


-- 深度比较实际值与预期值是否相等
Assertion.addMethod("toEqual", function(self, expected)
    local actual = self._obj
    local matcherName = "toEqual"
    ---@type MatcherHintOptions
    local options = {
        comment = i18n("深度比较"),
        isNot = flag(self, "negate"),
    }
    local pass = deepCompare(actual, expected, true)
    local message = pass and function()
        return matcherHint(matcherName, nil, nil, options) ..
            "\n\n" ..
            "Expected: not " .. printExpected(expected)
    end or function()
        return matcherHint(matcherName, nil, nil, options)
            .. "\n\n" ..
            printDiffOrStringify(actual, expected)
    end
    return {
        pass = pass,
        message = message,
    }
end)

-- 检查实际值是否为假值
Assertion.addMethod("toBeFalsy", function(self)
    local actual = self._obj
    local matcherName = "toBeFalsy"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    local pass = not actual
    return {
        pass = pass,
        message = function()
            return matcherHint(matcherName, nil, '', options) ..
                "\n\n" ..
                "Received: " ..
                printReceived(actual)
        end,
    }
end)

-- 检查实际值是否为真值
Assertion.addMethod("toBeTruthy", function(self)
    local actual = self._obj
    local matcherName = "toBeTruthy"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    local pass = not not actual
    return {
        pass = pass,
        message = function()
            return matcherHint(matcherName, nil, '', options)
                .. "\n\n"
                .. "Received: "
                .. printReceived(actual)
        end,
    }
end)

-- 检查函数是否抛出指定错误
Assertion.addMethod("toThrowError", function(self, expected)
    local actual = self._obj
    local matcherName = "toThrowError"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    if type(actual) ~= "function" then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, 'expected', options),
            matcherUtils.RECEIVED_COLOR("received") .. " " .. i18n("值必须是函数"),
            printWithType('Received', actual, printReceived)
        ))
    end

    local ok, error_message = pcall(actual)
    local pass = not ok
    if hasToString(error_message) then
        error_message = tostring(error_message)
        error_message = error_message:gsub('^.-:%d+: ', '', 1)
    end

    -- expected 为 nil 时仅检查是否抛出错误
    if expected ~= nil then
        local expectedType = type(expected)
        if expectedType == "string" then
            pass = pass and error_message == expected
        elseif expectedType == "table" then
            if type(error_message) == "table" then
                pass = pass and deepCompare(error_message, expected, true)
            else
                pass = pass and error_message == expected
            end
        end
    end

    local message = function()
        if expected == nil then
            -- 无参数时，仅显示是否抛出错误
            if pass then
                return matcherHint(matcherName, nil, '', options)
                    .. "\n\n"
                    .. "Expected: not to throw"
                    .. "\n"
                    .. "Received: threw " .. printReceived(error_message)
            else
                return matcherHint(matcherName, nil, '', options)
                    .. "\n\n"
                    .. "Expected: to throw an error"
                    .. "\n"
                    .. "Received: function did not throw"
            end
        end
        return matcherHint(matcherName, nil, nil, options)
            .. "\n\n" ..
            printDiffOrStringify(error_message, expected, {
                aAnnotation = "Expected message",
                bAnnotation = "Received message",
            })
    end

    return {
        pass = pass,
        message = message,
    }
end)

---@param expected string 模式字符串
---@param plain? boolean 是否使用字面量匹配
Assertion.addMethod("toMatch", function(self, expected, plain)
    local actual = self._obj
    local matcherName = "toMatch"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    if type(actual) ~= "string" then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, nil, options),
            matcherUtils.RECEIVED_COLOR("received") .. " " .. i18n("值必须是字符串"),
            printWithType('Received', actual, printReceived)
        ))
    end

    if type(expected) ~= "string" then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, nil, options),
            matcherUtils.EXPECTED_COLOR("expected") .. " " .. i18n("值必须是字符串"),
            printWithType('Expected', expected, printExpected)
        ))
    end

    if plain ~= nil then
        options.secondArgument = 'plain'
    end

    local startIndex = string.find(actual, expected, 1, plain)

    local pass = startIndex ~= nil
    local message = function()
        local tag = "pattern: "
        if plain then
            tag = "string: "
        end

        local expectedLine = "Expected " .. tag .. printExpected(expected)
        local receivedLine = "Received string: " .. printReceived(actual)
        return matcherHint(matcherName, nil, nil, options) .. "\n\n" .. expectedLine .. "\n" .. receivedLine
    end

    return {
        pass = pass,
        message = message,
    }
end)

--- 断言某个值是否与所提供数组中的任何值匹配
---@param expected any[] 预期值数组
Assertion.addMethod("toBeOneOf", function(self, expected)
    local actual = self._obj
    local matcherName = "toBeOneOf"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    if type(expected) ~= "table" then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, nil, options),
            matcherUtils.EXPECTED_COLOR("expected") .. " " .. i18n("值必须是 table"),
            printWithType('Expected', expected, printExpected)
        ))
    end

    local pass = false
    for _, candidate in ipairs(expected) do
        if actual == candidate then
            pass = true
            break
        end
    end

    return {
        pass = pass,
        message = function()
            return matcherHint(matcherName, nil, nil, options)
                .. "\n\n"
                .. printDiffOrStringify(actual, expected)
        end,
    }
end)

-- 检查数组或字符串是否包含目标值
Assertion.addMethod("toContain", function(self, expected)
    local actual = self._obj
    local matcherName = "toContain"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    if actual == nil then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, nil, options),
            matcherUtils.RECEIVED_COLOR("received") .. " " .. i18n("值不能为 nil"),
            printWithType('Received', actual, printReceived)
        ))
    end

    local actualType = type(actual)

    if actualType == "string" then
        if type(expected) ~= "string" then
            error(matcherErrorMessage(
                matcherHint(matcherName, nil, nil, options),
                matcherUtils.EXPECTED_COLOR("expected") .. " " .. i18n("值必须是字符串, 当 received 为字符串时"),
                printWithType('Expected', expected, printExpected) .. "\n" ..
                printWithType('Received', actual, printReceived)
            ))
        end
        local startIndex = string.find(actual, expected, 1, true)
        local pass = startIndex ~= nil
        local labelExpected = "Expected substring"
        local labelReceived = "Received string"
        local printLabel = getLabelPrinter(labelExpected, labelReceived)
        local message = function()
            local lines = {
                matcherHint(matcherName, nil, nil, options),
                "",
                printLabel(labelExpected) .. (options.isNot and "not " or "") .. printExpected(expected),
                printLabel(labelReceived) .. (options.isNot and "    " or "") .. printReceived(actual),
            }
            return tableConcat(lines, "\n")
        end

        return {
            pass = pass,
            message = message,
        }
    end

    if actualType ~= "table" then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, nil, options),
            matcherUtils.RECEIVED_COLOR("received") .. " " .. i18n("值必须是 table 或 string"),
            printWithType('Received', actual, printReceived)
        ))
    end

    local found = false
    for _, value in ipairs(actual) do
        if value == expected then
            found = true
            break
        end
    end

    local labelExpected = "Expected value"
    local labelReceived = "Received table"
    local printLabel = getLabelPrinter(labelExpected, labelReceived)
    local message = function()
        local lines = {
            matcherHint(matcherName, nil, nil, options),
            "",
            printLabel(labelExpected) .. (options.isNot and "not " or "") .. printExpected(expected),
            printLabel(labelReceived) .. (options.isNot and "    " or "") .. printReceived(actual),
        }
        return tableConcat(lines, "\n")
    end

    return {
        pass = found,
        message = message,
    }
end)

-- 检查数组是否包含深度相等的元素
Assertion.addMethod("toContainEqual", function(self, expected)
    local actual = self._obj
    local matcherName = "toContainEqual"
    ---@type MatcherHintOptions
    local options = {
        comment = "deep equality",
        isNot = flag(self, "negate"),
    }

    if actual == nil then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, nil, options),
            matcherUtils.RECEIVED_COLOR("received") .. " " .. i18n("值不能为 nil"),
            printWithType('Received', actual, printReceived)
        ))
    end

    if type(actual) ~= "table" then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, nil, options),
            matcherUtils.RECEIVED_COLOR("received") .. " " .. i18n("值必须是 table"),
            printWithType('Received', actual, printReceived)
        ))
    end

    local found = false
    for _, value in ipairs(actual) do
        if deepCompare(value, expected, true) then
            found = true
            break
        end
    end

    local labelExpected = "Expected value"
    local labelReceived = "Received table"
    local printLabel = getLabelPrinter(labelExpected, labelReceived)
    local message = function()
        local lines = {
            matcherHint(matcherName, nil, nil, options),
            "",
            printLabel(labelExpected) .. (options.isNot and "not " or "") .. printExpected(expected),
            printLabel(labelReceived) .. (options.isNot and "    " or "") .. printReceived(actual),
        }
        return tableConcat(lines, "\n")
    end

    return {
        pass = found,
        message = message,
    }
end)

-- 检查对象是否匹配子集
Assertion.addMethod("toMatchObject", function(self, expected)
    local actual = self._obj
    local matcherName = "toMatchObject"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    if type(actual) ~= "table" then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, nil, options),
            matcherUtils.RECEIVED_COLOR("received") .. " " .. i18n("值必须是 table"),
            printWithType('Received', actual, printReceived)
        ))
    end

    if type(expected) ~= "table" then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, nil, options),
            matcherUtils.EXPECTED_COLOR("expected") .. " " .. i18n("值必须是 table"),
            printWithType('Expected', expected, printExpected)
        ))
    end

    local pass = isMatchObject(actual, expected)
    local message
    if pass then
        message = function()
            local lines = {
                matcherHint(matcherName, nil, nil, options),
                "",
                "Expected: not " .. printExpected(expected),
            }
            if not deepCompare(actual, expected, true) then
                lines[#lines + 1] = "Received:     " .. printReceived(actual)
            end
            return tableConcat(lines, "\n")
        end
    else
        message = function()
            local subset = extractSubset(actual, expected)
            return matcherHint(matcherName, nil, nil, options)
                .. "\n\n"
                .. printDiffOrStringify(subset, expected)
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)

-- 检查对象是否具有指定路径, 并可选地比较路径对应的值.
---@param expectedPath any[] 要检查的路径数组, 每个元素对应一个键.
---@param ... any 可选的预期值, 用于比较路径对应的值. 必须要使用`...`来确定是否有预期值, select("#", ...) 如果大于0则表示有预期值, 即使这个值是 nil.
Assertion.addMethod("toHaveProperty", function(self, expectedPath, ...)
    local actual = self._obj
    local matcherName = "toHaveProperty"
    local expectedArgument = "path"
    local argumentCount = select("#", ...)
    local hasExpectedValue = argumentCount > 0
    local expectedValue = hasExpectedValue and select(1, ...) or nil
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }
    if hasExpectedValue then
        options.secondArgument = "value"
    end

    if actual == nil then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, expectedArgument, options),
            matcherUtils.RECEIVED_COLOR("received") .. " " .. i18n("值不能是 nil"),
            printWithType('Received', actual, printReceived)
        ))
    end

    if type(expectedPath) ~= "table" then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, expectedArgument, options),
            matcherUtils.EXPECTED_COLOR("expected") .. " " .. i18n("路径必须是 table"),
            printWithType('Expected', expectedPath, printExpected)
        ))
    end

    if #expectedPath == 0 then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, expectedArgument, options),
            matcherUtils.EXPECTED_COLOR("expected") .. " " .. i18n("路径不能是空数组"),
            printWithType('Expected', expectedPath, printExpected)
        ))
    end

    local pathResult = matcherUtils.getPath(actual, expectedPath)
    local receivedPath = pathResult.traversedPath
    local hasCompletePath = pathResult.hasEndProp and #receivedPath == #expectedPath
    local receivedValue = hasCompletePath and pathResult.value or pathResult.lastTraversedObject

    local pass
    if hasExpectedValue then
        ---@cast expectedValue any
        pass = pathResult.hasEndProp and deepCompare(pathResult.value, expectedValue, true)
    else
        pass = pathResult.hasEndProp and hasCompletePath
    end

    local message
    if pass then
        message = function()
            local lines = {
                matcherHint(matcherName, nil, expectedArgument, options),
                "",
            }
            if hasExpectedValue then
                lines[#lines + 1] = "Expected path: " .. printExpected(expectedPath)
                lines[#lines + 1] = ""
                lines[#lines + 1] = "Expected value: not " .. printExpected(expectedValue)
                if not deepCompare(expectedValue, receivedValue, true) then
                    lines[#lines + 1] = "Received value:     " .. printReceived(receivedValue)
                end
            else
                lines[#lines + 1] = "Expected path: not " .. printExpected(expectedPath)
                lines[#lines + 1] = ""
                lines[#lines + 1] = "Received value: " .. printReceived(receivedValue)
            end
            return tableConcat(lines, "\n")
        end
    else
        message = function()
            local hint = matcherHint(matcherName, nil, expectedArgument, options)
            if hasCompletePath and hasExpectedValue then
                return hint
                    .. "\n\n"
                    .. printDiffOrStringify(receivedValue, expectedValue, {
                        aAnnotation = "Expected value",
                        bAnnotation = "Received value",
                    })
            end

            local lines = {
                hint,
                "",
                "Expected path: " .. printExpected(expectedPath),
            }

            if hasCompletePath then
                lines[#lines + 1] = ""
                if hasExpectedValue then
                    lines[#lines + 1] = printDiffOrStringify(receivedValue, expectedValue, {
                        aAnnotation = "Expected value",
                        bAnnotation = "Received value",
                    })
                else
                    lines[#lines + 1] = "Received value: " .. printReceived(receivedValue)
                end
                return tableConcat(lines, "\n")
            end

            lines[#lines + 1] = "Received path: " .. printReceived(receivedPath)
            lines[#lines + 1] = ""
            if hasExpectedValue then
                lines[#lines + 1] = "Expected value: " .. printExpected(expectedValue)
            end
            lines[#lines + 1] = "Received value: " .. printReceived(receivedValue)
            return tableConcat(lines, "\n")
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)

-- 检查对象是否具有指定长度
---@param expected integer 预期长度
---@param useN boolean? 使用`n`字段表示长度, 默认为 `true`
Assertion.addMethod("toHaveLength", function(self, expected, useN)
    local actual = self._obj
    local matcherName = "toHaveLength"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    if useN ~= nil then
        options.secondArgument = 'useN'
    end

    local actualType = type(actual)
    if actualType ~= "string" and actualType ~= "table" then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, nil, options),
            matcherUtils.RECEIVED_COLOR("received") .. " " .. i18n("值必须是 table 或 string"),
            printWithType('Received', actual, printReceived)
        ))
    end

    ensureExpectedIsNonNegativeInteger(expected, matcherName, options)

    if useN == nil then
        useN = true
    end

    local actualLength
    if actualType == "string" then
        actualLength = #actual
    else
        if useN and type(actual.n) == "number" and math.type(actual.n) == "integer" then
            actualLength = actual.n
        else
            actualLength = #actual
        end
    end

    local pass = actualLength == expected
    local message = function()
        local labelExpected = "Expected length"
        local labelReceivedLength = "Received length"
        local labelReceivedValue = stringFormat("Received %s", actualType)
        local printLabel = getLabelPrinter(labelExpected, labelReceivedLength, labelReceivedValue)
        local expectedLine = printLabel(labelExpected) .. (options.isNot and "not " or "") .. printExpected(expected)
        local lines = {
            matcherHint(matcherName, nil, nil, options),
            "",
            expectedLine,
        }
        if not options.isNot then
            lines[#lines + 1] = printLabel(labelReceivedLength) .. printReceived(actualLength)
        end
        lines[#lines + 1] = printLabel(labelReceivedValue)
            .. (options.isNot and "    " or "") .. printReceived(actual)
        return tableConcat(lines, "\n")
    end

    return {
        pass = pass,
        message = message,
    }
end)

-- 检查实际值是否大于预期值
Assertion.addMethod("toBeGreaterThan", function(self, expected)
    local actual = self._obj
    local matcherName = "toBeGreaterThan"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    local pass = actual > expected
    local message = function()
        local expectedLine = stringFormat("Expected:%s > %s", options.isNot and " not" or "",
            printExpected(expected))
        local receivedLine = stringFormat("Received:%s   %s", options.isNot and "    " or "",
            printReceived(actual))
        return matcherHint(matcherName, nil, nil, options)
            .. "\n\n"
            .. expectedLine
            .. "\n"
            .. receivedLine
    end

    return {
        pass = pass,
        message = message,
    }
end)

-- 检查实际值是否大于或等于预期值
Assertion.addMethod("toBeGreaterThanOrEqual", function(self, expected)
    local actual = self._obj
    local matcherName = "toBeGreaterThanOrEqual"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    local pass = actual >= expected
    local message = function()
        local expectedLine = stringFormat("Expected:%s >= %s", options.isNot and " not" or "",
            printExpected(expected))
        local receivedLine = stringFormat("Received:%s    %s", options.isNot and "    " or "",
            printReceived(actual))
        return matcherHint(matcherName, nil, nil, options)
            .. "\n\n"
            .. expectedLine
            .. "\n"
            .. receivedLine
    end

    return {
        pass = pass,
        message = message,
    }
end)

-- 检查实际值是否小于预期值
Assertion.addMethod("toBeLessThan", function(self, expected)
    local actual = self._obj
    local matcherName = "toBeLessThan"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    local pass = actual < expected
    local message = function()
        local expectedLine = stringFormat("Expected:%s < %s", options.isNot and " not" or "",
            printExpected(expected))
        local receivedLine = stringFormat("Received:%s   %s", options.isNot and "    " or "",
            printReceived(actual))
        return matcherHint(matcherName, nil, nil, options)
            .. "\n\n"
            .. expectedLine
            .. "\n"
            .. receivedLine
    end

    return {
        pass = pass,
        message = message,
    }
end)

-- 检查实际值是否小于或等于预期值
---@return ExpectationResult
Assertion.addMethod("toBeLessThanOrEqual", function(self, expected)
    local actual = self._obj
    local matcherName = "toBeLessThanOrEqual"
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    local pass = actual <= expected
    local message = function()
        local expectedLine = stringFormat("Expected:%s <= %s", options.isNot and " not" or "",
            printExpected(expected))
        local receivedLine = stringFormat("Received:%s    %s", options.isNot and "    " or "",
            printReceived(actual))
        return matcherHint(matcherName, nil, nil, options)
            .. "\n\n"
            .. expectedLine
            .. "\n"
            .. receivedLine
    end

    return {
        pass = pass,
        message = message,
    }
end)
