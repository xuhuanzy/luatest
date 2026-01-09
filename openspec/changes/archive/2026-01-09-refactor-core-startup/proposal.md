# Proposal: refactor-core-startup

## Why
当前 `luatest/core` 的“从配置到启动”链路存在明显断点与耦合：

- **配置解析缺失**：`luatest/core/controller/config/resolveConfig.lua` 仅返回 `core/defaults.lua`，无法从项目配置文件/运行参数生成有效 `SerializedConfig`。
- **启动职责混杂**：`luatest/core/controller/core.lua` 同时承担 config、logger、reporters、worker lifecycle、全局 `print` hook、错误收集/清理等职责，导致启动路径难以演进、难以测试、也难以复用为 CLI 入口。
- **启动上下文过窄**：`WorkerExecuteContext` 只包含 `files`，无法自然承载 `cwd/root/config/streams/argv` 等信息，造成“配置解析 -> 文件解析 -> 启动执行”无法形成单一可复用入口。
- **可执行入口缺失**：`bin/` 目前为空，`singletonRunner` 只能硬编码当前文件并直接调用 controller；未来要做 CLI/脚本集成会被迫复制启动逻辑。

本项目仍处于原型阶段，本变更允许对 `luatest/core/*` 做破坏性重构（不保留兼容层），以建立更清晰的启动与配置模式。

## What Changes
1. **引入统一的启动入口（Core App）**
   - 新增一个“组合根（composition root）”模块（命名待实现阶段确定，例如 `luatest.core.app`），对外暴露 `run(options)`：
     - 输入：`cwd/argv/configFile/configOverrides/files/include/exclude/streams` 等
     - 输出：结构化 `RunResult`（例如 `exitCode`、duration、errors、统计信息），供 `singletonRunner`/未来 CLI 复用

2. **完整的配置解析与归一化（Config Resolution）**
   - 支持三类来源并明确优先级：**defaults < config file < runtime overrides**
   - 在解析阶段完成：字段校验、默认值填充、结构归一化（确保 runner/runtime/reporters 使用到的配置形态稳定）

3. **启动流水线分层（Bootstrap Pipeline）**
   - Phase 1：resolve config（读取/合并/校验/归一化）
   - Phase 2：resolve test files（显式 files 或 include/exclude 规则）
   - Phase 3：init controller（state/reporters/logger）
   - Phase 4：run worker（collect/run；单线程模型保持不变）
   - Phase 5：finalize（report end、cleanup、恢复全局）

4. **明确错误与清理策略（Fail-safe lifecycle）**
   - 任意阶段出错都必须：
     - 记录为 unhandled error（供 reporters 最终输出）
     - 恢复被临时覆盖的全局（例如 `print`）
     - 执行 logger/renderer/worker teardown
   - 最终把错误向调用方抛出（或通过 `RunResult.exitCode=1` 反映失败），避免 silent failure

## Non-Goals
- **永远不实现 watch mode**（不支持文件变更触发重跑，不规划该能力，也不为其保留字段/兼容层）
- 不引入真实多 worker 并发执行（仍以单进程单线程为基线）
- 不在本变更中完成完整 CLI（但启动入口需能被 CLI 直接复用）
- 不为 `luatest/core/*` 提供兼容层（允许破坏性重构；调用点按 tasks 更新）

## Impact
- `luatest/core/*` 将出现“结构性重写”，核心启动 API 可能从 `Luatest.new():start(...)` 迁移为 `core.run(...)`（或类似入口）。
- `luatest/singletonRunner.lua` 将在实现阶段切换为调用新的启动入口，以保持 `require("luatest.singletonRunner")()` 的使用方式可继续工作（除非我们决定连该入口也一起 breaking）。
- 现有 reporting 行为继续以 `specs/test-reporting/spec.md` 为准；本变更的目标是不改变 reporting 语义，只重构启动与配置链路。

## Open Questions（需要你确认）
已确认：
1. 配置文件：固定为 `luatest.config.lua`（Lua 文件返回 table），不支持 JSON。
2. 文件选择：允许 `include/exclude` glob 用于项目级运行（显式 `files` 仍优先）。
3. 启动 API：`core.run()` 返回结构化 `RunResult`，由上层决定是否 `os.exit(code)`。
4. `singletonRunner`：在 CLI 模式下静默 no-op（便于手动调试进入断点；避免重复启动）。

## Vitest 对齐参考（用于指导结构，而非复制实现）
本变更的结构会参考 Vitest 的三个关键点，但做 Lua/单线程下的裁剪：

- `packages/vitest/src/node/core.ts`：`async _setServer(...)` 的“重置状态 -> resolveConfig -> 初始化 state/logger/run -> 运行”的骨架
- `packages/vitest/src/node/config/resolveConfig.ts`：defaults + user options + 上下文(root/mode) 合并与归一化
- `packages/vitest/src/node/config/serializeConfig.ts`：把“运行时真正需要”的配置提取为可传递形态（Vitest 用于 worker/跨进程；Luatest 可合并实现）

与 Vitest 的关键差异：
- Vitest 依赖 Vite 的更上层配置解析（`server.config`）；Luatest 必须自行完成完整配置解析，然后再交给 `Luatest:start`（或新的启动入口）执行。
- Vitest 在 watch/worker 场景下有“监控/协调”生命周期；Luatest 现阶段必须以“直接执行测试代码并同步返回结果”为基线。
- `singletonRunner` 需要一个简单的全局状态用于判断“是否处于 CLI 模式 / 是否已由上层启动执行”，避免重复执行。
