local collectorContext = require("luatest.runner.context").collectorContext
local mergeDefaults = require('luatest.utils.helpers').mergeDefaults
local selectValue = require('luatest.utils.helpers').selectValue
local setHooks = require("luatest.runner.map").setHooks
local setFn = require("luatest.runner.map").setFn
local getHooks = require("luatest.runner.map").getHooks
local createContext = require("luatest.runner.context").createContext
local collectTask = require("luatest.runner.context").collectTask
local beforeEach = require("luatest.runner.hooks").beforeEach
local afterEach = require("luatest.runner.hooks").afterEach
local beforeAll = require("luatest.runner.hooks").beforeAll
local afterAll = require("luatest.runner.hooks").afterAll
local createChainable = require("luatest.runner.utils.chain")
local createTaskName = require("luatest.runner.utils.tasks").createTaskName
local runWithSuite = require("luatest.runner.context").runWithSuite
local getCurrentTest = require("luatest.runner.test-state").getCurrentTest
local withFixtures = require("luatest.runner.fixture").withFixtures


---@namespace Luatest

---@export namespace
local export = {}

---@type Runner
local runner
---@type SuiteCollector
local defaultSuite
---@type string
local currentTestFilepath

---@return SuiteHooks
local function createSuiteHooks()
    return {
        beforeAll = {},
        afterAll = {},
        beforeEach = {},
        afterEach = {},
    }
end
export.createSuiteHooks = createSuiteHooks

---格式化名称
---@param name string | function | table
---@return string
local function formatName(name)
    local nameType = type(name)
    if nameType == 'string' then
        return name
    elseif nameType == 'table' then
        return name.name or '<anonymous>'
    elseif nameType == 'function' then
        return '<anonymous>'
    end
    return tostring(name)
end

---@return Runner
export.getRunner = function()
    assert(runner, 'not found runner')
    return runner
end

---@return SuiteCollector
local function getCurrentSuite()
    local currentSuite = collectorContext.currentSuite or defaultSuite
    assert(currentSuite, 'not found current suite')
    return currentSuite
end
export.getCurrentSuite = getCurrentSuite

---@class _Test
---@field package fn function 内部记录的函数
---@field skip any
local TestMeta = {
    beforeEach = beforeEach,
    afterEach = afterEach,
    beforeAll = beforeAll,
    afterAll = afterAll,
}
TestMeta.__index = TestMeta ---@package

---@package
TestMeta.__call = function(self, context, ...)
    self.fn(context, ...)
end

function TestMeta:skipIf(condition)
    if condition then
        return self.skip
    end
    return self
end

function TestMeta:runIf(condition)
    if condition then
        return self
    end
    return self.skip
end

---@param fn function
---@param context? {string: any}
---@return TestAPI
local function createTaskCollector(fn, context)
    local task = setmetatable({
        fn = fn,
    }, TestMeta)

    ---@type TestAPI
    local _test = createChainable({ "sequential", "skip", "only", "todo", "fails" }, task)
    if context then
        ---@diagnostic disable-next-line: undefined-field
        _test:mergeContext(context)
    end

    return _test
end

---创建测试
---@param fn function
---@param context? {string: any}
---@return TestAPI
local function createTest(fn, context)
    return createTaskCollector(fn, context)
end


---@generic T
---@param optionsOrFn? TestOptions | T
---@return { options: TestOptions, handler?: function }
local function parseArguments(optionsOrFn)
    ---@type TestOptions
    local options = {}
    local fn

    if type(optionsOrFn) == 'table' then
        options = optionsOrFn
    else
        fn = optionsOrFn
    end

    return {
        options = options,
        handler = fn,
    }
end

