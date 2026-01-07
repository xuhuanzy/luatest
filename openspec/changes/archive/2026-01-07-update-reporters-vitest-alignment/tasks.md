# Tasks: update-reporters-vitest-alignment

## 0. Prep
- [x] 0.1 确认 Vitest 基线（commit/tag）与输出范围（见 proposal Open Questions）
- [x] 0.2 确认项目约束：单线程执行模型、暂不实现 Artifacts 与 Annotations/Annotate（避免任务范围膨胀）

## 1. SummaryReporter（windowed summary）
- [x] 1.1 在 `luatest/core/controller/reporters/summary.lua` 增加 module/test 事件处理（queued/collected/caseResult/moduleEnd...）；hook 事件本次忽略
- [x] 1.2 实现“运行中模块列表 + 进度”的窗口内容渲染，并保留底部四行 summary
- [x] 1.3 调整刷新策略（节流/避免闪烁），确保在典型事件频率下 duration/进度可见
- [x] 1.4 在模块行显示并用颜色标记耗时（替代慢用例/慢 hook 列表）

## 2. DefaultReporter（事件转发 + 选项对齐）
- [x] 2.1 在 `luatest/core/controller/reporters/default.lua` 转发 module/test/hook 回调到 SummaryReporter
- [x] 2.2 增加 `summary` 选项（对齐 Vitest 命名）并与 `windowed/config.windowed` 兼容
- [x] 2.3 提取并复用 TTY 判定模块 `luatest/utils/tty.lua`
- [x] 2.4 非 TTY 自动禁用 windowed summary（保留 `FORCE_TTY=true|false` 显式覆盖）
- [x] 2.5 捕获 `print` 的 stdout 并通过 `onUserConsoleLog` 以 `stdout | file > suite > test` block 实时输出（连续同任务合并 header，避免每次输出都重复 header）
- [x] 2.6 在 failed module 结束时输出 `❯ file (n tests | m failed) duration` + test list（文件头箭头按失败态使用红色；ms + 耗时颜色；嵌套 suite 的 test 行额外缩进以体现层级）

## 3. BaseReporter（结束输出结构）
- [x] 3.1 在 `luatest/core/controller/reporters/base.lua` 增加 No test found 的输出分支
- [x] 3.2 使用 `renderers/utils.lua` 的 `errorBanner/divider` 输出失败与 unhandled errors 区块（最小实现）
- [x] 3.3 严格参考 Vitest 对齐“errors vs summary”的输出顺序（errors→summary）
- [x] 3.4 对齐 banner/divider 列宽获取：实现并接入 `tty.getColumns()`（避免横线未铺满终端）
- [x] 3.5 对齐 Failed Tests 的详细错误输出：`FAIL  file > suite > test` 头 + 完整错误内容 + `divider([i/total])` 进度（不渲染源码片段/codeframe）

## 4. Logger（与 windowed 输出相关的基础行为）
- [x] 4.1 对齐 cursor hide/show 的触发时机与 cleanup 行为（不引入平台依赖）
- [x] 4.2（可选）补齐与 reporters 相关的 helper 输出（本次不需要）

## 5. Validation
- [x] 5.1 增加一个可运行脚本（例如 `scripts/test_summary_reporter.lua`）模拟事件流并断言输出关键行（避免依赖真实 TTY）
- [x] 5.2 在脚本中覆盖耗时阈值与颜色标记（至少断言“超过阈值时使用对应颜色序列/或对应格式化函数”）
- [x] 5.3 覆盖 `tty.isTTY()` 的关键分支（`FORCE_TTY`、`CI`、`TERM=dumb`）
- [x] 5.4 运行 `lua scripts/test_reporter_pipeline.lua` 与新增脚本，确保输出稳定
- [x] 5.5 更新 `scripts/test_default_reporter_output.lua` 覆盖 stdout block（含连续输出合并 header）与 failed module 列表输出（含嵌套 suite 缩进）
- [x] 5.6 更新脚本覆盖 Failed Tests 的 `FAIL` 头、错误内容与 `divider([i/total])` 进度输出
