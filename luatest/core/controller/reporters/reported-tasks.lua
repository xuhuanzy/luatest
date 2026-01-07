---@namespace Luatest

local Class = require("luatest.utils.class")
local createTaskName = require("luatest.runner.utils.tasks").createTaskName

---@alias ReportedTaskType "module" | "suite" | "test"
---@alias ReportedTestState "pending" | "passed" | "failed" | "skipped"
---@alias ReportedSuiteState "pending" | "passed" | "failed" | "skipped"
---@alias ReportedModuleState ReportedSuiteState | "queued"

---@class ReportedTaskOptions
---@field each boolean?
---@field fails boolean?
---@field shuffle boolean?
---@field retry number?
---@field repeats number?
---@field sequential boolean?
---@field mode RunMode?

---@class TestResultPending
---@field state "pending"
---@field errors nil

---@class TestResultPassed
---@field state "passed"
---@field errors any[]?

---@class TestResultFailed
---@field state "failed"
---@field errors any[]

---@class TestResultSkipped
---@field state "skipped"
---@field errors nil
---@field note string?

---@alias TestResult TestResultPending | TestResultPassed | TestResultFailed | TestResultSkipped

---@param task Test|Suite
---@return ReportedTaskOptions
local function buildOptions(task)
    return {
        each = task.each,
        fails = task.type == "test" and task.fails or nil,
        shuffle = task.shuffle,
        retry = task.retry,
        repeats = task.repeats,
        sequential = task.sequential,
        mode = task.mode,
    }
end

---@param state StateManager
---@param runnerTask Task
---@param reportedTask any
local function storeTask(state, runnerTask, reportedTask)
    state.reportedTasksMap[runnerTask] = reportedTask
end

---@param state StateManager
---@param runnerTask Task
---@return any
local function getReportedTask(state, runnerTask)
    local reportedTask = state:getReportedEntity(runnerTask)
    if not reportedTask then
        error(string.format('Task instance was not found for %s "%s"', runnerTask.type, runnerTask.name), 2)
    end
    return reportedTask
end

---@param task Suite|File
---@return ReportedSuiteState
local function getSuiteState(task)
    local mode = task.mode
    local state = task.result and task.result.state or nil
    if mode == "skip" or mode == "todo" or state == "skip" or state == "todo" then
        return "skipped"
    end
    if state == nil or state == "run" or state == "only" then
        return "pending"
    end
    if state == "fail" then
        return "failed"
    end
    if state == "pass" then
        return "passed"
    end
    error(string.format("Unknown suite state: %s", tostring(state)), 2)
end

---@class TestCollection
---@field private state StateManager
---@field private task Suite|File
local TestCollection = {}
TestCollection.__index = TestCollection

---@param task Suite|File
---@param state StateManager
---@return TestCollection
function TestCollection.new(task, state)
    ---@type TestCollection
    local self = setmetatable({}, TestCollection)
    self.task = task
    self.state = state
    return self
end

---@return integer
function TestCollection:size()
    return #(self.task.tasks or {})
end

---@param index integer # 1-based; 支持负数(-1 表示最后一个)
---@return any?
function TestCollection:at(index)
    local tasks = self.task.tasks or {}
    if index < 0 then
        index = #tasks + index + 1
    end
    local t = tasks[index]
    if not t then
        return nil
    end
    return getReportedTask(self.state, t)
end

