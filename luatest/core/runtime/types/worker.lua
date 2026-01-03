---@namespace Luatest


---@class WorkerGlobalState
---@field ctx WorkerContext
---@field current? Task 当前正在执行的任务
---@field filepath? string 当前工作文件路径
---@field durations { prepare: number, environment: number }
---@field collectStartTime number
---@field onCleanup fun(listener: fun())
---@field evaluatedModules EvaluatedModules 已加载的模块
---@field rpc? RuntimeRPC 与主线通信的接口, 但实际上我们目前是单线程模式, 这里是为了可能的扩展.

---@class WorkerContext
---@field config SerializedConfig 配置
---@field files string[] 工作文件列表
---@field controller? table 主控中心(主线程)引用
---@field rpc RuntimeRPC 与主线通信的接口, 但实际上我们目前是单线程模式, 这里是为了可能的扩展.

---@class WorkerExecuteContext
---@field files string[]

---@class LuatestWorker
---@field runTests fun(state: WorkerGlobalState)
---@field collectTests fun(state: WorkerGlobalState)
