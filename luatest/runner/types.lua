---@namespace Luatest

---@alias RunMode  'run' | 'skip' | 'only' | 'todo' | 'queued'

---@class SuiteAPI

---@alias TaskState RunMode | "pass" | "fail"

---@class SuiteCollector<ExtraContext: table>
---@field name string
---@field mode RunMode
---@field options TestOptions

---@class TestOptions
---@field timeout number? 测试超时时间(毫秒)
---@field retry number? 测试失败重试次数. 当重试次数用尽时, 最后一个测试错误将被抛出. 嵌套的 describe 将继承父 describe 的 retry
---@field repeats number? 测试成功后重复次数. 嵌套的 describe 将继承父 describe 的 repeats
---@field sequential boolean? 是否顺序运行. 嵌套的 describe 将继承父 describe 的 sequential
---@field shuffle boolean? 套件中的测试是否随机运行
---@field skip boolean? 是否跳过这个测试
---@field only boolean? 该测试是否为套件中唯一运行的测试
---@field todo boolean? 是否应该跳过测试并标记为待办事项
---@field fails boolean? 测试是否预期失败. 如果预期失败, 则测试将会通过, 否则测试将失败.


-- Task 基础类型
---@class TaskBase
---@field id string 任务唯一标识(基于文件路径和位置生成)
---@field name string 任务名称
---@field type "suite" | "test" | "file" 任务类型
---@field mode RunMode 运行模式
---@field file string 所属文件路径
---@field result TaskResult? 执行结果
---@field retry number? 失败重试次数, 默认 0
---@field repeats number? 成功后重复次数, 默认 0
---@field meta table<string, any>? 自定义元数据

-- File 任务类型
---@class File : TaskBase
---@field type "file"
---@field filepath string 文件路径
---@field suites Suite[] 包含的测试套件列表
---@field collectDuration number? 收集测试耗时(毫秒)

-- Suite 任务类型
---@class Suite : TaskBase
---@field type "suite"
---@field file File 所属文件任务
---@field tasks Task[] 子任务(Test 或 Suite)
---@field beforeAllHooks fun()[] 套件前置钩子
---@field afterAllHooks fun()[] 套件后置钩子
---@field beforeEachHooks fun(context: TestContext)[] 每个测试前置钩子
---@field afterEachHooks fun(context: TestContext)[] 每个测试后置钩子

-- Test 任务类型
---@class Test : TaskBase
---@field type "test"
---@field file File 所属文件任务
---@field suite Suite? 所属套件
---@field fn fun(context: TestContext) 测试函数
---@field context TestContext 测试上下文
---@field timeout number 测试超时时间(毫秒)
---@field onFailed fun(context: TestContext)[]? 失败时的回调
---@field onFinished fun(context: TestContext)[]? 完成时的回调

---@alias Task File | Suite | Test

-- 任务执行结果
---@class TaskResult
---@field state TaskState 测试状态
---@field errors table[]? 执行期间的错误列表
---@field duration number? 执行时长(毫秒)
---@field startTime number? 开始时间戳
---@field retryCount number? 实际重试次数
---@field repeatCount number? 实际重复次数

-- 测试上下文
---@class TestContext
---@field task Test 当前测试任务(只读)
---@field skip fun(note: string?) 跳过当前测试
---@field onTestFailed fun(fn: fun(context: TestContext), timeout: number?) 测试失败时的钩子
---@field onTestFinished fun(fn: fun(context: TestContext), timeout: number?) 测试完成时的钩子

-- Runner 配置
---@class RunnerConfig
---@field root string 项目根目录
---@field testTimeout number 测试超时时间(毫秒), 默认 5000
---@field hookTimeout number 钩子超时时间(毫秒), 默认 10000
---@field retry number 测试失败重试次数, 默认 0

-- Runner 接口
---@class Runner
---@field config RunnerConfig 配置对象
---@field importFile fun(filepath: string, source: "collect" | "setup"): any 导入测试文件
---@field onBeforeCollect fun(paths: string[])? 收集测试前的回调
---@field onCollectStart fun(file: File)? 文件任务创建后但未收集时的回调
---@field onCollected fun(files: File[])? 收集完成后的回调
---@field onBeforeRunFiles fun(files: File[])? 运行所有文件前的回调
---@field onAfterRunFiles fun(files: File[])? 运行所有文件后的回调
---@field onBeforeRunSuite fun(suite: Suite)? 运行 Suite 前的回调
---@field onAfterRunSuite fun(suite: Suite)? 运行 Suite 后的回调
---@field onBeforeRunTask fun(test: Test)? 运行 Test 前的回调
---@field onAfterRunTask fun(test: Test)? 运行 Test 后的回调
---@field onTaskUpdate fun(task: Task)? 任务更新回调(报告结果)
---@field extendTaskContext fun(context: TestContext): TestContext? 扩展测试上下文
