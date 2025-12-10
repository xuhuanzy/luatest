---@namespace Luatest

---@type table<Test, function>
local fnMap = setmetatable({}, { __mode = "k" })

---@type table<Suite, SuiteHooks>
local hooksMap = setmetatable({}, { __mode = "k" })

---设置测试函数
---@param key Test
---@param fn function
local function setFn(key, fn)
    fnMap[key] = fn
end

---获取测试函数
---@param key Test
---@return function
local function getFn(key)
    return fnMap[key]
end

---设置 Suite 钩子
---@param key Suite
---@param hooks SuiteHooks
local function setHooks(key, hooks)
    hooksMap[key] = hooks
end

---获取 Suite 钩子
---@param key Suite
---@return SuiteHooks
local function getHooks(key)
    return hooksMap[key]
end

---@export namespace
return {
    setFn = setFn,
    getFn = getFn,
    setHooks = setHooks,
    getHooks = getHooks,
}
