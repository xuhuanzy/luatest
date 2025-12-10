---@namespace Luatest


---@class PendingError
---@field code string
---@field taskId string
---@field message string
---@field note? string
local PendingError = {
    code = 'LUATEST_PENDING',
}

PendingError.__index = PendingError ---@package

---@param message string
---@param task Test
---@param note string?
---@return PendingError
function PendingError.new(message, task, note)
    ---@type Partial<PendingError>
    local o = {
        message = message,
        taskId = task.id,
        note = note,
    }
    return setmetatable(o, PendingError)
end

---@class TestRunAbortError
---@field name string
---@field reason string
---@field message string
local TestRunAbortError = {
    name = 'TestRunAbortError',
}
TestRunAbortError.__index = TestRunAbortError ---@package

function TestRunAbortError:new(message, reason)
    ---@type Partial<TestRunAbortError>
    local o = {
        message = message,
        reason = reason,
    }
    return setmetatable(o, TestRunAbortError)
end

---@export namespace
return {
    ---@export namespace
    PendingError = PendingError,
    ---@export namespace
    TestRunAbortError = TestRunAbortError,
}
