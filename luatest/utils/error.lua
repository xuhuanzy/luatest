---@namespace Luatest
---@using Luaassert

---@export global
---@param _err any
---@param diffOptions? DiffOptions
---@param seen? table<any, boolean>
---@return any
local function processError(_err, diffOptions, seen)
    if not seen then
        seen = setmetatable({}, { __mode = "k" })
    end
end

return processError
