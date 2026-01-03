---@namespace Luatest

local StateManager = require("luatest.core.controller.state")

---@class Luatest
---@field state StateManager
---@field testRun TestRun
local Luatest = {}
Luatest.__index = Luatest ---@package

---@return Luatest
function Luatest.new()
    ---@type Partial<Luatest>
    local self = {
        state = StateManager.new(),
    }

    return setmetatable(self, Luatest)
end

return Luatest
