# Proposal: add-reporter-pipeline

## Why
当前 Runner 通过 `luatest/core/runtime/runners/init.lua` 将 `onQueued` / `onCollected` / `onTaskUpdate` 上报到 Control（`luatest/core/controller/test-run.lua`），但：

- `TestRun:updated(update, events)` 只会调用 `state:updateTasks(update)`，完全忽略 `events`，导致事件信息丢失。
- controller 侧尚未实现 reporters 管线（`luatest/core/controller/reporters/*` 目前只有 `reported-tasks.lua` 与 `renderers/windowedRenderer.lua`），因此无法把“已存储的状态 + 流式事件”交付给 reporter 做实时/最终输出。

这使得后续想做类似 Vitest 的输出（进度、窗口化 summary、失败用例回放等）缺少可靠的数据来源与生命周期钩子。

另外，本项目虽然参考 Vitest，但实现里没有“主线程 + TestProject”的概念；我们已移除 TestProject，并将运行期所需状态统一挂在 `StateManager`（State）上。因此 reporting 的 API/设计也应围绕 State（而不是 project）来组织与查询。

## What Changes
- 在 Control 侧引入“上报信息存储层”：在 `StateManager` 中持久化 `TaskEventPack`（全局顺序 + 按 taskId 索引），与已有的 `TaskResultPack -> task.result/meta` 存储形成完整的 reporting state。
- 引入 reporters 管线（dispatcher/manager）：将 RPC 收到的 `onQueued` / `onCollected` / `onTaskUpdate`（以及 test run start/end）按确定顺序分发给 reporters，并保证在回调前 state 已更新。
- 提供最小可用的默认终端 reporter（可选 windowed 渲染）：基于 `reported-tasks.lua` 与 `renderers/windowedRenderer.lua` 输出运行中窗口化 summary 与结束时 summary（文件/用例统计、耗时）。

## Non-Goals
- 不在本变更中实现 watch mode、合并多次运行的 blob、typecheck/browser 等 Vitest 扩展功能。
- 不实现 artifact/attachment 相关能力（不存储、不上报、不渲染）。
- 不在本变更中引入多 worker/跨进程序列化；当前以单线程架构（同进程共享 task 实例）为前提，但设计会尽量保持将来可扩展。

## Impact
- 新增 reporting state 与 reporter 生命周期后，Controller 将成为“真相来源”，reporters 仅负责渲染/输出。
- 现有 runner 行为不变；只是在 controller 侧补齐事件存储与分发，后续可逐步把更多事件（hook start/end、console logs）接入同一通道。

## Open Questions
1. Reporter API 是否要对齐 Vitest（`onTestModuleQueued/onTestCaseResult/...`）还是以当前 `types/reporter.lua` 的 `onTaskUpdate` 为主并逐步扩展？
2. `TaskEventPack[3] data` 需要在首版就承载哪些信息（hook 名称、错误、console logs），还是先保持 `nil`，等用例驱动再加？
3. 默认 reporter 的输出期望：只做 summary（类似 `scripts/test_windowed_renderer.lua`）还是也要按 test/suite 粒度打印失败详情？
