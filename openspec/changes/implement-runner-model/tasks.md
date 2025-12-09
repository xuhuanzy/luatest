# Implementation Tasks

## 1. 类型定义

- [ ] 1.1 定义 Task 基础类型(Suite, Test, File)
- [ ] 1.2 定义 Runner 接口类型
- [ ] 1.3 定义 Hook 类型(beforeAll, afterAll, beforeEach, afterEach)
- [ ] 1.4 定义任务状态和结果类型

## 2. 收集器实现

- [ ] 2.1 实现全局收集上下文(collectorContext)
- [ ] 2.2 实现 `describe()` 函数创建 Suite
- [ ] 2.3 实现 `test()` / `it()` 函数创建 Test
- [ ] 2.4 实现上下文栈管理(pushSuite/popSuite)
- [ ] 2.5 实现测试树构建逻辑

## 3. 执行引擎核心

- [ ] 3.1 实现 `runSuite()` - Suite 递归执行
- [ ] 3.2 实现 `runTest()` - Test 执行和异常处理
- [ ] 3.3 实现生命周期钩子执行
- [ ] 3.4 实现任务状态更新和结果收集
- [ ] 3.5 实现 `runFiles()` - 文件级执行入口

## 4. Runner 接口

- [ ] 4.1 定义 Runner 配置接口
- [ ] 4.2 定义文件导入接口(importFile)
- [ ] 4.3 定义生命周期回调接口
- [ ] 4.4 实现 Runner 基础实现示例

## 5. 测试和验证

- [ ] 5.1 编写基础 Suite/Test 收集测试
- [ ] 5.2 编写嵌套 Suite 测试
- [ ] 5.3 编写生命周期钩子测试
- [ ] 5.4 编写执行顺序测试
- [ ] 5.5 编写错误处理测试

## 6. 文档

- [ ] 6.1 添加 API 使用示例
- [ ] 6.2 添加 Runner 接口实现指南
- [ ] 6.3 添加架构说明文档
