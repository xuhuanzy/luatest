local prettyFormat = require("luatest.utils.pretty-format").format

---@namespace Luatest

---@export namespace
local export = {}


--- 字符串化对象
---@param object any 要字符串化的对象
---@param maxDepth number? 最大深度
---@param maxWidth number? 最大宽度
---@return string @字符串化后的对象
local function stringify(object, maxDepth, maxWidth)
    return prettyFormat(object, {
        maxDepth = 10,
        maxWidth = 10,
    })
end
export.stringify = stringify


return export
