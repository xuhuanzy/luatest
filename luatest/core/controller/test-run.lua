---@namespace Luatest

---@class TestRun
---@field private luatest Luatest
local TestRun = {}
---@package
TestRun.__index = TestRun



---@param luatest Luatest
---@return TestRun
function TestRun.new(luatest)
    ---@type TestRun
    local self = setmetatable({ luatest = luatest }, TestRun)
    return self
end

---@param update TaskResultPack[]
---@param events TaskEventPack[]
function TestRun:updated(update, events)

end

function TestRun:start()

end

function TestRun:finish()

end

---@param file File
function TestRun:enqueued(file)
    self.luatest.state:collectFiles({ file })
end

---@param files File[]
function TestRun:collected(files)

end

return TestRun
