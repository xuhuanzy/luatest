---@namespace Luatest

local ReporterManager = require("luatest.core.controller.reporters.manager")
local createReporters = require("luatest.core.controller.reporters.utils").createReporters

---@export namespace
local export = {}

---@param ctx ReporterContext
---@param reporters Reporter[]?
---@return ReporterManager
function export.createReporterManager(ctx, reporters)
    local resolved = createReporters(reporters)
    local manager = ReporterManager.new(resolved, ctx)
    manager:init(ctx)
    return manager
end

return export
