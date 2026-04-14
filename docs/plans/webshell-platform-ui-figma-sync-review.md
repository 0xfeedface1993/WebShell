# WebShell UI Figma Sync Review

## Status
- Date: 2026-04-14
- State: Implemented
- Figma source: `https://www.figma.com/design/iONAby0elf2Qz8CU8CEVoj`
- MCP-readable node used for this pass: `00 Foundations` / `Foundations Board` (`4:16`)

## Scope
This pass compares the Figma foundations that are currently readable through MCP against the implemented SwiftUI shells:

- `WebShellClient-Apple/Packages/WebShellClientKit/Sources/WebShellClientKit/Views.swift`
- `WebShellAdmin-macOS/Packages/WebShellAdminKit/Sources/WebShellAdminKit/Views.swift`

The repo docs reference the Figma file as the completed design handoff, but do not include concrete screen or frame node links. Through MCP, the available source of truth for this review is therefore the foundations board: palette, typography intent, and primitive components.

## Figma To Implementation Findings
- Palette drift was corrected toward the foundations board:
  - app background: `#12171F`
  - card surface: `#1C2430`
  - component surface: `#262E3D`
  - accent aqua: `#2EC7B8`
  - warning amber: `#F2B247`
  - danger red: `#ED5952`
  - primary text: `#F2F7FC`
  - secondary text: `#C7D1E0`
  - border source: `rgba(84, 99, 122, 0.35)`
- Client primary buttons now match the primitive intent more closely: aqua fill, dark text, 14 pt semibold label, 44 pt height, and 14 pt corner radius.
- Client secondary/ghost buttons now use the component surface instead of a translucent lower-contrast card surface.
- Client URL input and task row radii now align to the primitive `Input/URL` and `Row/Task` 16 pt corner language.
- Client auth navigation and account surfaces no longer use the out-of-system purple accent; auth now maps to the amber warning language used by the Figma `AUTH REQUIRED` primitive.
- Admin buttons now carry design semantics:
  - primary: aqua fill with dark text
  - secondary: component surface with muted border
  - danger: red-brown fill with red border
  This prevents actions such as rollback and delete from appearing as normal primary actions.
- Admin palette and status pills were synced to the same graphite/aqua/amber/red foundations so Client and Admin read as one product family.

## Implementation To Figma Findings
- The implementation still uses SwiftUI system rounded and monospaced fonts. Figma specifies Geist and IBM Plex Mono. This remains an intentional native fallback unless the app bundles those fonts or Figma revises the handoff to use platform system fonts.
- The implementation has additional semantic colors such as `info` and `success` for file/detail/progress states. Figma foundations only expose app, panel, aqua, amber, and error. If those blue/green states remain product language, the Figma foundations should add them explicitly.
- The macOS global command strip should follow toolbar density rather than floating-action treatment. The revised design uses a single-line command bar with current view context, bundle and heartbeat metadata on the left, and the global link/sync/heartbeat commands on the right.
- Figma handoff should add screen-level frame links for:
  - macOS client tasks/files/accounts/settings
  - iOS reduced tab shell
  - admin rules/releases/devices/diagnostics/auth preview
  The task queue required screen or frame links, but the current repo docs only preserve the file-level link.

## External Design Reference
- Apple Human Interface Guidelines, Toolbars: `https://developer.apple.com/design/human-interface-guidelines/toolbars`

## Changes Made
- `WebShellClient-Apple`:
  - aligned palette tokens and text colors with foundations
  - changed primary/secondary button primitives
  - changed URL input and task row radii
  - remapped auth/account accent from purple to amber
  - moved the macOS global command strip out of the content overlay path so it no longer competes with the task header summary or Settings control-plane action area
  - changed the macOS command strip from an isolated right-aligned row into a compact single-line contextual command bar so the left side carries useful status instead of blank space
  - tightened macOS client density by reducing root/sidebar/panel padding, table row height, drawer spacing, button height, pill padding, and supporting type sizes
- `WebShellAdmin-macOS`:
  - aligned palette tokens with foundations
  - added primary/secondary/danger action tones
  - mapped rollback/delete actions to danger and refresh/manual actions to secondary
  - aligned status pill sizing and coloring

## Remaining Review Boundary
This pass does not claim pixel parity for full screens because concrete Figma screen frame nodes were not available in repo docs and were not returned from the root MCP metadata call. A follow-up pass should use exact `node-id` links for each screen and run side-by-side screenshot validation.

## Verification
Completed verification:

```bash
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellClient-Apple/Packages/WebShellClientKit && swift test
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellAdmin-macOS/Packages/WebShellAdminKit && swift test
xcode-mcp BuildProject on `/Users/yorl/Downloads/GitHub-Cool/WebShell/WebShell.xcworkspace` with active `WebShellClientMac`
cd /Users/yorl/Downloads/GitHub-Cool/WebShell/WebShellAdmin-macOS && xcodebuild -project WebShellAdmin.xcodeproj -scheme WebShellAdmin -destination 'platform=macOS' build
```

Results:

- `WebShellClientKit`: 64 tests passed.
- `WebShellAdminKit`: 14 tests passed.
- Xcode MCP `BuildProject`: `WebShellClientMac` built successfully and compiled `WebShellClientKit/Views.swift`.
- Admin macOS app build: `BUILD SUCCEEDED`; `WebShellAdminKit/Views.swift` compiled into the app target.
- Screenshot follow-up: after moving the macOS global command strip out of the content overlay path, the Tasks dense header and Settings control-plane action area no longer share the same z-layer with the floating controls. The later density follow-up changed that isolated right-aligned strip into a single-line contextual command bar with useful status on the left, then tightened the macOS client spacing and supporting type scale. Xcode MCP file diagnostics for `WebShellClientKit/Views.swift` passed, Xcode MCP `BuildProject` passed, and `WebShellClientKit` `swift test` passed again with 64 tests.
