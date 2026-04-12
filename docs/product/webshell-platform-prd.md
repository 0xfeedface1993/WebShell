# WebShell Platform PRD

## Document Status
- State: Active
- Last updated: 2026-04-10
- Product scope owner: WebShell platform
- This document is the product source of truth for the cross-repo platform split and v1 feature boundary.

## Summary
WebShell is a rule-driven download platform whose core value is that supported site behavior can evolve through server-shipped rule bundles instead of requiring a client app release for normal site changes. The product family is split into four repos with clear ownership:

- `WebShell-SPM`: shared rule engine, bundle model, resolver runtime, auth session runtime
- `WebShellClient-Apple`: macOS-first download client with iOS compatibility
- `WebShellAdmin-macOS`: native macOS admin console for rule and device operations
- `WebShellControlPlane`: Vapor control plane for bundle publishing, device management, and push orchestration

The v1 product goal is to make macOS the stable primary experience for rule-based foreground downloading, while iOS remains a compatible client with a reduced stability target and no background download support yet.

## Problem Statement
Traditional download tools usually depend on frequent client updates whenever a supported site changes DOM structure, auth flow, token shape, or final asset resolution behavior. This causes slow recovery, fragmented compatibility, and higher operational cost. The product target is to shift normal site adaptation into a versioned server-managed rule system so the client stays stable while supported sites change.

## Product Goals
- Let supported site behavior evolve without frequent app updates.
- Make macOS the primary daily-use client for task creation, task monitoring, and local file management.
- Keep rule logic centralized and versioned so all product surfaces consume the same bundle contract.
- Give operations staff a controlled way to validate, publish, roll back, and manually push rule bundles.
- Track devices, bundle versions, and refresh status so configuration delivery is observable and recoverable.

## Non-Goals For v1
- No iOS background download support.
- No App Store compliance work as part of the first delivery.
- No end-user cloud account system or cross-device library sync.
- No BT, magnet, HLS, m3u8, or streaming playback workflows.
- No visual low-code rule editor.
- No server-side storage of end-user site credentials.

## User Roles
- End user: enters a page URL, starts downloads, stops downloads, opens files, checks progress, size, speed, and file info.
- Operator: validates rules, publishes bundles, rolls back releases, manually pushes bundles, and watches device refresh health.
- Maintainer: evolves the rule engine, capability surface, auth workflow model, and downloader runtime.

## Product Pillars
- Dynamic compatibility: supported site changes should usually be handled by bundle updates.
- Operational control: releases must be reviewable, publishable, rollback-safe, and targetable to device groups.
- Stable client behavior: downloader UX and local file handling should remain predictable even when rule bundles change.
- Explicit boundaries: rules define site behavior, clients execute it, admin tools operate it, and the control plane distributes it.

## Repo Topology
| Repo | Responsibility | Notes |
| --- | --- | --- |
| `WebShell-SPM` | Shared rule model, sync, compile, resolve, auth session reuse, capabilities | Only source of truth for `RuleBundle`, `ProviderRule`, `WorkflowDefinition`, and `AuthPolicy` |
| `WebShellClient-Apple` | macOS-first download client with iOS compatibility | Built with XcodeGen + SwiftUI + TCA |
| `WebShellAdmin-macOS` | Native admin console for rule and device operations | Built with XcodeGen + SwiftUI + TCA |
| `WebShellControlPlane` | API and persistence layer for bundles, devices, release actions, and push orchestration | Built with Vapor + Fluent + Postgres |

## Shared Product Contract
The following contract is owned by `WebShell-SPM` and must not be redefined in downstream repos:

- `RuleBundle`
- `ProviderRule`
- `WorkflowDefinition`
- `AuthPolicy`
- capability registration and validation rules
- provider-family auth session reuse rules

This contract is consumed by the Apple client, the admin console, and the control plane. Any product that needs rule awareness must depend on the shared package contract rather than maintaining a parallel schema.

## WebShellClient-Apple PRD

### Positioning
`WebShellClient-Apple` is the primary end-user app. macOS is the main target because it is the more stable and realistic foreground download environment. iOS is compatibility coverage, not the first-priority operating environment.

### Supported Platforms
- macOS 14+
- iOS 17+

### Core User Flows
1. User enters a supported page URL.
2. Client identifies the provider through the active rule bundle.
3. If auth is required, the client renders a dynamic auth flow from the bundle-defined schema.
4. The client resolves the page into one or more downloader-ready requests.
5. Tasks enter a managed queue and start according to host concurrency limits.
6. Downloaded files become visible in the local file library and can be opened from the app.

### v1 Functional Requirements
- macOS UI is the primary product experience.
- iOS shares reducer and business logic, but not the same top-level layout.
- URL entry, rule sync, resolve, queue, download, open file, and file metadata views are in scope.
- Per-site foreground concurrency defaults to `3`.
- Duplicate downloads must be prevented by:
  - normalized source URL
  - resolved final request URL when available
  - already indexed local file identity
- File info must expose at least:
  - source URL
  - resolved URL
  - file name
  - file size
  - local path
  - creation timestamp
- iOS does not support background downloads in v1.

### Client Architecture Constraints
- SwiftUI + TCA only.
- TCA uses official upstream `ComposableArchitecture`.
- Shared services are injected through `DependencyValues`.
- Navigation, sheets, alerts, and long-lived tasks are reducer-owned.
- Shared async state defaults to `actor`.
- Long-lived effects must be cancellable and carry explicit cancellation IDs.

