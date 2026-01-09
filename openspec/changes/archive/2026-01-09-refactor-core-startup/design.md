# Design: refactor-core-startup

## Goals
- 形成一个“从配置解析到启动执行”的单一入口，避免 `singletonRunner`/未来 CLI 重复拼装逻辑。
- 将启动流程拆分为可测试的纯函数/小模块：`config -> files -> controller -> runtime -> finalize`。
- 明确生命周期与清理：任何异常都能保证恢复全局状态并完成资源清理。
- 在不改变 `specs/test-reporting/spec.md` 行为约束的前提下重构 `luatest/core/*`（本变更聚焦启动与配置，不重写 reporter 语义）。

## Constraints
- 单进程单线程执行模型保持不变（RPC/worker 仍是接口隔离，不是线程边界）。
- **永远不实现 watch mode**：不支持文件变更触发重跑，也不为其保留字段/兼容层。
- Lua 标准库缺少可靠的异步定时器；启动/执行阶段避免引入“后台刷新线程”之类机制。
- 原型阶段允许破坏性重写 `luatest/core/*`，不做兼容层；调用点在实现任务中同步调整。

## Current Flow (as-is)
入口（示例）：
- `luatest/singletonRunner.lua` 读取 `arg[0]`，调用 `luatest.core.controller.core`.new():start({ files = { currentFile } })

controller 启动（`luatest/core/controller/core.lua`）：
1. `resolveConfig(self)`（当前仅返回 defaults）
2. 构建 `Logger` 与 `ReporterManager`
3. `testRun:start(files)`（开始 run 生命周期）
4. `workerInit.start(config)` + 覆写全局 `print`
5. `workerInit.run(ctx)`（执行 collect + run）
6. 恢复 `print`、catch error、`testRun:finish()`、`logger:cleanup()`

关键问题：
- config 来源单一且不可扩展
- 启动入口不可复用（未来 CLI 必然复制逻辑）
- 生命周期/清理逻辑分散在 controller 内，难以拆分测试

## Proposed Architecture

### 1) Composition Root: `core.run(options)`
新增一个“组合根”入口（模块/命名在实现阶段确定），负责把纯数据转换为可运行的系统。

**Input (`RunOptions`)**
- `cwd`：运行目录（默认 Lua 进程当前目录）
- `argv`：命令行参数（为未来 CLI 预留；programmatic 可为空）
- `files`：显式文件列表（优先级高）
- `include/exclude`：文件选择规则（可选；用于项目级运行）
- `configFile`：显式配置文件路径（可选）
- `configOverrides`：运行时覆盖（可选；用于 CLI flags / IDE）
- `outputStream/errorStream`：输出流（默认 stdout/stderr）

**Output (`RunResult`)**
- `exitCode`：0/1（是否失败；供 CLI/脚本集成）
- `state`：最终 `StateManager`（reporters/IDE 可复用）
- `errors`：unhandled errors（与 reporters 输出一致）
- `summary`：基础统计（files/tests、duration、startAt 等）

### 1.1) Vitest 结构映射（仅参考骨架）
参考 Vitest `Vitest._setServer(...)` 的意图，我们在 Luatest 侧做等价映射（但不引入 Vite server / watcher）：

- `resolveConfig(vitest, options, server.config)` → `resolveConfig(runOptions)`：在 Luatest 内自行完成 defaults + config file + overrides 合并与归一化，产出“可直接运行”的配置。
- `serializeConfig(project)` → `serializeConfig(resolvedConfig)`：Vitest 用于跨 worker 传输；Luatest 单线程可以合并为一步，但仍建议在实现上保留“概念分层”（便于未来扩展多 worker）。
- `_setServer` 的“reset + init state/cache/testRun + start runner” → `core.run` 的“reset global state + init controller/logger/reporters + execute runtime + finalize”。

关键差异：
- Luatest 必须直接执行测试代码并同步返回（无 watch/后台监控线程作为前提）。
- Luatest 不存在 Vite 的上层配置解析，因此 `root/mode/env` 等必须由 Luatest 的解析器自行确定（来源：`cwd`/config file/overrides）。

