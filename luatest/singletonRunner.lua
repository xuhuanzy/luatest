---@diagnostic disable: return-type-mismatch, cast-type-mismatch
---@namespace Luatest

local core = require("luatest.core")
local bootstrap = require("luatest.core.bootstrap-state")

-- 提供单文件直接执行测试的功能
return setmetatable({}, {
    __call = function(self)
        -- CLI 模式下静默 no-op（便于手动调试时保留该入口）
        if bootstrap.isCliMode() then
            return
        end

        -- 检查是否已经运行
        if bootstrap.hasRun() then
            return
        end

        local ok, resultOrErr = pcall(function()
            if not arg or not arg[0] then
                error("require('luatest.singletonRunner')() 只能在直接运行测试文件时调用", 2)
            end

            local currentFile = arg[0]

            if not currentFile:match("%.lua$") then
                error("arg[0] 必须是一个 .lua 文件: " .. currentFile, 2)
            end

            local file = io.open(currentFile, "r")
            if not file then
                error("无法打开文件，请检查路径是否正确: " .. currentFile, 2)
            end
            file:close()

            return core.run({
                files = { currentFile },
            })
        end)

        if not ok then
            error(resultOrErr, 2)
        end

        ---@cast resultOrErr RunResult
        os.exit(resultOrErr.exitCode or 0)
    end
})
