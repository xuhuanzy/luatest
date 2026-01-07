# Design: add-reporter-pipeline

## 与 Vitest 的关键差异
Vitest 在 node 侧有 `Vitest`/`TestProject`/`State` 等对象边界，并且概念上存在“主线程/协调者 + worker”的划分。

本项目实现中：
- **不存在 TestProject**：已删除 project 概念；运行期状态统一挂在 `StateManager`（State）上。
- **RPC/worker 不是线程边界**：`core/runtime/*` 与 `core/controller/*` 目前运行在同一进程内，RPC 只是为了接口隔离与未来扩展预留。

因此，本变更的 reporter pipeline 必须以 **State** 作为唯一事实来源（source of truth），reporters 通过 State 查询/派生所需信息。

## 现状（数据流）
1. Runner 侧（`luatest/runner/run.lua`）在执行过程中批量产生：
   - `TaskResultPack[]`（taskId + result + meta）
   - `TaskEventPack[]`（taskId + event + data）
2. Runtime 侧（`luatest/core/runtime/runners/init.lua`）把 Runner 的 `onTaskUpdate` 包装为 `rpc().onTaskUpdate(update, events)`。
3. Controller 侧（`luatest/core/controller/rpc.lua`）转发到 `luatest.testRun:updated(update, events)`。
4. 当前 `luatest/core/controller/test-run.lua`：
   - 仅 `state:updateTasks(update)`；`events` 被忽略。
   - 没有 reporters 管线，也就谈不上把信息交付给 reporters。

## 目标（我们要补齐什么）
- **存储**：把 runner 上报的“状态更新 + 事件流”在 controller 侧形成可查询的 reporting state。
- **交付**：把这些信息可靠、按顺序地分发给 reporters（实时渲染与最终输出）。
- **范围约束**：不实现 artifact/attachment 上报与存储（对应 Vitest `recordArtifact`/`onTestCaseArtifactRecord` 逻辑）。

现有 `luatest/core/controller/state.lua` 与 `luatest/core/controller/reporters/reported-tasks.lua` 已经提供了关键基础：
- `StateManager.idMap`：taskId -> Task
- `StateManager.reportedTasksMap`：Task -> TestModule/TestSuite/TestCase（reported entity）
- `reported-tasks.lua`：为 reporters 提供稳定的“可查询对象”（`state() / result() / diagnostic() / children` 等）

本变更会在其上新增：
- `TaskEventPack` 的持久化与索引
- reporters 的生命周期与分发器

## 设计概览

### 1) Reporting State（存储层）
在 `StateManager` 中新增（命名待实现阶段确认）：
- `taskEvents: TaskEventPack[]`：按收到顺序追加，代表本次 run 的事件流。
- `taskEventsById: table<string, TaskEventPack[]>`：taskId -> events（便于 reporters/调试按任务查询）。

约束：
- **顺序**：必须保持 Runner 上报的事件顺序（同一批 `onTaskUpdate` 内也要保持 `events` 的原有顺序）。
- **一致性**：处理 `onTaskUpdate(update, events)` 时，先 `state:updateTasks(update)`，再记录/分发 `events`，确保 reporters 在事件回调中读取到最新 `task.result/meta`。

### 2) Reporter Pipeline（交付层）
新增一个“reporter dispatcher/manager”负责：
- 持有 `Reporter[]` 列表（顺序决定输出顺序）。
- 统一调用约定的生命周期钩子：
  - `onInit(ctx)`（可选）
  - `onTestRunStart(...)`
  - `onQueued(file)` / `onCollected(files)`
  - `onTaskUpdate(update, events)`
  - `onTestRunEnd(...)` / `onTestRunFinished()`
- 保障：单个 reporter 抛错不会影响整个运行（策略：捕获并转为 `state:catchError(...)` 或输出到 errorStream；实现阶段确定）。

#### Reporter Context
对齐 Vitest “reporter 拿到 ctx/state”的体验，但在本项目中 **不提供 project**，避免引入 `TestProject`：
- `ctx.state`：`StateManager`（只读约定；reporters 的查询入口）
- `ctx.config`：`SerializedConfig`
- `ctx.outputStream/errorStream`：终端输出
- `ctx.startTime/endTime`：本次运行的时间信息（用于 summary/duration）

### 3) Event Translation（可选增强）
如果我们决定对齐 Vitest 的 reporter API（`onTestCaseResult/onTestModuleEnd/...`），可以在 dispatcher 中把 `TaskEventPack` 翻译为更高层回调：
- `test-prepare` -> `onTestCaseReady(TestCase)`
- `test-finished` -> `onTestCaseResult(TestCase)`
- `suite-prepare`：
  - File（module）-> `onTestModuleStart(TestModule)`
  - Suite -> `onTestSuiteReady(TestSuite)`
- `suite-finished`：
  - File（module）-> `onTestModuleEnd(TestModule)`
  - Suite -> `onTestSuiteResult(TestSuite)`

此层翻译不改变底层 `onTaskUpdate(update, events)` 的原始交付，以便高级 reporters 按需自处理。

## 默认输出（Windowed Reporter）
项目已存在 `renderers/windowedRenderer.lua`，并有 `scripts/test_windowed_renderer.lua` 的渲染逻辑样例。

默认终端 reporter（名称待定）将：
- 在运行中周期性刷新窗口内容（Test Files/Tests/Start at/Duration）。
- 在 `onTestRunEnd` 时停止窗口、输出最终 summary。

窗口内容所需统计可完全由 `StateManager` 计算得到：
- 文件统计：遍历 `state:getFiles()`，按 `file.result.state` 归类
- 用例统计：遍历 `state.idMap` 或通过 `reported-tasks` 的 children 遍历，按 `TestCase:result().state` 归类
- Duration：`nowMs() - runStartMs`

## 兼容性与扩展点
- 当前同进程阶段：直接共享 Task 实例；`reportedTasksMap` 以 weak-key 绑定 Task 对象即可工作。
- 未来多 worker 阶段：若跨进程传输，需要把 Task 树与 update/events 变为可序列化数据；本变更的 event store 以 taskId 为主键，天然利于未来迁移（State 仍是汇聚点，但不等同于“主线程”概念）。
