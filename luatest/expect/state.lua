local MATCHERS_OBJECT = require("luatest.expect.constants").MATCHERS_OBJECT

---@namespace Luatest

if not _G[MATCHERS_OBJECT] then
    ---@type table<ExpectStatic, MatcherState>
    local globalState = setmetatable({}, {
        __mode = "k",
    })

    _G[MATCHERS_OBJECT] = globalState
end

---@export namespace
local export = {}

---@param expect ExpectStatic
---@return MatcherState
function export.getState(expect)
    return _G[MATCHERS_OBJECT] --[[@as table<ExpectStatic, MatcherState>]][expect]
end

---@generic State: MatcherState
---@param state Partial<State>
---@param expect ExpectStatic
function export.setState(state, expect)
    local map = _G[MATCHERS_OBJECT] ---@type table<ExpectStatic, MatcherState>
    local current = map[expect] or {}
    -- 合并新状态到当前状态
    for key, value in pairs(state) do
        current[key] = value
    end
    map[expect] = current
end

return export
