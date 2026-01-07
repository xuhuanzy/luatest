# Proposal: update-reporters-vitest-alignment

## Baseline (Vitest reference)
- Upstream: `vitest-dev/vitest` @ `fca1c95b47a9287b5d93fbd48a313117293651b7` (2026-01-06)
- Files:
  - `packages/vitest/src/node/logger.ts`
  - `packages/vitest/src/node/reporters/{base,default,summary,utils}.ts`
  - `packages/vitest/src/node/reporters/renderers/{utils,windowedRenderer}.ts`

## Why
`luatest` 的终端输出目前已经有 Vitest 风格的“windowed summary / render utils / reporter pipeline”骨架，但与 Vitest 的基础 reporter/logger 行为仍存在明显差异：
- `SummaryReporter` 仅渲染最终统计行，不展示“正在运行的测试文件 + 进度”等关键信息。
- `DefaultReporter` 没有把 module/test/hook 级事件转发给 summary，因此 windowed 模式缺少实时细节。
- `BaseReporter` 的结束输出结构与 Vitest 不一致（例如：错误区块与 summary 的组织方式、No test found 处理）。
- `Logger` 的终端体验（cursor、清屏/清理钩子）与 Vitest 的行为不完全一致，影响 windowed 输出稳定性。

对齐这些基础行为可以：
- 让默认输出更接近 Vitest（便于迁移与对照排错）。
- 让现有的 windowed renderer 真正输出“运行中状态”，而不只是静态 summary。
- 为后续实现更完整的 Vitest 风格输出（失败详情、suite/test 树、更多统计）打好基础。

## What Changes
1. **对齐 SummaryReporter（windowed summary）**
   - 增加“运行中模块列表 + 进度”的渲染（参考 Vitest `SummaryReporter.createSummary()`）。
   - 保留底部四行 summary：`Test Files` / `Tests` / `Start at` / `Duration`（使用现有 `renderers/utils.lua` 的格式化函数）。
   - 在实现上优先基于现有 reporter pipeline 的事件（`onTestModuleQueued/onTestModuleCollected/onTestCaseResult/onTestModuleEnd/...`）维护计数与可见模块列表。

2. **对齐 DefaultReporter（事件转发 + 选项兼容）**
   - 将 module/test/hook 级回调转发给 `SummaryReporter`（与 Vitest `default.ts` 对齐）。
   - 增加 `summary` 选项（与 Vitest 命名对齐），并与现有 `windowed`/`config.windowed` 做兼容映射（不做破坏性改动）。

3. **对齐 BaseReporter（结束输出结构）**
   - 增加 “No test found” 的基础处理（当前没有对应输出）。
   - 调整结束输出为 Vitest 风格的“错误区块 + 最终 summary”（顺序严格参考 Vitest：先 errors 区块，再最终 summary）。
   - 继续复用已有 `renderers/utils.lua` 的 `errorBanner/divider/getStateString/padSummaryTitle/formatTime` 等工具函数。

4. **对齐 Logger（与 windowed 输出相关的基础行为）**
   - 保持并强化：renderer attach/detach 时的 cursor 管理、`clearScreen/clearFullScreen` 语义与 flush 行为。
   - 不强行引入 Node 等价的 signal hook（Lua 标准库缺少可靠方案）；改为通过 controller 生命周期保证 `cleanup()` 一定被调用。

## Non-Goals
- 完整复刻 Vitest `BaseReporter` 的所有输出（snapshot/typecheck/browser/ui/import breakdown 等）。
- 不实现 Artifacts（artifact/attachment 等）与 Annotations/Annotate（用例注解/标注等）相关能力（不存储、不上报、不渲染）。
- 不引入真实的多线程/多进程 worker 并发执行；当前流程基线是单线程，本提案仅对齐输出行为与事件驱动渲染。
- 为 Lua 引入新的强依赖（例如 isatty 的 native 绑定、异步 event loop）来追求 100% 行为一致。
- 捕获所有绕过 `print/logger` 的直接 `io.stdout:write` 输出（Lua 标准库层面很难无侵入拦截）。

## Impact
- 默认 reporter 的终端输出会发生变化（windowed 模式信息更丰富；结束输出区块结构更接近 Vitest）。
- 可能新增/兼容 reporter 选项字段（例如 `summary`），但保持现有配置可用。
- 对现有 runner/controller 的数据流不做破坏性修改；主要在 reporter/logger 层增强。

## Decisions (已确认)
- Vitest 对齐基线：`vitest-dev/vitest` @ `fca1c95b47a9287b5d93fbd48a313117293651b7`（2026-01-06）。
- 非 TTY 环境下自动禁用 windowed summary。
- 结束输出顺序严格参考 Vitest：先打印失败/Unhandled Errors，再打印最终 summary。
- 不实现“慢用例/慢 hook 列表”；改为在输出中用不同颜色标记耗时（优先在 windowed summary 的模块行显示/上色耗时）。
- 耗时颜色阈值固定分档：`>= 5000ms` 红色，`>= 1000ms` 黄色，其它默认色/弱化。
- TTY 判定逻辑提取为独立模块统一实现（例如 `luatest/utils/tty.lua`），reporters/logger 只调用该模块。
