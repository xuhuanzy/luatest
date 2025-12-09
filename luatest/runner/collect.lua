-- 测试收集器
-- 实现 describe, test, it 等 API
-- 管理全局收集上下文

---@type Suite? 当前正在定义的 Suite
local currentSuite = nil

---@type Suite[] Suite 栈
local suiteStack = {}

---@type File? 当前文件任务
local currentFile = nil

-- 生成唯一 ID
local idCounter = 0
local function generateId()
    idCounter = idCounter + 1
    return tostring(idCounter)
end

-- 重置收集上下文
local function resetContext()
    currentSuite = nil
    suiteStack = {}
    currentFile = nil
    idCounter = 0
end

-- 推入 Suite 到栈
---@param suite Suite
local function pushSuite(suite)
    table.insert(suiteStack, suite)
    currentSuite = suite
end

-- 从栈弹出 Suite
local function popSuite()
    table.remove(suiteStack)
    currentSuite = suiteStack[#suiteStack]
end

-- 创建 Suite
---@param name string Suite 名称
---@param fn fun() Suite 定义函数
---@return Suite
local function createSuite(name, fn)
    ---@type Suite
    local suite = {
        id = generateId(),
        name = name,
        type = "suite",
        mode = "run",
        file = currentFile,
        tasks = {},
        beforeAllHooks = {},
        afterAllHooks = {},
        beforeEachHooks = {},
        afterEachHooks = {},
    }
    return suite
end

-- 创建 Test
---@param name string 测试名称
---@param fn fun(context: TestContext) 测试函数
---@return Test
local function createTest(name, fn)
    if not currentSuite then
        error("test() must be called inside describe()", 2)
    end

    ---@type Test
    local test = {
        id = generateId(),
        name = name,
        type = "test",
        mode = "run",
        file = currentFile,
        suite = currentSuite,
        fn = fn,
        context = {},
        timeout = 5000,
    }
    return test
end

-- describe API
---@param name string Suite 名称
---@param fn fun() Suite 定义函数
local function describe(name, fn)
    local suite = createSuite(name, fn)

    if currentSuite then
        table.insert(currentSuite.tasks, suite)
    elseif currentFile then
        table.insert(currentFile.suites, suite)
    end

    pushSuite(suite)
    fn()
    popSuite()
end

-- test API
---@param name string 测试名称
---@param fn fun(context: TestContext) 测试函数
local function test(name, fn)
    local testTask = createTest(name, fn)
    if currentSuite then
        table.insert(currentSuite.tasks, testTask)
    end
end

-- it 是 test 的别名
local it = test

-- beforeAll 钩子
---@param fn fun() 钩子函数
local function beforeAll(fn)
    if not currentSuite then
        error("beforeAll() must be called inside describe()", 2)
    end
    table.insert(currentSuite.beforeAllHooks, fn)
end

-- afterAll 钩子
---@param fn fun() 钩子函数
local function afterAll(fn)
    if not currentSuite then
        error("afterAll() must be called inside describe()", 2)
    end
    table.insert(currentSuite.afterAllHooks, fn)
end

-- beforeEach 钩子
---@param fn fun(context: TestContext) 钩子函数
local function beforeEach(fn)
    if not currentSuite then
        error("beforeEach() must be called inside describe()", 2)
    end
    table.insert(currentSuite.beforeEachHooks, fn)
end

-- afterEach 钩子
---@param fn fun(context: TestContext) 钩子函数
local function afterEach(fn)
    if not currentSuite then
        error("afterEach() must be called inside describe()", 2)
    end
    table.insert(currentSuite.afterEachHooks, fn)
end

-- 收集测试文件
---@param filepaths string[] 文件路径列表
---@param runner Runner Runner 实例
---@return File[] 文件任务列表
local function collectTests(filepaths, runner)
    local files = {}

    if runner.onBeforeCollect then
        runner:onBeforeCollect(filepaths)
    end

    for _, filepath in ipairs(filepaths) do
        resetContext()

        ---@type File
        local file = {
            id = generateId(),
            name = filepath,
            type = "file",
            mode = "run",
            filepath = filepath,
            file = filepath,
            suites = {},
        }

        currentFile = file

        if runner.onCollectStart then
            runner:onCollectStart(file)
        end

        runner:importFile(filepath, "collect")

        table.insert(files, file)
    end

    if runner.onCollected then
        runner:onCollected(files)
    end

    return files
end

return {
    describe = describe,
    test = test,
    it = it,
    beforeAll = beforeAll,
    afterAll = afterAll,
    beforeEach = beforeEach,
    afterEach = afterEach,
    collectTests = collectTests,
    resetContext = resetContext,
}