### First-Phase Feature Areas
- `InputURLFeature`
- `RuleSyncFeature`
- `TasksFeature`
- `FilesFeature`
- `AccountsFeature`
- `SettingsFeature`

## WebShellAdmin-macOS PRD

### Positioning
`WebShellAdmin-macOS` is an internal operational console for managing rules, releases, devices, and release health. It is not an end-user product and does not need iOS compatibility.

### v1 Functional Requirements
- Edit rule JSON or DSL as text.
- Validate bundle structure before publish.
- Preview auth-related material derived from the bundle.
- Publish a versioned bundle with a release note.
- Roll back a published bundle.
- Manually push a bundle to selected devices or device groups.
- View registered devices, active versions, last heartbeat, and last refresh result.
- Aggregate diagnostics around failed refreshes and release actions.

### First-Phase Feature Areas
- `RulesFeature`
- `ReleasesFeature`
- `DevicesFeature`
- `DiagnosticsFeature`
- `AuthSchemaPreviewFeature`

## WebShellControlPlane PRD

### Positioning
`WebShellControlPlane` is the private operations backend. It stores bundle versions, device state, push actions, and release history. It is not a public SaaS and does not need multi-tenant design in v1.

### v1 API Surface
- `POST /devices/register`
- `POST /devices/heartbeat`
- `GET /devices`
- `GET /devices/{id}`
- `GET /rule-bundles/active`
- `POST /rule-bundles/publish`
- `POST /rule-bundles/{version}/push`
- `POST /rule-bundles/{version}/rollback`
- `POST /auth-schemas/preview`

### Distribution Model
- Real-time distribution uses `APNs` silent push plus client pull.
- Push conveys that a new version is available; it does not ship the full bundle payload.
- Clients must also poll on launch and foreground entry so distribution still converges if silent push is delayed or dropped.

### Persistence Requirements
- Production database: Postgres
- Rule bundles and auth schema payloads are versioned records
- Devices are first-class managed entities with:
  - platform
  - app version
  - target group
  - current bundle version
  - push token
  - heartbeat timestamp
  - last refresh result
- Release actions must be auditable

## Auth Boundary
Auth behavior is dynamic and rule-driven, but `WebShell` should not become a credential hosting platform.

### Auth Ownership
- `WebShell-SPM`: auth workflow execution model and session reuse semantics
- `WebShellControlPlane`: auth schema publication and bundle association
- `WebShellClient-Apple`: form rendering, auth action execution, and local secure credential storage

### Auth Rules
- End-user credentials stay on device only.
- Provider-family session reuse is keyed by provider family plus account identity.
- Auth workflow changes can ship in bundle updates.
- A rule bundle may require auth, but the admin console does not own user credential management.

## Data And State

### Client Local State
- active bundle snapshot
- download task queue
- local file index
- provider session state
- credential references and secure material

### Server State
- versioned bundle records
- publish notes
- rollback history
- device inventory
- push events
- refresh outcomes

## UX Constraints
- macOS uses a denser, primary workflow for task and file management.
- iOS keeps the same capability boundary but accepts reduced stability and a simpler shell.
- User-visible failure reasons must be explicit, not generic. At minimum:
  - unsupported site
  - stale or invalid rule
  - auth required
  - auth expired
  - network failure
  - duplicate task
  - file already downloaded

## Implementation Status Snapshot
As of `2026-04-10`, the first delivery scaffold is already in place:

- `WebShellClient-Apple`: created and wired with XcodeGen, TCA reducers, shared package dependencies, queueing, duplicate checks, and tests
- `WebShellAdmin-macOS`: created and wired with XcodeGen, TCA reducers, rule validation, release actions, diagnostics aggregation, and tests
- `WebShellControlPlane`: created with Vapor routes, models, migrations, bundle validation, push action handling, and route tests

This PRD remains the product boundary reference even as implementation details continue evolving.

## Acceptance Criteria For v1
- A supported site can recover from normal site-flow changes through a bundle publish instead of a client app release.
- The macOS client can ingest a URL, resolve it, queue it, download it, and open the resulting file.
- Per-site concurrency is enforced at `3` by default.
- Duplicate downloads are rejected before redundant work starts.
- The admin console can validate, publish, roll back, and manually push bundles.
- The control plane records device state, release history, and refresh outcomes.
- Auth-driven flows can be described by the bundle model without introducing server-side credential storage.

## Risks And Open Questions
- Distribution and policy risk remains high if the product is intended for general App Store distribution.
- Silent push is not guaranteed to be immediate, so pull-based convergence remains mandatory.
- Auth workflows will vary substantially by provider family and will need product review as real sites are added.
- Future background download support on iOS should be planned as a separate product increment instead of expanding v1 scope.

## Relationship To Engineering Plans
- Product scope and boundary: `docs/product/webshell-platform-prd.md`
- Admin Rules management PRD: `docs/product/webshell-admin-rules-management-prd.md`
- Platform execution roadmap: `docs/plans/webshell-platform-roadmap.md`
- Platform execution queue: `docs/plans/webshell-platform-task-queue.md`
- Shared engine implementation plan: `docs/plans/remote-rule-engine-plan.md`
- Shared engine execution queue: `docs/plans/remote-rule-engine-queue.md`
- Shared engine validation status: `docs/plans/remote-rule-engine-validation.md`
