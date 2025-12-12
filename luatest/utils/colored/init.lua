local tableConcat = table.concat
---@namespace Luatest

---@class Sequence
---@field open string
---@field close string

---@class Options
---@field enabled boolean
---@field level integer


---@enum Color
local Color = {
    reset = { open = "\27[0m", close = "\27[0m" },
    bold = { open = "\27[1m", close = "\27[22m" },
    dim = { open = "\27[2m", close = "\27[22m" },
    italic = { open = "\27[3m", close = "\27[23m" },
    underline = { open = "\27[4m", close = "\27[24m" },
    inverse = { open = "\27[7m", close = "\27[27m" },
    hidden = { open = "\27[8m", close = "\27[28m" },
    strikethrough = { open = "\27[9m", close = "\27[29m" },
    black = { open = "\27[30m", close = "\27[39m" },
    red = { open = "\27[31m", close = "\27[39m" },
    green = { open = "\27[32m", close = "\27[39m" },
    yellow = { open = "\27[33m", close = "\27[39m" },
    blue = { open = "\27[34m", close = "\27[39m" },
    magenta = { open = "\27[35m", close = "\27[39m" },
    cyan = { open = "\27[36m", close = "\27[39m" },
    white = { open = "\27[37m", close = "\27[39m" },
    gray = { open = "\27[90m", close = "\27[39m" },
    grey = { open = "\27[90m", close = "\27[39m" },
    redBright = { open = "\27[91m", close = "\27[39m" },
    greenBright = { open = "\27[92m", close = "\27[39m" },
    yellowBright = { open = "\27[93m", close = "\27[39m" },
    blueBright = { open = "\27[94m", close = "\27[39m" },
    magentaBright = { open = "\27[95m", close = "\27[39m" },
    cyanBright = { open = "\27[96m", close = "\27[39m" },
    whiteBright = { open = "\27[97m", close = "\27[39m" },
    bgBlack = { open = "\27[40m", close = "\27[49m" },
    bgRed = { open = "\27[41m", close = "\27[49m" },
    bgGreen = { open = "\27[42m", close = "\27[49m" },
    bgYellow = { open = "\27[43m", close = "\27[49m" },
    bgBlue = { open = "\27[44m", close = "\27[49m" },
    bgMagenta = { open = "\27[45m", close = "\27[49m" },
    bgCyan = { open = "\27[46m", close = "\27[49m" },
    bgWhite = { open = "\27[47m", close = "\27[49m" },
    bgGray = { open = "\27[100m", close = "\27[49m" },
    bgGrey = { open = "\27[100m", close = "\27[49m" },
    bgRedBright = { open = "\27[101m", close = "\27[49m" },
    bgGreenBright = { open = "\27[102m", close = "\27[49m" },
    bgYellowBright = { open = "\27[103m", close = "\27[49m" },
    bgBlueBright = { open = "\27[104m", close = "\27[49m" },
    bgMagentaBright = { open = "\27[105m", close = "\27[49m" },
    bgCyanBright = { open = "\27[106m", close = "\27[49m" },
    bgWhiteBright = { open = "\27[107m", close = "\27[49m" },
}

---@class (partial) Style
---@field reset Style 重置
---@field bold Style 加粗
---@field dim Style 弱化暗淡
---@field italic Style 斜体
---@field underline Style 下划线
---@field inverse Style 反显
---@field hidden Style 隐藏
---@field strikethrough Style 删除线
---@field black Style 黑色
---@field red Style 红色
---@field green Style 绿色
---@field yellow Style 黄色
---@field blue Style 蓝色
---@field magenta Style 品红色
---@field cyan Style 青色
---@field white Style 白色
---@field gray Style 灰色
---@field grey Style 灰色
---@field redBright Style 亮红色
---@field greenBright Style 亮绿色
---@field yellowBright Style 亮黄色
---@field blueBright Style 亮蓝色
---@field magentaBright Style 亮品红色
---@field cyanBright Style 亮青色
---@field whiteBright Style 亮白色
---@field bgBlack Style 背景黑色
---@field bgRed Style 背景红色
---@field bgGreen Style 背景绿色
---@field bgYellow Style 背景黄色
---@field bgBlue Style 背景蓝色
---@field bgMagenta Style 背景品红色
---@field bgCyan Style 背景青色
---@field bgWhite Style 背景白色
---@field bgGray Style 背景灰色
---@field bgGrey Style 背景灰色
---@field bgRedBright Style 背景亮红色
---@field bgGreenBright Style 背景亮绿色
---@field bgYellowBright Style 背景亮黄色
---@field bgBlueBright Style 背景亮蓝色
---@field bgMagentaBright Style 背景亮品红色
---@field bgCyanBright Style 背景亮青色
---@field bgWhiteBright Style 背景亮白色

---@param value integer
---@return integer
local function sanitizeLevel(value)
    local lvl = tonumber(value) or 0
    if lvl < 0 then
        lvl = 0
    elseif lvl > 3 then
        lvl = 3
    end
    return math.floor(lvl)
end

---@return integer
local function detectLevel()
    if os.getenv("NO_COLOR") then
        return 0
    end
    -- windows 10/11 现在也支持 ANSI 颜色代码了
    return 1
end

---@param stack Sequence[]
---@return Sequence[]
local function cloneStack(stack)
    local newStack = {}
    for i = 1, #stack do
        newStack[i] = stack[i]
    end
    return newStack
end

---@param ... any
---@return string
local function stringifyArgs(...)
    local count = select("#", ...)
    if count == 1 then
        local value = select(1, ...)
        return value == nil and "" or tostring(value)
    end

    local buffer = {}
    for i = 1, count do
        local value = select(i, ...)
        buffer[i] = value == nil and "" or tostring(value)
    end
    return tableConcat(buffer, " ")
end

---@class (partial) Style
---@field private stack Sequence[]
---@field private options Options
---@overload fun(...: any...): string
local Style = {}

---@package
---@param stack? Sequence[]
---@param options Options
---@return Style
function Style.new(stack, options)
    return setmetatable({
        stack = stack or {},
        options = options,
    }, Style)
end

---@package
---@param self Style
---@param key string
---@return any
function Style.__index(self, key)
    local seq = Color[key]
    if seq then
        local stack = cloneStack(self.stack)
        stack[#stack + 1] = seq
        return Style.new(stack, self.options)
    end

    return nil
end

---@package
---@param self Style
---@param ... any
---@return string
function Style.__call(self, ...)
    local message = stringifyArgs(...)

    if not self.options.enabled or self.options.level <= 0 or #self.stack == 0 or message == "" then
        return message
    end

    local openBuffer = {}
    local closeBuffer = {}

    for index = 1, #self.stack do
        openBuffer[index] = self.stack[index].open
        closeBuffer[#self.stack - index + 1] = self.stack[index].close
    end

    return tableConcat(openBuffer) .. message .. tableConcat(closeBuffer)
end

---@return boolean
function Style:getEnabled()
    return self.options.enabled
end

---@param enabled boolean
---@return Style
function Style:setEnabled(enabled)
    self.options.enabled = not not enabled
    return self
end

---@return integer
function Style:getLevel()
    return self.options.level
end

---@param level integer
---@return Style
function Style:setLevel(level)
    self.options.level = sanitizeLevel(level)
    return self
end

local defaultLevel = detectLevel()
return Style.new({}, {
    enabled = defaultLevel > 0,
    level = defaultLevel,
})
