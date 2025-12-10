local collectorContext = require("luatest.runner.context").collectorContext
local defaultsTable = require('luatest.utils.utils').defaultsTable
local selectValue = require('luatest.utils.utils').selectValue
local setHooks = require("luatest.runner.map").setHooks
local setFn = require("luatest.runner.map").setFn
local getHooks = require("luatest.runner.map").getHooks
local createContext = require("luatest.runner.context").createContext
local collectTask = require("luatest.runner.context").collectTask


---@namespace Luatest

---@type Runner
local runner
---@type SuiteCollector
local defaultSuite

---@return SuiteHooks
local function createSuiteHooks()
    return {
        beforeAll = {},
        afterAll = {},
        beforeEach = {},
        afterEach = {},
    }
end

---@type string
local currentTestFilepath

-- ID 计数器
local idCounter = 0

---生成唯一 ID
---@return string
local function generateId()
    idCounter = idCounter + 1
    return tostring(idCounter)
end

---重置 ID 计数器
local function resetIdCounter()
    idCounter = 0
end


---创建任务的完整名称
---@param parts (string|nil)[]
---@param separator? string
---@return string
local function createTaskName(parts, separator)
    local result = {}
    for _, part in ipairs(parts) do
        if part and part ~= "" then
            table.insert(result, part)
        end
    end
    return table.concat(result, separator or " > ")
end

---格式化名称
---@param name string|function
---@return string
local function formatName(name)
    if type(name) == 'string' then
        return name
    elseif type(name) == 'function' then
        local info = debug.getinfo(name, "n")
        return info and info.name or '<anonymous>'
    else
        return tostring(name)
    end
end

---在指定 suite 上下文中运行函数
---@param collector SuiteCollector
---@param fn function
local function runWithSuite(collector, fn)
    local prevSuite = collectorContext.currentSuite
    collectorContext.currentSuite = collector
    fn()
    collectorContext.currentSuite = prevSuite
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
---@param factory? SuiteFactory 工厂函数
---@param mode RunMode 运行模式
---@param suiteOptions? TestOptions 套件选项
---@return SuiteCollector
local function createSuiteCollector(name, factory, mode, suiteOptions)
    factory = factory or function() end

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
            setFn(task, handler)
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
    local test

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
            local prevSuite = collectorContext.currentSuite
            collectorContext.currentSuite = collector
            factory(collector.test)
            collectorContext.currentSuite = prevSuite
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
SuiteMeta.__index = SuiteMeta
---@param name string
---@param factoryOrOptions SuiteFactory | TestOptions
SuiteMeta.__call = function(self, name, factoryOrOptions)
    local mode = "run" ---@type RunMode
    if self.only then
        mode = "only"
    elseif self.skip then
        mode = "skip"
    elseif self.todo then
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

    local isSequentialSpecified = options.sequential or self.sequential
    -- 从当前套件继承选项
    options = defaultsTable({
        shuffle = selectValue(self.shuffle, options.shuffle,
            (currentSuite and currentSuite.options and currentSuite.options.shuffle),
            (runner and runner.config.sequence.shuffle)),
    }, currentSuite and currentSuite.options or {}, options)
    ---@cast options TestOptions
    -- 继承套件中的顺序特性
    options.sequential = isSequentialSpecified or options.sequential
end

-- 创建 Suite
---@return SuiteAPI
local function createSuite()

end
