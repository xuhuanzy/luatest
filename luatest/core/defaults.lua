---@namespace Luatest

local configDefaults = {
    -- runner required
    root = "",
    name = nil,
    retry = 0,
    testTimeout = 5000,
    includeTaskLocation = false,
    testNamePattern = nil,
    passWithNoTests = false,
    allowOnly = false,
    diffOptions = nil,

    -- runtime / execution
    bail = nil,
    logHeapUsage = nil,
    mockReset = false,
    clearMocks = false,
    restoreMocks = false,
    unstubGlobals = false,
    isolate = true,
    windowed = true,
    sequence = {
        shuffle = false,
        seed = 0,
        hooks = "stack",
    },
    reporters = { "default" },
    clearScreen = false,
    include = { "**/*.test.lua", "**/*.spec.lua" },
    exclude = {
        "**/node_modules/**",
        "**/dist/**",
        "**/cypress/**",
        "**/.idea/**",
        "**/.git/**",
        "**/.cache/**",
        "**/out/**",
        "**/.output/**",
        "**/.temp/**",
        "**/.upstream/**",
        "**/.tmp/**",
    },
}

return configDefaults
