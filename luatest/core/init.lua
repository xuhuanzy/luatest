---@namespace Luatest

local run = require("luatest.core.run").run

---@export namespace
local export = {
    run = run,
}

return export

