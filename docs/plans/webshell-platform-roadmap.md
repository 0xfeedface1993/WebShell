# WebShell Platform Roadmap

## Current Must-Read
- Product source of truth: `docs/product/webshell-platform-prd.md`
- Platform roadmap: `docs/plans/webshell-platform-roadmap.md`
- Platform task queue: `docs/plans/webshell-platform-task-queue.md`
- Shared engine plan: `docs/plans/remote-rule-engine-plan.md`

## Read Order
1. `docs/product/webshell-platform-prd.md`
2. `docs/plans/webshell-platform-roadmap.md`
3. `docs/plans/webshell-platform-task-queue.md`
4. `docs/plans/remote-rule-engine-plan.md`

## Objective
Turn the WebShell rule engine into a usable multi-repo product system consisting of:

- a macOS-first Apple client with iOS compatibility
- a native macOS admin console
- a Vapor control plane
- a shared engine package that remains the only rule-contract owner

The roadmap focuses on the first stable product checkpoint, not the full long-term backlog.

## Status Summary
- Overall state: `In Progress`
- First stable checkpoint target: macOS foreground download + control plane publish/push + admin publish workflow + dynamic auth path
- Current focus: convert the completed X2 scripted validation into a macOS-first, operator-driven checkpoint
- Last updated: `2026-04-11`

## Scope Boundaries

### In Scope
- Multi-repo split already scaffolded and buildable
- TCA-based Apple apps
- Vapor control plane with Postgres production backing
- APNs silent-push distribution path
- Dynamic auth form rendering in the Apple client based on rule bundle definitions
- Figma UI and interaction design for the Apple client and admin console

### Out Of Scope For This Checkpoint
- iOS background downloads
- App Store compliance packaging
- user account cloud sync
- visual low-code rule editing
- server-side end-user credential storage

## Truth Sources
1. `docs/product/webshell-platform-prd.md` for product boundary
2. `docs/plans/webshell-platform-task-queue.md` for current execution order and status
3. repo source code in:
   - `/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellClient-Apple`
   - `/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellAdmin-macOS`
   - `/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellControlPlane`
   - `/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShell-SPM`

## Phase Roadmap

### Phase R0: Platform Foundation
- State: `Done`
- Purpose: establish the repo split and first runnable scaffold
- Deliverables:
  - `WebShellClient-Apple` created with XcodeGen + TCA + tests
  - `WebShellAdmin-macOS` created with XcodeGen + TCA + tests
  - `WebShellControlPlane` created with Vapor routes, models, migrations, and tests
  - cross-repo PRD written

### Phase R1: Product UX Definition
- State: `Done`
- Purpose: define the visual language, key flows, and interaction states before heavy UI polish
- Deliverables:
  - Figma file for `WebShellClient-Apple`
  - Figma file for `WebShellAdmin-macOS`
  - interaction flows for URL input, auth-required resolve, queued/running/completed tasks, release publish, manual push, diagnostics review
  - state coverage for empty/loading/error/success/auth-expired cases

### Phase R2: Control Plane Productionization
- State: `Done`
- Purpose: move the backend from scaffolded functionality to a production-oriented delivery path
- Deliverables:
  - real APNs silent-push dispatch path
  - Postgres-first persistence details completed
  - richer push event recording and failure tracking
  - environment configuration for credentials and routing
  - updated route and integration tests

### Phase R3: Dynamic Auth Product Flow
- State: `Done`
- Purpose: connect the Apple client to rule-driven auth definitions instead of treating auth as a placeholder
- Deliverables:
  - client-side mapping from rule bundle auth definitions to dynamic form state
  - TCA flow for auth prompting, submission, validation feedback, and retry resolve
  - secure local storage boundaries for auth material references
  - tests for auth-triggered resolution and auth-success retry

### Phase R4: Vertical Slice Stabilization
- State: `In Progress`
- Purpose: validate the first end-to-end operator and user journey
- Deliverables:
  - publish bundle from admin
  - control plane records publish and push
  - Apple client receives refresh signal and converges to latest bundle
  - auth-required site can be resolved after dynamic form completion
  - macOS client can queue, download, inspect, and open the file
- Current checkpoint note:
  - X1 is now complete and documented in `docs/plans/webshell-platform-x1-validation.md`.
  - X1 proved live publish, device registration, live sync, heartbeat, push bookkeeping, and rule-driven auth challenge surfacing.
  - X2 is now complete and documented in `docs/plans/webshell-platform-x2-validation.md`.
  - X2 proved real APNs-delivered refresh on a physical iOS device and a controlled authenticated happy path ending in a delivered, opened file.
  - Remaining R4 work is to prove the same behavior through the macOS-first operator path, including admin-driven publish and macOS client file delivery.

## Workstreams
| ID | Workstream | State | Depends On | Repos | Done When |
| --- | --- | --- | --- | --- | --- |
| W0 | Documentation and coordination | In Progress | - | `WebShell-SPM/docs` | PRD, roadmap, and queue stay current with execution |
| W1 | Figma UX and interaction design | Done | W0 | Figma workspace | Key product flows and states are designed and reviewable |
| W2 | Control plane productionization | Done | W0 | `WebShellControlPlane` | APNs and Postgres details are completed and tested |
| W3 | Apple dynamic auth integration | Done | W0, W2 partial | `WebShellClient-Apple`, `WebShell-SPM` | auth-required flows are driven by the rule model in the client |
| W4 | End-to-end checkpoint | Done | W1, W2, W3 | all repos | one real vertical slice is testable and documented |

## Suggested Execution Order
1. Lock the roadmap and queue so design and code tasks follow the same boundary.
2. Run Figma design work in parallel with backend completion because those write surfaces do not conflict.
3. Complete control plane APNs and Postgres details before finishing the client auth UX, because device push and auth schema delivery define some client state expectations.
4. Finish Apple dynamic auth flow once the backend shape and auth-preview expectations are stable enough.
5. Run end-to-end stabilization only after all three tracks converge.

## Exit Criteria For This Checkpoint
- The roadmap docs reflect actual current state.
- Figma delivers reviewable screen and interaction coverage for the first product flows.
- The control plane uses real APNs delivery plumbing and production-shaped Postgres persistence.
- The Apple client renders and handles dynamic auth flows from the shared rule model.
- The task queue contains only bounded remaining work, not vague epics.

## Handoff Notes
- Any new agent working on this effort must read the PRD, this roadmap, and the task queue before editing code or design assets.
- Update the task queue as soon as a batch starts or finishes.
- Do not create parallel planning docs unless the current set becomes insufficient.
