---@namespace Luatest

---@alias RunMode  'run' | 'skip' | 'only' | 'todo' | 'queued'

---@class SuiteAPI

---@class TestAPI<ExtraContext: table>

---@alias SuiteFactory fun(test: TestAPI) 工厂函数

---@alias TaskState RunMode | "pass" | "fail"

---@class SuiteCollector<ExtraContext: table>
---@field type "collector"                                   -- 类型标识
---@field name string                                        -- 套件名称
---@field mode RunMode                                       -- 运行模式
---@field options? TestOptions                               -- 测试选项
---@field test TestAPI                                       -- test/it API
---@field tasks (Test|Suite<ExtraContext>|SuiteCollector<ExtraContext>)[]                -- 子任务列表
---@field file? File                                         -- 所属文件
---@field suite? Suite                                       -- 父 Suite
---@field task fun(name: string, options?: TaskCustomOptions): Test  -- 创建测试
---@field collect fun(file: File): Suite                     -- 收集并返回 Suite
---@field clear fun()                                        -- 清空任务
---@field on fun<T extends keyof SuiteHooks>(name: T, ...: function)  -- 添加钩子

---@class TaskCustomOptions: TestOptions
---@field each boolean?              -- 是否由 .each() 方法生成
---@field meta table<string, any>?   -- 自定义元数据
---@field handler function?          -- 执行函数

---@class TestOptions
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
---@field location { line: number, column: number, file: string }? 任务位置信息
---@field shuffle boolean? 是否随机运行
---@field sequential boolean? 是否顺序运行
---@field concurrent boolean? 是否并发运行

-- Suite 任务类型
---@class Suite: TaskBase
---@field type "suite"
---@field file File 文件任务, 这是文件的根任务
---@field tasks Task[] 作为套件组成部分的一系列任务
---@field fullName string 完整名称(包含文件路径)
---@field fullTestName string? 完整测试名称(不包含文件路径)

-- File 任务类型
---@class File: Suite
---@field type "file"
---@field filepath string 文件路径

---@class TaskPopulated: TaskBase
---@field file File 文件任务, 这是文件的根任务
---@field fails boolean? 测试是否预期失败. 如果测试失败, 它将被标记为通过
---@field onFailed OnTestFailedHandler[]? 任务失败时运行的钩子. 执行顺序取决于 `sequence.hooks` 配置
---@field onFinished OnTestFinishedHandler[]? 任务完成后运行的钩子. 执行顺序取决于 `sequence.hooks` 配置

-- Test 任务类型
---@class Test<ExtraContext: table>: TaskPopulated
---@field type "test" 任务类型
---@field context TestContext 将传递给测试函数的测试上下文
---@field annotations TestAnnotation[] 自定义注解数组
---@field fullTestName string 完整测试名称

---@alias Task Test | File | Suite

-- 任务执行结果
---@class TaskResult
---@field state TaskState 测试状态
---@field errors table[]? 执行期间的错误列表
---@field duration number? 执行时长(毫秒)
---@field startTime number? 开始时间戳
---@field retryCount number? 实际重试次数
---@field repeatCount number? 实际重复次数
---@field note string? 测试跳过或失败的注释
---@field pending boolean? 是否调用过`context.skip()`跳过任务

---@alias OnTestFailedHandler fun(context: TestContext) 测试失败时的处理函数

---@alias OnTestFinishedHandler fun(context: TestContext) 测试完成时的处理函数

-- 测试注解
---@class TestAnnotation
---@field type string 注解类型
---@field message string? 注解消息

-- 测试上下文
---@class TestContext
---@field task Test 当前测试任务(只读)
---@field skip fun(self: self, condition?: boolean, note: string?) 标记测试为跳过. 此调用后所有执行都将被跳过. 且此函数会抛出错误.
---@field onTestFailed fun(self: self, fn: fun(context: TestContext)) 测试失败时的钩子
---@field onTestFinished fun(self: self, fn: fun(context: TestContext)) 测试完成时的钩子

---'stack': 将以相反的顺序排列 "after" 钩子, "before" 钩子将按照它们定义的顺序运行
---
---'list': 将按照定义的顺序对所有钩子进行排序
---@alias SequenceHooks 'stack' | 'list'

---@class RunnerConfig
---@field root string 项目根目录
---@field retry number 测试失败重试次数, 默认 0
---@field testTimeout number 测试超时时间(毫秒), 默认 5000
---@field includeTaskLocation boolean? 是否包含任务位置信息
---@field sequence { shuffle?: boolean, seed: number, hooks: SequenceHooks, concurrent?: boolean }

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

---@alias BeforeAllListener fun(suite: Suite|File) 在所有测试前运行的钩子

---@alias AfterAllListener fun(suite: Suite|File) 在所有测试后运行的钩子

---@alias BeforeEachListener fun(context: TestContext, suite: Suite) 在每个测试前运行的钩子

---@alias AfterEachListener fun(context: TestContext, suite: Suite) 在每个测试后运行的钩子

-- 套件钩子集合
---@class SuiteHooks<ExtraContext: table>
---@field beforeAll BeforeAllListener[] 所有测试前的钩子数组
---@field afterAll AfterAllListener[] 所有测试后的钩子数组
---@field beforeEach BeforeEachListener[] 每个测试前的钩子数组
---@field afterEach AfterEachListener[] 每个测试后的钩子数组
