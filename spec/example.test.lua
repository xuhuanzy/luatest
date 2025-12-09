-- 测试用例示例
-- 演示如何使用 luatest API
-- 如果是直接运行此文件，执行测试
require("luatest.runner")()

local luatest = require("luatest")
local describe = luatest.describe
local test = luatest.test
local it = luatest.it
local beforeEach = luatest.beforeEach
local afterEach = luatest.afterEach

describe("示例测试套件", function()
    local counter = 0

    beforeEach(function(ctx)
        counter = counter + 1
        print(string.format("  [beforeEach] counter = %d", counter))
    end)

    afterEach(function(ctx)
        print(string.format("  [afterEach] counter = %d", counter))
    end)

    test("简单测试", function(ctx)
        print("    [test] 执行简单测试")
        assert(1 + 1 == 2, "1 + 1 应该等于 2")
    end)

    it("使用 it 别名", function(ctx)
        print("    [it] 执行 it 测试")
        assert(type("hello") == "string", "应该是字符串类型")
    end)

    test("测试上下文", function(ctx)
        print("    [test] 测试上下文")
        assert(ctx.task ~= nil, "context.task 应该存在")
        assert(ctx.task.name == "测试上下文", "任务名称应该匹配")
    end)

    describe("嵌套套件", function()
        test("嵌套测试1", function(ctx)
            print("      [nested] 嵌套测试1")
            assert(counter > 0, "counter 应该大于 0")
        end)

        test("嵌套测试2", function(ctx)
            print("      [nested] 嵌套测试2")
            assert(true, "总是通过")
        end)
    end)
end)

describe("B", function()
    test('B1', function()
        assert(true, "总是通过")
    end)
end)
