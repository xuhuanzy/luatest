# Design: refactor-core-single-project-config

## Context
本次重构目标是把 `luatest/core` 从“可扩展但偏重预留”的结构，收敛到“当前阶段可快速验证”的单项目同步执行模型。核心约束：

- 不做异步/多线程
- 不做多项目
- 配置输入只来自根配置文件与 CLI 参数
- 启动必须先解析，再初始化测试中心

## Architecture

### 1) Startup Phases
新的 `core.run(options)` 采用固定五阶段：

1. `parse cli input`（由 CLI 层完成语法解析，并转为核心可消费的 overrides/targets）
2. `resolve config`（defaults + root config + cli overrides）
3. `resolve files`（显式文件或 include/exclude + targets）
4. `create test center`（controller/state/reporter/runtime 组装）
5. `execute & finalize`（执行、收尾、恢复全局）

### 2) Config Model
配置解析只接受两类外部输入：

- `<root>/luatest.config.lua`
- CLI overrides

并保证：

- precedence 固定：`defaults < root config < cli overrides`
- 解析阶段完成类型校验
- 解析阶段完成结构归一化
- 下游只消费“稳定配置对象”

### 3) Test Center Creation
测试中心（controller + runtime wiring）创建时机后移到“配置/文件都成功解析之后”。

这样可以保证：

- 配置错误时不会产生半初始化状态
- 文件发现失败时不会触发 reporter/worker 生命周期
- 整体生命周期更可预测

### 4) Error & Cleanup
执行阶段仍保持 fail-safe：

- 覆写全局（如 `print`）必须在 `finalize` 恢复
- runtime teardown 必须在 `finalize` 执行
- 错误转换为结构化结果（`exitCode=1` + errors）

### 5) Boundary Control
本次实现仅修改：

- `luatest/core/**`
- 必要的 CLI 接线（`bin/luatest.lua`）

明确不改：

- `luatest/expect/**`
- `luatest/runner/**`

若实现过程中确需触达上述目录，必须先向你确认。
