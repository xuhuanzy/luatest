local collectorContext = require("luatest.runner.context").collectorContext
---@namespace Luatest

---@type SuiteCollector
local defaultSuite

---@class _Suite
local SuiteMeta = {}
SuiteMeta.__index = SuiteMeta
SuiteMeta.__call = function(self, name)
    local mode = "run"
    if self.only then
        mode = "only"
    elseif self.skip then
        mode = "skip"
    elseif self.todo then
        mode = "todo"
    end
    local currentSuite = collectorContext.currentSuite or defaultSuite
end

-- 创建 Suite
---@return SuiteAPI
local function createSuite()

end
