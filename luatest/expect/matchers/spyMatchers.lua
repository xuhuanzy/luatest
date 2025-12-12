local i18n = require("luatest.i18n")
local isMockFunction = require('luatest.spy.mock').isMockFunction
local matcherUtils = require("luatest.expect.matchers.matcherUtils")
local matcherErrorMessage = matcherUtils.matcherErrorMessage
local matcherHint = matcherUtils.matcherHint
local printWithType = matcherUtils.printWithType
local ensureExpectedIsNonNegativeInteger = matcherUtils.ensureExpectedIsNonNegativeInteger
local deepCompare = require("luatest.utils.helpers").deepCompare
local Assertion = require("luatest.expect.assertion")
local flag = require("luatest.expect.util").flag
local stringify = require("luatest.utils.display").stringify
local printExpected = require("luatest.utils.diff").printExpected
local printReceived = require("luatest.utils.diff").printReceived
local getLabelPrinter = require("luatest.utils.diff").getLabelPrinter
local stringFormat = string.format
local tableConcat = table.concat
local mathMin = math.min
local DIM_COLOR = matcherUtils.DIM_COLOR

---@namespace Luatest

local PRINT_LIMIT = 3 ---@readonly 打印参数数量限制
local NO_ARGUMENTS = i18n("调用时未提供参数") ---@readonly 无参数提示
local NO_CALLS = i18n("mock 函数尚未被调用") ---@readonly 未调用提示
local NO_RETURNS = i18n("mock 函数尚未返回结果") ---@readonly 未返回提示

---@param expand boolean?
---@return boolean
local function isExpand(expand)
    return expand ~= false
end

---@param val any
---@return string
local function printCommon(val)
    return DIM_COLOR(stringify(val))
end

---@param expected any
---@param received any
---@return boolean
local function isEqualValue(expected, received)
    return deepCompare(expected, received, true)
end

---@param expected any[]
---@return string
local function printExpectedArgs(expected)
    expected = expected or {}
    if #expected == 0 then
        return NO_ARGUMENTS
    end

    local printed = {}
    for index = 1, #expected do
        printed[index] = printExpected(expected[index])
    end
    return tableConcat(printed, ", ")
end


---@param expected any[]
---@param received any[]
---@return boolean
local function isEqualCall(expected, received)
    expected = expected or {}
    received = received or {}
    if #received ~= #expected then
        return false
    end
    return isEqualValue(expected, received)
end

---@param expected any[]
---@param result table
---@return boolean
local function isEqualReturn(expected, result)
    if result == nil or result.type ~= "return" then
        return false
    end

    expected = expected or {}
    local expectedValue
    if #expected <= 1 then
        expectedValue = expected[1]
    else
        expectedValue = expected
    end

    local receivedValue = result.value
    if #expected > 1 and type(receivedValue) ~= "table" then
        receivedValue = { receivedValue }
    end

    return isEqualValue(expectedValue, receivedValue)
end

---@param expected any[]?
---@return string
local function printExpectedReturns(expected)
    expected = expected or {}
    if #expected > 1 then
        return printExpectedArgs(expected)
    end
    return printExpected(expected[1])
end


---@param received any[]
---@param expected any[]?
---@return string
local function printReceivedArgs(received, expected)
    received = received or {}
    if #received == 0 then
        return NO_ARGUMENTS
    end

    local printed = {}
    for index = 1, #received do
        local value = received[index]
        if expected and index <= #expected and isEqualValue(expected[index], value) then
            printed[index] = printCommon(value)
        else
            printed[index] = printReceived(value)
        end
    end

    return tableConcat(printed, ", ")
end

---@param received any
---@param expected any[]?
---@return string
local function printReceivedReturns(received, expected)
    expected = expected or {}
    if #expected > 1 then
        local receivedList = type(received) == "table" and received or { received }
        return printReceivedArgs(receivedList, expected)
    end

    if #expected == 1 and isEqualValue(expected[1], received) then
        return printCommon(received)
    end

    return printReceived(received)
end

-- 计算成功返回次数
---@param results MockResult[]
---@return integer
local function countSuccessReturns(results)
    results = results or {} ---@type MockResult[]
    local total = 0
    for index = 1, #results do
        if results[index] and results[index].type ~= "throw" then
            total = total + 1
        end
    end
    return total
end

