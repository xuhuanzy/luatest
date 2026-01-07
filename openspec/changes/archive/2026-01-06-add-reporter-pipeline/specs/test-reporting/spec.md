## ADDED Requirements

### Requirement: Persist runner task updates for reporting
The controller MUST persist `TaskResultPack` updates into `StateManager` so that reporters can query task `result` and `meta` by `taskId`.

#### Scenario: Reporter reads latest task result after onTaskUpdate
- **GIVEN** a test file has been collected and its tasks are registered in `StateManager.idMap`
- **WHEN** the controller receives `onTaskUpdate(update, events)` containing a `TaskResultPack` for a known `taskId`
- **THEN** `StateManager.idMap[taskId].result` MUST reflect the latest `result` from the pack
- **AND** `StateManager:getReportedEntityById(taskId)` MUST reflect the same underlying task state

### Requirement: Persist runner task events in order
The controller MUST persist `TaskEventPack` events in the order received, both as a run-scoped sequence and indexed by `taskId`.

#### Scenario: Reporter inspects event history deterministically
- **WHEN** the controller processes `onTaskUpdate(update, events)` with multiple `TaskEventPack` entries
- **THEN** the stored run-scoped event sequence MUST preserve the original `events` order
- **AND** the per-`taskId` event list MUST contain all events for that `taskId` in the same relative order

### Requirement: Dispatch reporting callbacks after state is updated
The controller MUST dispatch reporting callbacks to configured reporters (`onQueued`, `onCollected`, `onTaskUpdate`, and test run start/end) in a deterministic order. For `onTaskUpdate`, it MUST update `StateManager` before invoking reporter callbacks.

#### Scenario: Reporter observes consistent state during event callbacks
- **GIVEN** a reporter callback reads task state through `StateManager`
- **WHEN** the controller receives `onTaskUpdate(update, events)`
- **THEN** the controller MUST apply `update` to `StateManager` before invoking reporter callbacks for this batch

### Requirement: Provide a minimal default terminal reporter
If no reporters are explicitly configured, the controller MUST provide a default terminal reporter that outputs at least a final summary containing test files count, tests count, start time, and duration.

#### Scenario: Default reporter prints a summary at the end of the run
- **WHEN** the test run finishes
- **THEN** the default reporter MUST print a human-readable summary including file/test counts and duration

