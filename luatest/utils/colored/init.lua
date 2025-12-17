---@namespace Luatest

local tableConcat = table.concat
local tostring = tostring

---@class ColorSequence
---@field open string
---@field close string
---@field replace? string  -- 用于 bold/dim 的特殊处理

---@type table<string, ColorSequence>
local colorsMap = {
    reset = { open = "\27[0m", close = "\27[0m" },
    bold = { open = "\27[1m", close = "\27[22m", replace = "\27[22m\27[1m" },
    dim = { open = "\27[2m", close = "\27[22m", replace = "\27[22m\27[2m" },
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
    bgBlack = { open = "\27[40m", close = "\27[49m" },
    bgRed = { open = "\27[41m", close = "\27[49m" },
    bgGreen = { open = "\27[42m", close = "\27[49m" },
    bgYellow = { open = "\27[43m", close = "\27[49m" },
    bgBlue = { open = "\27[44m", close = "\27[49m" },
    bgMagenta = { open = "\27[45m", close = "\27[49m" },
    bgCyan = { open = "\27[46m", close = "\27[49m" },
    bgWhite = { open = "\27[47m", close = "\27[49m" },

    blackBright = { open = "\27[90m", close = "\27[39m" },
    redBright = { open = "\27[91m", close = "\27[39m" },
    greenBright = { open = "\27[92m", close = "\27[39m" },
    yellowBright = { open = "\27[93m", close = "\27[39m" },
    blueBright = { open = "\27[94m", close = "\27[39m" },
    magentaBright = { open = "\27[95m", close = "\27[39m" },
    cyanBright = { open = "\27[96m", close = "\27[39m" },
    whiteBright = { open = "\27[97m", close = "\27[39m" },
    bgGray = { open = "\27[100m", close = "\27[49m" },
    bgGrey = { open = "\27[100m", close = "\27[49m" },

    bgBlackBright = { open = "\27[100m", close = "\27[49m" },
    bgRedBright = { open = "\27[101m", close = "\27[49m" },
    bgGreenBright = { open = "\27[102m", close = "\27[49m" },
    bgYellowBright = { open = "\27[103m", close = "\27[49m" },
    bgBlueBright = { open = "\27[104m", close = "\27[49m" },
    bgMagentaBright = { open = "\27[105m", close = "\27[49m" },
    bgCyanBright = { open = "\27[106m", close = "\27[49m" },
    bgWhiteBright = { open = "\27[107m", close = "\27[49m" },
}

---检测是否支持颜色输出
---@return boolean
local function isSupported()
    ---@type string[]|nil
    local argv = rawget(_G, "arg")

    ---@param flag string
    ---@return boolean
    local function hasArg(flag)
        if type(argv) ~= "table" then
            return false
        end
        for _, value in pairs(argv) do
            if value == flag then
                return true
            end
        end
        return false
    end

    if os.getenv("NO_COLOR") ~= nil or hasArg("--no-color") then
        return false
    end

    local isWindows = package.config:sub(1, 1) == "\\"
    local isTTY = os.getenv("FORCE_TTY") ~= "false"

    return os.getenv("FORCE_COLOR") ~= nil
        or hasArg("--color")
        or isWindows
        or (isTTY and os.getenv("TERM") ~= "dumb")
        or (os.getenv("CI") ~= nil)
end

