---@namespace Luatest

---@export namespace
local export = {}

local KEY = "__LUATEST_BOOTSTRAP_STATE__"

---@class BootstrapState
---@field cli boolean
---@field running boolean
---@field runCount integer

---@return BootstrapState
local function getOrCreate()
    local state = rawget(_G, KEY)
    if type(state) == "table" then
        ---@cast state BootstrapState
        if state.cli == nil then state.cli = false end
        if state.running == nil then state.running = false end
        if state.runCount == nil then state.runCount = 0 end
        return state
    end

    ---@type BootstrapState
    state = {
        cli = false,
        running = false,
        runCount = 0,
    }
    rawset(_G, KEY, state)
    return state
end

---@return BootstrapState
function export.get()
    return getOrCreate()
end

---@return boolean
function export.isCliMode()
    return getOrCreate().cli == true
end

---@param value boolean
function export.setCliMode(value)
    getOrCreate().cli = value == true
end

---@return boolean
function export.hasRun()
    local s = getOrCreate()
    return s.running == true or (s.runCount or 0) > 0
end

function export.markRunStarted()
    local s = getOrCreate()
    s.running = true
    s.runCount = (s.runCount or 0) + 1
end

function export.markRunFinished()
    getOrCreate().running = false
end

function export.reset()
    rawset(_G, KEY, {
        cli = false,
        running = false,
        runCount = 0,
    })
end

return export

