## ADDED Requirements

### Requirement: 任务模型定义

系统 SHALL 定义三种任务类型: File, Suite, Test, 以树状结构组织测试.

#### Scenario: 创建 File 任务

- **GIVEN** 一个测试文件路径
- **WHEN** 创建 File 任务对象
- **THEN** File 对象包含 id, name, type="file", suites 列表

#### Scenario: 创建 Suite 任务

- **GIVEN** 一个测试套件名称
- **WHEN** 创建 Suite 任务对象
- **THEN** Suite 对象包含 id, name, type="suite", tasks 列表, 以及四类钩子列表

#### Scenario: 创建 Test 任务

- **GIVEN** 一个测试用例名称和测试函数
- **WHEN** 创建 Test 任务对象
- **THEN** Test 对象包含 id, name, type="test", fn 测试函数

#### Scenario: 嵌套 Suite 结构

- **GIVEN** 一个父 Suite 包含子 Suite
- **WHEN** 构建任务树
- **THEN** 子 Suite 被添加到父 Suite 的 tasks 列表中

### Requirement: Runner 接口定义

系统 SHALL 定义 Runner 接口, 将环境相关操作委托给外部实现.

#### Scenario: 实现文件导入

- **GIVEN** 一个 Runner 实例
- **WHEN** 调用 runner.importFile(filepath)
- **THEN** 文件被加载并执行, 返回模块或测试定义

#### Scenario: 任务更新回调

- **GIVEN** 一个 Runner 实例配置了 onTaskUpdate 回调
- **WHEN** 某个任务状态变化
- **THEN** onTaskUpdate 被调用并传入任务对象

#### Scenario: 访问 Runner 配置

- **GIVEN** 一个 Runner 实例
- **WHEN** 访问 runner.config
- **THEN** 返回包含 testTimeout 等配置的表

### Requirement: Suite 执行

系统 SHALL 递归执行 Suite 及其子任务, 并处理生命周期钩子.

#### Scenario: 执行单个 Suite

- **GIVEN** 一个包含测试的 Suite
- **WHEN** 调用 runSuite(suite, runner)
- **THEN** 依次执行: beforeAll 钩子, 所有子任务, afterAll 钩子

#### Scenario: 执行嵌套 Suite

- **GIVEN** 一个包含子 Suite 的 Suite
- **WHEN** 调用 runSuite(parentSuite, runner)
- **THEN** 递归执行所有子 Suite

#### Scenario: beforeAll 钩子失败

- **GIVEN** 一个 Suite 的 beforeAll 钩子抛出错误
- **WHEN** 执行该 Suite
- **THEN** 跳过该 Suite 的所有测试, 标记为 fail, 并执行 afterAll 钩子

#### Scenario: afterAll 钩子始终执行

- **GIVEN** 一个 Suite 的测试执行过程中有失败
- **WHEN** Suite 执行完成
- **THEN** afterAll 钩子仍然被执行

### Requirement: Test 执行

系统 SHALL 执行单个测试并收集结果.

#### Scenario: 执行成功的测试

- **GIVEN** 一个测试函数不抛出错误
- **WHEN** 调用 runTest(test, runner)
- **THEN** 测试标记为 pass, result.state = "pass"

#### Scenario: 执行失败的测试

- **GIVEN** 一个测试函数抛出错误
- **WHEN** 调用 runTest(test, runner)
- **THEN** 测试标记为 fail, result.state = "fail", result.error 包含错误信息

#### Scenario: 记录测试执行时间

- **GIVEN** 一个测试函数
- **WHEN** 执行测试
- **THEN** result.startTime 和 result.endTime 被记录, duration 被计算

#### Scenario: beforeEach 钩子执行

- **GIVEN** 当前 Suite 定义了 beforeEach 钩子
- **WHEN** 执行该 Suite 的某个测试
- **THEN** beforeEach 钩子在测试函数前执行

#### Scenario: afterEach 钩子始终执行

- **GIVEN** 当前测试失败
- **WHEN** 测试执行完成
- **THEN** afterEach 钩子仍然被执行

#### Scenario: 继承父 Suite 的 hooks

- **GIVEN** 父 Suite 定义了 beforeEach 钩子, 子 Suite 也定义了 beforeEach 钩子
- **WHEN** 执行子 Suite 的测试
- **THEN** 父的 beforeEach 先执行, 然后是子的 beforeEach

### Requirement: 文件执行入口

系统 SHALL 提供 runFiles 函数作为执行多个测试文件的入口.

#### Scenario: 执行多个文件

- **GIVEN** 一个包含多个 File 任务的列表
- **WHEN** 调用 runFiles(files, runner)
- **THEN** 依次执行每个 File 的所有 Suite

#### Scenario: 文件执行失败不影响其他文件

- **GIVEN** 第一个文件执行失败
- **WHEN** 调用 runFiles([file1, file2], runner)
- **THEN** 第二个文件仍然被执行

### Requirement: 错误处理

系统 SHALL 捕获并记录测试执行中的所有错误.

#### Scenario: 捕获测试函数错误

- **GIVEN** 测试函数中调用 `error("test failed")`
- **WHEN** 执行测试
- **THEN** 错误被捕获, result.error = "test failed", 包含堆栈信息

#### Scenario: 捕获钩子函数错误

- **GIVEN** beforeEach 钩子抛出错误
- **WHEN** 执行测试
- **THEN** 测试被标记为 fail, error 包含钩子错误信息

#### Scenario: 保留错误堆栈

- **GIVEN** 测试函数在第 10 行抛出错误
- **WHEN** 错误被捕获
- **THEN** result.error 包含文件名和行号信息