-- 替换字符串中的 close 序列, 防止嵌套样式被提前关闭
---@param str string
---@param close string
---@param replace string
---@param startIndex integer
---@return string
local function replaceClose(str, close, replace, startIndex)
    local parts = {}
    local cursor = 1
    local index = startIndex

    while index do
        parts[#parts + 1] = str:sub(cursor, index - 1)
        parts[#parts + 1] = replace
        cursor = index + #close
        ---@diagnostic disable-next-line: assign-type-mismatch
        index = str:find(close, cursor, true)
    end

    parts[#parts + 1] = str:sub(cursor)
    return tableConcat(parts)
end

---@type table
local formatterMt = {
    ---@param self Formatter
    ---@param input any
    ---@return string
    __call = function(self, input)
        local str = tostring(input)
        local close = self.close
        local open = self.open
        local index = str:find(close, #open + 1, true)
        if index then
            return open .. replaceClose(str, close, self.replace, index) .. close
        end
        return open .. str .. close
    end,
}

---@type table
local stringFormatterMt = {
    __call = function(_, input)
        return tostring(input)
    end,
}

-- 创建格式化函数
---@param open string
---@param close string
---@param replace? string
---@return Formatter
local function createFormatter(open, close, replace)
    replace = replace or open

    ---@class Formatter
    ---@field open string
    ---@field close string
    ---@field replace string
    ---@overload fun(input: any): string
    return setmetatable({
        open = open,
        close = close,
        replace = replace,
    }, formatterMt)
end

-- 创建空操作的格式化函数
---@return Formatter
local function createStringFormatter()
    return setmetatable({
        open = "",
        close = "",
        replace = "",
    }, stringFormatterMt)
end


-- 获取默认颜色对象, 该对象不支持颜色
---@return Colors
local function getDefaultColors()
    local stringFormatter = createStringFormatter()
    ---@diagnostic disable-next-line: missing-fields
    ---@type Colors
    local colors = {
        isColorSupported = false,
    }

    for name in pairs(colorsMap) do
        colors[name] = stringFormatter
    end

    return colors
end

-- 创建颜色对象
---@return Colors
local function createColors()
    local enabled = isSupported()

    if not enabled then
        return getDefaultColors()
    end

    ---@diagnostic disable-next-line: missing-fields
    ---@type Colors
    local colors = {
        isColorSupported = enabled,
    }

    for name, seq in pairs(colorsMap) do
        colors[name] = createFormatter(seq.open, seq.close, seq.replace)
    end

    return colors
end

---@class Colors
---@field isColorSupported boolean 是否支持颜色
---@field reset Formatter 重置
---@field bold Formatter 加粗
---@field dim Formatter 弱化/暗淡
---@field italic Formatter 斜体
---@field underline Formatter 下划线
---@field inverse Formatter 反显
---@field hidden Formatter 隐藏
---@field strikethrough Formatter 删除线
---@field black Formatter 黑色
---@field red Formatter 红色
---@field green Formatter 绿色
---@field yellow Formatter 黄色
---@field blue Formatter 蓝色
---@field magenta Formatter 品红色
---@field cyan Formatter 青色
---@field white Formatter 白色
---@field gray Formatter 灰色
---@field grey Formatter 灰色
---@field blackBright Formatter 亮黑色
---@field redBright Formatter 亮红色
---@field greenBright Formatter 亮绿色
---@field yellowBright Formatter 亮黄色
---@field blueBright Formatter 亮蓝色
---@field magentaBright Formatter 亮品红色
---@field cyanBright Formatter 亮青色
---@field whiteBright Formatter 亮白色
---@field bgBlack Formatter 背景黑色
---@field bgRed Formatter 背景红色
---@field bgGreen Formatter 背景绿色
---@field bgYellow Formatter 背景黄色
---@field bgBlue Formatter 背景蓝色
---@field bgMagenta Formatter 背景品红色
---@field bgCyan Formatter 背景青色
---@field bgWhite Formatter 背景白色
---@field bgGray Formatter 背景灰色
---@field bgGrey Formatter 背景灰色
---@field bgBlackBright Formatter 背景亮黑色
---@field bgRedBright Formatter 背景亮红色
---@field bgGreenBright Formatter 背景亮绿色
---@field bgYellowBright Formatter 背景亮黄色
---@field bgBlueBright Formatter 背景亮蓝色
---@field bgMagentaBright Formatter 背景亮品红色
---@field bgCyanBright Formatter 背景亮青色
---@field bgWhiteBright Formatter 背景亮白色
local M = createColors()
M.createColors = createColors
M.getDefaultColors = getDefaultColors
M.isSupported = isSupported

return M
