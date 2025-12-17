---@namespace Luatest
local tableConcat = table.concat
local stringRep = string.rep

local DEFAULT_RENDER_INTERVAL_MS = 1000

-- ANSI 转义序列常量
local ESC = "\27["
local CLEAR_LINE = ESC .. "K"
local MOVE_CURSOR_ONE_ROW_UP = ESC .. "1A"
local SYNC_START = ESC .. "?2026h"
local SYNC_END = ESC .. "?2026l"

---@alias StreamType "output" | "error"

-- 移除 ANSI 转义序列
---@param str string
---@return string
---@return integer
local function stripVTControlCharacters(str)
    -- 移除各种 ANSI 转义序列
    return str
        :gsub("\27%[[%d;]*[A-Za-z]", "")   -- CSI 序列
        :gsub("\27%][^\7]*\7", "")         -- OSC 序列
        :gsub("\27[PX^_][^\27]*\27\\", "") -- DCS/PM/APC/SOS 序列
end

-- 计算实际需要渲染到流中的行数
---@param rows string[]
---@param columns integer
---@return integer
local function getRenderedRowCount(rows, columns)
    local count = 0
    for _, row in ipairs(rows) do
        local text = stripVTControlCharacters(row)
        count = count + math.max(1, math.ceil(#text / columns))
    end
    return count
end

---@class WindowRendererOptions
---@field outputStream file 输出流
---@field errorStream file 错误流
---@field getColumns fun(): integer 获取终端列数
---@field interval? integer 渲染间隔(ms)
---@field getWindow fun(): string[] 获取窗口内容

---@class BufferItem
---@field type StreamType
---@field message string

---@class WindowRenderer
---@field private options WindowRendererOptions
---@field private buffer BufferItem[]
---@field private windowHeight integer
---@field private started boolean
---@field private finished boolean
---@field private lastRenderTime number
---@field private renderScheduled boolean
local WindowRenderer = {}
WindowRenderer.__index = WindowRenderer

-- 创建一个新的 WindowRenderer
-- 在终端底部渲染 getWindow 的内容, 并将所有拦截的输出转发到其上方
---@param options WindowRendererOptions
---@return WindowRenderer
function WindowRenderer.new(options)
    ---@type WindowRenderer
    local self = setmetatable({}, WindowRenderer)

    self.options = {
        interval = options.interval or DEFAULT_RENDER_INTERVAL_MS,
        outputStream = options.outputStream or io.stdout,
        errorStream = options.errorStream or io.stderr,
        getColumns = options.getColumns,
        getWindow = options.getWindow,
    }

    self.buffer = {}
    self.windowHeight = 0
    self.started = false
    self.finished = false
    self.lastRenderTime = 0
    self.renderScheduled = false

    return self
end

-- 启动渲染器
function WindowRenderer:start()
    self.started = true
    self.finished = false
    self.lastRenderTime = os.clock() * 1000
end

-- 停止渲染器
function WindowRenderer:stop()
    self.started = false
end

-- 结束渲染, 写出所有缓冲内容并停止缓冲
--
-- 之后所有拦截的写入将直接转发到实际写入
function WindowRenderer:finish()
    self.finished = true
    self:flushBuffer()
end

-- 将消息添加到缓冲区
---@param message string
---@param type? StreamType
function WindowRenderer:log(message, type)
    type = type or "output"
    if self.finished or not self.started then
        self:write(message, type)
    else
        self.buffer[#self.buffer + 1] = { type = type, message = message }
    end
end

-- 队列新的渲染更新
function WindowRenderer:schedule()
    if not self.renderScheduled then
        self.renderScheduled = true
        self:flushBuffer()

        -- 重置标志
        self.renderScheduled = false
    end
end

-- 检查是否应该渲染
---@return boolean
function WindowRenderer:shouldRender()
    local now = os.clock() * 1000
    if now - self.lastRenderTime >= self.options.interval then
        self.lastRenderTime = now
        return true
    end
    return false
end

-- 刷新缓冲区
---@private
function WindowRenderer:flushBuffer()
    if #self.buffer == 0 then
        return self:render()
    end

    ---@type BufferItem?
    local current = nil

    -- 将相同类型的消息合并到单次渲染中
    for _, next in ipairs(self.buffer) do
        if not current then
            current = next
        elseif current.type ~= next.type then
            self:render(current.message, current.type)
            current = next
        else
            current.message = current.message .. next.message
        end
    end

    -- 清空缓冲区
    self.buffer = {}

    if current then
        self:render(current.message, current.type)
    end
end

-- 渲染内容
---@private
---@param message? string
---@param type? StreamType
function WindowRenderer:render(message, type)
    type = type or "output"

    if self.finished then
        self:clearWindow()
        if message and message ~= "" then
            self:write(message, type)
        end
        return
    end

    local windowContent = self.options.getWindow()
    local columns = self.options.getColumns()
    local rowCount = getRenderedRowCount(windowContent, columns)
    local padding = self.windowHeight - rowCount

    if padding > 0 and message then
        padding = padding - getRenderedRowCount({ message }, columns)
    end

    self:write(SYNC_START)
    self:clearWindow()

    if message then
        self:write(message, type)
    end

    if padding > 0 then
        self:write(stringRep("\n", padding --[[@as integer]]))
    end

    self:write(tableConcat(windowContent, "\n"))
    self:write(SYNC_END)

    self.windowHeight = rowCount + math.max(0, padding)
end

--- 清除窗口
---@private
function WindowRenderer:clearWindow()
    if self.windowHeight == 0 then
        return
    end

    self:write(CLEAR_LINE)

    for _ = 1, self.windowHeight - 1 do
        self:write(MOVE_CURSOR_ONE_ROW_UP .. CLEAR_LINE)
    end

    self.windowHeight = 0
end

-- 写入消息到对应的流
---@private
---@param message string
---@param type? StreamType
function WindowRenderer:write(message, type)
    type = type or "output"
    local stream = type == "error" and self.options.errorStream or self.options.outputStream
    stream:write(message)
    stream:flush()
end

---@export namespace
return {
    WindowRenderer = WindowRenderer,
    stripVTControlCharacters = stripVTControlCharacters,
    getRenderedRowCount = getRenderedRowCount,
}
