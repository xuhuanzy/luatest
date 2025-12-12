local flag = require("luatest.expect.util").flag
local addMethod = require("luatest.expect.util").addMethod
local i18n = require("luatest.i18n")
local matcherUtils = require("luatest.expect.matchers.matcherUtils")
local errorLevel = require("luatest.utils.error").errorLevel
local RECEIVED_COLOR = matcherUtils.RECEIVED_COLOR

---@namespace Luatest


---@class Assertion<T>: Matchers<T> & Inverse<Matchers<T>>
---@field _obj any 断言目标
local Assertion = {}

---@package
Assertion.__index = function(self, key)
    if key == "not_" then
        flag(self, "negate", true)
        return self
    end
    return rawget(Assertion, key)
end

---@param obj any 断言目标
---@param msg? string 自定义错误消息
---@return Assertion
function Assertion.new(obj, msg)
    ---@type Assertion
    local self = setmetatable({
        _obj = obj,
        __flags = {
            message = msg,
        },
    }, Assertion)

    return self
end

---@param name string 方法名
---@param fn (fun(self: Assertion, ...: any): ExpectationResult) 方法体
function Assertion.addMethod(name, fn)
    local function wrapAssertionMethod(self, ...)
        local result = fn(self, ...)
        local isNot = flag(self, "negate")
        if (result.pass and isNot) or (not result.pass and not isNot) then
            local message = result.message and result.message() or RECEIVED_COLOR(i18n("没有为此匹配器指定消息。"))
            message = "\n" .. message
            error(message, errorLevel())
        end
    end

    addMethod(Assertion, name, wrapAssertionMethod)
end

return Assertion
