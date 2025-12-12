local i18n = require("luatest.i18n.core")
---@namespace Luatest

---@type table<string, {[I18n.Locale]: string}>
local translations = {
}

for key, translation in pairs(translations) do
    i18n:set(key, translation)
end
