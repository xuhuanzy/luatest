# Change: 实现简单的 Runner 模型

## Why

luatest 框架目前缺少测试执行引擎. 参考 Vitest 的 `@vitest/runner` 设计, 我们需要实现一个环境无关的测试调度器, 负责:

- 组织测试结构(Suite/Test/File)
- 收集测试任务
- 处理生命周期钩子
- 执行测试逻辑并报告结果

这是测试框架的核心组件, 为后续的文件发现、并发执行、报告生成等功能奠定基础.

## What Changes

本变更将实现以下核心能力:

1. **任务模型 (Task Model)**

   - 定义 Suite, Test, File 三种任务类型
   - 实现任务树状结构
   - 支持任务元数据(名称、状态、结果等)

2. **收集器模式 (Collector Pattern)**

   - 实现全局收集上下文
   - 提供 `describe()` 和 `test()` API
   - 支持测试定义的栈式管理

3. **执行引擎 (Execution Engine)**

   - 实现 Suite 递归执行
   - 实现 Test 执行和结果收集
   - 支持生命周期钩子 (beforeAll, afterAll, beforeEach, afterEach)

4. **Runner 接口抽象**
   - 定义 Runner 接口, 将文件加载等环境相关操作委托给外部实现
   - 提供生命周期回调钩子

## Impact

- **新增 specs**:
  - `runner` - 测试执行引擎
  - `collector` - 测试收集机制
- **影响的代码**:

  - `luatest/runner/` - 新增 runner 核心实现
  - `luatest/types.lua` - 定义任务和 runner 接口类型

- **明确不包含**:
  - 文件发现和监听(不实现, 由外部提供)
  - 并发执行控制(不需要)
  - 热重载机制(不需要)
  - 断言库(使用独立的 luaassert)
  - 报告生成(后续实现)

## Dependencies

无前置依赖, 这是第一个核心功能.

## Migration Impact

这是新功能, 无迁移影响.
