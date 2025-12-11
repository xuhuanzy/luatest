---@namespace Luatest

---@export namespace
local export = {}

-- 解决循环引用问题
---@[lsp_optimization("delayed_definition")]
local _getCurrentSuite
---@[lsp_optimization("delayed_definition")]
local _getCurrentTest

---@return SuiteCollector
local function getCurrentSuite()
    if not _getCurrentSuite then
        _getCurrentSuite = require("luatest.runner.suite").getCurrentSuite
    end
    return _getCurrentSuite()
end

---@return Test?
local function getCurrentTest()
    if not _getCurrentTest then
        _getCurrentTest = require("luatest.runner.test-state").getCurrentTest
    end
    return _getCurrentTest()
end


-- 注册一个回调函数, 在开始运行当前上下文中的所有测试之前调用一次
--
---@param fn BeforeAllListener 回调函数
export.beforeAll = function(fn)
    assert(type(fn) == 'function', '"beforeAll" callback must be a function')
    getCurrentSuite().on('beforeAll', fn)
end



-- 注册一个回调函数, 在当前上下文中所有测试运行完毕后调用一次.
--
-- **注意:** afterAll 钩子按注册的相反顺序执行.
---@param fn AfterAllListener 回调函数
export.afterAll = function(fn)
    assert(type(fn) == 'function', '"afterAll" callback must be a function')
    getCurrentSuite().on('afterAll', fn)
end

-- 注册一个回调函数, 在当前上下文中的每个测试运行前调用.
--
-- **注意:** beforeEach 钩子按定义顺序执行
---@param fn BeforeEachListener 回调函数
export.beforeEach = function(fn)
    assert(type(fn) == 'function', '"beforeEach" callback must be a function')
    getCurrentSuite().on('beforeEach', fn)
end

-- 注册一个回调函数, 在当前上下文中的每个测试运行后调用.
--
-- **注意:** afterEach 钩子按注册的相反顺序执行.
---@param fn AfterEachListener 回调函数
export.afterEach = function(fn)
    assert(type(fn) == 'function', '"afterEach" callback must be a function')
    getCurrentSuite().on('afterEach', fn)
end


---创建测试钩子
---@param name string 钩子名称
---@param handler fun(test: Test, fn: function) 处理函数
---@return fun(fn: function)
local function createTestHook(name, handler)
    return function(fn)
        assert(type(fn) == 'function', string.format('"%s" callback must be a function', name))

        local current = getCurrentTest()
        if not current then
            error(string.format('Hook %s() can only be called inside a test', name), 2)
        end

        return handler(current, fn)
    end
end

-- 注册一个回调函数, 当测试失败时调用. 由于`afterEach`可能会影响测试结果, 因此它在`afterEach`之后调用.
--
-- **注意:** onTestFailed 钩子按注册的相反顺序执行
---@type fun(fn: OnTestFailedHandler)
export.onTestFailed = createTestHook('onTestFailed', function(test, fn)
    test.onFailed = test.onFailed or {}
    table.insert(test.onFailed, fn)
end)

-- 注册一个回调函数, 当测试结束时调用(无论成功或失败). 由于`afterEach`可能会影响测试结果, 因此它在`afterEach`之后调用.
--
-- **注意:** onTestFinished 钩子按注册的相反顺序执行
---@type fun(fn: OnTestFinishedHandler)
export.onTestFinished = createTestHook('onTestFinished', function(test, fn)
    test.onFinished = test.onFinished or {}
    table.insert(test.onFinished, fn)
end)

return export
