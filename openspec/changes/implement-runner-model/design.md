# Technical Design: Runner Model

## Context

本设计文档描述 luatest 的核心测试执行引擎实现方案.

**背景**: 参考 Vitest 的 `@vitest/runner` 包, 它是一个环境无关的测试调度器, 通过接口抽象将环境特定操作委托给外部实现.

**约束**:

- 使用 Lua 5.4
- 保持简洁, 初始实现 < 400 行代码
- 纯 Lua 实现, 无 C 扩展依赖
- 支持协程异步测试(后续扩展)
- 使用 emmylua 注解系统

**涉众**:

- luatest 框架开发者
- 测试用例编写者

## Goals / Non-Goals

**Goals**:

- 实现基础的测试收集和执行机制
- 提供清晰的 API (`describe`, `test`, `it`)
- 支持生命周期钩子
- 支持嵌套测试套件
- 提供可扩展的 Runner 接口
- 支持 retry(重试) 和 repeats(重复) 机制
- 提供丰富的测试上下文(TestContext)

**Non-Goals**:

- 文件监听和热重载(不需要)
- 并发执行控制(不需要)
- 断言库实现(使用独立的 luaassert)
- 报告格式化(后续实现)
- only/skip/todo 标记(初始版本不实现)

## Architecture

### 核心组件关系

```
┌─────────────────────────────────────────┐
│          User Test File                 │
│  describe("suite", function()           │
│    test("case", function(ctx) ... end)  │
│  end)                                   │
└──────────────┬──────────────────────────┘
               │ 执行时调用
               ▼
┌─────────────────────────────────────────┐
│       Collector (suite.lua)             │
│  - 全局上下文 collectorContext          │
│  - describe() API                       │
│  - test() / it() API                    │
│  - Suite 栈管理                         │
└──────────────┬──────────────────────────┘
               │ 构建
               ▼
┌─────────────────────────────────────────┐
│        Task Tree (types.lua)            │
│  File { suites: [...] }                 │
│    └─ Suite { tests: [...] }            │
│         └─ Test { fn, context }         │
└──────────────┬──────────────────────────┘
               │ 执行
               ▼
┌─────────────────────────────────────────┐
│      Execution Engine (run.lua)         │
│  - runFiles() - 文件级入口              │
│  - runSuite() - 递归执行套件            │
│  - runTest() - 测试执行(retry/repeats)  │
│  - 钩子执行及上下文传递                 │
└──────────────┬──────────────────────────┘
               │ 委托环境操作
               ▼
┌─────────────────────────────────────────┐
│      Runner Interface                   │
│  - importFile(filepath, source)         │
│  - onBeforeRunTask(test)                │
│  - onAfterRunTask(test)                 │
│  - extendTaskContext(context)           │
│  - 更多生命周期钩子...                  │
└─────────────────────────────────────────┘
```

### 数据流

1. **收集阶段**:

   ```
   onBeforeCollect(paths)
   → importFile(test.lua, "collect")
   → 执行 describe/test 调用
   → 填充 collectorContext
   → 构建 Task 树
   → onCollected(files)
   ```

2. **执行阶段**:
   ```
   onBeforeRunFiles(files)
   → runSuite(file.suite)
     → onBeforeRunSuite(suite)
     → beforeAll hooks
     → runTest(test) for each test
       → onBeforeRunTask(test)
       → beforeEach hooks(ctx)
       → execute test fn(ctx)
       → afterEach hooks(ctx)
       → retry logic if failed
       → repeats logic if success
       → onAfterRunTask(test)
     → afterAll hooks
     → onAfterRunSuite(suite)
   → onAfterRunFiles(files)
   ```

## Decisions

### Decision 1: 使用 Table 实现任务树

**选择**: 使用 Lua table 存储任务层级结构

**理由**:

- Lua 原生支持, 无需额外依赖
- 灵活的结构, 易于扩展
- 性能足够(测试文件数量通常 < 1000)

**替代方案**:

