local runBaseTests = require("luatest.core.runtime.workers.base").runBaseTests
---@namespace Luatest

---@type LuatestWorker
local defaultWorker = {
    runTests = function(state)
        runBaseTests("run", state)
    end,
    collectTests = function(state)
        runBaseTests("collect", state)
    end
}


return defaultWorker