---@param returnCount integer
---@param callCount integer
---@return string
local function printNumberOfReturns(returnCount, callCount)
    local message = "\nNumber of returns: " .. printReceived(returnCount)
    if callCount ~= returnCount then
        message = message .. "\nNumber of calls:   " .. printReceived(callCount)
    end
    return message
end

---@param results MockResult<any>[]
---@return string
local function formatReturnLines(results)
    results = results or {}
    local lines = {}
    local printed = 0
    for index = 1, #results do
        local result = results[index]
        if result and result.type == "return" then
            lines[#lines + 1] = stringFormat("%d: %s", index, printReceived(result.value))
            printed = printed + 1
            if printed >= PRINT_LIMIT then
                break
            end
        end
    end
    return tableConcat(lines, "\n")
end

---@param value any
---@param matcherName string
---@param argumentName string
---@param options MatcherHintOptions
local function ensurePositiveInteger(value, matcherName, argumentName, options)
    if type(value) ~= "number" or value < 1 or math.type(value) ~= "integer" then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, argumentName, options),
            stringFormat("%s must be a positive integer", argumentName),
            printWithType(argumentName, value, stringify)
        ))
    end
end

---@alias PrintLabel fun(text: string, isExpectedCall: boolean): string
---@alias IndexedCall {[1]: integer, [2]: any[]}
---@alias IndexedResult {[1]: integer, [2]: { type: string, value: any }}

---@param received any
---@param matcherName string
---@param expectedArgument any
---@param options MatcherHintOptions
---@return Mock
local function getSpy(received, matcherName, expectedArgument, options)
    if not isMockFunction(received) then
        error(matcherErrorMessage(
            matcherHint(matcherName, nil, expectedArgument, options),
            matcherUtils.RECEIVED_COLOR("received") .. " " .. i18n("值必须是 mock 或 spy 函数"),
            printWithType('Received', received, printReceived)
        ))
    end
    return received
end