- userdata + metatable: 过度设计, 增加复杂度
- 字符串序列化: 性能差, 调试困难

### Decision 2: 全局收集上下文

**选择**: 使用模块级全局变量 `collectorContext` 保存当前 Suite 栈

**理由**:

- 符合 Lua 测试文件的同步执行模型
- API 简洁, 用户无需手动传递上下文
- 与 Jest/Vitest 行为一致

**风险**: 不支持并发收集(但用户明确不需要并发)

**缓解**: 在设计时预留扩展点, 将上下文访问封装为函数

### Decision 3: Runner 接口抽象

**选择**: 定义 Runner 接口, 将文件加载委托给外部

**理由**:

- 环境无关性: runner 不依赖 `dofile` 或 `require`
- 可测试性: 可以注入 mock runner
- 可扩展性: 支持不同的文件加载策略(缓存、转换等)
- 丰富的生命周期: 参考 Vitest 提供多个钩子点

### Decision 4: 生命周期钩子存储在 Suite

**选择**: 将 beforeAll/afterAll/beforeEach/afterEach 存储在 Suite 对象中

**理由**:

- 符合作用域: 钩子仅在当前 Suite 及其子级生效
- 执行顺序清晰: 父 Suite 的 beforeEach 先于子 Suite
- 易于实现继承: 递归时自然传播

### Decision 5: TestContext 设计

**选择**: 参考 Vitest 提供 TestContext 对象, 包含 task, skip, onTestFailed 等方法

**理由**:

- 提供测试内部的控制能力(如动态 skip)
- 支持测试级的回调钩子
- 为后续扩展预留空间(如 signal, annotate 等)

## Data Models

参考 Vitest 的类型定义(`VitestRunner`, `Task`, `TestContext`), 结合 Lua 特性简化实现.

### 基础类型

```lua
---@alias RunMode "run" | "skip" | "only" | "todo"
---@alias TaskState RunMode | "pass" | "fail"
```

### Task 类型层级

```lua
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

---@class File : TaskBase
---@field type "file"
---@field filepath string 文件路径(UNIX 格式)
---@field suites Suite[] 包含的测试套件列表
---@field collectDuration number? 收集测试耗时(毫秒)

---@class Suite : TaskBase
---@field type "suite"
---@field file File 所属文件任务
---@field tasks Task[] 子任务(Test 或 Suite)
---@field beforeAllHooks fun()[] 套件前置钩子
---@field afterAllHooks fun()[] 套件后置钩子
---@field beforeEachHooks fun(context: TestContext)[] 每个测试前置钩子
---@field afterEachHooks fun(context: TestContext)[] 每个测试后置钩子

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
```

### TaskResult

```lua
---@class TaskResult
---@field state TaskState 测试状态
---@field errors table[]? 执行期间的错误列表
---@field duration number? 执行时长(毫秒)
---@field startTime number? 开始时间戳
---@field retryCount number? 实际重试次数
---@field repeatCount number? 实际重复次数
```

### TestContext

参考 Vitest 的 TestContext, 提供测试运行时上下文:

```lua
---@class TestContext
---@field task Test 当前测试任务(只读)
---@field skip fun(note: string?) 跳过当前测试

---在测试失败时调用的钩子
---@param fn fun(context: TestContext)
---@param timeout number?
function TestContext:onTestFailed(fn, timeout) end

---在测试完成时调用的钩子
---@param fn fun(context: TestContext)
---@param timeout number?
function TestContext:onTestFinished(fn, timeout) end
```

### Runner 接口

参考 Vitest 的 VitestRunner, 简化为核心功能:

