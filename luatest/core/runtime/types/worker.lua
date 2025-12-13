---@namespace Luatest


---@class WorkerGlobalState
---@field current? Task 当前正在执行的任务
---@field filepath string 工作文件路径
---@field onCleanup fun(self: self, listener: fun())
