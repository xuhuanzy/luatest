# Proposal: refactor-core-single-project-config

## Why
当前 `luatest/core` 的配置链路仍带有“为未来并发/多项目预留”的复杂度，但项目当前明确处于测试阶段，且本次方向是：

- 仅支持**单项目**执行模型
- 仅解析**根目录配置文件** `luatest.config.lua`
- 仅接受 **CLI 参数**作为运行时覆盖来源
- 启动顺序固定为：**先解析配置，再初始化测试中心**

继续保留多来源/多形态入口会让 `core` 重构目标变得模糊，也会增加调试和验证成本。

## What Changes
1. **重写 core 启动管线（允许破坏性改动）**
   - `core.run(...)` 变为单一组合根入口
   - 入口阶段固定为：`parse CLI -> resolve config -> resolve files -> create test center -> execute -> finalize`

2. **收敛配置来源与解析策略**
   - 配置来源固定：`defaults < <root>/luatest.config.lua < cli overrides`
   - 不再支持任意路径配置文件解析（例如旧的 `configFile` 输入）
   - 配置校验与归一化在执行前一次性完成

3. **测试中心初始化后置**
   - 仅在配置和文件列表都解析成功后创建测试中心（controller/state/reporter/runtime wiring）
   - 配置错误、文件发现错误在初始化前直接失败并返回结构化结果

4. **明确改动边界**
   - 本变更仅修改 `luatest/core/**` 与必要的 CLI 接线代码
   - `luatest/expect/**`、`luatest/runner/**` 默认**不修改**；若实现中确需调整，将先征得你确认

## Non-Goals
- 不实现 watch 模式
- 不实现异步执行与多线程/多进程 worker
- 不实现多项目配置（如 `projects`）
- 不引入兼容层

## Impact
- `core` 对外输入形态会更聚焦于 CLI 使用场景
- 旧的“任意配置文件路径”行为将被移除
- 由于当前未投入生产，可接受 API/行为 breaking change

## Notes for Approval
你已明确授权：可完全重构 `luatest/core`，无需兼容代码。

待你批准后，我会按本 proposal 直接进入实现，并严格遵守：
- 不触碰 `expect/runner`，除非先得到你确认。
