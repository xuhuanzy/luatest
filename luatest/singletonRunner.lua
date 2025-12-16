---@namespace Luatest

local worker = require("luatest.core.runtime.worker")

local isRunning = false

-- 提供单文件直接执行测试的功能
---@export global
return setmetatable({}, {
    __call = function(self)
        -- 检查是否在 CLI 模式

        -- 检查是否已经运行
        if isRunning then
            return
        end
        isRunning = true


        -- 检查是否为单文件直接运行
        if not arg or not arg[0] then
            error("require('luatest.runner')() 只能在直接运行测试文件时调用", 2)
        end
        local currentFile = arg[0]

        worker.run({
            config = {
                isolate = true,
                clearMocks = false,
                mockReset = false,
                restoreMocks = false,
                unstubGlobals = false,
                sequence = {
                    shuffle = false,
                }
            },
            files = { currentFile },
        })



        -- -- 加载 SimpleRunner
        -- local SimpleRunner = require("luatest.runner.SimpleRunner")

        -- -- 合并配置
        -- local defaultConfig = {
        --     root = ".",
        --     testTimeout = 5000,
        --     hookTimeout = 10000,
        --     retry = 0,
        -- }

        -- local finalConfig = config or {}
        -- for k, v in pairs(defaultConfig) do
        --     if finalConfig[k] == nil then
        --         finalConfig[k] = v
        --     end
        -- end

        -- local runnerInstance = SimpleRunner.new(finalConfig)
        -- local currentFile = arg[0]


        -- -- 收集并运行测试
        -- local files = collect.collectTests({ currentFile }, runnerInstance)
        -- run.runFiles(files, runnerInstance)

        -- 清除标记
        isRunning = false

        -- 退出程序
        os.exit(0)
    end
})
