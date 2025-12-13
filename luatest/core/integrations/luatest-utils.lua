---@namespace Luatest

---@export namespace
local export = {}


local _stubsGlobalNilValue = {}

---@return LuatestUtils
local function createLuaTestUtils()
    ---@type table<any, any>
    local _stubsGlobal = {}
    ---@class LuatestUtils
    local utils = {
        -- 更改全局变量的值.
        -- 我们可以调用`tu.unstubAllGlobals`恢复其原始值.
        ---@param name any
        ---@param value any
        stubGlobal = function(name, value)
            -- 如果不为 nil, 说明已经 stub 过
            if _stubsGlobal[name] == nil then
                local original = _G[name]
                _stubsGlobal[name] = original == nil and _stubsGlobalNilValue or original
            end
            _G[name] = value
        end,
        -- 将值重置为首次调用 tu.stubGlobal 之前的值
        unstubAllGlobals = function()
            for name, original in pairs(_stubsGlobal) do
                _G[name] = original == _stubsGlobalNilValue and nil or original
            end
            _stubsGlobal = {}
        end,
    }

    return utils
end

---@export namespace
export.luatestUtils = createLuaTestUtils()
-- lua 工具函数
---@export namespace
export.tu = export.luatestUtils

return export
