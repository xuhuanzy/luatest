local NOOP = require("luatest.utils.helpers").NOOP
local i18n = require("luatest.i18n")

local type = type
local select = select
local tableRemove = table.remove
local stringFormat = string.format
local tableUnpack = table.unpack

---@namespace Luatest

-- 调用顺序计数器
local invocationCallCounter = 1

-- 递增调用计数器, 并返回当前值
---@return integer
local function nextInvocationCallCounter()
    local order = invocationCallCounter
    invocationCallCounter = invocationCallCounter + 1
    return order
end

---@return MockContext
local function getDefaultState()
    return {
        calls = {},
        contexts = {},
        results = {},
        invocationCallOrder = {},
        lastCall = nil,
    }
end

---@param original? Procedure|table @原始函数或表
---@return MockConfig
local function getDefaultConfig(original)
    return {
        mockImplementation = nil,
        mockOriginal = original,
        mockName = "mock.fn()",
        onceMockImplementations = {},
    }
end

---@type table<fun(), true>  @还原函数表
local MOCK_RESTORE = setmetatable({}, { __mode = "k" })
---@type table<Mock, true>  @活跃的 mock 实例表
local REGISTERED_MOCKS = setmetatable({}, { __mode = "k" })
---@type table<Mock, MockConfig>  @mock 实例与配置的映射表
local MOCK_CONFIGS = setmetatable({}, { __mode = "k" })

---@class Mock<T>
---@field package state MockContext
---@field package config MockConfig
---@field mock MockContext<T>
---@field private name string
---@field private captureInstance? fun(...: any): any @实例捕获函数, 默认捕获第一个参数为实例.
---@field private restoreConfig MockRestoreConfig @还原配置
---@overload fun(...: MockParameters<T>...): MockReturnType<T>
local Mock = {}
---@package
Mock.__index = Mock

