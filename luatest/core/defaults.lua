---@namespace Luatest

local configDefaults = {
    mockReset = false,
    clearMocks = false,
    restoreMocks = false,
    unstubGlobals = false,
    isolate = true,
    windowed = true,
    sequence = {
        shuffle = false,
    },
    reporters = { "default" },
}

return configDefaults
