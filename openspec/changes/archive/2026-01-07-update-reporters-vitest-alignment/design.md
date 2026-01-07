# Design: update-reporters-vitest-alignment

## Goals
- 让 `luatest/core/controller/reporters/*` 与 `luatest/core/controller/logger.lua` 的“基础输出体验”更接近 Vitest。
- 优先对齐：windowed summary 的信息密度与事件驱动更新、DefaultReporter 的事件转发、结束输出区块结构。

## Key Constraints (与 Vitest 的差异来源)
1. **单线程执行模型**
   - 本项目代码结构看起来像“主线程 + 多 worker/RPC”，但当前 controller/runtime/worker 全部运行在同一进程/同一线程中。
   - 因此所有“实时渲染/进度更新”不能依赖后台线程或真正并发，只能依赖事件驱动与节流刷新策略。

2. **Lua 缺少 Node 的事件循环与定时器 API**
   - Vitest `SummaryReporter` 依赖 `setInterval/setTimeout` 来更新 duration、以及短暂保留已完成模块以减少闪烁。
   - Lua 标准库没有可靠的非阻塞 timer；如果强行 busy-wait 会影响测试执行。
   - 设计取舍：以“事件驱动刷新”为主（依赖 runner/controller 上报频率），避免引入新的 runtime 依赖。

3. **TTY 判断受限，但要求非 TTY 自动禁用**
   - Node `process.stdout.isTTY` 可直接判断；Lua 标准库没有等价 API。
   - 目标：当输出被重定向/非交互式（非 TTY）时，自动关闭 windowed summary，避免 ANSI 控制序列污染日志。
   - 设计取舍：实现一个 `isTTY` 启发式判定 + 显式覆盖，并将该逻辑提取为独立模块统一复用：
     - 建议文件：`luatest/utils/tty.lua`，提供 `isTTY()`（以及必要时的 `isNonTTY()`/`getReason()`）
     - reporters/logger 不再内联判断逻辑，只调用 `tty.isTTY()`
     - `FORCE_TTY=true|false` 用于强制启用/禁用（优先级最高）。
     - 默认在 `CI` 或 `TERM=dumb` 等场景视为非 TTY。
     - 其它场景视为 TTY（同时仍受 `config.windowed` 与 reporter options 控制）。
   - 注意：颜色支持（`colored.isSupported()`）与 TTY 是两件事；windowed summary 需要 `isTTY=true` 且终端支持 ANSI 控制序列才启用。

4. **无法无侵入拦截所有 stdout/stderr**
   - Vitest `WindowRenderer` 通过 monkey patch `process.stdout.write` 拦截所有输出。
   - `luatest` 目前通过：
     - `Logger:attachRenderer(renderer)` 把 `logger.write/log/error` 路由到 renderer
     - 在 `Luatest:start()` 临时覆写全局 `print` 指向 logger
   - 仍可能存在绕过路径（直接 `io.stdout:write`）。
   - 设计取舍：明确保证“print/logger 输出”在 window 上方即可，避免对用户代码做侵入式改写。

5. **Artifacts/Annotations 暂不实现**
   - 与 Vitest 的 `recordArtifact`/`TestAnnotation` 等能力不同，luatest 暂不实现 artifact/attachment 与用例注解能力。
   - 设计取舍：本次对齐聚焦于基础报告输出与 windowed summary，不引入新的 artifact/annotation 数据模型与渲染路径。

## Proposed Architecture

### 1) SummaryReporter（windowed summary）实现策略
目标对齐 Vitest `packages/vitest/src/node/reporters/summary.ts` 的核心体验，但在 Lua 环境中做约束内的实现：
- **数据来源**
  - 使用现有 reporter pipeline 回调：
    - `onTestModuleQueued` / `onTestModuleCollected` / `onTestModuleEnd`
    - `onTestCaseResult`
  - **不实现**慢用例/慢 hook 的独立列表，因此 `onTestCaseReady`/`onHookStart`/`onHookEnd` 不作为本次实现依赖（即便 DefaultReporter 仍转发这些事件，SummaryReporter 也可以忽略）。