---触发 mock 时记录参数, 上下文, 执行结果
---@param self Mock
---@param ... any 调用参数
---@return any @执行结果
---@package
Mock.__call = function(self, ...)
    local args = { ... }
    local state = self.state
    local config = self.config
    state.calls[#state.calls + 1] = args
    state.lastCall = args
    state.invocationCallOrder[#state.invocationCallOrder + 1] = nextInvocationCallCounter()

    -- 上下文为`nil`时会破坏数组索引, 因此使用占位符`false`.
    local context = false
    if self.captureInstance then
        context = self.captureInstance(...)
    end
    state.contexts[#state.contexts + 1] = context

    local implementation = tableRemove(config.onceMockImplementations, 1)
        or config.mockImplementation
        or config.mockOriginal
        or NOOP
    ---@cast implementation function

    ---@type {[1]: boolean, [2]: any}
    local resultObj = { pcall(implementation, ...) }
    local ok = resultObj[1] and true or false
    ---@type any
    local returnValue = { tableUnpack(resultObj, 2) }
    if #returnValue == 1 then
        returnValue = returnValue[1]
    end
    ---@type MockResult<Procedure>
    local result = {
        type = ok and "return" or "throw",
        value = returnValue,
    }
    state.results[#state.results + 1] = result

    if not ok then
        error(returnValue, 0)
    end

    return returnValue
end

---返回下一次执行所使用的实现函数
function Mock:getMockImplementation()
    return self.config.onceMockImplementations[1] or self.config.mockImplementation
end

--- 设置模拟实现
---@param implementation Procedure
---@return self
function Mock:mockImplementation(implementation)
    self.config.mockImplementation = implementation
    return self
end

--- 接收一个仅执行一次的实现函数, 并在下次调用时使用.
---
--- 当一次性函数耗尽时, 会使用默认实现.
---@param implementation Procedure
---@return Mock
function Mock:mockImplementationOnce(implementation)
    self.config.onceMockImplementations[#self.config.onceMockImplementations + 1] = implementation
    return self
end

--- 接收一个值, 该值将在模拟函数执行时返回.
---@param value any
---@return self
function Mock:mockReturnValue(value)
    return self:mockImplementation(function()
        return value
    end)
end

--- 接收一个一次性实现的值, 该值将在模拟函数执行时返回.
---
--- 如果一次性实现函数已耗尽, 则使用默认实现.
---@param value any
---@return self
function Mock:mockReturnValueOnce(value)
    return self:mockImplementationOnce(function()
        return value
    end)
end

---清空所有记录但保留当前实现。
function Mock:mockClear()
    self.state.calls = {}
    self.state.contexts = {}
    self.state.results = {}
    self.state.invocationCallOrder = {}
    self.state.lastCall = nil
    return self
end

---重置 mock, 将实现还原到创建时的状态.
function Mock:mockReset()
    self:mockClear()
    local config = self.config
    local restoreConfig = self.restoreConfig

    if restoreConfig.resetToMockImplementation then
        config.mockImplementation = restoreConfig.mockImplementation
    else
        config.mockImplementation = nil
    end
    if restoreConfig.resetToMockName then
        config.mockName = self.name or "mock.fn()"
    else
        config.mockName = "mock.fn()"
    end
    config.onceMockImplementations = {}
    return self
end

function Mock:mockRestore()
    self:mockReset()
    if self.restoreConfig.restore then
        self.restoreConfig.restore()
    end
    return self
end

function Mock:getMockName()
    return self.config.mockName or "mock.fn()"
end

--- 创建 mock 实例.
---@param options? MockInstanceOption
---@return Mock
local function createMockInstance(options)
    options = options or {} ---@cast options MockInstanceOption
    if options.restore then
        MOCK_RESTORE[options.restore] = true
    end

    local state = getDefaultState()
    local config = getDefaultConfig(options.originalImplementation)

    local name = options.name or "Mock"
    ---@type PartialFunction<Mock>
    local mock = {
        state = state,
        config = config,
        mock = state, -- state 的别名, 用于外部使用
        _isMockFunction = true,
        name = name,
        captureInstance = options.captureInstance,
        restoreConfig = {
            resetToMockImplementation = options.resetToMockImplementation,
            mockImplementation = options.mockImplementation,
            resetToMockName = options.resetToMockName,
            restore = options.restore,
        }
    }
    local mock = setmetatable(mock, Mock)
    ---@cast mock Mock

    -- 重置为 mock 名称, 用于更好的调试效果
    if options.resetToMockName then
        config.mockName = name or "mock.fn()"
    end
    MOCK_CONFIGS[mock] = config
    REGISTERED_MOCKS[mock] = true

    if options.mockImplementation then
        mock:mockImplementation(options.mockImplementation)
    end

    return mock
end

--- 检查给定参数是否为 mock 函数.
---@param fn any
---@return boolean
local function isMockFunction(fn)
    if type(fn) ~= "table" then
        return false
    end
    return getmetatable(fn) == Mock
end

--- 创建监视程序.
---@generic T: Procedure
---@param originalImplementation T?
---@return Mock<T>
local function fn(originalImplementation)
    return createMockInstance({
        mockImplementation = originalImplementation,
        resetToMockImplementation = true,
    })
end


---默认的上下文捕获函数，返回第一个参数。
---@param ... any
---@return any
local function defaultCaptureContext(...)
    return select(1, ...)
end

---@generic T, K extends keyof T
---@param object T
---@param key K
---@return Mock<std.RawGet<T, K>>
local function spyOn(object, key)
    local original = object[key]
    assert(type(original) == "function", stringFormat(i18n("spyOn() 仅能用于监视函数. 但收到 '%s'"), type(original)))

    local name = type(key) == "string" and key or ("[%q]"):format(tostring(key))

    local mockInstance = createMockInstance({
        originalImplementation = original,
        restore = function ()
            object[key] = original
        end,
        captureInstance = defaultCaptureContext,
        name = name,
    })

    object[key] = mockInstance
    return mockInstance
end

--- 该方法会一次性恢复所有由 spyOn 创建的 spy 的原始实现.
---
--- 一旦完成还原, 即可重新对其进行监视.
local function restoreAllMocks()
    for restore in pairs(MOCK_RESTORE) do
        restore()
    end
    MOCK_RESTORE = setmetatable({}, { __mode = "k" })
end

--- 对所有 spies 调用 `.mockClear()`. 这将清除模拟的历史记录, 但不影响模拟的实现.
local function clearAllMocks()
    for mock in pairs(REGISTERED_MOCKS) do
        mock:mockClear()
    end
end

--- 对所有 spies 调用 `.mockReset()`. 这将清除模拟的历史记录, 并将每个模拟的实现重置为其原始状态.
local function resetAllMocks()
    for mock in pairs(REGISTERED_MOCKS) do
        mock:mockReset()
    end
end

---@export namespace
---@class MockStatic
local export = {
    fn = fn,
    spyOn = spyOn,
    isMockFunction = isMockFunction,
    restoreAllMocks = restoreAllMocks,
    clearAllMocks = clearAllMocks,
    resetAllMocks = resetAllMocks,
}

return export
