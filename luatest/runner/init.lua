-- Runner 主模块
-- 导出收集和执行相关的 API

local collect = require("luatest.runner.collect")
local run = require("luatest.runner.run")

local runner = {
    -- 收集器 API
    describe = collect.describe,
    test = collect.test,
    it = collect.it,
    beforeAll = collect.beforeAll,
    afterAll = collect.afterAll,
    beforeEach = collect.beforeEach,
    afterEach = collect.afterEach,
    collectTests = collect.collectTests,

    -- 执行器 API
    runTest = run.runTest,
    runSuite = run.runSuite,
    runFiles = run.runFiles,
    createContext = run.createContext,
}

-- 设置元表，使模块可调用
-- 用法: require("luatest.runner")()
setmetatable(runner, {
    __call = function(self, config)
        -- 检查是否在 CLI 模式
        if package.loaded["_luatest_cli_mode"] then
            -- CLI 模式下不执行
            return
        end

        -- 检查是否已经运行
        if package.loaded["_luatest_running"] then
            return
        end

        -- 检查是否为单文件直接运行
        if not arg or not arg[0] then
            error("require('luatest.runner')() 只能在直接运行测试文件时调用", 2)
        end

        -- 标记正在运行
        package.loaded["_luatest_running"] = true

        -- 加载 SimpleRunner
        local SimpleRunner = require("luatest.runner.SimpleRunner")

        -- 合并配置
        local defaultConfig = {
            root = ".",
            testTimeout = 5000,
            hookTimeout = 10000,
            retry = 0,
        }

        local finalConfig = config or {}
        for k, v in pairs(defaultConfig) do
            if finalConfig[k] == nil then
                finalConfig[k] = v
            end
        end

        local runnerInstance = SimpleRunner.new(finalConfig)
        local currentFile = arg[0]

        print("🚀 运行测试文件: " .. currentFile .. "\n")

        -- 收集并运行测试
        local files = collect.collectTests({ currentFile }, runnerInstance)
        run.runFiles(files, runnerInstance)

        -- 清除标记
        package.loaded["_luatest_running"] = nil

        -- 退出程序
        os.exit(0)
    end
})

return runner