---创建 SuiteCollector
---@param name string 套件名称
---@param factory? SuiteFactory 工厂函数, 即`describe`定义的函数体
---@param mode RunMode 运行模式
---@param suiteOptions? TestOptions 套件选项
---@return SuiteCollector
local function createSuiteCollector(name, factory, mode, suiteOptions)
    factory = factory or function() end ---@type SuiteFactory

    ---@type (Test|Suite|SuiteCollector)[]
    local tasks = {}

    ---@type Suite
    local suite

    ---@type SuiteCollector
    local collector

    ---初始化 Suite 对象
    ---@param includeLocation boolean
    local function initSuite(includeLocation)
        local currentSuite = collectorContext.currentSuite and collectorContext.currentSuite.suite

        suite = {
            id = '',
            type = 'suite',
            name = name,
            fullName = createTaskName({
                currentSuite and currentSuite.fullName or
                (collectorContext.currentSuite and collectorContext.currentSuite.file and collectorContext.currentSuite.file.fullName),
                name
            }),
            fullTestName = createTaskName({
                currentSuite and currentSuite.fullTestName,
                name
            }),
            mode = mode,
            suite = currentSuite,
            ---@diagnostic disable-next-line: assign-type-mismatch
            file = currentSuite and currentSuite.file or
                (collectorContext.currentSuite and collectorContext.currentSuite.file),
            shuffle = suiteOptions and suiteOptions.shuffle,
            tasks = {},
            meta = {},
        }
        ---@cast suite Suite
        -- 位置信息
        if includeLocation and runner and runner.config and runner.config.includeTaskLocation then
            local info = debug.getinfo(4, "Sl")
            if info then
                suite.location = {
                    line = info.currentline,
                    column = 1,
                    file = info.short_src
                }
            end
        end

        setHooks(suite, createSuiteHooks())
    end

    -- 初始化
    initSuite(true)

    ---创建测试任务
    ---@param taskName string 任务名称
    ---@param options? TaskCustomOptions 任务选项
    ---@return Test
    local function task(taskName, options)
        taskName = taskName or ''
        options = options or {} ---@type TaskCustomOptions

        local currentSuite = collectorContext.currentSuite and collectorContext.currentSuite.suite

        ---@type Test
        local task = {
            id = '',
            name = taskName,
            fullName = createTaskName({
                currentSuite and currentSuite.fullName or
                (collectorContext.currentSuite and collectorContext.currentSuite.file and collectorContext.currentSuite.file.fullName),
                taskName
            }),
            fullTestName = createTaskName({
                currentSuite and currentSuite.fullTestName,
                taskName
            }),
            suite = currentSuite,
            each = options.each,
            fails = options.fails,
            ---@diagnostic disable-next-line: assign-type-mismatch
            context = nil,
            type = 'test',
            ---@diagnostic disable-next-line: assign-type-mismatch
            file = currentSuite and currentSuite.file or
                (collectorContext.currentSuite and collectorContext.currentSuite.file),
            retry = options.retry or (runner and runner.config and runner.config.retry) or 0,
            repeats = options.repeats,
            mode = options.only and 'only'
                or options.skip and 'skip'
                or options.todo and 'todo'
                or 'run',
            meta = options.meta or {},
            annotations = {},
        }

        local handler = options.handler
        if task.mode == 'run' and not handler then
            task.mode = 'todo'
        end

        task.shuffle = suiteOptions and suiteOptions.shuffle
        local context = createContext(task)
        task.context = context

        -- 设置处理函数
        if handler then
            setFn(task, withFixtures(runner, handler, context))
        end

        -- 位置信息
        if runner and runner.config and runner.config.includeTaskLocation then
            local info = debug.getinfo(2, "Sl")
            if info then
                task.location = {
                    line = info.currentline,
                    column = 1,
                    file = info.short_src
                }
            end
        end

        table.insert(tasks, task)
        return task
    end

    ---@type TestAPI
    local test = createTest(function(self, name, optionsOrFn)
        local args = parseArguments(optionsOrFn)
        local options = args.options
        local handler = args.handler
        if type(suiteOptions) == "table" then
            options = mergeDefaults({}, suiteOptions, options)
        end
        options.sequential = self.sequential or (options and options.sequential)
        local test = task(formatName(name), mergeDefaults({
            handler = handler,
        }, self, options))
        test.type = "test"
        return test
    end)

    --- 清空任务
    local function clear()
        for i = #tasks, 1, -1 do
            tasks[i] = nil
        end
        initSuite(false)
    end

    ---收集任务
    ---@param file File
    ---@return Suite
    local function collect(file)
        if not file then
            error("File is required to collect tasks.", 2)
        end

        if factory then
            runWithSuite(collector, function()
                factory(test)
            end)
        end

        ---@type Task[]
        local allChildren = {}

        for _, item in ipairs(tasks) do
            if item.type == 'collector' then
                ---@cast item SuiteCollector
                table.insert(allChildren, item.collect(file))
            else
                table.insert(allChildren, item)
            end
        end

        suite.tasks = allChildren
        return suite
    end

    ---@type SuiteCollector
    collector = {
        type = 'collector',
        name = name,
        mode = mode,
        suite = suite,
        options = suiteOptions,
        test = test,
        tasks = tasks,
        collect = collect,
        task = task,
        clear = clear,
        on = function(hookName, ...)
            local hooks = getHooks(suite)
            local hookList = hooks[hookName]
            if hookList then
                for _, fn in ipairs({ ... }) do
                    table.insert(hookList, fn)
                end
            end
        end,
    }

    collectTask(collector)
    return collector