```lua
---@class RunnerConfig
---@field root string 项目根目录
---@field testTimeout number 测试超时时间(毫秒), 默认 5000
---@field hookTimeout number 钩子超时时间(毫秒), 默认 10000
---@field retry number 测试失败重试次数, 默认 0

---@class Runner
---@field config RunnerConfig 配置对象

---导入测试文件
---@param filepath string 文件路径
---@param source "collect" | "setup" 导入来源
---@return any
function Runner:importFile(filepath, source) end

---收集测试前的回调
---@param paths string[] 文件路径列表
function Runner:onBeforeCollect(paths) end

---文件任务创建后但未收集时的回调
---@param file File
function Runner:onCollectStart(file) end

---收集完成后的回调
---@param files File[]
function Runner:onCollected(files) end

---运行所有文件前的回调
---@param files File[]
function Runner:onBeforeRunFiles(files) end

---运行所有文件后的回调
---@param files File[]
function Runner:onAfterRunFiles(files) end

---运行 Suite 前的回调
---@param suite Suite
function Runner:onBeforeRunSuite(suite) end

---运行 Suite 后的回调
---@param suite Suite
function Runner:onAfterRunSuite(suite) end

---运行 Test 前的回调
---@param test Test
function Runner:onBeforeRunTask(test) end

---运行 Test 后的回调
---@param test Test
function Runner:onAfterRunTask(test) end

---任务更新回调(报告结果)
---@param task Task
function Runner:onTaskUpdate(task) end

---扩展测试上下文(可选)
---@param context TestContext
---@return TestContext
function Runner:extendTaskContext(context) end
```

## Implementation Strategy

### 阶段 1: 基础类型和收集器 (简单)

- 定义 Task 类型(使用 emmylua 注解)
- 实现 collectorContext
- 实现 describe/test API

**验证**: 能够收集简单的测试树

### 阶段 2: 执行引擎 (核心)

- 实现 runSuite/runTest
- 实现钩子执行及 TestContext 传递
- 实现结果收集
- 实现 retry 和 repeats 逻辑

**验证**: 能够执行测试并收集结果

### 阶段 3: Runner 接口 (抽象)

- 定义 Runner 接口及所有生命周期钩子
- 实现简单的 dofile-based Runner
- 集成收集和执行流程

**验证**: 端到端执行测试文件

## Risks / Trade-offs

| 风险                     | 影响 | 缓解措施                            |
| ------------------------ | ---- | ----------------------------------- |
| 全局状态限制扩展性       | 低   | 用户明确不需要并发, 接受此限制      |
| 递归深度限制(嵌套 Suite) | 低   | Lua 栈深度通常 > 200, 足够测试场景  |
| 错误栈信息丢失           | 中   | 使用 `debug.traceback()` 捕获完整栈 |
| 钩子执行顺序复杂         | 低   | 参考 Jest 文档, 清晰注释执行顺序    |
| TestContext 实现复杂度   | 中   | 初期实现核心功能, 逐步扩展          |

## Migration Plan

本变更为新功能, 无迁移需求.

**集成计划**:

1. 从 `luatest/runner/` 导出 `describe`, `test`, `it`
2. 从 `luatest/init.lua` re-export 全局 API
3. 提供示例测试文件作为参考
4. 提供 Runner 实现示例

**回滚策略**:

- 删除 `luatest/runner/` 目录
- 回退 `luatest/types.lua` 修改

## Open Questions

1. **是否需要同时支持 `test()` 和 `it()`?**
   - 建议: 支持, 作为别名, 与 Jest/Vitest 一致
2. **钩子是否支持异步(协程)?**

   - 初期: 仅支持同步
   - 后续: 通过检测返回值是否为 coroutine 支持异步

3. **是否需要 File 作为独立的 Task 类型?**

   - 建议: 需要, 用于文件级的 setup/teardown(后续扩展)

4. **TestContext.skip() 如何实现?**
   - 建议: 抛出特殊的 SkipError, 在 runTest 中捕获并标记状态

## References

- Vitest Runner 源码: `@vitest/runner` 包分析
- Vitest 类型定义: `VitestRunner`, `Task`, `TestContext`
- Jest 文档: https://jestjs.io/docs/setup-teardown
- Lua 5.4 Manual: https://www.lua.org/manual/5.4/
- EmmyLua 注解文档: `.lspdocs/annotations_CN/`
