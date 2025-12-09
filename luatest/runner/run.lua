-- 测试执行引擎
-- 负责运行 Suite 和 Test
-- 处理生命周期钩子和错误

local types = require("luatest.types")

-- 创建 TestContext
---@param test Test
---@return TestContext
local function createContext(test)
    ---@type TestContext
    local context = {
        task = test,
        skip = function(note)
            local err = { type = "skip", note = note }
            error(err, 2)
        end,
        onTestFailed = function(self, fn, timeout)
            if not test.onFailed then test.onFailed = {} end
            table.insert(test.onFailed, fn)
        end,
        onTestFinished = function(self, fn, timeout)
            if not test.onFinished then test.onFinished = {} end
            table.insert(test.onFinished, fn)
        end,
    }
    return context
end

-- 执行钩子列表
---@param hooks fun()[]
---@param context TestContext?
local function runHooks(hooks, context)
    for _, hook in ipairs(hooks) do
        if context then
            hook(context)
        else
            hook()
        end
    end
end

-- 执行单个测试
---@param test Test
---@param runner Runner
local function runTest(test, runner)
    test.result = { state = "run", startTime = os.time() }

    if runner.onBeforeRunTask then
        runner:onBeforeRunTask(test)
    end

    local startTime = os.clock()

    -- 收集 beforeEach 钩子(包括父 Suite)
    local beforeEachHooks = {}
    local suite = test.suite
    while suite do
        for i = #suite.beforeEachHooks, 1, -1 do
            table.insert(beforeEachHooks, 1, suite.beforeEachHooks[i])
        end
        suite = suite.suite
    end

    -- 收集 afterEach 钩子
    local afterEachHooks = {}
    suite = test.suite
    while suite do
        for _, hook in ipairs(suite.afterEachHooks) do
            table.insert(afterEachHooks, hook)
        end
        suite = suite.suite
    end

    -- 创建上下文
    local context = createContext(test)
    test.context = context

    if runner.extendTaskContext then
        context = runner:extendTaskContext(context)
        test.context = context
    end

    -- 执行测试(带 retry 逻辑)
    local maxRetries = test.retry or runner.config.retry or 0
    local retryCount = 0
    local success = false
    local lastError = nil

    while retryCount <= maxRetries and not success do
        -- beforeEach hooks
        local hookOk, hookErr = pcall(function()
            runHooks(beforeEachHooks, context)
        end)

        if not hookOk then
            test.result.state = "fail"
            test.result.errors = test.result.errors or {}
            table.insert(test.result.errors, {
                message = "beforeEach hook failed: " .. tostring(hookErr),
                stack = debug.traceback(),
            })
            break
        end

        -- 执行测试函数
        local testOk, testErr = pcall(function()
            test.fn(context)
        end)

        -- afterEach hooks (总是执行)
        pcall(function()
            runHooks(afterEachHooks, context)
        end)

        if testOk then
            success = true
            test.result.state = "pass"
        elseif testErr and type(testErr) == "table" and testErr.type == "skip" then
            test.result.state = "skip"
            success = true
        else
            lastError = testErr
            retryCount = retryCount + 1
        end
    end

    if not success then
        test.result.state = "fail"
        test.result.errors = test.result.errors or {}
        table.insert(test.result.errors, {
            message = tostring(lastError),
            stack = debug.traceback(),
        })
        test.result.retryCount = retryCount - 1
    end

    test.result.duration = (os.clock() - startTime) * 1000

    -- onTestFailed 回调
    if test.result.state == "fail" and test.onFailed then
        for _, fn in ipairs(test.onFailed) do
            pcall(fn, context)
        end
    end

    -- onTestFinished 回调
    if test.onFinished then
        for _, fn in ipairs(test.onFinished) do
            pcall(fn, context)
        end
    end

    if runner.onAfterRunTask then
        runner:onAfterRunTask(test)
    end

    if runner.onTaskUpdate then
        runner:onTaskUpdate(test)
    end
end

-- 递归执行 Suite
---@param suite Suite
---@param runner Runner
local function runSuite(suite, runner)
    if runner.onBeforeRunSuite then
        runner:onBeforeRunSuite(suite)
    end

    local ok, err = pcall(function()
        runHooks(suite.beforeAllHooks)
    end)

    if not ok then
        suite.result = {
            state = "fail",
            errors = { { message = "beforeAll failed: " .. tostring(err), stack = debug.traceback() } },
        }
        for _, task in ipairs(suite.tasks) do
            task.result = { state = "skip" }
        end
    else
        for _, task in ipairs(suite.tasks) do
            if task.type == "suite" then
                runSuite(task, runner)
            elseif task.type == "test" then
                runTest(task, runner)
            end
        end
    end

    pcall(function()
        runHooks(suite.afterAllHooks)
    end)

    if runner.onAfterRunSuite then
        runner:onAfterRunSuite(suite)
    end
end

-- 执行文件列表
---@param files File[]
---@param runner Runner
local function runFiles(files, runner)
    if runner.onBeforeRunFiles then
        runner:onBeforeRunFiles(files)
    end

    for _, file in ipairs(files) do
        for _, suite in ipairs(file.suites) do
            runSuite(suite, runner)
        end
    end

    if runner.onAfterRunFiles then
        runner:onAfterRunFiles(files)
    end
end

return {
    runTest = runTest,
    runSuite = runSuite,
    runFiles = runFiles,
    createContext = createContext,
}
