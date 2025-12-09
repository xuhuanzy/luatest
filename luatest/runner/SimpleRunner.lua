-- Simple Runner 实现示例
-- 演示如何实现 Runner 接口

---@class SimpleRunner : Runner
local SimpleRunner = {}
SimpleRunner.__index = SimpleRunner

---创建新的 SimpleRunner
---@param config RunnerConfig
---@return SimpleRunner
function SimpleRunner.new(config)
    local self = setmetatable({}, SimpleRunner)
    self.config = config or {
        root = ".",
        testTimeout = 5000,
        hookTimeout = 10000,
        retry = 0,
    }
    return self
end

---导入测试文件
---@param filepath string
---@param source "collect" | "setup"
---@return any
function SimpleRunner:importFile(filepath, source)
    -- 使用 dofile 加载文件
    return dofile(filepath)
end

---收集测试前的回调
---@param paths string[]
function SimpleRunner:onBeforeCollect(paths)
    print(string.format("[Collect] 开始收集 %d 个文件", #paths))
end

---收集完成后的回调
---@param files File[]
function SimpleRunner:onCollected(files)
    local totalTests = 0
    for _, file in ipairs(files) do
        for _, suite in ipairs(file.suites) do
            totalTests = totalTests + #suite.tasks
        end
    end
    print(string.format("[Collect] 收集完成, 共 %d 个测试", totalTests))
end

---运行所有文件前的回调
---@param files File[]
function SimpleRunner:onBeforeRunFiles(files)
    print(string.format("[Run] 开始运行 %d 个文件", #files))
end

---运行所有文件后的回调
---@param files File[]
function SimpleRunner:onAfterRunFiles(files)
    print("[Run] 运行完成")
end

---运行 Test 前的回调
---@param test Test
function SimpleRunner:onBeforeRunTask(test)
    io.write(string.format("  ▶ %s ... ", test.name))
    io.flush()
end

---运行 Test 后的回调
---@param test Test
function SimpleRunner:onAfterRunTask(test)
    if test.result then
        if test.result.state == "pass" then
            print("✓")
        elseif test.result.state == "fail" then
            print("✗")
            if test.result.errors then
                for _, err in ipairs(test.result.errors) do
                    print(string.format("    Error: %s", err.message))
                end
            end
        elseif test.result.state == "skip" then
            print("⊘")
        end
    end
end

return SimpleRunner
