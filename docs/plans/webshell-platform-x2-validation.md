# WebShell Platform X2 Validation

## Goal
Validate the second real vertical slice across the current product system:

- deliver a real silent push through APNs to a physical iOS device
- confirm the Apple client refreshes to the newly published bundle after the push
- prove the authenticated happy path ends in a delivered local file
- prove the delivered file can be opened by the client flow

## Local Setup Used
- Date: `2026-04-11`
- Physical device: `xts-ipad` `iPad8,5` (`00008027-000939693422002E`)
- Control plane internal base URL: `http://[::1]:8088`
- Control plane device-facing base URL: `http://[fd67:80ab:3f63::2]:8088`
- Device tunnel peer used by the runner: device `fd67:80ab:3f63::1` -> host `fd67:80ab:3f63::2`
- Database: local Postgres with role `yorl` and database `webshell_control_plane`
- APNs mode: enabled with sandbox topic `com.groovy.CloudDownloader`
- APNs credentials used by the runner:
  - key id `VFWK7HX6G5`
  - team id `N39GRU244C`
- Runner scripts:
  - `./WebShell-SPM/scripts/webshell-platform-real-apns-slice.sh`
  - `./WebShell-SPM/scripts/webshell-platform-auth-download-slice.sh`

## Product Fixes Required During X2
- `WebShellClient-Apple` iOS target was moved to an explicit Info.plist so the built app actually carries:
  - `CFBundleIdentifier`
  - `UIBackgroundModes = remote-notification`
  - `NSAppTransportSecurity` allowances required by the current internal HTTP control-plane transport
- The real APNs runner was updated to:
  - prefer the wired CoreDevice tunnel IPv6 instead of blindly using `en0`
  - separate device-facing control-plane URL from the runner's internal health-check URL
  - emit connection metadata into `connection.txt`
  - complete cleanly after summarizing the target device
- `POST /devices/register` in the control plane was hardened into an idempotent registration path so concurrent launch registration and APNs token linking no longer fail on duplicate primary keys.

Relevant source:
- [WebShellClientiOS-Info.plist](/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellClient-Apple/App/iOS/WebShellClientiOS-Info.plist)
- [project.yml](/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellClient-Apple/project.yml)
- [webshell-platform-real-apns-slice.sh](/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShell-SPM/scripts/webshell-platform-real-apns-slice.sh)
- [ControlPlaneController.swift](/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellControlPlane/Sources/WebShellControlPlane/Controllers/ControlPlaneController.swift)

## Real APNs Slice

### Observed Result
```text
REAL_APNS_SLICE_OK target_group=apns-slice-1775840331 bundle_version=apns.slice.1775840350
REAL_APNS_SLICE_DEVICE {"lastRefreshMessage":"Bundle apns.slice.1775840350 delivered via APNs.","appVersion":"apns-slice","currentBundleVersion":"apns.slice.1775840350","id":"18ABE078-D57E-4455-A1C0-26BC700F1BAC","displayName":"iOS Client","platform":"iOS","targetGroup":"apns-slice-1775840331","lastHeartbeatAt":"2026-04-10T16:59:12Z","lastRefreshStatus":"success"}
REAL_APNS_SLICE_RUN_DIR /tmp/webshell-real-apns-20260411-005851
```

### Device Markers Observed
```text
WEBSHELL_SLICE APNS_TOKEN_UPDATED token_preview=207e8aedebd8
WEBSHELL_SLICE DEVICE_REGISTERED device_id=18ABE078-D57E-4455-A1C0-26BC700F1BAC platform=iOS
WEBSHELL_SLICE APNS_TOKEN_LINKED device_id=18ABE078-D57E-4455-A1C0-26BC700F1BAC token_preview=207e8aedebd8
WEBSHELL_SLICE APNS_REFRESH_RECEIVED bundle=apns.slice.1775840350 event=rule_bundle_refresh
WEBSHELL_SLICE APNS_REFRESH_SYNCED bundle=apns.slice.1775840350
WEBSHELL_SLICE APNS_HEARTBEAT_SENT bundle=apns.slice.1775840350 device_id=18ABE078-D57E-4455-A1C0-26BC700F1BAC
```

### Control Plane Outcome
- Published bundle version: `apns.slice.1775840350`
- Push summary: requested `1`, attempted `1`, success `1`, failed `0`, skipped `0`
- Device record converged to:
  - `currentBundleVersion = apns.slice.1775840350`
  - `lastRefreshStatus = success`
  - `lastRefreshMessage = Bundle apns.slice.1775840350 delivered via APNs.`

## Auth Download And Open Slice

### Observed Result
```text
AUTH_DOWNLOAD_OPEN_OK bundle_version=auth.slice.1775840434
AUTH_DOWNLOAD_OPEN_OK local_path=/var/folders/xy/xmf987_s3vdctfww3hxfgnp40000gn/T/WebShellClientSmoke-3BCC6559-D7ED-4CFB-BA2E-3018EEC27040/Downloads/vip.txt
AUTH_DOWNLOAD_OPEN_OK filename=vip.txt
```

### What This Proved
- The rule bundle exposed an auth-required provider flow.
- Auth material was submitted and stored successfully.
- The client retried resolve after auth completion.
- The authenticated resolve path emitted a downloader-ready request.
- The file was written to disk as `vip.txt`.
- The file-open path completed successfully through the client environment.

## Acceptance Readout
- `real APNs-backed refresh reaches the target device`: passed on physical iPad hardware through APNs sandbox delivery.
- `client converges to the latest published bundle after silent push`: passed; the device heartbeat and control-plane device record both moved to `apns.slice.1775840350`.
- `auth material can be submitted successfully for a controlled provider`: passed through the controlled auth fixture path.
- `authenticated resolve ends in a delivered local file`: passed; the auth slice produced a real downloaded `vip.txt`.
- `file open path is exercised`: passed; the smoke slice completed through `open()` after the file landed on disk.

## Current Limits
- The APNs slice is still a shell runner, not a product-grade automated CI lane.
- The authenticated happy path currently uses a controlled local fixture server instead of a live external provider.
- X2 proves the transport and vertical behavior, but the publish step is still CLI-driven rather than exercised through the macOS admin UI.

## Verification Commands
```bash
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellControlPlane && swift test
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellClient-Apple/Packages/WebShellClientKit && swift test
cd /Users/yorl/Downloads/GitHub-Cool/WebShell && ./WebShell-SPM/scripts/webshell-platform-real-apns-slice.sh
cd /Users/yorl/Downloads/GitHub-Cool/WebShell && ./WebShell-SPM/scripts/webshell-platform-auth-download-slice.sh
```

## Next Step
Move beyond X2 by proving the same product intent through a macOS-first, operator-driven slice:

1. publish from the admin surface instead of only the smoke helper
2. drive the main happy path through the macOS client rather than only the iOS device slice
3. tighten the current broad ATS allowance once the control plane transport story is finalized
