---@namespace Luatest

local createFileTask = require("luatest.runner.utils.collect").createFileTask
local reportedTasks = require("luatest.core.controller.reporters.reported-tasks")

---@class StateManagerOptions
---@field root? string
---@field projectName? string
---@field onUnhandledError? fun(error: any): boolean|nil

---@class StateManager
---@field root? string # 项目根目录(替代 vitest TestProject.config.root)
---@field projectName? string # 项目名称(替代 vitest TestProject.config.name)
---@field filesMap table<string, File[]> # filepath -> File[]
---@field pathsSet table<string, boolean> # path -> true
---@field idMap table<string, Task> # taskId -> Task
---@field taskFileMap table<Task, File> # Task -> File (weak keys)
---@field errorsSet table<any, boolean> # error -> true
---@field reportedTasksMap table<Task, TestModule|TestSuite|TestCase> # Task -> reported entity (weak keys)
---@field blobs? any
---@field transformTime number
---@field onUnhandledError? fun(error: any): boolean|nil # 返回 false 表示忽略
---@field _data { browserLastPort?: number, timeoutIncreased: boolean }
local StateManager = {}

StateManager.__index = StateManager ---@package

---@param err any
---@return boolean
local function isAggregateError(err)
    return type(err) == "table" and type(err.errors) == "table"
end

