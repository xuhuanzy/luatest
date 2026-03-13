## MODIFIED Requirements
### Requirement: Resolve configuration with deterministic precedence
The core MUST resolve an effective configuration by merging:
1) built-in defaults
2) the root config file `<root>/luatest.config.lua` (if present)
3) CLI/runtime overrides
with the precedence: overrides > root config file > defaults.

#### Scenario: CLI overrides win over root config
- **GIVEN** defaults define `isolate=true`
- **AND** `<root>/luatest.config.lua` sets `isolate=false`
- **AND** CLI overrides set `isolate=true`
- **WHEN** the configuration is resolved
- **THEN** the effective configuration MUST use `isolate=true`

### Requirement: Support an optional config file
The core MUST support loading only one optional config file from project root: `<root>/luatest.config.lua`.

The core MUST NOT rely on arbitrary config file paths as a supported input for the new startup flow.

#### Scenario: Missing root config file falls back to defaults
- **GIVEN** `<root>/luatest.config.lua` does not exist
- **WHEN** the configuration is resolved
- **THEN** the effective configuration MUST equal built-in defaults merged with CLI/runtime overrides (if any)

#### Scenario: Root config file is a Lua module returning a table
- **GIVEN** `<root>/luatest.config.lua` exists
- **AND** it returns a Lua table
- **WHEN** the configuration is resolved
- **THEN** the returned table MUST be merged into defaults according to precedence rules

### Requirement: Validate and normalize configuration
The core MUST validate configuration types and MUST normalize the effective configuration into a stable shape required by runner/runtime/reporters.

#### Scenario: Invalid config produces an actionable error
- **GIVEN** a config source provides `bail="2"` (string)
- **WHEN** the configuration is validated
- **THEN** the core MUST surface an error that identifies the invalid field path (`bail`) and the expected type (number)
