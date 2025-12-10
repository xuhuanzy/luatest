---@namespace Luatest

---将值转换为数组
---@generic T
---@param value? Arrayable<T>
---@return T[]
local function toArray(value)
    if value == nil then
        return {}
    end
    if type(value) == 'table' and #value > 0 then
        ---@diagnostic disable-next-line: return-type-mismatch
        return value
    end
    return { value }
end

---检查是否是测试用例
---@param s Task
---@return boolean
---@return_cast s Test
local function isTestCase(s)
    return s.type == 'test'
end

---获取所有测试
---@param suite Task | Task[]
---@return Test[]
local function getTests(suite)
    local tests = {}
    local arraySuites = toArray(suite)

    for _, s in ipairs(arraySuites) do
        if isTestCase(s) then
            table.insert(tests, s)
        else
            for _, task in ipairs(s.tasks or {}) do
                if isTestCase(task) then
                    table.insert(tests, task)
                else
                    local taskTests = getTests(task)
                    for _, test in ipairs(taskTests) do
                        table.insert(tests, test)
                    end
                end
            end
        end
    end

    return tests
end

---获取所有任务（扁平化）
---@param tasks Task | Task[]
---@return Task[]
local function getTasks(tasks)
    tasks = tasks or {}
    local result = {}
    local arrayTasks = toArray(tasks)

    for _, s in ipairs(arrayTasks) do
        if isTestCase(s) then
            table.insert(result, s)
        else
            table.insert(result, s)
            local subTasks = getTasks(s.tasks)
            for _, task in ipairs(subTasks) do
                table.insert(result, task)
            end
        end
    end

    return result
end

---获取所有 Suite
---@param suite Task | Task[]
---@return Suite[]
local function getSuites(suite)
    local result = {}
    local arraySuites = toArray(suite)

    for _, s in ipairs(arraySuites) do
        if s.type == 'suite' then
            table.insert(result, s)
            local subSuites = getSuites(s.tasks)
            for _, subSuite in ipairs(subSuites) do
                table.insert(result, subSuite)
            end
        end
    end

    return result
end


---检查是否有测试
---@param suite Arrayable<Suite>
---@return boolean
local function hasTests(suite)
    local arraySuites = toArray(suite)

    for _, s in ipairs(arraySuites) do
        if s.tasks then
            for _, c in ipairs(s.tasks) do
                if isTestCase(c) or hasTests(c) then
                    return true
                end
            end
        end
    end
    return false
end

---检查是否失败
---@param suite Task | Task[]
---@return boolean
local function hasFailed(suite)
    local arraySuites = toArray(suite)

    for _, s in ipairs(arraySuites) do
        if s.result and s.result.state == 'fail' then
            return true
        end
        if s.type == 'suite' and hasFailed(s.tasks) then
            return true
        end
    end

    return false
end

---获取任务名称数组
---@param task Task
---@return string[]
local function getNames(task)
    local names = { task.name }
    local current = task

    while current and current.suite do
        current = current.suite
        if current and current.name then
            table.insert(names, 1, current.name)
        end
    end

    if current ~= task.file then
        table.insert(names, 1, task.file.name)
    end

    return names
end

---获取完整名称
---@param task Task
---@param separator? string
---@return string
local function getFullName(task, separator)
    separator = separator or ' > '
    return table.concat(getNames(task), separator)
end

---获取测试名称
---@param task Task
---@param separator? string
---@return string
local function getTestName(task, separator)
    separator = separator or ' > '
    local names = getNames(task)
    local result = {}
    for i = 2, #names do
        table.insert(result, names[i])
    end
    return table.concat(result, separator)
end

---创建任务名称
---@param names (string|nil)[]
---@param separator? string
---@return string
local function createTaskName(names, separator)
    separator = separator or ' > '
    local filtered = {}
    for _, name in ipairs(names) do
        if name ~= nil and name ~= '' then
            table.insert(filtered, name)
        end
    end
    return table.concat(filtered, separator)
end

---@export namespace
return {
    toArray = toArray,
    isTestCase = isTestCase,
    getTests = getTests,
    getTasks = getTasks,
    getSuites = getSuites,
    hasTests = hasTests,
    hasFailed = hasFailed,
    getNames = getNames,
    getFullName = getFullName,
    getTestName = getTestName,
    createTaskName = createTaskName,
}
