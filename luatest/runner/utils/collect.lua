local processError = require("luatest.utils.error")
---@namespace Luatest



---@export namespace
local export = {}

-- 生成字符串哈希
---@param str string
---@return string
local function generateHash(str)
    local hash = 0
    if #str == 0 then
        return tostring(hash)
    end
    for i = 1, #str do
        local char = string.byte(str, i)
        hash = ((hash << 5) - hash) + char
        hash = hash & 0xFFFFFFFF -- 转为32位整数
    end
    return tostring(hash)
end
export.generateHash = generateHash

-- 生成文件哈希
---@param file string 相对于项目根目录的文件路径
---@param projectName string? 项目名称
---@return string
local function generateFileHash(file, projectName)
    return generateHash(file .. (projectName or ""))
end
export.generateFileHash = generateFileHash

-- 创建文件任务
---@param filepath string
---@param root string
---@param projectName string?
---@return File
local function createFileTask(filepath, root, projectName)
    -- 获取相对路径
    local path = filepath
    if root and #root > 0 then
        -- 简单的相对路径处理
        if filepath:sub(1, #root) == root then
            path = filepath:sub(#root + 1)
            if path:sub(1, 1) == "/" or path:sub(1, 1) == "\\" then
                path = path:sub(2)
            end
        end
    end

    ---@type File
    local file = {
        id = generateFileHash(path, projectName),
        name = path,
        fullName = path,
        type = "suite",
        mode = "queued",
        filepath = filepath,
        tasks = {},
        ---@diagnostic disable-next-line: assign-type-mismatch
        file = nil,
        projectName = projectName,
    }
    file.file = file
    return file
end
export.createFileTask = createFileTask

-- 计算Suite的哈希值
---@param parent Suite
local function calculateSuiteHash(parent)
    for idx, t in ipairs(parent.tasks) do
        t.id = parent.id .. "_" .. idx
        if t.type == "suite" then
            calculateSuiteHash(t)
        end
    end
end
export.calculateSuiteHash = calculateSuiteHash

-- 检查是否有任务标记为only
---@param suite Suite
---@return boolean
local function someTasksAreOnly(suite)
    for _, t in ipairs(suite.tasks) do
        if t.mode == "only" then
            return true
        end
        if t.type == "suite" and someTasksAreOnly(t) then
            return true
        end
    end
    return false
end
export.someTasksAreOnly = someTasksAreOnly

-- 获取任务完整名称
---@param task TaskBase
---@return string
local function getTaskFullName(task)
    if task.suite then
        return getTaskFullName(task.suite) .. " " .. task.name
    end
    return task.name
end

-- 跳过所有任务
---@param suite Suite
local function skipAllTasks(suite)
    for _, t in ipairs(suite.tasks) do
        if t.mode == "run" or t.mode == "queued" then
            t.mode = "skip"
            if t.type == "suite" then
                skipAllTasks(t)
            end
        end
    end
end

-- 将所有任务标记为todo
---@param suite Suite
local function todoAllTasks(suite)
    for _, t in ipairs(suite.tasks) do
        if t.mode == "run" or t.mode == "queued" then
            t.mode = "todo"
            if t.type == "suite" then
                todoAllTasks(t)
            end
        end
    end
end

-- 检查是否允许`only`修饰符
---@param task TaskBase
---@param allowOnly boolean?
local function checkAllowOnly(task, allowOnly)
    if allowOnly then
        return
    end
    local err = processError(
        "Unexpected .only modifier. Remove it or pass allowOnly option to bypass this error"
    )

    task.result = {
        state = "fail",
        errors = { err },
    }
end

-- 解释任务模式.
---@param file Suite
---@param namePattern string? 测试名称匹配模式
---@param onlyMode boolean? 是否有only任务
---@param parentIsOnly boolean? 父级是否为only
---@param allowOnly boolean? 是否允许only修饰符
function export.interpretTaskModes(file, namePattern, onlyMode, parentIsOnly, allowOnly)
    ---@param suite Suite
    ---@param pIsOnly boolean?
    local function traverseSuite(suite, pIsOnly)
        local suiteIsOnly = pIsOnly or suite.mode == "only"

        for _, t in ipairs(suite.tasks) do
            -- 检查父suite或任务本身是否标记为included
            local includeTask = suiteIsOnly or t.mode == "only"

            if onlyMode then
                if t.type == "suite" and (includeTask or export.someTasksAreOnly(t)) then
                    -- 不跳过这个suite
                    if t.mode == "only" then
                        checkAllowOnly(t, allowOnly)
                        t.mode = "run"
                    end
                elseif t.mode == "run" and not includeTask then
                    t.mode = "skip"
                elseif t.mode == "only" then
                    checkAllowOnly(t, allowOnly)
                    t.mode = "run"
                end
            end

            if t.type == "test" then
                if namePattern and not string.match(getTaskFullName(t), namePattern) then
                    t.mode = "skip"
                end
            elseif t.type == "suite" then
                if t.mode == "skip" then
                    skipAllTasks(t)
                elseif t.mode == "todo" then
                    todoAllTasks(t)
                else
                    traverseSuite(t, includeTask)
                end
            end
        end

        -- 如果所有子任务都被跳过, 标记为skip
        if suite.mode == "run" or suite.mode == "queued" then
            local allSkipped = #suite.tasks > 0
            for _, t in ipairs(suite.tasks) do
                if t.mode == "run" or t.mode == "queued" then
                    allSkipped = false
                    break
                end
            end
            if allSkipped then
                suite.mode = "skip"
            end
        end
    end

    traverseSuite(file, parentIsOnly)
end

return export