- **状态模型（建议）**
  - `runningModules: map<moduleId, RunningModule>`
    - `filename`（module.task.name）
    - `projectName`（module.task.projectName，可选）
    - `total` / `completed`
    - `state`（queued/pending/finished）
    - `startedAtMs`（用于渲染“已运行耗时”；不依赖后台 timer，仅在 render 时计算）
    - `durationMs`（module 结束后可用的总耗时，用于渲染与颜色标记）
  - `modulesCounter` 与 `testsCounter`（类似 Vitest 的 Counter）
    - 以事件驱动更新，避免每次 render 全量扫描 state
- **渲染输出（窗口内容）**
  - 顶部空行
  - 每个 running module 一行（模块名 + 进度；queued 显示 `[queued]`；并在可用时附带耗时 `formatTime(...)`，按阈值用颜色标记）
  - 空行
  - 底部四行 summary（与现有 `BaseReporter:getSummaryLines()` 顺序一致）
  - 末尾空行
- **刷新策略**
  - 延续现有 `WindowRenderer:shouldRender()` + `schedule()` 的节流方式（避免高频刷新造成抖动）。
  - 不引入后台 timer；耗时显示在渲染时计算（`nowMs() - startedAtMs`），更新频率依赖事件频率与节流策略。

#### 耗时颜色标记（替代慢用例列表）
- 目标：不额外增加“慢用例/慢 hook”行数，仅通过颜色让耗时信息在模块行中更显著。
- 方案：对模块行的耗时字符串按阈值着色（固定分档；非 TTY/不支持颜色时不着色）。
  - 固定分档：`>= 5000ms` 使用红色；`>= 1000ms` 使用黄色；其它使用默认色/弱化显示。

### 2) DefaultReporter（事件转发与选项）
- 将以下回调转发给 summary（与 Vitest `default.ts` 对齐）：
  - `onTestModuleQueued/onTestModuleCollected/onTestModuleEnd`
  - `onTestCaseReady/onTestCaseResult`
  - `onHookStart/onHookEnd`
- 选项兼容：
  - 新增 `summary`（对齐 Vitest 命名），与现有 `windowed`/`config.windowed` 映射：
    - `summary=false` 或 `windowed=false` 或 `config.windowed=false` → 禁用 windowed summary
    - 其它情况启用，但必须满足 `isTTY=true`（非 TTY 自动禁用）；且在 ANSI 能力不足时禁用

### 3) BaseReporter（结束输出结构）
最小对齐 Vitest 的“结束阶段结构”，并复用已有 render utils：
- 当没有任何文件/用例且没有 errors 时输出 `No test found`（文本/退出码策略需确认）。
- 当存在失败或 unhandled errors：
  - 打印失败用例/套件区块（使用 `errorBanner`/`divider`），再打印最终 summary（顺序严格参考 Vitest：errors→summary）。
  - 失败详情先做最小实现（不做 stacktrace/codeframe 合成与 error merge）。

### 4) Logger（基础行为）
对齐范围限制在“支撑 reporters 输出”的能力：
- renderer attach/detach 时 cursor hide/show + flush
- `clearScreen/clearFullScreen` 受 `config.clearScreen` 控制
- cleanup 一定恢复 cursor（由 controller 生命周期保证）

## Compatibility Notes
- 本变更应保持 `config.reporters` 现有写法可用：
  - `{"default"}` / `{ {"default", { windowed=false }} }` 等
- 若引入 `summary` 选项，需保证不破坏旧的 `windowed` 语义。

## Validation Plan (high level)
- 添加一个脚本或 spec 来模拟 reporter 生命周期与事件序列，断言：
  - SummaryReporter 输出包含模块行与底部 summary 行
  - DefaultReporter 的转发使 SummaryReporter 的 counters 正确增长
  - 结束输出包含 No test found / errorBanner / summary（顺序严格参考 Vitest：errors→summary）
