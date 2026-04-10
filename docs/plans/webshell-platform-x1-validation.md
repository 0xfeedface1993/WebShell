# WebShell Platform X1 Validation

## Goal
Validate the first real vertical slice across the current product system:

- publish a rule bundle through the control plane
- register a client device and sync the active bundle
- send a heartbeat with the active bundle version
- exercise manual push bookkeeping
- confirm the Apple client surfaces a rule-driven auth challenge

## Local Setup Used
- Date: `2026-04-10`
- Control plane base URL: `http://127.0.0.1:8088`
- Database: local Postgres with role `yorl` and database `webshell_control_plane`
- APNs mode: disabled locally, so push attempts without a device token are expected to end in `skipped`

Commands used to prepare the backend:

```bash
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellControlPlane
DATABASE_USERNAME=yorl DATABASE_PASSWORD='' DATABASE_NAME=webshell_control_plane PORT=8088 swift run WebShellControlPlane migrate -y
DATABASE_USERNAME=yorl DATABASE_PASSWORD='' DATABASE_NAME=webshell_control_plane PORT=8088 swift run WebShellControlPlane serve --hostname 127.0.0.1 --port 8088
```

## Product Fixes Required During X1
- The first live publish attempt failed with `413 Payload Too Large`.
- The control plane routes for `POST /rule-bundles/publish` and `POST /auth-schemas/preview` were updated to use explicit body collection with `2mb` limits.
- After that route fix, live publish worked with the real bundle payload size.

Relevant source:
- [ControlPlaneController.swift](/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellControlPlane/Sources/WebShellControlPlane/Controllers/ControlPlaneController.swift)

## Slice Runner
A temporary smoke executable was used to drive the live slice against the running control plane while reusing the real client-side services:

- publish a unique copy of `RuleBundleFixtures.defaultBundle`
- register a device through `ControlPlaneDeviceService`
- sync via `RuleEngineService`
- send heartbeat via `ControlPlaneDeviceService`
- trigger manual push for the registered device
- resolve an auth-protected `jkpan-vip` URL and capture the auth challenge

## Observed Result

```text
X1 release version: 2026.04.10.catalog.x1.1775835746
X1 device registered: A698A115-2066-4BC2-9ED9-893A3B8583B7 [macOS-X1]
X1 rule sync active version: 2026.04.10.catalog.x1.1775835746
X1 heartbeat version: 2026.04.10.catalog.x1.1775835746
X1 push summary: requested=1 attempted=0 success=0 failed=0 skipped=1
X1 device refresh status: skipped message=Device has no APNs token.
X1 auth outcome: auth required surfaced: Missing username for jkpan-vip/default
X1 auth challenge provider: jkpan-vip
X1 auth challenge fields: username,password,captcha
```

## Acceptance Readout
- `publish bundle from admin/control plane`: passed at the API and persistence layer through live publish.
- `client converges to latest bundle`: passed through live sync and heartbeat using the published bundle version.
- `manual push bookkeeping`: passed; the push route recorded a device-scoped push event and updated device refresh state.
- `auth-required flow is rule-driven`: passed; the client surfaced a real auth challenge for `jkpan-vip` with the expected dynamic fields.

## Current Limits
- APNs delivery was not fully exercised because the local device registration used no push token and `APNS_ENABLED` stayed disabled.
- The first slice stops at `auth required surfaced`; it does not yet prove `auth completed -> authenticated download delivered -> file opened`.
- The smoke executable used for the live run is temporary and not yet committed as a durable repository utility.

## UI Acceptance Against PRD And Figma
### WebShellClient-Apple
- Implemented a macOS-first graphite shell with fixed left navigation, top command strip, queue pane, inspector pane, and amber auth recovery card.
- Implemented an iOS-compatible shell using the same palette and state language, but with a reduced tabbed layout.
- The implemented screens cover the PRD states for URL entry, queue/status, files, accounts, settings, auth required, and auth expired.

Relevant source:
- [Views.swift](/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellClient-Apple/Packages/WebShellClientKit/Sources/WebShellClientKit/Views.swift)

### WebShellAdmin-macOS
- Implemented a matching graphite admin shell with fixed navigation and dedicated rules, releases, devices, diagnostics, and auth preview surfaces.
- The rules editor and diagnostics layout now reflect the Figma hierarchy more closely, including strong card separation and operator-focused density.

Relevant source:
- [Views.swift](/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellAdmin-macOS/Packages/WebShellAdminKit/Sources/WebShellAdminKit/Views.swift)

### Verification Commands
```bash
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellClient-Apple/Packages/WebShellClientKit && swift test
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellClient-Apple && xcodebuild -project WebShellClientApple.xcodeproj -scheme WebShellClientMac -destination 'platform=macOS' build
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellAdmin-macOS/Packages/WebShellAdminKit && swift test
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellAdmin-macOS && xcodebuild -project WebShellAdmin.xcodeproj -scheme WebShellAdmin -destination 'platform=macOS' build
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellControlPlane && swift test
```

## Next Step
Move from the current X1 checkpoint to a second slice that proves:

1. a real APNs-backed refresh reaches the target device
2. auth material can be submitted successfully for a controlled provider
3. the authenticated resolve path ends in a delivered local file
