-- luatest 主模块
-- 导出所有公共 API

local runner = require("luatest.runner")
local expectApi = require("luatest.expect")

---@export global
---@class Luatest.Static
local export = {}

---@readonly
export.describe = runner.describe
---@readonly
export.test = runner.test
---@readonly
export.it = runner.it

export.beforeAll = runner.beforeAll
export.afterAll = runner.afterAll
export.beforeEach = runner.beforeEach
export.afterEach = runner.afterEach
export.onTestFailed = runner.onTestFailed
export.onTestFinished = runner.onTestFinished
export.expect = expectApi.expect
export.mock = expectApi.mock


return export