end



---@class _Suite
local SuiteMeta = {}
SuiteMeta.__index = SuiteMeta ---@package

---@param name string
---@param factoryOrOptions SuiteFactory | TestOptions
SuiteMeta.__call = function(self, context, name, factoryOrOptions)
    local mode = "run" ---@type RunMode
    if context.only then
        mode = "only"
    elseif context.skip then
        mode = "skip"
    elseif context.todo then
        mode = "todo"
    end
    ---@type SuiteCollector?
    local currentSuite = collectorContext.currentSuite or defaultSuite
    local parsed = parseArguments(factoryOrOptions)
    local options = parsed.options
    local factory = parsed.handler
    if mode == "run" and not factory then
        mode = "todo"
    end

    local isSequentialSpecified = options.sequential or context.sequential
    -- 从当前套件继承选项
    options = mergeDefaults({
        shuffle = selectValue(context.shuffle, options.shuffle,
            (currentSuite and currentSuite.options and currentSuite.options.shuffle),
            (runner and runner.config.sequence.shuffle)),
    }, currentSuite and currentSuite.options or {}, options)
    ---@cast options TestOptions
    -- 继承套件中的顺序特性
    options.sequential = isSequentialSpecified or options.sequential
    return createSuiteCollector(formatName(name), factory, mode, options)
end

-- 创建 Suite
---@return SuiteAPI
local function createSuite()
    local suite = setmetatable({}, SuiteMeta)
    local suiteAPI = createChainable({
        'sequential', 'shuffle', 'skip', 'only', 'todo'
    }, suite)
    return suiteAPI
end

---@readonly
---@type SuiteAPI
local suite = createSuite()
export.suite = suite

---@readonly
---@type TestAPI
local test = createTest(function(self, name, optionsOrFn)
    if getCurrentTest() then
        error(
            "Calling the test function inside another test function is not allowed. Please put it inside \"describe\" or \"suite\" so it can be properly collected.",
            2)
    end
    ---@diagnostic disable-next-line: undefined-field
    getCurrentSuite().test.fn(
        self,
        formatName(name),
        optionsOrFn
    )
end)
export.test = test

export.describe = export.suite
export.it = export.test


---@param runner Runner
---@return SuiteCollector
local function createDefaultSuite(runner)
    local collector = suite('', function() end)
    -- 没有顶级套件
    collector.suite = nil
    return collector
end

---清空收集器上下文
---@param file File
---@param currentRunner Runner
function export.clearCollectorContext(file, currentRunner)
    if defaultSuite == nil then
        defaultSuite = createDefaultSuite(currentRunner)
    end
    defaultSuite.file = file
    runner = currentRunner
    currentTestFilepath = file.filepath
    for i = #collectorContext.tasks, 1, -1 do
        collectorContext.tasks[i] = nil
    end
    defaultSuite.clear()
    collectorContext.currentSuite = defaultSuite
end

---获取默认套件
---@return SuiteCollector
function export.getDefaultSuite()
    return defaultSuite
end

return export
