---@namespace Luatest

local processError = require("luatest.utils.error").processError
local setFileContext = require("luatest.runner.context").setFileContext
local clearCollectorContext = require("luatest.runner.suite").clearCollectorContext
local createFileTask = require("luatest.runner.utils.collect").createFileTask
local getDefaultSuite = require("luatest.runner.suite").getDefaultSuite
local createSuiteHooks = require("luatest.runner.suite").createSuiteHooks
local getHooks = require("luatest.runner.map").getHooks
local collectorContext = require("luatest.runner.context").collectorContext
local setHooks = require("luatest.runner.map").setHooks
local calculateSuiteHash = require("luatest.runner.utils.collect").calculateSuiteHash
local someTasksAreOnly = require("luatest.runner.utils.collect").someTasksAreOnly
local interpretTaskModes = require("luatest.runner.utils.collect").interpretTaskModes

---@export namespace
local export = {}


-- 合并hooks
---@param baseHooks SuiteHooks
---@param hooks SuiteHooks
---@return SuiteHooks
local function mergeHooks(baseHooks, hooks)
    for key, hookList in pairs(hooks) do
        for _, hook in ipairs(hookList) do
            table.insert(baseHooks[key], hook)
        end
    end
    return baseHooks
end

-- 收集测试文件
---@param specs string[] 文件路径列表
---@param runner Runner
---@return File[]
function export.collectTests(specs, runner)
    local files = {} ---@type File[]
    local config = runner.config

    for _, spec in ipairs(specs) do
        local filepath = spec

        -- 创建文件任务
        local file = createFileTask(filepath, config.root, config.name)
        setFileContext(file, {})
        file.shuffle = config.sequence.shuffle

        -- 触发收集开始回调
        if runner.onCollectStart then
            runner:onCollectStart(file)
        end

        -- 清空收集器上下文
        clearCollectorContext(file, runner)

        local ok, err = pcall(function()
            -- 导入文件, 此时会执行文件中的测试定义
            runner:importFile(filepath, "collect")

            -- 获取默认套件并收集
            local defaultTasks = getDefaultSuite().collect(file)

            local fileHooks = createSuiteHooks()
            mergeHooks(fileHooks, getHooks(defaultTasks))

            -- 处理收集到的任务
            local allTasks = {}

            -- 先添加默认套件的任务
            for _, task in ipairs(defaultTasks.tasks) do
                table.insert(allTasks, task)
            end
            -- 再添加收集器上下文的任务
            for _, task in ipairs(collectorContext.tasks) do
                table.insert(allTasks, task)
            end

            for _, c in ipairs(allTasks) do
                if c.type == "test" or c.type == "suite" then
                    table.insert(file.tasks, c)
                elseif c.type == "collector" then
                    local collectedSuite = c:collect(file)
                    if collectedSuite.name ~= "" or #collectedSuite.tasks > 0 then
                        mergeHooks(fileHooks, getHooks(collectedSuite))
                        table.insert(file.tasks, collectedSuite)
                    end
                end
            end

            setHooks(file, fileHooks)
        end)

        if not ok then
            local error = processError(err)
            file.result = {
                state = "fail",
                errors = { error },
            }
        end

        -- 计算Suite哈希
        calculateSuiteHash(file)

        -- 解释任务模式
        local hasOnlyTasks = someTasksAreOnly(file)
        interpretTaskModes(
            file,
            config.testNamePattern,
            hasOnlyTasks,
            false,
            config.allowOnly
        )

        -- 将`queued`模式改为`run`
        if file.mode == "queued" then
            file.mode = "run"
        end

        table.insert(files, file)
    end

    return files
end

return export