---@param calls any[][]
---@return string
local function formatCallLines(calls)
    calls = calls or {}
    local count = #calls
    local limit = mathMin(count, PRINT_LIMIT)
    local lines = {}
    for index = 1, limit do
        local callArgs = calls[index] or {}
        lines[#lines + 1] = stringFormat("%d: %s", index, printReceivedArgs(callArgs))
    end
    return tableConcat(lines, "\n")
end

---@param indexedCalls IndexedCall[]
---@param expected any[]?
---@param indent string?
---@return string
local function formatIndexedCallLines(indexedCalls, expected, indent)
    indexedCalls = indexedCalls or {} ---@type IndexedCall[]
    indent = indent or ""
    local lines = {}
    for index = 1, #indexedCalls do
        local callIndex = indexedCalls[index][1]
        local callArgs = indexedCalls[index][2] or {}
        lines[#lines + 1] = stringFormat("%s%d: %s", indent, callIndex, printReceivedArgs(callArgs, expected))
    end
    return tableConcat(lines, "\n")
end

---@param expected any[]?
---@param indexedCalls IndexedCall[]
---@param isSingleCall boolean
---@return string
local function printReceivedCallsNegative(expected, indexedCalls, isSingleCall)
    if not indexedCalls or #indexedCalls == 0 then
        return ""
    end

    if isSingleCall then
        local args = indexedCalls[1][2] or {}
        return "Received call: " .. printReceivedArgs(args, expected)
    end

    return "Received calls:\n" .. formatIndexedCallLines(indexedCalls, expected, "  ")
end

---@param expected any[]?
---@param indexedCalls IndexedCall[]
---@param expand boolean
---@param isSingleCall boolean
---@return string
local function printExpectedReceivedCallsPositive(expected, indexedCalls, expand, isSingleCall)
    local labelPrinter = getLabelPrinter("Expected", "Received")
    local lines = {}
    ---@diagnostic disable-next-line: param-type-mismatch
    lines[#lines + 1] = labelPrinter("Expected") .. printExpectedArgs(expected)

    if not indexedCalls or #indexedCalls == 0 then
        lines[#lines + 1] = labelPrinter("Received") .. printReceived(NO_CALLS)
        return tableConcat(lines, "\n")
    end

    if isSingleCall or not expand then
        local args = indexedCalls[1][2] or {}
        lines[#lines + 1] = labelPrinter("Received") .. printReceivedArgs(args, expected)
    else
        lines[#lines + 1] = labelPrinter("Received") .. "\n" .. formatIndexedCallLines(indexedCalls, expected, "  ")
    end

    return tableConcat(lines, "\n")
end

---@param result { type: string, value: any }?
---@param expected any[]?
---@return string
local function formatResultValue(result, expected)
    if not result then
        return NO_RETURNS
    end
    local prefix = ""
    if result.type == "return" then
        prefix = "returned "
    elseif result.type == "throw" then
        prefix = "threw "
    end

    if result.type ~= "return" then
        return prefix .. printReceived(result.value)
    end

    return prefix .. printReceivedReturns(result.value, expected)
end

---@param label string
---@param expected any[]?
---@param indexedResults IndexedResult[]
---@param isSingleResult boolean
---@return string
local function printReceivedResults(label, expected, indexedResults, isSingleResult)
    indexedResults = indexedResults or {}
    if #indexedResults == 0 then
        return label .. printReceived(NO_RETURNS)
    end

    if isSingleResult then
        return label .. formatResultValue(indexedResults[1][2], expected)
    end

    local lines = { label }
    for index = 1, #indexedResults do
        local resultIndex = indexedResults[index][1]
        local resultValue = indexedResults[index][2]
        lines[#lines + 1] = stringFormat("  %d: %s", resultIndex, formatResultValue(resultValue, expected))
    end
    return tableConcat(lines, "\n")
end

-- 检查函数是否至少被调用了一次
Assertion.addMethod("toHaveBeenCalled", function(self, ...)
    local actual = self._obj
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }
    local spy = getSpy(actual, "toHaveBeenCalled", "", options)
    local mockName = spy:getMockName()
    local calls = spy.mock.calls
    local callCount = #calls
    local pass = callCount > 0

    local message ---@type fun(): string
    if pass then
        message = function()
            return matcherHint("toHaveBeenCalled", mockName, "", options)
                .. "\n\n"
                .. "Expected number of calls: " .. printExpected(0) .. "\n"
                .. "Received number of calls: " .. printReceived(callCount) .. "\n\n"
                .. formatCallLines(calls)
        end
    else
        message = function()
            return matcherHint("toHaveBeenCalled", mockName, "", options)
                .. "\n\n"
                .. "Expected number of calls: >= " .. printExpected(1) .. "\n"
                .. "Received number of calls:    " .. printReceived(callCount)
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)

-- 检查函数是否被调用了特定次数
---@param expected integer
Assertion.addMethod("toHaveBeenCalledTimes", function(self, expected)
    local matcherName = "toHaveBeenCalledTimes"
    local expectedArgument = "expected"
    local actual = self._obj
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }
    ensureExpectedIsNonNegativeInteger(expected, matcherName, options)
    local spy = getSpy(actual, matcherName, expectedArgument, options)
    local mockName = spy:getMockName()
    local callCount = #spy.mock.calls
    local pass = callCount == expected
    local message
    if pass then
        message = function()
            return matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "Expected number of calls: not " .. printExpected(expected)
        end
    else
        message = function()
            return matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "Expected number of calls: " .. printExpected(expected) .. "\n"
                .. "Received number of calls: " .. printReceived(callCount)
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)

-- 检查函数是否至少一次被调用, 并带有特定的参数
Assertion.addMethod("toHaveBeenCalledWith", function(self, ...)
    local matcherName = "toHaveBeenCalledWith"
    local expectedArgument = "...expected"
    local actual = self._obj
    local expected = { ... }
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    local spy = getSpy(actual, matcherName, expectedArgument, options)
    local mockName = spy:getMockName()
    local calls = spy.mock.calls or {}
    local callCount = #calls
    local pass = false

    for index = 1, callCount do
        if isEqualCall(expected, calls[index]) then
            pass = true
            break
        end
    end

    local message ---@type fun(): string
    if pass then
        message = function()
            local indexedCalls = {}
            local callIndex = 1
            while callIndex <= callCount and #indexedCalls < PRINT_LIMIT do
                if isEqualCall(expected, calls[callIndex]) then
                    indexedCalls[#indexedCalls + 1] = { callIndex, calls[callIndex] }
                end
                callIndex = callIndex + 1
            end

            local shouldSkipDetails = callCount == 1 and stringify(calls[1]) == stringify(expected)
            local result = matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "Expected: not " .. printExpectedArgs(expected) .. "\n"

            if not shouldSkipDetails then
                result = result
                    .. printReceivedCallsNegative(expected, indexedCalls, callCount == 1)
                    .. "\n"
            end

            result = result .. "Number of calls: " .. printReceived(callCount)
            return result
        end
    else
        message = function()
            local indexedCalls = {}
            local limit = mathMin(callCount, PRINT_LIMIT)
            for index = 1, limit do
                indexedCalls[#indexedCalls + 1] = { index, calls[index] }
            end

            return matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. printExpectedReceivedCallsPositive(expected, indexedCalls, isExpand(flag(self, "expand")),
                    callCount == 1)
                .. "\nNumber of calls: " .. printReceived(callCount)
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)

-- 检查函数在其最后一次调用时是否被传入了特定的参数
Assertion.addMethod("toHaveBeenLastCalledWith", function(self, ...)
    local matcherName = "toHaveBeenLastCalledWith"
    local expectedArgument = "...expected"
    local actual = self._obj
    local expected = { ... }
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    local spy = getSpy(actual, matcherName, expectedArgument, options)
    local mockName = spy:getMockName()
    local calls = spy.mock.calls or {}
    local callCount = #calls
    local lastCall = spy.mock.lastCall ---@cast lastCall -?
    local pass = callCount > 0 and isEqualCall(expected, lastCall)

    local message ---@type fun(): string
    if pass then
        message = function()
            local indexedCalls = {}
            if callCount > 1 then
                indexedCalls[#indexedCalls + 1] = { callCount - 1, calls[callCount - 1] }
            end
            indexedCalls[#indexedCalls + 1] = { callCount, lastCall }

            local shouldSkipDetails = callCount == 1 and stringify(lastCall) == stringify(expected)
            local result = matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "Expected: not " .. printExpectedArgs(expected) .. "\n"

            if not shouldSkipDetails then
                result = result
                    .. printReceivedCallsNegative(expected, indexedCalls, callCount == 1)
                    .. "\n"
            end

            result = result .. "Number of calls: " .. printReceived(callCount)
            return result
        end
    else
        message = function()
            local indexedCalls = {}
            if callCount > 0 then
                if callCount > 1 then
                    local precedingIndex = callCount - 1
                    while precedingIndex >= 1 and not isEqualCall(expected, calls[precedingIndex]) do
                        precedingIndex = precedingIndex - 1
                    end
                    if precedingIndex < 1 then
                        precedingIndex = callCount - 1
                    end
                    if precedingIndex >= 1 then
                        indexedCalls[#indexedCalls + 1] = { precedingIndex, calls[precedingIndex] }
                    end
                end
                indexedCalls[#indexedCalls + 1] = { callCount, lastCall }
            end

            return matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. printExpectedReceivedCallsPositive(expected, indexedCalls, isExpand(flag(self, "expand")),
                    callCount == 1)
                .. "\nNumber of calls: " .. printReceived(callCount)
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)

-- 检查函数是否在特定的次数被调用时带有特定的参数
Assertion.addMethod("toHaveBeenNthCalledWith", function(self, nth, ...)
    local matcherName = "toHaveBeenNthCalledWith"
    local expectedArgument = "n"
    local actual = self._obj
    local expected = { ... }
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
        expectedColor = function(arg) return arg end,
        secondArgument = "...expected",
    }

    ensurePositiveInteger(nth, matcherName, expectedArgument, options)

    local spy = getSpy(actual, matcherName, expectedArgument, options)
    local mockName = spy:getMockName()
    local calls = spy.mock.calls or {}
    local callCount = #calls
    local targetIndex = nth
    local targetCall = calls[targetIndex]
    local pass = targetCall ~= nil and isEqualCall(expected, targetCall)

    local message ---@type fun(): string
    if pass then
        message = function()
            local indexedCalls = {}
            if targetIndex - 1 >= 1 then
                indexedCalls[#indexedCalls + 1] = { targetIndex - 1, calls[targetIndex - 1] }
            end
            indexedCalls[#indexedCalls + 1] = { targetIndex, targetCall }
            if targetIndex + 1 <= callCount then
                indexedCalls[#indexedCalls + 1] = { targetIndex + 1, calls[targetIndex + 1] }
            end

            local shouldSkipDetails = callCount == 1 and stringify(calls[1]) == stringify(expected)
            local result = matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "n: " .. tostring(nth) .. "\n"
                .. "Expected: not " .. printExpectedArgs(expected) .. "\n"

            if not shouldSkipDetails then
                result = result
                    .. printReceivedCallsNegative(expected, indexedCalls, callCount == 1)
                    .. "\n"
            end

            result = result .. "Number of calls: " .. printReceived(callCount)
            return result
        end
    else
        message = function()
            local indexedCalls = {}
            if targetIndex <= callCount then
                if targetIndex - 1 >= 1 then
                    local precedingIndex = targetIndex - 1
                    while precedingIndex >= 1 and not isEqualCall(expected, calls[precedingIndex]) do
                        precedingIndex = precedingIndex - 1
                    end
                    if precedingIndex < 1 then
                        precedingIndex = targetIndex - 1
                    end
                    if precedingIndex >= 1 then
                        indexedCalls[#indexedCalls + 1] = { precedingIndex, calls[precedingIndex] }
                    end
                end

                indexedCalls[#indexedCalls + 1] = { targetIndex, calls[targetIndex] }

                if targetIndex + 1 <= callCount then
                    local followingIndex = targetIndex + 1
                    while followingIndex <= callCount and not isEqualCall(expected, calls[followingIndex]) do
                        followingIndex = followingIndex + 1
                    end
                    if followingIndex > callCount then
                        followingIndex = targetIndex + 1
                    end
                    if followingIndex <= callCount then
                        indexedCalls[#indexedCalls + 1] = { followingIndex, calls[followingIndex] }
                    end
                end
            elseif callCount > 0 then
                local fallbackIndex = callCount
                local searchIndex = callCount
                while searchIndex >= 1 and not isEqualCall(expected, calls[searchIndex]) do
                    searchIndex = searchIndex - 1
                end
                if searchIndex >= 1 then
                    fallbackIndex = searchIndex
                end
                indexedCalls[#indexedCalls + 1] = { fallbackIndex, calls[fallbackIndex] }
            end

            return matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "n: " .. tostring(nth) .. "\n"
                .. printExpectedReceivedCallsPositive(expected, indexedCalls, isExpand(flag(self, "expand")),
                    callCount == 1)
                .. "\nNumber of calls: " .. printReceived(callCount)
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)

--- 检查最后一次调用是否返回了预期的值
Assertion.addMethod("toHaveLastReturnedWith", function(self, ...)
    local matcherName = "toHaveLastReturnedWith"
    local expectedArgument = "...expected"
    local actual = self._obj
    local expected = { ... }
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    local spy = getSpy(actual, matcherName, expectedArgument, options)
    local mockName = spy:getMockName()
    local mock = spy.mock or {}
    local calls = mock.calls or {}
    local results = mock.results or {}
    local resultCount = #results
    local lastResult = results[resultCount]
    local pass = resultCount > 0 and isEqualReturn(expected, lastResult)

    local message ---@type fun(): string
    if pass then
        message = function()
            local indexedResults = {}
            if resultCount > 1 then
                indexedResults[#indexedResults + 1] = { resultCount - 1, results[resultCount - 1] }
            end
            indexedResults[#indexedResults + 1] = { resultCount, lastResult }

            local shouldSkipDetails = resultCount == 1
                and lastResult ~= nil
                and lastResult.type == "return"
                and isEqualReturn(expected, lastResult)

            local result = matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "Expected: not " .. printExpectedReturns(expected) .. "\n"

            if not shouldSkipDetails then
                result = result
                    .. printReceivedResults("Received:     ", expected, indexedResults, resultCount == 1)
                    .. "\n"
            end

            result = result .. printNumberOfReturns(countSuccessReturns(results), #calls)
            return result
        end
    else
        message = function()
            local indexedResults = {}
            if resultCount > 0 then
                if resultCount > 1 then
                    local precedingIndex = resultCount - 1
                    while precedingIndex >= 1 and not isEqualReturn(expected, results[precedingIndex]) do
                        precedingIndex = precedingIndex - 1
                    end
                    if precedingIndex < 1 then
                        precedingIndex = resultCount - 1
                    end
                    if precedingIndex >= 1 then
                        indexedResults[#indexedResults + 1] = { precedingIndex, results[precedingIndex] }
                    end
                end

                indexedResults[#indexedResults + 1] = { resultCount, lastResult }
            end

            return matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "Expected: " .. printExpectedReturns(expected) .. "\n"
                .. printReceivedResults("Received: ", expected, indexedResults, resultCount == 1)
                .. "\n"
                .. printNumberOfReturns(countSuccessReturns(results), #calls)
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)

--- 检查第 n 次调用是否返回了预期的值
Assertion.addMethod("toHaveNthReturnedWith", function(self, nth, ...)
    local matcherName = "toHaveNthReturnedWith"
    local expectedArgument = "n"
    local actual = self._obj
    local expected = { ... }
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
        expectedColor = function(arg) return arg end,
        secondArgument = "...expected",
    }

    ensurePositiveInteger(nth, matcherName, expectedArgument, options)

    local spy = getSpy(actual, matcherName, expectedArgument, options)
    local mockName = spy:getMockName()
    local mock = spy.mock or {}
    local calls = mock.calls or {}
    local results = mock.results or {}
    local resultCount = #results
    local targetIndex = nth
    local targetResult = results[targetIndex]
    local pass = targetResult ~= nil and isEqualReturn(expected, targetResult)

    local message ---@type fun(): string
    if pass then
        message = function()
            local indexedResults = {}
            if targetIndex - 1 >= 1 then
                indexedResults[#indexedResults + 1] = { targetIndex - 1, results[targetIndex - 1] }
            end
            indexedResults[#indexedResults + 1] = { targetIndex, targetResult }
            if targetIndex + 1 <= resultCount then
                indexedResults[#indexedResults + 1] = { targetIndex + 1, results[targetIndex + 1] }
            end

            local shouldSkipDetails = resultCount == 1
                and targetResult ~= nil
                and targetResult.type == "return"
                and isEqualReturn(expected, targetResult)

            local result = matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "n: " .. tostring(nth) .. "\n"
                .. "Expected: not " .. printExpectedReturns(expected) .. "\n"

            if not shouldSkipDetails then
                result = result
                    .. printReceivedResults("Received:     ", expected, indexedResults, resultCount == 1)
                    .. "\n"
            end

            result = result .. printNumberOfReturns(countSuccessReturns(results), #calls)
            return result
        end
    else
        message = function()
            local indexedResults = {}
            if targetIndex <= resultCount then
                if targetIndex - 1 >= 1 then
                    local precedingIndex = targetIndex - 1
                    while precedingIndex >= 1 and not isEqualReturn(expected, results[precedingIndex]) do
                        precedingIndex = precedingIndex - 1
                    end
                    if precedingIndex < 1 then
                        precedingIndex = targetIndex - 1
                    end
                    if precedingIndex >= 1 then
                        indexedResults[#indexedResults + 1] = { precedingIndex, results[precedingIndex] }
                    end
                end
                indexedResults[#indexedResults + 1] = { targetIndex, targetResult }
                if targetIndex + 1 <= resultCount then
                    local followingIndex = targetIndex + 1
                    while followingIndex <= resultCount and not isEqualReturn(expected, results[followingIndex]) do
                        followingIndex = followingIndex + 1
                    end
                    if followingIndex > resultCount then
                        followingIndex = targetIndex + 1
                    end
                    if followingIndex <= resultCount then
                        indexedResults[#indexedResults + 1] = { followingIndex, results[followingIndex] }
                    end
                end
            elseif resultCount > 0 then
                local fallbackIndex = resultCount
                local searchIndex = resultCount
                while searchIndex >= 1 and not isEqualReturn(expected, results[searchIndex]) do
                    searchIndex = searchIndex - 1
                end
                if searchIndex >= 1 then
                    fallbackIndex = searchIndex
                end
                indexedResults[#indexedResults + 1] = { fallbackIndex, results[fallbackIndex] }
            end

            return matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "n: " .. tostring(nth) .. "\n"
                .. "Expected: " .. printExpectedReturns(expected) .. "\n"
                .. printReceivedResults("Received: ", expected, indexedResults, resultCount == 1)
                .. "\n"
                .. printNumberOfReturns(countSuccessReturns(results), #calls)
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)

-- 检查函数是否至少返回了一次值
Assertion.addMethod("toHaveReturned", function(self, expected)
    local matcherName = "toHaveReturned"
    local expectedArgument = ""
    local actual = self._obj
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    local spy = getSpy(actual, matcherName, expectedArgument, options)
    local mockName = spy:getMockName()
    local mock = spy.mock or {}
    local calls = mock.calls or {}
    local results = mock.results or {}
    local returnCount = countSuccessReturns(results)
    local callCount = #calls
    local pass = returnCount > 0

    local message ---@type fun(): string
    if pass then
        message = function()
            local result = matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "Expected number of returns: " .. printExpected(0) .. "\n"
                .. "Received number of returns: " .. printReceived(returnCount)

            local returnLines = formatReturnLines(results)
            if returnLines ~= "" then
                result = result .. "\n\n" .. returnLines
            end

            if callCount ~= returnCount then
                result = result .. "\n\nReceived number of calls:   " .. printReceived(callCount)
            end

            return result
        end
    else
        message = function()
            local result = matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "Expected number of returns: >= " .. printExpected(1) .. "\n"
                .. "Received number of returns:    " .. printReceived(returnCount)

            if callCount ~= returnCount then
                result = result .. "\nReceived number of calls:      " .. printReceived(callCount)
            end

            return result
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)

--- 检查函数是否在确切的次数内成功返回了值
Assertion.addMethod("toHaveReturnedTimes", function(self, expected)
    local matcherName = "toHaveReturnedTimes"
    local expectedArgument = "expected"
    local actual = self._obj
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    ensureExpectedIsNonNegativeInteger(expected, matcherName, options)

    local spy = getSpy(actual, matcherName, expectedArgument, options)
    local mockName = spy:getMockName()
    local mock = spy.mock or {}
    local calls = mock.calls or {}
    local results = mock.results or {}
    local returnCount = countSuccessReturns(results)
    local callCount = #calls
    local pass = returnCount == expected

    local message ---@type fun(): string
    if pass then
        message = function()
            local result = matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "Expected number of returns: not " .. printExpected(expected)

            if callCount ~= returnCount then
                result = result .. "\n\nReceived number of calls:   " .. printReceived(callCount)
            end

            return result
        end
    else
        message = function()
            local result = matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "Expected number of returns: " .. printExpected(expected) .. "\n"
                .. "Received number of returns: " .. printReceived(returnCount)

            local returnLines = formatReturnLines(results)
            if returnLines ~= "" then
                result = result .. "\n\n" .. returnLines
            end

            if callCount ~= returnCount then
                result = result .. "\n\nReceived number of calls:   " .. printReceived(callCount)
            end

            return result
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)


--- 检查函数是否至少一次成功返回了带有特定参数的值
Assertion.addMethod("toHaveReturnedWith", function(self, ...)
    local matcherName = "toHaveReturnedWith"
    local expectedArgument = "...expected"
    local actual = self._obj
    local expected = { ... }
    ---@type MatcherHintOptions
    local options = {
        isNot = flag(self, "negate"),
    }

    local spy = getSpy(actual, matcherName, expectedArgument, options)
    local mockName = spy:getMockName()
    local mock = spy.mock or {}
    local calls = mock.calls or {}
    local results = mock.results or {}
    local resultCount = #results
    local callCount = #calls
    local pass = false
    local matchedResults = {}

    for index = 1, resultCount do
        local result = results[index]
        if isEqualReturn(expected, result) then
            pass = true
            if #matchedResults < PRINT_LIMIT then
                matchedResults[#matchedResults + 1] = { index, result }
            end
        end
    end

    local message ---@type fun(): string
    if pass then
        message = function()
            local shouldSkipDetails = resultCount == 1
                and results[1] ~= nil
                and results[1].type == "return"
                and isEqualReturn(expected, results[1])

            local result = matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "Expected: not " .. printExpectedReturns(expected) .. "\n"

            if not shouldSkipDetails then
                result = result
                    .. printReceivedResults("Received:     ", expected, matchedResults, resultCount == 1)
                    .. "\n"
            end

            result = result .. printNumberOfReturns(countSuccessReturns(results), callCount)
            return result
        end
    else
        message = function()
            local limitedResults = {}
            local limit = mathMin(resultCount, PRINT_LIMIT)
            for index = 1, limit do
                limitedResults[#limitedResults + 1] = { index, results[index] }
            end

            return matcherHint(matcherName, mockName, expectedArgument, options)
                .. "\n\n"
                .. "Expected: " .. printExpectedReturns(expected) .. "\n"
                .. printReceivedResults("Received: ", expected, limitedResults, resultCount == 1)
                .. "\n"
                .. printNumberOfReturns(countSuccessReturns(results), callCount)
        end
    end

    return {
        pass = pass,
        message = message,
    }
end)
