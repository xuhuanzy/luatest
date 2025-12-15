---@namespace Luatest

local suite = require("luatest.runner.suite")
local hooks = require("luatest.runner.hooks")

local runner = {
    describe = suite.describe,
    test = suite.test,
    it = suite.it,

    afterAll = hooks.afterAll,
    beforeAll = hooks.beforeAll,
    beforeEach = hooks.beforeEach,
    afterEach = hooks.afterEach,
    onTestFailed = hooks.onTestFailed,
    onTestFinished = hooks.onTestFinished,
}

return runner