# Tasks: refactor-core-single-project-config

## 1. Spec & Scope
- [x] 1.1 对齐并确认“单项目 + 根配置 + CLI 覆盖 + 先解析后初始化”边界
- [x] 1.2 明确禁止修改 `expect/runner`（除非获得额外确认）

## 2. Core Pipeline Refactor
- [x] 2.1 重构 `core.run` 为分阶段流水线（解析配置 -> 解析文件 -> 初始化测试中心 -> 执行）
- [x] 2.2 统一错误返回模型，确保初始化前错误可直接终止
- [x] 2.3 保留并强化失败清理逻辑（global restore / teardown）

## 3. Config Resolution Simplification
- [x] 3.1 将配置文件来源收敛为 `<root>/luatest.config.lua`
- [x] 3.2 合并优先级固定为 `defaults < root config < cli overrides`
- [x] 3.3 在解析阶段完成校验与归一化，输出稳定配置结构

## 4. CLI Wiring
- [x] 4.1 调整 CLI 参数映射，仅保留本次支持的配置输入
- [x] 4.2 移除/拒绝与“非根配置文件”相关的旧入口行为

## 5. Validation
- [x] 5.1 运行已有脚本验证配置解析与文件解析
- [x] 5.2 运行端到端执行脚本确认重构后可完成一次完整运行
- [x] 5.3 更新变更任务状态为完成
