local getHooks = require("luatest.runner.map").getHooks
local getFn = require("luatest.runner.map").getFn
local setCurrentTest = require("luatest.runner.test-state").setCurrentTest
local addRunningTest = require("luatest.runner.test-state").addRunningTest
local processError = require("luatest.utils.error").processError
local hasTests = require("luatest.runner.utils.tasks").hasTests
local hasFailed = require("luatest.runner.utils.tasks").hasFailed
local collectTests = require("luatest.runner.collect").collectTests
local nowMs = require("luatest.utils.helpers").nowMs
local unixNow = require("luatest.utils.helpers").unixNow
local now = os.clock

---@namespace Luatest

---@export namespace
local export = {}


---反转表
---@generic T
---@param t T[]
---@return T[]
local function reverseTable(t)
    local reversed = {}
    for i = #t, 1, -1 do
        table.insert(reversed, t[i])
    end
    return reversed
end

---@type table<string, [TaskResult?, TaskMeta?]>
local packs = {}
---@type TaskEventPack[]
local eventsPacks = {}

---@param runner Runner
local function sendTasksUpdate(runner)
    if next(packs) == nil then
        return
    end

    ---@type TaskResultPack[]
    local taskPacks = {}
    for id, tuple in pairs(packs) do
        taskPacks[#taskPacks + 1] = { id, tuple[1], tuple[2] }
    end

    -- 发送任务更新
    if runner.onTaskUpdate then
        runner:onTaskUpdate(taskPacks, eventsPacks)
    end

    -- 清空事件和任务
    for i = #eventsPacks, 1, -1 do
        eventsPacks[i] = nil
    end
    for k in pairs(packs) do
        packs[k] = nil
    end
end

---@param fn fun(runner: Runner)
---@param ms number
---@return fun(runner: Runner)
local function throttle(fn, ms)
    local last = 0
    local now = nowMs()
    return function(runner)
        now = nowMs()
        if now - last > ms then
            last = now
            return fn(runner)
        end
    end
end

local sendTasksUpdateThrottled = throttle(sendTasksUpdate, 100)

---@param runner Runner
function export.finishSendTasksUpdate(runner)
    sendTasksUpdate(runner)
end

-- 更新任务状态并通知 Runner
---@param event TaskUpdateEvent
---@param task Task
---@param runner Runner
local function updateTask(event, task, runner)
    eventsPacks[#eventsPacks + 1] = { task.id, event, nil }
    packs[task.id] = { task.result, task.meta }
    sendTasksUpdateThrottled(runner)
end
export.updateTask = updateTask

-- 处理任务失败
---@param result TaskResult
---@param err any
---@param runner Runner
local function failTask(result, err, runner)
    -- 检查是否是 PendingError (skip)
    if type(err) == "table" and err.code == "LUATEST_PENDING" then
        result.state = "skip"
        result.note = err.note
        result.pending = true
        return
    end

    result.state = "fail"
    local errors = { err }
    result.errors = result.errors or {}
    for _, e in ipairs(errors) do
        local error = processError(e, runner.config and runner.config.diffOptions)
        table.insert(result.errors, error)
    end
end

---根据 sequence 配置获取 Suite 钩子列表
---@param suite Suite
---@param name keyof SuiteHooks
---@param sequence SequenceHooks
---@return function[]
local function getSuiteHooks(suite, name, sequence)
    local hooks = getHooks(suite)[name]
    if sequence == "stack" and (name == "afterAll" or name == "afterEach") then
        return reverseTable(hooks)
    end
    ---@diagnostic disable-next-line: return-type-mismatch
    return hooks
end

-- 调用 Suite 级钩子
---@param suite Suite
---@param currentTask Task
---@param name keyof SuiteHooks
---@param runner Runner
---@param args any[]
---@return any[] callbacks 清理回调列表
local function callSuiteHook(suite, currentTask, name, runner, args)
    local sequence = runner.config.sequence.hooks
    local callbacks = {}

    -- 获取父 Suite, 停在 file 级别
    ---@type Suite?
    local parentSuite = nil
    if suite['filepath'] == nil then
        -- 不是 File, 可能有父 Suite
        parentSuite = suite.suite or suite.file
    end

    -- beforeEach: 先调用父级钩子
    if name == "beforeEach" and parentSuite then
        local parentCallbacks = callSuiteHook(parentSuite, currentTask, name, runner, args)
        for _, cb in ipairs(parentCallbacks) do
            table.insert(callbacks, cb)
        end
    end

    ---@type BeforeAllListener[] | BeforeEachListener<table>[]
    local hooks = getSuiteHooks(suite, name, sequence)

    -- TODO: hooks 不为空时更新任务状态

    for _, hook in ipairs(hooks) do
        local result = hook(table.unpack(args))
        -- 如果钩子返回函数, 则将其作为清理回调
        if type(result) == "function" then
            table.insert(callbacks, result)
        end
    end

    -- TODO: hooks 不为空时更新任务状态

    -- afterEach: 后调用父级钩子
    if name == "afterEach" and parentSuite then
        local parentCallbacks = callSuiteHook(parentSuite, currentTask, name, runner, args)
        for _, cb in ipairs(parentCallbacks) do
            table.insert(callbacks, cb)
        end
    end

    return callbacks
end

-- 调用测试级钩子 (onTestFailed/onTestFinished)
---@param runner Runner
---@param test Test
---@param hooks function[]
---@param sequence SequenceHooks
local function callTestHooks(runner, test, hooks, sequence)
    if sequence == "stack" then
        hooks = reverseTable(hooks)
    end

    if #hooks == 0 then
        return
    end

    for _, fn in ipairs(hooks) do
        local ok, err = pcall(fn, test.context)
        if not ok then
            ---@diagnostic disable-next-line: param-type-mismatch
            failTask(test.result, err, runner)
        end
    end
end

-- 调用清理钩子
---@param runner Runner
---@param cleanups unknown[]
local function callCleanupHooks(runner, cleanups)
    local sequence = runner.config.sequence.hooks

    if sequence == "stack" then
        cleanups = reverseTable(cleanups)
    end

    for _, fn in ipairs(cleanups) do
        -- TODO: 执行元表 __call
        if type(fn) == "function" then
            fn()
        end
    end
end

-- 标记子任务为跳过
---@param suite Suite
---@param runner Runner
local function markTasksAsSkipped(suite, runner)
    for _, t in ipairs(suite.tasks) do
        t.mode = "skip"
        t.result = t.result or {}
        t.result.state = "skip"
        updateTask("test-finished", t, runner)
        if t.type == "suite" then
            markTasksAsSkipped(t, runner)
        end
    end
end

-- 执行单个测试
---@param test Test
---@param runner Runner
function export.runTest(test, runner)
    -- 运行前回调
    if runner.onBeforeRunTask then
        runner:onBeforeRunTask(test)
    end

    -- 跳过非运行模式的测试
    if test.mode ~= "run" and test.mode ~= "queued" then
        updateTask("test-prepare", test, runner)
        updateTask("test-finished", test, runner)
        return
    end

    -- TODO: 理论上这一步不会被触发
    if test.result and test.result.state == "fail" then
        updateTask("test-failed-early", test, runner)
        return
    end

    local start = now()

    test.result = {
        state = "run",
        startTime = unixNow(),
        retryCount = 0,
    }
    ---@cast test.result TaskResult
    updateTask("test-prepare", test, runner)

    local cleanupRunningTest = addRunningTest(test)
    setCurrentTest(test)

    local suite = test.suite or test.file

    local repeats = test.repeats or 0
    for repeatCount = 0, repeats do
        local retry = test.retry or 0
        for retryCount = 0, retry do
            local beforeEachCleanups = {} ---@type any[]

            -- 执行测试
            local ok, err = pcall(function()
                if runner.onBeforeTryTask then
                    runner:onBeforeTryTask(test, { retry = retryCount, repeats = repeatCount })
                end

                test.result.repeatCount = repeatCount
                -- beforeEach 钩子
                beforeEachCleanups = callSuiteHook(
                    suite,
                    test,
                    "beforeEach",
                    runner,
                    { test.context, suite }
                )
                if runner.runTask then
                    runner:runTask(test)
                else
                    -- 执行测试函数
                    local fn = getFn(test)
                    if not fn then
                        error("Test function is not found. Did you add it using `setFn`?")
                    end
                    fn()
                end
                if runner.onAfterTryTask then
                    runner:onAfterTryTask(test, { retry = retryCount, repeats = repeatCount })
                end

                if test.result.state ~= "fail" then
                    if not test.repeats then
                        test.result.state = "pass"
                    elseif test.repeats and retry == retryCount then
                        test.result.state = "pass"
                    end
                end
            end)

            if not ok then
                failTask(test.result, err, runner)
            end

            -- 测试完成回调
            if runner.onTaskFinished then
                local taskOk, taskErr = pcall(function()
                    runner:onTaskFinished(test)
                end)
                if not taskOk then
                    failTask(test.result, taskErr, runner)
                end
            end

            -- afterEach 钩子
            local afterOk, afterErr = pcall(function()
                callSuiteHook(suite, test, "afterEach", runner, { test.context, suite })
                if #beforeEachCleanups > 0 then
                    callCleanupHooks(runner, beforeEachCleanups)
                end
            end)
            if not afterOk then
                failTask(test.result, afterErr, runner)
            end

            -- onTestFinished 钩子
            if test.onFinished and #test.onFinished > 0 then
                callTestHooks(runner, test, test.onFinished, "stack")
            end

            -- onTestFailed 钩子
            if test.result.state == "fail" and test.onFailed and #test.onFailed > 0 then
                callTestHooks(runner, test, test.onFailed, runner.config.sequence.hooks)
            end

            test.onFailed = nil
            test.onFinished = nil

            if runner.onAfterRetryTask then
                runner:onAfterRetryTask(test, { retry = retryCount, repeats = repeatCount })
            end

            -- 检查是否跳过 PendingError
            if (test.result and test.result.pending) or (test.result and test.result.state == "skip") then
                test.mode = "skip"
                test.result = {
                    state = "skip",
                    note = test.result.note,
                    pending = true,
                    duration = (now() - start) * 1000,
                }
                updateTask("test-finished", test, runner)
                setCurrentTest(nil)
                cleanupRunningTest()
                return
            end

            -- 通过则跳出重试循环
            if test.result.state == "pass" then
                break
            end

            -- 重试
            if retryCount < retry then
                test.result.state = "run"
                test.result.retryCount = (test.result.retryCount or 0) + 1
            end

            -- 更新测试信息
            updateTask("test-retried", test, runner)
        end
    end

    -- 如果测试标记为失败, 则反转结果
    if test.fails then
        if test.result.state == "pass" then
            local error = processError({ message = "Expect test to fail" })
            test.result.state = "fail"
            test.result.errors = { error }
        else
            test.result.state = "pass"
            test.result.errors = nil
        end
    end

    cleanupRunningTest()
    setCurrentTest(nil)

    test.result.duration = (now() - start) * 1000

    -- 运行后回调
    if runner.onAfterRunTask then
        runner:onAfterRunTask(test)
    end

    updateTask("test-finished", test, runner)
end

---执行 Suite
---@param suite Suite
---@param runner Runner
function export.runSuite(suite, runner)
    -- 运行前回调
    if runner.onBeforeRunSuite then
        runner:onBeforeRunSuite(suite)
    end

    -- 如果收集阶段已失败则跳过
    if suite.result and suite.result.state == "fail" then
        markTasksAsSkipped(suite, runner)
        updateTask("suite-failed-early", suite, runner)
        return
    end

    local start = now()
    local mode = suite.mode

    suite.result = {
        state = (mode == "skip" or mode == "todo") and mode or "run",
        startTime = unixNow(),
    }

    updateTask("suite-prepare", suite, runner)

    local beforeAllCleanups = {} ---@type any[]

    if suite.mode == "skip" then
        suite.result.state = "skip"
        updateTask("suite-finished", suite, runner)
    elseif suite.mode == "todo" then
        suite.result.state = "todo"
        updateTask("suite-finished", suite, runner)
    else
        -- 正常执行
        local ok, err = pcall(function()
            -- beforeAll 钩子
            local beforeOk, beforeErr = pcall(function()
                beforeAllCleanups = callSuiteHook(suite, suite, "beforeAll", runner, { suite })
            end)
            if not beforeOk then
                markTasksAsSkipped(suite, runner)
                error(beforeErr)
            end
            if runner.runSuite then
                runner:runSuite(suite)
            else
                -- 执行所有子任务
                --TODO: 添加随机化支持
                for _, task in ipairs(suite.tasks) do
                    if task.type == "test" then
                        export.runTest(task, runner)
                    elseif task.type == "suite" then
                        export.runSuite(task, runner)
                    end
                end
            end
        end)

        if not ok then
            failTask(suite.result, err, runner)
        end

        -- afterAll 钩子和清理
        local afterOk, afterErr = pcall(function()
            callSuiteHook(suite, suite, "afterAll", runner, { suite })
            if #beforeAllCleanups > 0 then
                callCleanupHooks(runner, beforeAllCleanups)
            end
            -- TODO:文件级清理
            -- if suite.file == suite then
            --     ---@cast suite File
            --     local context = getFileContext(suite)
            -- end
        end)
        if not afterOk then
            failTask(suite.result, afterErr, runner)
        end

        -- 设置最终状态
        if suite.mode == "run" or suite.mode == "queued" then
            if not runner.config.passWithNoTests and not hasTests(suite) then
                suite.result.state = "fail"
                if not suite.result.errors or #suite.result.errors == 0 then
                    local error = processError({
                        message = string.format("No test found in suite %s", suite.name)
                    })
                    suite.result.errors = { error }
                end
            elseif hasFailed(suite) then
                suite.result.state = "fail"
            else
                suite.result.state = "pass"
            end
        end

        suite.result.duration = (now() - start) * 1000

        -- 运行后回调
        if runner.onAfterRunSuite then
            runner:onAfterRunSuite(suite)
        end

        updateTask("suite-finished", suite, runner)
    end
end

-- 执行多个文件
---@param files File[]
---@param runner Runner
function export.runFiles(files, runner)
    for _, file in ipairs(files) do
        -- 检查空文件
        if #file.tasks == 0 and not runner.config.passWithNoTests then
            if not file.result or not file.result.errors or #file.result.errors == 0 then
                local error = processError({
                    message = string.format("No test suite found in file %s", file.filepath)
                })
                file.result = {
                    state = "fail",
                    errors = { error },
                }
            end
        end

        -- 执行测试, file 也是 suite
        export.runSuite(file, runner)
    end
end

-- 开始测试.
--
-- 先收集测试文件, 然后再执行测试.
---@param specs string[] 文件路径列表
---@param runner Runner
---@return File[] files 测试文件结果
function export.startTests(specs, runner)
    local ok, result = pcall(function()
        -- 收集前回调
        if runner.onBeforeCollect then
            runner:onBeforeCollect(specs)
        end

        -- 收集测试
        local files = collectTests(specs, runner)

        -- 收集后回调
        if runner.onCollected then
            runner:onCollected(files)
        end

        -- 运行文件前回调
        if runner.onBeforeRunFiles then
            runner:onBeforeRunFiles(files)
        end

        -- 执行测试
        export.runFiles(files, runner)

        -- 运行文件后回调
        if runner.onAfterRunFiles then
            runner:onAfterRunFiles(files)
        end

        export.finishSendTasksUpdate(runner)
        return files
    end)
    if not ok then
        error(result)
    end
    ---@cast result -string

    return result
end

return export
