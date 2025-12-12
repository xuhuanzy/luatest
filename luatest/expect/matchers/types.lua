---@namespace Luatest

---@class MatcherHintOptions
---@field comment string? 注释
---@field isNot boolean? 是否取反
---@field secondArgument string? 第二个参数
---@field expectedColor? fun(arg: string): string 预期值颜色
---@field receivedColor? fun(arg: string): string? 实际值颜色
---@field secondArgumentColor? fun(arg: string): string?? 第二个参数颜色