---@return any[]
function TestCollection:array()
    local out = {}
    for child in self:iter() do
        out[#out + 1] = child
    end
    return out
end

---@return fun(): any?
function TestCollection:iter()
    local i = 0
    local tasks = self.task.tasks or {}
    return function()
        i = i + 1
        local t = tasks[i]
        if not t then
            return nil
        end
        return getReportedTask(self.state, t)
    end
end

---@class ReportedTaskImplementation
---@field task Task
---@field state StateManager
---@field id string
---@field location { line: number, column: number, file: string }?
local ReportedTaskImplementation = Class.class("Luatest.ReportedTaskImplementation")

---@param task Task
---@param state StateManager
function ReportedTaskImplementation:__init(task, state)
    self.task = task
    self.state = state
    self.id = task.id
    self.location = task.location
end

---如果任务未结束或被跳过, 也会返回 true
---@return boolean
function ReportedTaskImplementation:ok()
    local result = self.task.result
    return not result or result.state ~= "fail"
end

---@return TaskMeta
function ReportedTaskImplementation:meta()
    return self.task.meta or {}
end

---@param task Task
---@param state StateManager
---@return any
function ReportedTaskImplementation:register(task, state)
    local existing = state:getReportedEntity(task)
    if existing then
        return existing
    end

    local instance = self.new(task, state)
    ---@cast instance TestModule | TestCase | TestSuite
    storeTask(state, task, instance)
    return instance
end

---@class SuiteImplementation: ReportedTaskImplementation
---@field task Suite|File
---@field children TestCollection
local SuiteImplementation = Class.class("Luatest.SuiteImplementation", ReportedTaskImplementation)

---@param task Suite|File
---@param state StateManager
function SuiteImplementation:__init(task, state)
    SuiteImplementation.super(self, task, state)
    self.children = TestCollection.new(task, state)
end

---@return any[]
function SuiteImplementation:errors()
    return (self.task.result and self.task.result.errors) or {}
end

---@class TestModule: SuiteImplementation
---@field type "module"
---@field task File
---@field moduleId string # 通常是绝对路径(由 runner 传入)
---@field relativeModuleId string # 对应 file.name
local TestModule = Class.class("Luatest.TestModule", SuiteImplementation)

---@param task File
---@param state StateManager
function TestModule:__init(task, state)
    TestModule.super(self, task, state)
    self.type = "module"
    self.moduleId = task.filepath
    self.relativeModuleId = task.name
end

---@return ReportedModuleState
function TestModule:state()
    local state = self.task.result and self.task.result.state or nil
    if state == "queued" or (state == nil and self.task.mode == "queued") then
        return "queued"
    end
    return getSuiteState(self.task)
end

---@return { duration: number, prepareDuration: number, environmentSetupDuration: number, collectDuration: number, setupDuration: number, heap: number?}
function TestModule:diagnostic()
    local duration = (self.task.result and self.task.result.duration) or 0
    return {
        environmentSetupDuration = self.task.environmentLoad or 0,
        prepareDuration = self.task.prepareDuration or 0,
        collectDuration = self.task.collectDuration or 0,
        setupDuration = self.task.setupDuration or 0,
        duration = duration,
        heap = self.task.result and self.task.result.heap or nil,
    }
end

---@class TestSuite: SuiteImplementation
---@field type "suite"
---@field task Suite
---@field module TestModule
---@field parent TestSuite|TestModule
---@field name string
---@field options ReportedTaskOptions
---@field fullName string
local TestSuite = Class.class("Luatest.TestSuite", SuiteImplementation)

---@param task Suite
---@param state StateManager
function TestSuite:__init(task, state)
    TestSuite.super(self, task, state)

    self.type = "suite"
    self.name = task.name

    ---@type TestModule
    self.module = getReportedTask(state, task.file)

    if task.suite then
        ---@type TestSuite
        self.parent = getReportedTask(state, task.suite)
    else
        self.parent = self.module
    end

    self.options = buildOptions(task)

    local fullTestName = task.fullTestName
    if type(fullTestName) == "string" and fullTestName ~= "" then
        self.fullName = fullTestName
    elseif self.parent.type ~= "module" then
        self.fullName = createTaskName({ self.parent.fullName, self.name })
    else
        self.fullName = self.name
    end
end

---@return ReportedSuiteState
function TestSuite:state()
    return getSuiteState(self.task)
end

---@class TestCase: ReportedTaskImplementation
---@field type "test"
---@field task Test
---@field module TestModule
---@field parent TestSuite|TestModule
---@field name string
---@field options ReportedTaskOptions
---@field fullName string
local TestCase = Class.class("Luatest.TestCase", ReportedTaskImplementation)

---@param task Test
---@param state StateManager
function TestCase:__init(task, state)
    TestCase.super(self, task, state)

    self.type = "test"
    self.name = task.name

    ---@type TestModule
    self.module = getReportedTask(state, task.file)

    if task.suite then
        ---@type TestSuite
        self.parent = getReportedTask(state, task.suite)
    else
        self.parent = self.module
    end

    self.options = buildOptions(task)

    local fullTestName = task.fullTestName
    if type(fullTestName) == "string" and fullTestName ~= "" then
        self.fullName = fullTestName
    elseif self.parent.type ~= "module" then
        self.fullName = createTaskName({ self.parent.fullName, self.name })
    else
        self.fullName = self.name
    end
end

---@return TestResult
function TestCase:result()
    local result = self.task.result
    local mode = (result and result.state) or self.task.mode

    if not result and (mode == "skip" or mode == "todo") then
        ---@type TestResultSkipped
        return {
            state = "skipped",
            note = nil,
            errors = nil,
        }
    end

    if not result or result.state == "run" or result.state == "queued" then
        ---@type TestResultPending
        return { state = "pending", errors = nil }
    end

    if result.state == "fail" then
        ---@type TestResultFailed
        return { state = "failed", errors = result.errors or {} }
    end

    if result.state == "pass" then
        ---@type TestResultPassed
        return { state = "passed", errors = result.errors }
    end

    --- skip/todo
    ---@type TestResultSkipped
    return { state = "skipped", note = result.note, errors = nil }
end

---@export namespace
return {
    TestCollection = TestCollection,
    TestCase = TestCase,
    TestSuite = TestSuite,
    TestModule = TestModule,
    getSuiteState = getSuiteState,
    getReportedTask = getReportedTask,
}
