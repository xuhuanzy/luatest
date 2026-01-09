# Tasks: refactor-core-startup

## 0. Prep
- [x] 0.1 明确 Open Questions（配置文件格式、文件选择、对外入口形态、root/cwd 策略）
- [x] 0.2 梳理当前入口调用点（`singletonRunner`、脚本、文档）并列出需要同步修改的文件清单
  - 注：本项目永远不实现 watch 模式（不做文件变更触发重跑）

## 1. Config Resolution
- [x] 1.1 定义新的配置数据模型（defaults + normalization 目标形态）并补齐缺失字段（root/name/sequence/hooks 等 runner 依赖项）
- [x] 1.2 实现 config file 读取（默认文件名 `luatest.config.lua` + 显式路径），并实现 `overrides > file > defaults` 合并
- [x] 1.3 实现配置校验与错误输出（字段路径 + 来源），并为错误建立统一错误类型/码（便于 CLI/IDE）
- [x] 1.4 为 config resolution 增加脚本级验证（例如 `scripts/test_config_resolution.lua`）

## 2. Bootstrap Pipeline（入口与生命周期）
- [x] 2.1 新增统一入口 `core.run(options)`（命名在实现阶段确定），返回结构化 `RunResult`
- [x] 2.2 实现 files resolution：显式 files 校验；补齐 include/exclude glob 规则、扫描与稳定排序
- [x] 2.3 重写 controller 启动 wiring：从 `run(options)` 注入 streams/已解析 config/files，驱动 reporter 生命周期（`Luatest:start` 不再做 config IO/解析）
- [x] 2.4 统一封装全局 `print` hook（保证异常时也能恢复）并完善 worker/logger cleanup

## 3. Integration
- [x] 3.0 新增全局 bootstrap state（用于 CLI/singletonRunner 判断“是否处于 CLI / 是否已执行过”）
- [x] 3.1 更新 `luatest/singletonRunner.lua`：改为调用新的启动入口，并基于 bootstrap state 实现“CLI 模式静默 no-op + 进程内仅执行一次”
- [x] 3.2 更新/新增一个“项目级运行”示例脚本（例如 `scripts/run_project.lua`），覆盖 config file + include/exclude + exitCode

## 4. Validation
- [x] 4.1 冒烟运行：`lua spec/example.test.lua`（不修改该文件）
- [x] 4.2 脚本验证：运行新增的 config/bootstrap 脚本，断言关键输出/exitCode
- [x] 4.3 回归 `openspec validate --strict`（确保本 change 文档与 specs 仍通过）
