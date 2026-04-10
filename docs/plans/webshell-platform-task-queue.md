# WebShell Platform Task Queue

## Source Of Truth
- Product boundary: `docs/product/webshell-platform-prd.md`
- Sequence and phases: `docs/plans/webshell-platform-roadmap.md`
- Shared engine specifics: `docs/plans/remote-rule-engine-plan.md`

## Status Legend
- `Todo`
- `In Progress`
- `Blocked`
- `Done`

## Current Focus
- preserve X2 validation evidence and keep the real-device runner stable
- move the next checkpoint back to the macOS-first product path instead of the iOS compatibility slice
- reduce temporary transport allowances once the control-plane delivery path is finalized

## Queue
| ID | Title | Status | Owner | Depends On | Repo / Surface | Acceptance Summary |
| --- | --- | --- | --- | --- | --- | --- |
| P0 | Write platform PRD | Done | Codex | - | `WebShell-SPM/docs/product` | PRD exists and defines repo boundaries, v1 scope, and acceptance |
| P1 | Write roadmap and task queue docs | Done | Codex | P0 | `WebShell-SPM/docs/plans` | roadmap and queue exist and are linked from the PRD context |
| C0 | Scaffold `WebShellClient-Apple` | Done | Codex | P0 | `WebShellClient-Apple` | XcodeGen, TCA, tests, and macOS build pass |
| A0 | Scaffold `WebShellAdmin-macOS` | Done | Codex | P0 | `WebShellAdmin-macOS` | XcodeGen, TCA, tests, and macOS build pass |
| B0 | Scaffold `WebShellControlPlane` | Done | Codex | P0 | `WebShellControlPlane` | Vapor routes, migrations, and route tests pass |
| D1 | Design Apple client information architecture and state inventory | Done | Euler | P1 | Figma | navigation, key screens, and state inventory are defined |
| D2 | Design Apple client core screens and interactions | Done | Euler | D1 | Figma | URL entry, auth prompt, task list, file detail, settings states are designed |
| D3 | Design admin console screens and operator flows | Done | Euler | D1 | Figma | rules, releases, devices, diagnostics, auth preview states are designed |
| D4 | Package design deliverables and implementation notes | Done | Euler | D2, D3 | Figma + docs | handoff includes screen links, state notes, and interaction rules |
| B1 | Replace placeholder push dispatcher with real APNs delivery path | Done | Lagrange | B0, P1 | `WebShellControlPlane` | APNs client, payload format, environment config, and tests exist |
| B2 | Complete Postgres-first persistence details | Done | Lagrange | B0, P1 | `WebShellControlPlane` | production schema and models reflect bundle, device, and push-event needs |
| B3 | Record delivery outcomes and failure detail for push attempts | Done | Lagrange | B1, B2 | `WebShellControlPlane` | push history records success/failure and target coverage |
| B4 | Add backend docs and validation for env setup | Done | Lagrange | B1, B2, B3 | `WebShellControlPlane` | README or env docs explain Postgres and APNs requirements |
| F1 | Map shared auth definitions into client-side dynamic form state | Done | Pasteur | C0, P1 | `WebShellClient-Apple`, `WebShell-SPM` read-only | dynamic field model derives from rule bundle auth definitions |
| F2 | Build TCA auth prompt flow and secure submission path | Done | Pasteur | F1 | `WebShellClient-Apple` | auth form UI, reducer flow, and credential submission path exist |
| F3 | Retry resolve after auth success and surface auth-specific errors | Done | Pasteur | F2 | `WebShellClient-Apple` | auth-required resolve path can recover after successful form completion |
| F4 | Add tests for auth-required flows | Done | Pasteur | F2, F3 | `WebShellClient-Apple` | reducer/integration coverage exists for auth prompt and retry |
| X1 | Validate first end-to-end slice | Done | Codex | D4, B4, F4 | all repos | one documented vertical slice can be demonstrated end-to-end |
| X2 | Validate real APNs refresh and authenticated file-delivery slice | Done | Codex | X1 | all repos | physical-device push refresh and auth-to-file-open path are documented end-to-end |

## Active Batch Notes

### Batch D: Figma UI And Interaction Design
- Scope:
  - `WebShellClient-Apple` macOS-first shell
  - `WebShellClient-Apple` iOS compatibility shell
  - `WebShellAdmin-macOS`
- Required states:
  - empty
  - loading
  - success
  - auth required
  - auth expired
  - publish success
  - publish failure
  - device refresh failure
- Handoff requirement:
  - include screen or frame links
  - include component/state notes usable by implementation
- Result:
  - Figma file: `https://www.figma.com/design/iONAby0elf2Qz8CU8CEVoj`
  - status: completed

### Batch B: Control Plane Completion
- Scope:
  - APNs dispatch pipeline
  - Postgres persistence refinements
  - push result recording
  - route and env documentation
- Write boundary:
  - `/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellControlPlane`
- Must preserve:
  - current route surface
  - current tests unless replacing with stronger coverage
- Result:
  - `swift test` passed with `8` route tests
  - APNs client and push attempt persistence added
  - device registration is now idempotent under launch/token-link concurrency

### Batch F: Dynamic Auth Integration
- Scope:
  - dynamic auth form state
  - TCA auth UX
  - resolve retry after auth
  - secure local storage usage
- Write boundary:
  - `/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellClient-Apple`
- Read-only references:
  - `/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShell-SPM`
- Result:
  - `swift test` passed with `12` package tests
  - auth-required and auth-expired flows now have dedicated client UX paths
  - auth slice now proves `auth success -> resolve retry -> download -> file open`

## Immediate Next Actions
1. Add a macOS-first X3 slice that publishes from `WebShellAdmin-macOS` and validates the primary product path instead of the iOS compatibility path.
2. Promote the real APNs runner and auth fixture utilities from temporary validation helpers into maintained tooling with explicit env setup docs.
3. Replace the current broad iOS ATS allowance with a tighter transport policy once the control plane endpoint strategy is stable.

## Evidence Expectations
- Design work: Figma links plus concise interaction notes
- Backend work: passing `swift test` and changed file list
- Client work: passing package tests and changed file list
- Integration checkpoint: updated queue status plus a short verification summary

## Latest Evidence
- Figma design handoff: `https://www.figma.com/design/iONAby0elf2Qz8CU8CEVoj`
- Client verification: `cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellClient-Apple/Packages/WebShellClientKit && swift test`
- Backend verification: `cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellControlPlane && swift test`
- Client macOS build: `cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellClient-Apple && xcodebuild -project WebShellClientApple.xcodeproj -scheme WebShellClientMac -destination 'platform=macOS' build`
- Admin verification: `cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellAdmin-macOS/Packages/WebShellAdminKit && swift test`
- Admin macOS build: `cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellAdmin-macOS && xcodebuild -project WebShellAdmin.xcodeproj -scheme WebShellAdmin -destination 'platform=macOS' build`
- X1 validation notes: `docs/plans/webshell-platform-x1-validation.md`
- X2 validation notes: `docs/plans/webshell-platform-x2-validation.md`
- Real APNs slice: `cd /Users/yorl/Downloads/GitHub-Cool/WebShell && ./WebShell-SPM/scripts/webshell-platform-real-apns-slice.sh`
- Auth download/open slice: `cd /Users/yorl/Downloads/GitHub-Cool/WebShell && ./WebShell-SPM/scripts/webshell-platform-auth-download-slice.sh`
