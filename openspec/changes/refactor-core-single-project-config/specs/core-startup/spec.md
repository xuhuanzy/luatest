## MODIFIED Requirements
### Requirement: Provide an end-to-end run entrypoint
The core MUST provide a single entrypoint that runs tests end-to-end from resolved configuration to execution.

The startup order MUST be deterministic:
1) resolve config
2) resolve files
3) initialize test center
4) execute test run

#### Scenario: Programmatic run executes a list of files
- **GIVEN** `run(options)` is called with `files={"a.test.lua","b.test.lua"}`
- **WHEN** the run completes
- **THEN** the core MUST have executed both files in a deterministic order
- **AND** the run MUST produce a structured result (for example `exitCode` and basic summary data)

### Requirement: Resolve configuration before starting execution
The core MUST resolve and validate the effective configuration before creating the test center and before starting test execution.

#### Scenario: Test center creation happens after config resolution
- **GIVEN** a config file sets `isolate=false`
- **AND** runtime overrides set `isolate=true`
- **WHEN** the run starts
- **THEN** the effective config MUST be resolved first
- **AND** test center initialization MUST use the resolved config (`isolate=true`)

## ADDED Requirements
### Requirement: Enforce single-project startup model
The core MUST run in a single-project model and MUST NOT support multi-project startup orchestration.

#### Scenario: Startup uses exactly one project root
- **GIVEN** `run(options)` starts a test run
- **WHEN** config and file resolution complete
- **THEN** execution MUST target exactly one resolved project root
- **AND** the run MUST produce one aggregated `RunResult`
