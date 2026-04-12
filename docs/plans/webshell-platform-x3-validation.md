# WebShell Platform X3 Validation

## Goal
Validate the macOS-first operator path across the current product system:

- publish an auth-capable rule bundle from the `WebShellAdmin-macOS` repo surface
- persist the published release through the Vapor control plane
- register a macOS client device and sync the active bundle
- drive the dynamic-auth happy path through the macOS client
- verify authenticated resolve, download, file landing, and file open

## Local Setup Used
- Date: `2026-04-11`
- Control plane base URL: `http://127.0.0.1:8089`
- Auth fixture base URL: `http://127.0.0.1:18081`
- Database: local Postgres with role `yorl` and database `webshell_control_plane`
- APNs mode: disabled for this slice; the goal is admin publish plus macOS foreground convergence, not push transport
- Runner script: `./WebShell-SPM/scripts/webshell-platform-x3-operator-slice.sh`
- Run directory: `/tmp/webshell-x3-operator-20260411-075958`

## Product Fixes Required During X3
- Added `WebShellAdminSmoke` as a maintained smoke executable in `WebShellAdmin-macOS` so the admin repo can publish a controlled rule bundle through the same `AdminControlPlaneHTTPService` path used by the app layer.
- Made `AdminControlPlaneHTTPService` public-configurable so validation and future operator tooling can target a local control plane without relying only on process-global defaults.
- Added the missing `.skipped` render state to the admin device refresh status model and UI pills, matching control-plane push outcomes.
- Added `operator-auth-download-open` to `WebShellClientSmoke` so the macOS client environment can register, sync, authenticate, download, and open in one reproducible slice.
- Made `ControlPlaneSettings` public where needed for the smoke driver to point the client environment at the local control plane.

Relevant source:
- [Package.swift](/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellAdmin-macOS/Packages/WebShellAdminKit/Package.swift)
- [WebShellAdminSmoke main.swift](/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellAdmin-macOS/Packages/WebShellAdminKit/Sources/WebShellAdminSmoke/main.swift)
- [ClientsAndServices.swift](/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellAdmin-macOS/Packages/WebShellAdminKit/Sources/WebShellAdminKit/ClientsAndServices.swift)
- [Models.swift](/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellAdmin-macOS/Packages/WebShellAdminKit/Sources/WebShellAdminKit/Models.swift)
- [Views.swift](/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellAdmin-macOS/Packages/WebShellAdminKit/Sources/WebShellAdminKit/Views.swift)
- [WebShellClientSmoke main.swift](/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellClient-Apple/Packages/WebShellClientKit/Sources/WebShellClientSmoke/main.swift)
- [Models.swift](/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellClient-Apple/Packages/WebShellClientKit/Sources/WebShellClientKit/Models.swift)
- [webshell-platform-x3-operator-slice.sh](/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShell-SPM/scripts/webshell-platform-x3-operator-slice.sh)

## Operator Slice

### Observed Result
```text
X3_OPERATOR_SLICE_OK target_group=x3-operator-1775865598 bundle_version=x3.operator.1775865598
X3_ADMIN_RELEASE ADMIN_PUBLISHED_BUNDLE_VERSION x3.operator.1775865598; ADMIN_PUBLISHED_RELEASE_STATUS published; ADMIN_PUBLISHED_TARGET_GROUP x3-operator-1775865598;
X3_MACOS_CLIENT MACOS_CLIENT_REGISTERED device_id=37883E51-7479-4651-95BD-720749C75497 platform=macOS; MACOS_CLIENT_SYNCED bundle_version=x3.operator.1775865598; MACOS_CLIENT_HEARTBEAT bundle_version=x3.operator.1775865598; MACOS_AUTH_CHALLENGE provider=local-jkpan-vip fields=username,password,captcha; MACOS_AUTH_DOWNLOAD_OPEN_OK local_path=/var/folders/xy/xmf987_s3vdctfww3hxfgnp40000gn/T/WebShellClientOperator-FB1938FB-D2C9-4AE5-B794-1E0225F4D6F4/Downloads/vip.txt; MACOS_AUTH_DOWNLOAD_OPEN_OK filename=vip.txt;
X3_DEVICE {"platform": "macOS", "currentBundleVersion": "x3.operator.1775865598", "appVersion": "x3-operator", "displayName": "york的Mac mini", "targetGroup": "x3-operator-1775865598", "lastHeartbeatAt": "2026-04-11T00:00:46Z", "lastRefreshStatus": "idle", "lastRefreshMessage": "Registered", "id": "37883E51-7479-4651-95BD-720749C75497"}
X3_RUN_DIR /tmp/webshell-x3-operator-20260411-075958
```

### What This Proved
- `WebShellAdmin-macOS` can publish a controlled auth-capable release to the control plane through the admin service layer.
- The control plane persisted the release as the active bundle and served that exact version to the client.
- The macOS client registered as a managed device and sent a heartbeat with the synced bundle version.
- The client surfaced the rule-driven dynamic auth challenge for `local-jkpan-vip` with `username`, `password`, and `captcha` fields.
- Auth material submission unblocked resolve retry.
- The authenticated request downloaded `vip.txt` to disk.
- The macOS file-open path completed through the client environment after the file landed.

## Acceptance Readout
- `publish from admin`: passed through the `WebShellAdmin-macOS` smoke executable using `AdminControlPlaneHTTPService`.
- `control plane records the release`: passed; the active bundle version served to the client matched `x3.operator.1775865598`.
- `macOS client converges to latest bundle`: passed through sync and heartbeat.
- `dynamic auth path completes`: passed through challenge, material save, retry resolve, and download.
- `file lands and opens`: passed; the client emitted a local `vip.txt` path and completed the file-open call.

## Current Limits
- This is a reproducible smoke-driven operator slice, not a point-and-click UI automation of the running `WebShellAdmin` app.
- APNs was intentionally disabled because X2 already proved the real APNs transport; X3 focused on the macOS primary product path.
- The auth provider remains a controlled local fixture, not a live third-party site.

## Verification Commands
```bash
cd /Users/yorl/Downloads/GitHub-Cool/WebShell && ./WebShell-SPM/scripts/webshell-platform-x3-operator-slice.sh
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellControlPlane && swift test
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellAdmin-macOS/Packages/WebShellAdminKit && swift test
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellAdmin-macOS && xcodebuild -project WebShellAdmin.xcodeproj -scheme WebShellAdmin -destination 'platform=macOS' build
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellClient-Apple/Packages/WebShellClientKit && swift test
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellClient-Apple && xcodebuild -project WebShellClientApple.xcodeproj -scheme WebShellClientMac -destination 'platform=macOS' build
```

## Next Step
Move from validation to hardening:

1. promote the X2/X3 shell runners into documented maintained tooling
2. decide whether the admin publish path needs a UI automation harness or if service-layer smoke coverage is sufficient for the current checkpoint
3. tighten temporary transport allowances once the control-plane endpoint and certificate strategy are fixed
