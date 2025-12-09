# Project Context

## Purpose

实现一个 Lua 测试框架

## Tech Stack

Lua5.4

## Project Conventions

### Code Style

#### 命名规范

- 使用类似 TS 的命名规则而不是 lua 社区常用的下划线命名法

#### 注解规则

- 使用`emmylua-rust`注解, 语法参考 https://github.com/EmmyLuaLs/emmylua-analyzer-rust/tree/main/docs/emmylua_doc/annotations_CN

#### 语言规范

- 所有注释应该使用中文, 但标点符号使用英文

### Architecture Patterns

- **模块化设计**: 保持测试框架的核心功能模块化, 易于扩展和维护
- **简洁优先**: 默认实现少于 100 行代码的解决方案, 单文件实现直到证明不足够
- **避免过度工程**: 除非有明确的性能数据或规模需求, 否则选择简单、经过验证的模式

### Testing Strategy

- **自举测试**: 作为测试框架本身, 应该能够测试自己的功能
- **示例驱动**: 通过实际的测试用例来验证框架的功能
- **文档测试**: 确保文档中的示例代码是可运行和正确的

### Git Workflow

- **OpenSpec 驱动**: 重大功能变更需要先创建 OpenSpec 提案, 经过审核后再实施
  - 新功能/Breaking Changes/架构变更 → 创建提案 (`openspec/changes/`)
  - Bug 修复/文档更新/配置调整 → 直接修改
- **分支策略**:
  - `main` 分支为稳定版本
  - 功能分支命名使用 kebab-case, 如 `add-async-testing`
- **提交规范**: 使用清晰的提交信息, 说明修改的内容和原因

## Domain Context

### Lua 测试框架

本项目旨在为 Lua 5.4 开发一个现代化的测试框架, 参考 JavaScript 生态系统中成熟的测试框架(如 Vitest、Jest)的设计理念, 但针对 Lua 语言的特性进行适配.

主要框架概念参考自 Vitest.

### 关键概念

- **测试套件 (Test Suite)**: 组织相关测试用例的容器
- **测试用例 (Test Case)**: 单个测试场景的定义
- **断言 (Assertion)**: 验证预期结果的机制, 使用`luaassert`库. 该库API高度类似 jest: `expect(actual):toBe(expected)`
- **异步测试**: 支持 Lua 协程的异步测试场景

## Important Constraints

- **Lua 版本**: 严格使用 Lua 5.4
- **纯 Lua 实现**: 尽量避免依赖 C 扩展, 保持跨平台兼容性
- **性能要求**: 测试框架的执行开销应该尽可能小, 不影响测试速度

## External Dependencies

- **emmylua-rust**: 用于提供 LSP 支持和代码注解, 帮助开发者编写类型安全的代码
- **OpenSpec CLI**: 用于管理项目规范和变更提案的工具链
