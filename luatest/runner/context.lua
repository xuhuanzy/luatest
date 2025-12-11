local PendingError = require("luatest.runner.errors").PendingError
---@namespace Luatest



---@export namespace
local export = {}

---@class RuntimeContext
local collectorContext = {
    ---@type (SuiteCollector|Test)[]
    tasks = {},
    ---@type SuiteCollector?
    currentSuite = nil
}

export.collectorContext = collectorContext

---@param test Test
---@return TestContext
local function createContext(test)
    ---@type TestContext
    local context = {
        task = test,
        skip = function(self, condition, note)
            if condition == false then
                return
            end
            if test.result == nil then
                test.result = { state = "skip" }
            end
            test.result.pending = true
            error(PendingError.new('test is skipped; abort execution', test, note), 2)
        end,
        onTestFailed = function(self, handler)
            if not test.onFailed then test.onFailed = {} end
            table.insert(test.onFailed, handler)
        end,
        onTestFinished = function(self, handler)
            if not test.onFinished then test.onFinished = {} end
            table.insert(test.onFinished, handler)
        end,
    }
    return context
end
export.createContext = createContext

---@param task SuiteCollector
export.collectTask = function(task)
    if collectorContext.currentSuite then
        table.insert(collectorContext.currentSuite.tasks, task)
    end
end

---@param suite SuiteCollector
---@param fn function
function export.runWithSuite(suite, fn)
    local prev = collectorContext.currentSuite
    collectorContext.currentSuite = suite
    fn()
    collectorContext.currentSuite = prev
end

---#region 文件上下文

---@type table<File, table<string, any>>
local fileContexts = setmetatable({}, { __mode = "k" })

---@param file File
---@return table<string, any>
function export.getFileContext(file)
    local context = fileContexts[file]
    if not context then
        error(string.format("Cannot find file context for %s", file.name))
    end
    return context
end

---@param file File
---@param context table<string, any>
function export.setFileContext(file, context)
    fileContexts[file] = context
end

--#endregion



return export
