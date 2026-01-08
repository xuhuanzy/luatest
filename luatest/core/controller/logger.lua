---@namespace Luatest

local Class = require("luatest.utils.class")
local tty = require("luatest.utils.tty")

local ESC = "\27["
local ERASE_DOWN = ESC .. "J"
local ERASE_SCROLLBACK = ESC .. "3J"
local CURSOR_TO_START = ESC .. "1;1H"
local HIDE_CURSOR = ESC .. "?25l"
local SHOW_CURSOR = ESC .. "?25h"
local CLEAR_SCREEN = "\27c"

---@class LoggerOptions
---@field outputStream? file
---@field errorStream? file
---@field getColumns? fun(): integer
---@field clearScreen? boolean

---@class Logger
---@field outputStream file
---@field errorStream file
---@field private getColumnsFn fun(): integer
---@field private clearScreen boolean
---@field private renderer any?
---@field private clearScreenPending string?
---@field private cleanupListeners function[]
---@field private cursorHidden boolean
local Logger = Class.class("Luatest.Logger")

---@param options? LoggerOptions
function Logger:__init(options)
    options = options or {}

    self.outputStream = options.outputStream or io.stdout
    self.errorStream = options.errorStream or io.stderr
    self.getColumnsFn = options.getColumns or function()
        return 80
    end
    self.clearScreen = options.clearScreen == true

    self.renderer = nil
    self.clearScreenPending = nil
    self.cleanupListeners = {}
    self.cursorHidden = false
end

---@param message string
---@param streamType? "output"|"error"
function Logger:write(message, streamType)
    streamType = streamType or "output"
    if message == nil or message == "" then
        return
    end

    if self.renderer and type(self.renderer.log) == "function" then
        self.renderer:log(message, streamType)
        if type(self.renderer.schedule) == "function" then
            self.renderer:schedule()
        end
        return
    end

    local stream = streamType == "error" and self.errorStream or self.outputStream
    stream:write(message)
    stream:flush()
end

---@private
function Logger:_clearScreen()
    if self.clearScreenPending == nil then
        return
    end

    local log = self.clearScreenPending
    self.clearScreenPending = nil
    self:write(CURSOR_TO_START .. ERASE_DOWN .. log .. "\n", "output")
end

---@param message string
function Logger:log(message)
    self:_clearScreen()
    self:write(message, "output")
end

---@param message string
function Logger:error(message)
    self:_clearScreen()
    self:write(message, "error")
end

---@param message string
function Logger:warn(message)
    self:_clearScreen()
    self:write(message, "error")
end

---@param message? string
function Logger:clearFullScreen(message)
    message = message or ""

    if not self.clearScreen then
        if message ~= "" then
            self:log(message .. "\n")
        end
        return
    end

    if message ~= "" then
        self:write(CLEAR_SCREEN .. ERASE_SCROLLBACK .. message .. "\n", "output")
    else
        self:write(CLEAR_SCREEN .. ERASE_SCROLLBACK, "output")
    end
end

---@param message string
---@param force? boolean
function Logger:clearScreen(message, force)
    if not self.clearScreen then
        self:log(message .. "\n")
        return
    end

    self.clearScreenPending = message
    if force then
        self:_clearScreen()
    end
end

---@return integer
function Logger:getColumns()
    local ok, cols = pcall(self.getColumnsFn)
    if ok and type(cols) == "number" and cols > 0 then
        return math.floor(cols)
    end
    return 80
end

---@param listener fun()
function Logger:onTerminalCleanup(listener)
    if type(listener) ~= "function" then
        return
    end
    self.cleanupListeners[#self.cleanupListeners + 1] = listener
end

function Logger:hideCursor()
    if self.cursorHidden then
        return
    end
    if not tty.isTTY() then
        return
    end
    self:write(HIDE_CURSOR, "output")
    self.cursorHidden = true
end

function Logger:showCursor()
    if not self.cursorHidden then
        return
    end
    self:write(SHOW_CURSOR, "output")
    self.cursorHidden = false
end

---@param renderer any
function Logger:attachRenderer(renderer)
    self.renderer = renderer
    self:hideCursor()
end

---@param renderer? any
function Logger:detachRenderer(renderer)
    if renderer == nil or self.renderer == renderer then
        self.renderer = nil
        self:showCursor()
    end
end

function Logger:cleanup()
    for _, fn in ipairs(self.cleanupListeners) do
        pcall(fn)
    end
    self:showCursor()
end

return Logger
