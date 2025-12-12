---@namespace Luatest

local expect = require('luatest.expect.expect')
require("luatest.expect.matchers.matchers")
require("luatest.expect.matchers.spyMatchers")
local Assertion = require("luatest.expect.assertion")
local mock = require('luatest.spy.mock')
local util = require("luatest.expect.util")

---@type table<function, true>
local used = {}

-- 注册自定义断言函数
---@param fn fun(exports: table, util: table)
---@return table @ 导出表
local function use(fn)
    local exports = {
        Assertion = Assertion,
        util = util,
    }
    if not used[fn] then
        fn(exports, util)
        used[fn] = true
    end

    return exports
end

---@class Api
---@export namespace
local Api = {
    expect = expect,
    mock = mock,
    use = use,
}

return Api
