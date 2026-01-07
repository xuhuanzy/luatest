## MODIFIED Requirements

### Requirement: Provide a minimal default terminal reporter
If no reporters are explicitly configured, the controller MUST provide a default terminal reporter.

At minimum, the default reporter MUST:
- Print a final summary containing `Test Files`, `Tests`, `Start at`, and `Duration`.
- When there are failed tasks or unhandled errors, print a dedicated error section (format and ordering MUST follow a Vitest-like structure; errors section MUST be printed before the final summary).
- Support disabling windowed summary rendering via configuration (`config.windowed=false`) and reporter options.
- Automatically disable windowed summary when output is non-TTY (to avoid ANSI control sequences in logs).

#### Scenario: Default reporter prints summary and errors at the end of the run
- **GIVEN** no custom reporters are configured
- **WHEN** the test run finishes
- **THEN** the default reporter MUST print a human-readable summary including file/test counts and duration
- **AND** **WHEN** there are unhandled errors or failed tests
- **THEN** the reporter MUST print a dedicated error section before the final summary

## ADDED Requirements

### Requirement: Support a windowed summary reporter in interactive terminals
When windowed summary is enabled, the controller MUST support a windowed summary reporter that renders a bottom-of-terminal window and forwards other logs above it.

The windowed summary MUST include:
- A list of currently queued/running test modules with their progress (at minimum: module name and `completed/total` or `[queued]`).
- The final four summary lines: `Test Files`, `Tests`, `Start at`, and `Duration` (in that order).

When color output is supported, the windowed summary MUST colorize module duration indicators using fixed tiers:
- `>= 5000ms`: red
- `>= 1000ms`: yellow
- otherwise: default/dim

The windowed summary MUST be disabled when output is non-TTY.

#### Scenario: Windowed summary shows running modules and bottom summary
- **GIVEN** windowed summary is enabled
- **WHEN** at least one test module is queued/collected and tests are executed
- **THEN** the window content MUST include per-module progress lines
- **AND** MUST include the four bottom summary lines in order

#### Scenario: Windowed summary is disabled on non-TTY output
- **GIVEN** windowed summary is enabled
- **AND** the output is non-TTY (for example, redirected to a file)
- **WHEN** the test run starts
- **THEN** the controller MUST disable windowed summary rendering

#### Scenario: Windowed summary colorizes module durations
- **GIVEN** windowed summary is enabled in a TTY and color output is supported
- **WHEN** a module progress line renders a duration of `6000ms`
- **THEN** the duration indicator MUST be colored red
- **AND** **WHEN** a module progress line renders a duration of `1500ms`
- **THEN** the duration indicator MUST be colored yellow

### Requirement: Default reporter forwards module/test lifecycle events to summary
When the default reporter uses a summary reporter, it MUST forward module/test/hook lifecycle callbacks so the summary can update progress deterministically.

#### Scenario: Summary counters update via forwarded events
- **GIVEN** the default reporter is active and windowed summary is enabled
- **WHEN** the controller dispatches module and test lifecycle callbacks
- **THEN** the summary output MUST reflect updated module/test progress
