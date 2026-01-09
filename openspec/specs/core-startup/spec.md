# core-startup Specification

## Purpose
TBD - created by archiving change refactor-core-startup. Update Purpose after archive.
## Requirements
### Requirement: Provide an end-to-end run entrypoint
The core MUST provide a single entrypoint that runs tests end-to-end from resolved configuration to execution.

#### Scenario: Programmatic run executes a list of files
- **GIVEN** `run(options)` is called with `files={"a.test.lua","b.test.lua"}`
- **WHEN** the run completes
- **THEN** the core MUST have executed both files in a deterministic order
- **AND** the run MUST produce a structured result (for example `exitCode` and basic summary data)

### Requirement: Never implement watch mode
The core MUST NOT implement watch mode.

Watch mode is defined as: observing file system changes and automatically re-running tests as a result.

#### Scenario: No watch-related behavior is exposed
- **GIVEN** a user is running tests via `core.run()`
- **WHEN** test files change on disk during or after the run
- **THEN** the core MUST NOT start a new run automatically

### Requirement: Resolve configuration before starting execution
The core MUST resolve and validate the effective configuration before starting test execution.

#### Scenario: Execution uses the resolved configuration
- **GIVEN** a config file sets `isolate=false`
- **AND** runtime overrides set `isolate=true`
- **WHEN** the run starts executing tests
- **THEN** the execution MUST use `isolate=true` as resolved by config precedence

### Requirement: Resolve test files before execution
The core MUST resolve the final test file list before starting execution.

#### Scenario: Explicit files bypass discovery
- **GIVEN** `run(options)` is called with an explicit non-empty `files` list
- **WHEN** the run starts
- **THEN** the core MUST NOT perform include/exclude discovery for determining the execution set

### Requirement: Support glob-based discovery with include/exclude
When no explicit `files` are provided, the core MUST support discovering test files using `include` glob patterns and filtering them using `exclude` glob patterns.

The resulting file list MUST be deterministically ordered.

#### Scenario: include/exclude glob produces a stable ordered list
- **GIVEN** `run(options)` is called with `include={"spec/**/*.test.lua"}` and `exclude={"spec/fixtures/**"}`
- **WHEN** file discovery runs
- **THEN** the core MUST return a deterministically ordered list of matching files

### Requirement: Ensure cleanup and global restoration on failure
If execution fails unexpectedly, the core MUST still perform cleanup (logger/renderer/worker teardown) and MUST restore any temporarily overridden globals (for example `print`).

#### Scenario: Global print is restored after an unhandled error
- **GIVEN** the core temporarily overrides global `print` during execution
- **AND** an unhandled error occurs during worker execution
- **WHEN** the run finalizes
- **THEN** global `print` MUST be restored to its original value