---@param set table<any, boolean>
---@return any[]
local function setToArray(set)
    local arr = {}
    for k in pairs(set) do
        arr[#arr + 1] = k
    end
    return arr
end

---@param a any[]
---@param b any[]
---@return any[]
local function concatArrays(a, b)
    for i = 1, #b do
        a[#a + 1] = b[i]
    end
    return a
end

---@param files File[]
---@return File[]
local function filterNonLocalFiles(files)
    local out = {}
    for _, file in ipairs(files) do
        if file and not file["local"] then
            out[#out + 1] = file
        end
    end
    return out
end

---@return StateManager
---@param options? StateManagerOptions
function StateManager.new(options)
    options = options or {}
    ---@type Partial<StateManager>
    local self = {
        root = options.root,
        projectName = options.projectName,

        filesMap = {},
        pathsSet = {},
        idMap = {},
        taskFileMap = setmetatable({}, { __mode = "k" }),
        errorsSet = {},
        reportedTasksMap = setmetatable({}, { __mode = "k" }),
        blobs = nil,
        transformTime = 0,
        metadata = {},
        onUnhandledError = options.onUnhandledError,
        _data = {
            timeoutIncreased = false,
        },
    }
    return setmetatable(self, StateManager)
end

---@param error any
---@param errorType string
function StateManager:catchError(error, errorType)
    if isAggregateError(error) then
        ---@cast error { errors: any[] }
        for _, inner in ipairs(error.errors) do
            self:catchError(inner, errorType)
        end
        return
    end

    if type(error) == "table" then
        ---@diagnostic disable-next-line: inject-field
        error.type = errorType
    else
        error = { type = errorType, message = error }
    end

    if type(error) == "table" and error.code == "LUATEST_PENDING" then
        local task = error.taskId and self.idMap[error.taskId] or nil
        if task then
            task.mode = "skip"
            task.result = task.result or { state = "skip" }
            task.result.state = "skip"
            task.result.note = error.note
        end
        return
    end

    if not self.onUnhandledError or self.onUnhandledError(error) ~= false then
        self.errorsSet[error] = true
    end
end

function StateManager:clearErrors()
    for k in pairs(self.errorsSet) do
        self.errorsSet[k] = nil
    end
end

---@return any[]
function StateManager:getUnhandledErrors()
    return setToArray(self.errorsSet)
end

---@return string[]
function StateManager:getPaths()
    ---@type string[]
    local out = {}
    for p in pairs(self.pathsSet) do
        out[#out + 1] = p
    end
    table.sort(out)
    return out
end

---Return files that were running or collected.
---@param keys? string[]
---@return File[]
function StateManager:getFiles(keys)
    if keys then
        local out = {}
        for _, key in ipairs(keys) do
            concatArrays(out, filterNonLocalFiles(self.filesMap[key] or {}))
        end
        return out
    end

    local out = {}
    for _, list in pairs(self.filesMap) do
        concatArrays(out, filterNonLocalFiles(list))
    end

    table.sort(out, function(a, b)
        return (a.filepath or "") < (b.filepath or "")
    end)

    return out
end

---@return any[]
function StateManager:getTestModules(keys)
    local out = {}
    for _, file in ipairs(self:getFiles(keys)) do
        local entity = self:getReportedEntity(file)
        if entity ~= nil then
            out[#out + 1] = entity
        end
    end
    return out
end

---@return string[]
function StateManager:getFilepaths()
    ---@type string[]
    local out = {}
    for filepath in pairs(self.filesMap) do
        out[#out + 1] = filepath
    end
    table.sort(out)
    return out
end

---@return string[]
function StateManager:getFailedFilepaths()
    local out = {}
    for _, file in ipairs(self:getFiles()) do
        if file.result and file.result.state == "fail" then
            out[#out + 1] = file.filepath
        end
    end
    return out
end

---@param paths? string[]
function StateManager:collectPaths(paths)
    for _, path in ipairs(paths or {}) do
        self.pathsSet[path] = true
    end
end

---@param files File[]
function StateManager:collectFiles(files)
    for _, file in ipairs(files or {}) do
        local filepath = file.filepath or file.name
        if filepath then
            local existing = self.filesMap[filepath] or {}

            -- 保留来自其他 projectName 的条目; 同 projectName 的用新文件替换
            local filtered = {}
            for _, prev in ipairs(existing) do
                if prev.projectName ~= file.projectName then
                    filtered[#filtered + 1] = prev
                end
            end
            filtered[#filtered + 1] = file
            self.filesMap[filepath] = filtered
        end

        self:updateId(file)
    end
end

---@param paths string[]
function StateManager:clearFiles(paths)
    local root = self.root
    local projectName = self.projectName
    for _, path in ipairs(paths or {}) do
        local files = self.filesMap[path]

        local fileTask = createFileTask(path, root or "", projectName)
        fileTask["local"] = true

        self:updateId(fileTask)

        if not files then
            self.filesMap[path] = { fileTask }
        else
            local filtered = {}
            for _, file in ipairs(files) do
                if file.projectName ~= projectName then
                    filtered[#filtered + 1] = file
                end
            end
            if #filtered == 0 then
                self.filesMap[path] = { fileTask }
            else
                filtered[#filtered + 1] = fileTask
                self.filesMap[path] = filtered
            end
        end
    end
end

---@param task Task
function StateManager:updateId(task)
    local existing = self.idMap[task.id]

    if existing == task then
        if not self.reportedTasksMap[task] then
            if task.type == "suite" and task.filepath ~= nil then
                reportedTasks.TestModule:register(task, self)
            elseif task.type == "suite" then
                reportedTasks.TestSuite:register(task, self)
            else
                reportedTasks.TestCase:register(task, self)
            end
        end

        if task.type == "suite" and task.tasks then
            for _, child in ipairs(task.tasks) do
                self:updateId(child)
            end
        end
        return
    end

    if not self.reportedTasksMap[task] then
        if task.type == "suite" and task.filepath ~= nil then
            reportedTasks.TestModule:register(task, self)
        elseif task.type == "suite" then
            reportedTasks.TestSuite:register(task, self)
        else
            reportedTasks.TestCase:register(task, self)
        end
    end

    self.idMap[task.id] = task

    local file = task.file
    if file then
        self.taskFileMap[task] = file
    end

    if task.type == "suite" and task.tasks then
        for _, child in ipairs(task.tasks) do
            self:updateId(child)
        end
    end
end

---@param task Task
---@return any
function StateManager:getReportedEntity(task)
    return self.reportedTasksMap[task]
end

---@param taskId string
---@return any
function StateManager:getReportedEntityById(taskId)
    local task = self.idMap[taskId]
    return task and self.reportedTasksMap[task] or nil
end

---@param packs TaskResultPack[]
function StateManager:updateTasks(packs)
    for _, pack in ipairs(packs or {}) do
        local id = pack[1]
        local result = pack[2]
        local meta = pack[3]
        local task = id and self.idMap[id] or nil
        if task then
            task.result = result
            task.meta = meta
            if result and result.state == "skip" then
                task.mode = "skip"
            end
        end
    end
end

---@return integer
function StateManager:getCountOfFailedTests()
    local count = 0
    for _, task in pairs(self.idMap) do
        if task and task.result and task.result.state == "fail" then
            count = count + 1
        end
    end
    return count
end

return StateManager
