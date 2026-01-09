## ADDED Requirements

### Requirement: Provide a global bootstrap state for CLI and singleton runner
The core MUST provide a minimal global bootstrap state that can be read by `singletonRunner` and set by a future CLI entrypoint.

This state MUST at minimum represent:
- whether the process is running under a CLI-controlled mode
- whether a test run has already been started in the current process

#### Scenario: singletonRunner is a no-op under CLI mode
- **GIVEN** the global bootstrap state indicates CLI mode is enabled
- **WHEN** `singletonRunner` is invoked inside a test file
- **THEN** it MUST NOT start a new test run
- **AND** it MUST be silent (no error and no warning)

#### Scenario: singletonRunner runs only once per process
- **GIVEN** CLI mode is disabled
- **WHEN** `singletonRunner` is invoked multiple times in the same process
- **THEN** it MUST start at most one test run
