---@namespace Luatest


---@class WorkerGlobalState
---@field ctx WorkerContext
---@field current? Task 当前正在执行的任务
---@field filepath? string 当前工作文件路径
---@field onCleanup fun(listener: fun())
---@field evaluatedModules EvaluatedModules 已加载的模块

---@class WorkerContext
---@field config SerializedConfig 配置
---@field files string[] 工作文件列表

---@class LuatestWorker
---@field runTests fun(state: WorkerGlobalState)
---@field collectTests fun(state: WorkerGlobalState)
