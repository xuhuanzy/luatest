---@namespace Luatest


---@class Reporter
---@field onTestRunStart fun(self: self) # 测试运行开始
---@field onTestRunFinished fun(self: self)? # 测试运行结束
---@field onQueued fun(self: self, file: File)? # 单个文件进入队列(开始收集前)
---@field onCollected fun(self: self, files: File[])? # 收集完成后的回调(收到完整任务树)
---@field onTaskUpdate fun(self: self, update: TaskResultPack[], events: TaskEventPack[]) # 任务更新
---@field onTaskArtifactRecord fun(self: self, testId: string, artifact: any): any? # 任务产物/注解记录
---@field onAfterSuiteRun fun(self: self, meta: any)? # suite 运行后的 meta (例如 coverage)
