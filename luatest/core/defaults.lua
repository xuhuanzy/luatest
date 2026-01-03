---@namespace Luatest

local configDefaults = {
    mockReset = false,
    clearMocks = false,
    restoreMocks = false,
    unstubGlobals = false,
    isolate = true,
    sequence = {
        shuffle = false,
    }
}

return configDefaults
