---@namespace Luatest

local MATCHERS_OBJECT = {}
local GLOBAL_EXPECT = {}

---@export namespace
local export = {
    -- 匹配器对象
    ["MATCHERS_OBJECT"] = MATCHERS_OBJECT,
    -- 全局 expect
    ["GLOBAL_EXPECT"] = GLOBAL_EXPECT,
}

return export
