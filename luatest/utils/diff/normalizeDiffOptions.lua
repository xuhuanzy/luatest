---@namespace Luatest

local colored = require("luatest.utils.colored")

---@param text string
---@return string
local function noColor(text)
    return text
end

local DIFF_CONTEXT_DEFAULT = 5
local DIFF_TRUNCATE_THRESHOLD_DEFAULT = 0 -- 0 表示不截断

---@return DiffOptionsNormalized
local function getDefaultOptions()
    ---@type DiffOptionsNormalized
    return {
        aAnnotation = "Expected",
        aColor = colored.green,
        aIndicator = "-",
        bAnnotation = "Received",
        bColor = colored.red,
        bIndicator = "+",
        changeColor = colored.inverse,
        changeLineTrailingSpaceColor = noColor,
        commonColor = colored.dim,
        commonIndicator = " ",
        commonLineTrailingSpaceColor = noColor,
        compareKeys = nil,
        contextLines = DIFF_CONTEXT_DEFAULT,
        emptyFirstOrLastLinePlaceholder = "",
        includeChangeCounts = false,
        omitAnnotationLines = false,
        patchColor = colored.yellow,
        truncateThreshold = DIFF_TRUNCATE_THRESHOLD_DEFAULT,
        truncateAnnotation = "... 差异报告被截断",
        truncateAnnotationColor = noColor,
    }
end

---@param compareKeys? fun(a: string, b: string): number
---@return (fun(a: any, b: any): boolean)?
local function getCompareKeys(compareKeys)
    if type(compareKeys) == "function" then
        return compareKeys
    end
    return nil
end

---@param contextLines number|nil
---@return integer
local function getContextLines(contextLines)
    if type(contextLines) == "number"
        and contextLines >= 0
        and math.floor(contextLines) == contextLines
    then
        ---@cast contextLines integer
        return contextLines
    end
    return DIFF_CONTEXT_DEFAULT
end

--- 获取归一化差异选项
---@param options? DiffOptions
---@return DiffOptionsNormalized
local function normalizeDiffOptions(options)
    options = options or {}

    local normalized = getDefaultOptions()
    for key, value in pairs(options) do
        normalized[key] = value
    end
    ---@cast options DiffOptions

    normalized.compareKeys = getCompareKeys(options.compareKeys)
    normalized.contextLines = getContextLines(options.contextLines)

    return normalized
end

return normalizeDiffOptions
