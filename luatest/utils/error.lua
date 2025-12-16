---@namespace Luatest

---@export namespace
local export = {}

---@param _err any
---@param diffOptions? DiffOptions
---@param seen? table<any, boolean>
---@return any
function export.processError(_err, diffOptions, seen)
    if not seen then
        seen = setmetatable({}, { __mode = "k" })
    end
    return _err
end

-- 查询调用栈中第一个不在调用者所在文件中的函数调用层级以报告错误
---@param level integer? 用作调用者源文件的级别
---@return integer @ 报告错误的层级
function export.errorLevel(level)
    level = (level or 1) + 1 --  调用者源文件的级别
    local info = debug.getinfo(level, "S")
    local source = (info or {}).source
    local file = source
    while file and (file == source or source == "=(tail call)") do
        level = level + 1
        info = debug.getinfo(level, "S")
        source = (info or {}).source
    end
    if level > 1 then level = level - 1 end -- 扣除 errorlevel() 本身的调用层级
    return level
end

-- 抛出错误
---@param e Error|string 当传入`string`时, 会自动转换为`Error`对象
function export.throw(e)
    if type(e) == "string" then
        ---@type Error
        e = { message = e }
    end
    error(e, 2)
end

return export
