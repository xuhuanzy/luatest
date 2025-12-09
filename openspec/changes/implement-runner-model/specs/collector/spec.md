## ADDED Requirements

### Requirement: 收集上下文管理

系统 SHALL 维护全局收集上下文 collectorContext, 用于跟踪当前正在定义的 Suite.

#### Scenario: 初始化收集上下文

- **GIVEN** 开始收集新的测试文件
- **WHEN** 重置收集上下文
- **THEN** collectorContext.currentSuite 为 nil, suiteStack 为空

#### Scenario: 推入 Suite 到栈

- **GIVEN** 当前正在定义一个 Suite
- **WHEN** 调用 pushSuite(suite)
- **THEN** suite 被添加到 suiteStack, currentSuite 指向该 suite

#### Scenario: 从栈弹出 Suite

- **GIVEN** Suite 定义完成
- **WHEN** 调用 popSuite()
- **THEN** currentSuite 恢复为栈中的前一个 Suite

#### Scenario: 嵌套 Suite 栈管理

- **GIVEN** 定义了嵌套的 Suite A > B > C
- **WHEN** 进入 C 时
- **THEN** suiteStack = [A, B, C], currentSuite = C

### Requirement: describe API

系统 SHALL 提供 describe 函数用于定义测试套件.

#### Scenario: 定义顶层 Suite

- **GIVEN** 没有当前 Suite
- **WHEN** 调用 describe("my suite", function() ... end)
- **THEN** 创建一个新的 Suite, 添加到 File.suites, 执行回调函数

#### Scenario: 定义嵌套 Suite

- **GIVEN** 当前在 Suite A 中
- **WHEN** 调用 describe("nested", function() ... end)
- **THEN** 创建子 Suite, 添加到 Suite A 的 tasks, 执行回调函数

#### Scenario: describe 回调中定义测试

- **GIVEN** describe 回调函数
- **WHEN** 回调中调用 test("case", fn)
- **THEN** 测试被添加到当前 Suite 的 tasks

#### Scenario: describe 回调执行后恢复上下文

- **GIVEN** 嵌套 describe 调用
- **WHEN** 内层 describe 回调执行完成
- **THEN** currentSuite 恢复为外层 Suite

### Requirement: test 和 it API

系统 SHALL 提供 test 和 it 函数用于定义测试用例, 两者行为完全相同.

#### Scenario: 定义测试用例

- **GIVEN** 当前在 Suite 中
- **WHEN** 调用 test("my test", function() ... end)
- **THEN** 创建 Test 对象, 添加到当前 Suite 的 tasks

#### Scenario: it 作为 test 的别名

- **GIVEN** 当前在 Suite 中
- **WHEN** 调用 it("my test", fn)
- **THEN** 行为与 test() 完全相同

#### Scenario: 在 Suite 外定义 test 错误

- **GIVEN** 没有当前 Suite (顶层)
- **WHEN** 调用 test("orphan test", fn)
- **THEN** 抛出错误 "test() must be called inside describe()"

### Requirement: 生命周期钩子注册

系统 SHALL 提供 beforeAll, afterAll, beforeEach, afterEach 函数注册钩子.

#### Scenario: 注册 beforeAll 钩子

- **GIVEN** 当前在 Suite 中
- **WHEN** 调用 beforeAll(function() ... end)
- **THEN** 函数被添加到当前 Suite 的 beforeAllHooks

#### Scenario: 注册 afterAll 钩子

- **GIVEN** 当前在 Suite 中
- **WHEN** 调用 afterAll(function() ... end)
- **THEN** 函数被添加到当前 Suite 的 afterAllHooks

#### Scenario: 注册 beforeEach 钩子

- **GIVEN** 当前在 Suite 中
- **WHEN** 调用 beforeEach(function() ... end)
- **THEN** 函数被添加到当前 Suite 的 beforeEachHooks

#### Scenario: 注册 afterEach 钩子

- **GIVEN** 当前在 Suite 中
- **WHEN** 调用 afterEach(function() ... end)
- **THEN** 函数被添加到当前 Suite 的 afterEachHooks

#### Scenario: 多个钩子按注册顺序执行

- **GIVEN** 注册了两个 beforeEach 钩子
- **WHEN** 执行测试
- **THEN** 钩子按注册顺序执行

### Requirement: 测试树构建

系统 SHALL 在文件导入后构建完整的任务树.

#### Scenario: 收集简单测试文件

- **GIVEN** 测试文件包含一个 describe 和两个 test
- **WHEN** importFile 执行完成
- **THEN** File 对象包含一个 Suite, Suite.tasks 包含两个 Test

#### Scenario: 收集嵌套结构

- **GIVEN** 测试文件包含嵌套的 describe
- **WHEN** 构建任务树
- **THEN** 父 Suite.tasks 包含子 Suite, 子 Suite.tasks 包含 Test

#### Scenario: 为任务生成唯一 ID

- **GIVEN** 多个测试
- **WHEN** 创建 Task 对象
- **THEN** 每个 Task.id 都是唯一的

#### Scenario: 任务关联所属文件

- **GIVEN** 从文件 "test.lua" 收集的测试
- **WHEN** 创建 Task 对象
- **THEN** 所有 Task.file = "test.lua"

### Requirement: 收集阶段入口

系统 SHALL 提供 collectTests 函数作为收集阶段的入口.

#### Scenario: 收集单个文件

- **GIVEN** 一个测试文件路径
- **WHEN** 调用 collectTests({filepath}, runner)
- **THEN** 返回包含一个 File 任务的列表

#### Scenario: 收集多个文件

- **GIVEN** 多个测试文件路径
- **WHEN** 调用 collectTests(filepaths, runner)
- **THEN** 返回包含多个 File 任务的列表

#### Scenario: 收集前重置上下文

- **GIVEN** 之前已收集过测试
- **WHEN** 调用 collectTests 收集新文件
- **THEN** collectorContext 被重置, 不包含旧的 Suite 信息

#### Scenario: 收集时调用 runner.importFile

- **GIVEN** 一个测试文件路径 "test.lua"
- **WHEN** 调用 collectTests({"test.lua"}, runner)
- **THEN** runner.importFile("test.lua") 被调用
