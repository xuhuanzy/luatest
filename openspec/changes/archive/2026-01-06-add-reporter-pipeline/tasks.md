# Tasks: add-reporter-pipeline

## 1. Reporting state（controller 存储）
- [x] 1.1 在 `StateManager` 中持久化 `TaskEventPack`（全局顺序 + taskId 索引）
- [x] 1.2 为 run 记录时间信息（start/end/duration）并暴露给 reporters 使用

## 2. Reporter pipeline（分发与生命周期）
- [x] 2.1 新增 reporter dispatcher/manager（维护 reporter 列表并 fan-out 回调）
- [x] 2.2 在 `Luatest:start` / `TestRun:start` / `TestRun:finish` 中接入 reporter 生命周期（init/start/end）
- [x] 2.3 修改 `TestRun:updated(update, events)`：先更新 state，再记录 events，并调用 reporters
- [x] 2.4 将 `enqueued/collected` 事件也分发给 reporters（用于文件级进度/窗口统计）

## 3. Default terminal reporter（最小可用输出）
- [x] 3.1 基于 `renderers/windowedRenderer.lua` 实现 windowed reporter（运行中刷新 summary）
- [x] 3.2 实现非 windowed fallback（非 TTY/关闭 window 模式时，至少输出最终 summary）
- [x] 3.3 用 `reported-tasks.lua` 输出失败用例最小信息（模块/用例名 + 错误摘要）

## 4. Validation
- [x] 4.1 新增冒烟脚本 `scripts/test_reporter_pipeline.lua`：模拟 `onQueued/onCollected/onTaskUpdate` 并断言 state/event store 与分发顺序
- [x] 4.2 本地运行：`lua scripts/test_state_manager.lua` + `lua scripts/test_reporter_pipeline.lua`
