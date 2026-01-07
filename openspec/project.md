# Project Context

## Purpose
`luatest` 是一个受 Vitest/Jest 启发的 Lua 测试框架，目标是提供：
- BDD 风格测试 DSL：`describe`/`test`/`it` + `beforeAll`/`afterAll`/`beforeEach`/`afterEach`
- 断言库：`expect(...)`（支持 `not_` 反向断言）
- Mock/Spy：`mock.fn()`、`mock.spyOn()`、`restoreAllMocks()` 等
- 按测试文件隔离的模块运行环境（隔离 `require`/`package.loaded`，支持重置用户模块缓存）
- 可扩展的 controller/runtime 结构，为报告器与并发执行预留接口

## Tech Stack
- Language: **Lua**（当前本地验证通过 Lua 5.4.8；核心实现依赖 `load(..., env)` / `table.unpack`，因此最低 Lua 5.2+）
- Packaging: **LuaRocks**（`luatest-dev-1.rockspec`）
- Tooling:
  - EmmyLua 注解（大量使用 `---@namespace` / `---@class` / `---@alias` 等）
  - VS Code + EmmyLua Language Server（`.emmyrc.json`, `.vscode/`）
- Runtime: Lua 标准库（`io/os/debug/table/string/...`）；可选 LuaJIT 兼容（代码中对 `jit/ffi` 做了共享模块处理）

## Project Conventions

### Code Style
- 模块组织：以 `local export = {}` 导出；需要对外暴露时使用 `---@export namespace`/`---@export global`（配合 EmmyLua）
- 命名空间：文件顶部通常声明 `---@namespace Luatest`
- require 约定：模块名与目录结构一致，例如 `require("luatest.runner.run")`
- 文件命名：
  - 业务模块通常为 `lowerCamelCase.lua` 或 `kebab-case.lua`（跟随所在目录现有风格）
  - 测试文件使用 `*.test.lua`（位于 `spec/`）
- 其他：
  - 尽量使用 `local`，避免污染 `_G`；少量全局用于框架内部状态（例如全局 `expect`）
  - 错误抛出通常使用 `error(msg, errorLevel())` 以得到更友好的堆栈定位（见 `luatest/utils/error.lua`）

### Architecture Patterns
- Public API：`luatest/init.lua` 仅负责聚合导出 DSL（runner）与 expect/mock
- Runner（收集 + 执行）：`luatest/runner/*`
  - 收集：执行测试文件以构建 Task 树（File/Suite/Test）
  - 执行：按 Suite/Test、hook、mode（run/skip/only/todo/queued）驱动运行并上报事件
- Controller/State（主控状态）：`luatest/core/controller/*`
  - `StateManager` 维护 taskId → task 映射、文件/路径索引、reported entity（module/suite/test）等
  - RPC 目前用于单线程内的“接口隔离”，为未来多 worker 预留
- 执行模型：当前整体流程运行在**同一进程/同一线程**中；代码结构看起来像“主线程 + 多 worker/RPC”，但现阶段并不存在真实的多线程/多进程并发执行
- Runtime/Worker（执行环境）：`luatest/core/runtime/*`
  - 以 worker 抽象执行 `run`/`collect`
  - 当 `config.isolate=true` 时，对每个测试文件重置用户模块缓存并重建文件级隔离环境
- Module Isolation：`luatest/core/runtime/moduleRunner/*`
  - 通过自定义 `require` + `package.loaded` 代理实现“共享 luatest/标准库、隔离用户模块”的加载语义
- Assertions & Mocks：
  - `luatest/expect/*`：expect/Assertion/matchers（Jest 风格）
  - `luatest/spy/*`：mock.fn/spyOn/restoreAllMocks 等
- Utilities：`luatest/utils/*`（class/pretty-format/diff/colored/i18n 等）

### Testing Strategy
- 主要测试：`spec/*.test.lua`
  - 推荐写法：`local luatest = require("luatest")`，使用 `describe/test/it` 与 hooks
  - 运行方式：
    - 单文件：在测试文件顶部调用 `require("luatest.singletonRunner")()`，然后执行 `lua spec/xxx.test.lua`
    - 或者自行编写入口脚本调用 `require("luatest.core.controller.core").new():start({ files = {...} })`
- 冒烟/调试脚本：`scripts/test_*.lua`（例如 `lua scripts/test_state_manager.lua`）
- 约束：
  - runner 禁止在一个 test 执行期间再次调用 `test()` 定义新测试（必须放在 `describe`/suite 收集阶段）

### Git Workflow
- 分支：`main` + 短生命周期分支（推荐 `feat/<topic>` / `fix/<topic>` / `refactor/<topic>` / `chore/<topic>`）
- 提交：**必须严格遵循 Conventional Commits (v1.0.0)**
  - 格式：`<type>[optional scope][!]: <description>`
  - type：`feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert`
  - breaking change：使用 `!` 或 footer `BREAKING CHANGE: ...`
- 合并：推荐 squash merge；squash message 也必须是合规 Conventional Commit
- 当前阶段不把测试作为合并门禁：目前暂无标准化测试结果输出/退出码（主要用于本地手动调试）

## Domain Context
- 核心对象模型（Task）：
  - `File`：一个测试文件的根 suite
  - `Suite`：`describe(...)` 产生的套件节点
  - `Test`：`test/it(...)` 产生的测试节点
- 运行模式（RunMode）：`run` / `skip` / `only` / `todo` / `queued`
- Isolation：
  - “隔离”指为每个测试文件创建新的 file env，并清理用户模块缓存；luatest 自身与标准库模块保持共享
- Mock 生命周期：
  - runtime 在每个文件运行后默认调用 `tu.restoreAllMocks()` 清理 spy/mock 造成的污染（更细粒度行为由 config 决定）

## Important Constraints
- Lua 版本：最低 Lua 5.4.8
- 暂不实现：Artifacts（artifact/attachment 等）与 Annotations/Annotate（用例注解/标注等）；相关能力不存储、不上报、不渲染
- `spec/example.test.lua` 是用于观察整个测试流程与 reporter 输出是否正确的入口用例；除非用户明确要求，否则**绝对禁止修改**该文件内容（包括用例结构、断言、输出、依赖等）
- 当前实现状态（供 AI 协作时避坑）：
  - `bin/luatest.lua` 目前为注释状态，CLI 尚未启用
  - `luatest-dev-1.rockspec` 的 modules 列表存在未同步项（例如引用了不存在的 `luatest/utils/utils.lua`），发布/打包前需校验

## External Dependencies
- 无外部服务/API 依赖；项目为纯 Lua 实现
- 发行/安装通常通过 LuaRocks（`luatest-dev-1.rockspec`）
- License: MIT（`LICENSE`）