### 2) Config Resolution (`core/config/*`)
目标：把多来源输入合并为稳定形态的“有效配置”。

- **defaults**：框架内置默认值（现有 `core/defaults.lua` 的演进版）
- **config file**：默认文件名固定为 `luatest.config.lua`（Lua 文件返回 table）；也支持 `RunOptions.configFile` 指定显式路径；不支持 JSON
- **overrides**：运行时覆盖（CLI/IDE/programmatic）
- **precedence**：overrides > config file > defaults
- **validation**：对类型/字段做校验并产生可定位错误（包含字段路径与来源）
- **normalization**：保证关键子结构存在（例如 `sequence` table），避免下游到处写 nil 容错

实现原则（与 Vitest 的 resolve/serialize 合并策略相关）：
- `Luatest:start` 不负责做任何配置 IO/解析；它只接收“已解析完毕”的配置并运行（更易测试，也更利于 CLI/IDE 复用）。
- 解析阶段直接产出“可运行配置”（含 runner 必需字段的默认值与归一化），避免在执行期间再做补丁式 `nil` 容错。
- 若需要区分 controller 与 runtime 使用的字段，允许在解析阶段返回 `{ controllerConfig, runtimeConfig }` 两份；单线程下也可以是同一份表引用。

### 3) File Resolution (`core/files/*`)
目标：将 `files/include/exclude` 归一为最终 `files[]`。

- 若提供 `RunOptions.files`：直接使用（并进行存在性/后缀校验）
- 否则按 `include/exclude` glob 解析并生成候选文件集合，再应用 exclude 过滤
- 输出必须是确定顺序的列表（避免输出抖动导致 reporter/IDE 体验不稳定）

### 4) Controller Boot (`core/controller/*`)
目标：只做 wiring，避免把“解析逻辑”塞进 controller。

- controller 接收“已解析配置 + 已解析 files + streams”
- 组装 `StateManager`、`ReporterManager`、`Logger`
- 驱动 test run 生命周期：start -> onUpdate -> finish
- 与 runtime/worker 的交互保持现有单线程 RPC 思路（后续可扩展多 worker）

### 5) Fail-safe Lifecycle
核心原则：任何异常都不能导致全局状态与终端状态遗留污染。

- 全局覆写（例如 `print`）必须使用“作用域 guard”确保恢复
- logger renderer/cursor 必须在 finally/cleanup 中恢复
- worker teardown 必须在 finally 中执行
- 抛错策略：
  - 对“框架内部错误”记录为 unhandled error，并使 `exitCode=1`
  - 对“用户测试失败”走正常结果通道（同样 `exitCode=1`，但不抛异常）

### 6) Bootstrap Global State（给 singletonRunner/CLI 使用）
需要一个极小的全局状态（模块或 `_G` 上的命名空间均可，具体在实现阶段确定），用于：
- 标识是否处于 CLI 启动模式（CLI 负责置位；`singletonRunner` 检测到后应 no-op）
- 标识当前进程是否已触发过一次 run（避免同进程内重复执行）

该状态必须满足：
- 默认安全：未设置时视为“非 CLI + 未运行”，以支持直接 `lua spec/example.test.lua` 的单文件入口。
- 可恢复/可重置：测试执行结束后允许重置（用于同进程重复运行/脚本/IDE；不引入 watch）。

## Compatibility
本变更明确允许对 `luatest/core/*` 做破坏性重构，但需注意：
- `specs/test-reporting/spec.md` 是已归档能力的行为约束；除非我们在本 change 中显式修改该 spec，否则必须继续满足。
- `spec/example.test.lua` 禁止修改；实现阶段应确保其仍可通过 `singletonRunner` 跑通（即使内部 core API 已重写）。

## Implementation Notes (for tasks)
- 优先把“解析/归一化”实现为纯 Lua 函数，方便用脚本单测。
- 将“组合根”保持薄层，避免再次形成巨型 `core.lua`。
- 将最容易出错的全局操作（`print` hook、renderer cursor）集中封装，以便统一验证。
