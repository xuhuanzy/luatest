local configDefaults = require("luatest.core.defaults")
---@namespace Luatest

---@export namespace
local export = {}

---@param luatest Luatest
---@return SerializedConfig
function export.resolveConfig(luatest)
    return configDefaults
end

return export
