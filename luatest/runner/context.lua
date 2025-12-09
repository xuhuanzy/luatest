---@namespace Luatest

---@export namespace
local export = {}

---@class RuntimeContext
local collectorContext = {
    ---@type (SuiteCollector|Test)[]
    tasks = {},
    ---@type SuiteCollector?
    currentSuite = nil
}

export.collectorContext = collectorContext


return export
