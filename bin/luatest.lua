#!/usr/bin/env lua
-- luatest CLI 工具
-- 用于批量运行测试文件

local luatest = require("luatest")
local SimpleRunner = require("luatest.runner.SimpleRunner")

-- 设置 CLI 模式标记（防止测试文件中的 runner() 执行）
package.loaded["_luatest_cli_mode"] = true

-- 解析命令行参数
local testFiles = {}
local config = {
    root = ".",
    testTimeout = 5000,
    hookTimeout = 10000,
    retry = 0,
}

local i = 1
while i <= #arg do
    local param = arg[i]

    if param == "--timeout" then
        i = i + 1
        config.testTimeout = tonumber(arg[i])
    elseif param == "--retry" then
        i = i + 1
        config.retry = tonumber(arg[i])
    elseif param == "--help" or param == "-h" then
        print([[
luatest - Lua 测试框架

用法:
  lua bin/luatest.lua [选项] <测试文件...>

选项:
  --timeout <毫秒>   设置测试超时时间 (默认: 5000)
  --retry <次数>     设置失败重试次数 (默认: 0)
  --help, -h         显示此帮助信息

示例:
  lua bin/luatest.lua spec/example.test.lua
  lua bin/luatest.lua spec/*.test.lua
  lua bin/luatest.lua --timeout 10000 --retry 2 spec/example.test.lua
]])
        os.exit(0)
    elseif param:sub(1, 1) ~= "-" then
        table.insert(testFiles, param)
    else
        print("未知选项: " .. param)
        print("使用 --help 查看帮助")
        os.exit(1)
    end

    i = i + 1
end

-- 检查是否提供了测试文件
if #testFiles == 0 then
    print("错误: 未指定测试文件")
    print("使用 --help 查看帮助")
    os.exit(1)
end

-- 创建 Runner
local runner = SimpleRunner.new(config)

print(string.format("🚀 运行 %d 个测试文件...\n", #testFiles))

-- 标记正在运行
package.loaded["_luatest_running"] = true

-- 收集所有测试
local files = luatest.collectTests(testFiles, runner)

-- 运行测试
luatest.runFiles(files, runner)

-- 清除标记
package.loaded["_luatest_running"] = nil
package.loaded["_luatest_cli_mode"] = nil

print("\n✅ 所有测试完成!")
