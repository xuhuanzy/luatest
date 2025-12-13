local Assertion = require("luatest.expect.assertion")
local getState = require("luatest.expect.state").getState
local setState = require("luatest.expect.state").setState
local GLOBAL_EXPECT = require("luatest.expect.constants").GLOBAL_EXPECT
local mergeDefaults = require("luatest.utils.helpers").mergeDefaults
local getWorkerState = require("luatest.core.runtime.utils").getWorkerState
local getCurrentTest = require("luatest.runner.test-state").getCurrentTest
local flag = require("luatest.expect.util").flag
---@namespace Luatest

---@export namespace
local export = {}

---@class ExpectStatic
---@field package createTest? Test | TaskPopulated 创建时传入的测试
---@field getState fun(self: self): MatcherState
---@field setState fun(self: self, state: Partial<MatcherState>)
---@overload fun<T>(actual: T, message?: string): Assertion<T>
local expectStaticMeta = {}

---@package
expectStaticMeta.__index = expectStaticMeta

---@package
---@param self ExpectStatic
---@param actual any
---@param message? string
expectStaticMeta.__call = function(self, actual, message)
    local state = getState(self)
    setState({ assertionCalls = state.assertionCalls + 1 }, self)
    local assert = Assertion.new(actual, message)
    local test = self.createTest or getCurrentTest()
    if test then
        flag(assert, "luatest-test", test)
    end

    return assert
end

function expectStaticMeta:getState()
    return getState(self)
end

function expectStaticMeta:setState(state)
    setState(state, self)
end

---@param test? Test | TaskPopulated
---@return ExpectStatic
local function createExpect(test)
    ---@type ExpectStatic
    local expect = setmetatable({
        createTest = test,
    }, expectStaticMeta)
    local globalState = getState(_G[GLOBAL_EXPECT]) or {}
    ---@diagnostic disable-next-line: missing-fields
    ---@type MatcherState
    local state = {
        assertionCalls = 0,
        isExpectingAssertions = false,
        isExpectingAssertionsError = nil,
        expectedAssertionsNumber = nil,
        expectedAssertionsNumberErrorGen = nil,
        testPath = function()
            return getWorkerState().filepath
        end,
        currentTestName = test and (test.fullTestName or '') or globalState.currentTestName,
    }
    setState(mergeDefaults(state, globalState), expect)

    return expect
end

local globalExpect = createExpect()
_G[GLOBAL_EXPECT] = globalExpect


export.globalExpect = globalExpect
return export
