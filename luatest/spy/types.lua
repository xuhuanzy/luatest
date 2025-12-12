---@namespace Luatest

---@class MockInstanceOption
---@field name? string 模拟名称
---@field captureInstance? fun(...: any): any 实例捕获函数, 默认捕获第一个参数为实例.
---@field originalImplementation? fun(...: any): any 原始实现函数
---@field mockImplementation? fun(...: any): any  模拟实现函数
---@field resetToMockImplementation? boolean 是否重置为模拟实现
---@field restore? fun() 恢复原始实现
---@field keepMembersImplementation? boolean 是否保留成员实现
---@field resetToMockName? boolean 是否重置为模拟名称

---@alias Procedure fun(...: any...): any

---@alias MockParameters<T extends Procedure|table> T extends table and ConstructorParameters<T> or
---     T extends Procedure and Parameters<T> or never

---@alias MockReturnType<T extends Procedure|table> T extends table and nil or T extends Procedure and ReturnType<T> or never

---@alias MockContextCalls<T> T extends any... and any[] or T

---@class MockContext<T: Procedure|table>
---@field calls (MockContextCalls<MockParameters<T>>)[] 这是一个包含每次调用所有参数的数组. 数组中的每一项代表该次调用的参数.
---@field contexts any[] 这是一个包含每次调用时的上下文数组. 数组中的每一项代表该次调用的上下文.
---@field invocationCallOrder number[] 模拟执行的顺序。它返回一个数字数组，这些数字会在所有已定义的模拟之间共享。
---@field results MockResult<MockReturnType<T>>[] 这是一个包含每次调用结果的数组. 数组中的每一项代表该次调用的结果.
---@field lastCall MockParameters<T>|? 这是最后一次调用的参数. 如果 spy 从未被调用, 则返回 `undefined`.

---@class MockConfig
---@field mockImplementation? Procedure|table 模拟实现函数或表
---@field mockOriginal? Procedure|table 原始实现函数或表
---@field mockName? string 模拟名称
---@field onceMockImplementations (Procedure|table)[] 一次模拟实现函数或表数组

---@class MockResult<T>
---@field type "return" | "throw"
---@field value T

---@class MockRestoreConfig
---@field resetToMockImplementation? boolean @是否在重置时恢复默认实现.
---@field mockImplementation? Procedure @模拟实现函数.
---@field resetToMockName? boolean @是否在重置时恢复默认名称.
---@field restore? fun() @恢复原始实现.
