---@namespace Luatest

---@export namespace
local export = {}

---@type Test?
local _test

-- 设置当前测试
---@param test Test?
export.setCurrentTest = function(test)
    _test = test
end

-- 获取当前测试
---@return Test?
export.getCurrentTest = function()
    return _test
end

---@type table<Test, true>
local tests = {}

-- 添加正在运行的测试
---@param test Test
---@return fun() @ 返回清理函数
export.addRunningTest = function(test)
    tests[test] = true
    return function()
        tests[test] = nil
    end
end

-- 获取所有正在运行的测试
---@return table<Test, true>
export.getRunningTests = function()
    return tests
end

return export
