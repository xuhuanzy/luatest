---@namespace Luatest

---@type table<string, table<string, string>>
local registry = {}
---@type string, string
local currentLocale, fallbackLocale

---@alias I18n.Locale "en" | "zh"

---@class I18n
---@overload fun(key: string, ...: any): string
local M = setmetatable({}, {
    __call = function(self, key, ...)
        local str = registry[currentLocale][key] or registry[fallbackLocale][key] or key
        str = tostring(str)
        if select("#", ...) == 0 then
            return str
        end
        return str:format(...) or str
    end,
})

---@param key string
---@param value {[I18n.Locale]: string}
function M:set(key, value)
    for locale, str in pairs(value) do
        registry[locale][key] = str
    end
end

--- 设置语言环境
---@param locale I18n.Locale
function M:setLocale(locale)
    currentLocale = locale
    if not registry[currentLocale] then
        registry[currentLocale] = {}
    end
end

--- 设置默认语言环境
---@param locale I18n.Locale
function M:setFallbackLocale(locale)
    fallbackLocale = locale
    if not registry[fallbackLocale] then
        registry[fallbackLocale] = {}
    end
end

M:setLocale("en")
M:setFallbackLocale("en")
return M
