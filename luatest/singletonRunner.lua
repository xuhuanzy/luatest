---@namespace Luatest

local Luatest = require("luatest.core.controller.core")

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

        -- 校验是否为 .lua 文件
        if not currentFile:match("%.lua$") then
            error("arg[0] 必须是一个 .lua 文件: " .. currentFile, 2)
        end

        -- 校验文件是否存在
        local file = io.open(currentFile, "r")
        if not file then
            error("无法打开文件，请检查路径是否正确: " .. currentFile, 2)
        end
        file:close()

        -- 初始化
        local luatest = Luatest.new()
        luatest:start({
            files = { currentFile },
        })

        -- 清除标记
        isRunning = false

        os.exit(0)
    end
})
