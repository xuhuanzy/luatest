## ADDED Requirements

### Requirement: Resolve configuration with deterministic precedence
The core MUST resolve an effective configuration by merging:
1) built-in defaults
2) an optional project config file
3) runtime overrides (CLI/programmatic)
with the precedence: overrides > config file > defaults.

#### Scenario: Runtime overrides win over config file
- **GIVEN** defaults define `isolate=true`
- **AND** a config file sets `isolate=false`
- **AND** runtime overrides set `isolate=true`
- **WHEN** the configuration is resolved
- **THEN** the effective configuration MUST use `isolate=true`

### Requirement: Support an optional config file
The core MUST support loading an optional config file provided via `configFile`.
If `configFile` is not provided, the core SHOULD attempt to load the default config file name `luatest.config.lua` from the project root.

#### Scenario: Missing config file falls back to defaults
- **GIVEN** no `configFile` is provided
- **AND** the default config file does not exist
- **WHEN** the configuration is resolved
- **THEN** the effective configuration MUST equal the built-in defaults merged with runtime overrides (if any)

#### Scenario: Config file is a Lua module returning a table
- **GIVEN** the default config file `luatest.config.lua` exists
- **AND** it returns a Lua table
- **WHEN** the configuration is resolved
- **THEN** the returned table MUST be merged into defaults according to precedence rules

### Requirement: Validate and normalize configuration
The core MUST validate configuration types and MUST normalize the effective configuration into a stable shape required by runner/runtime/reporters.

#### Scenario: Invalid config produces an actionable error
- **GIVEN** the config source provides `bail="2"` (string)
- **WHEN** the configuration is validated
- **THEN** the core MUST surface an error that identifies the invalid field path (`bail`) and the expected type (number)
