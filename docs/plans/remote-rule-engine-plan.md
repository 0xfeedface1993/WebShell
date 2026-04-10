# Remote Rule Engine Plan

## Current Must-Read
- Product context for the multi-repo platform: `docs/product/webshell-platform-prd.md`
- Source of truth for plan: `docs/plans/remote-rule-engine-plan.md`
- Source of truth for progress: `docs/plans/remote-rule-engine-queue.md`
- Source of truth for validation state: `docs/plans/remote-rule-engine-validation.md`
- Read order for a new agent: `this plan -> queue -> validation -> Package.swift -> Sources/WebShellEngine/`

## Objective
Replace the legacy hard-coded download pipeline with a new rule-driven engine where the server ships versioned rule bundles, the client stores and activates them, download resolution is executed from compiled rules, and provider-family-scoped auth sessions are reused without requiring app updates for normal site flow changes.

## Deliverables
- D1: New public API centered on `ConfigSyncClient`, `DownloadResolver`, `AuthSessionStore`, `AuthMaterialProvider`, and `CapabilityRegistry`
- D2: Rule bundle schema and compiler with activation validation and capability checks
- D3: Resolver runtime that executes fixed workflow steps and emits downloader-ready requests
- D4: Provider-family auth runtime with session reuse and retry after auth refresh
- D5: New tracker docs and validation matrix for handoff-safe continuation
- D6: Legacy implementation removed from the default `WebShell` product path
- D7: Example bundle covering multiple real public provider families and one auth-required provider family

## Status Summary
- Overall: `In Progress`
- Current focus: externalize fixture rule bundles and continue any remaining provider-family migration without changing engine APIs
- Next action: move embedded fixture rules toward external JSON bundles, then continue rule-only provider additions
- Owner: Codex
- Last updated: 2026-04-09

## Truth Sources
1. `Sources/WebShellEngine/` for the active product implementation
2. `docs/plans/remote-rule-engine-queue.md` for execution status
3. `docs/plans/remote-rule-engine-validation.md` for scenario coverage and pending evidence
4. `Sources/WebShell/` only as legacy behavior reference, not as the current architecture

## Workstreams
| ID | Workstream | Dev | Measure | Depends on | Done when |
| --- | --- | --- | --- | --- | --- |
| B0 | Reset trackers and package surface | Done | Pending | - | New tracker set exists; default target points at new engine |
| B1 | Define domain model and public interfaces | Done | Pending | B0 | Public API and rule schema are fixed in source |
| B2 | Implement sync, storage, activation, and compilation | Done | Pending | B1 | Rule bundles can be fetched, stored, compiled, and activated |
| B3 | Implement resolver runtime and downloader contract | Done | Pending | B2 | A download URL can resolve to `ResolvedDownloadRequest` without legacy code |
| B4 | Implement auth runtime and provider-family session reuse | Done | Pending | B2 | Auth workflows can populate and reuse provider-family sessions |
| B5 | Add first vertical slices | Done | Pending | B3, B4 | One real public provider family and one auth-required family are modeled in rules |
| B6 | Retire default legacy path and document continuation work | In Progress | Pending | B5 | New API is the default path; remaining work is queued explicitly |

## Key Decisions
- New API only. The default library target no longer exports the legacy pipeline types.
- Rules are a fixed workflow DSL, not arbitrary remote code.
- Remote rules may reference only locally registered capabilities.
- Auth reuse is keyed by `providerFamily + accountID`.
- Auth HTTP execution stays in rules; credential material is supplied by `AuthMaterialProvider`.

## Exit Criteria
- [x] Default package product points at the new rule engine target
- [x] Active docs and queue no longer refer to the legacy hardening tracker as current work
- [x] Rule sync, compile, and resolve flows are implemented in code
- [x] Auth session reuse exists in code with provider-family scoping
- [ ] Validation matrix is fully executed against real build/test evidence
- [ ] More provider families are covered by rule bundles and fixtures

## Handoff Notes
- Read this plan first, then the queue and validation docs.
- Resume from the first `ready` item in `B6` unless a later status update says otherwise.
- Legacy code is now reference-only. Do not route new features through `Sources/WebShell/`.

## 2026-04-09 Progress Note
- Externalized the default fixture rule bundle to `Sources/WebShellEngine/Resources/RuleBundles/default.bundle.json` and switched `RuleBundleFixtures.defaultBundle` to resource loading.
- Migrated legacy auth templates into the bundled rule set: `legacy.vip.xsrfCaptcha.auth`, `legacy.vip.fastlogin.auth`, and `legacy.vip.generateDownload`.
- Added builtin capability `cookies.valueForName` to support header-token replay from persisted auth cookies.
- Added `legacy.vip.formhashCaptcha.auth` to the bundled JSON rule set, covering the old `LoginByFormhashAndCode` + `LoginVerifyCode` branch.
- Split the bundled fixture catalog into `public-sites.bundle.json`, `auth-workflows.bundle.json`, and `auth-sites.bundle.json`, then merged them at runtime through `RuleBundleFixtures.defaultBundle`.
- Promoted `xrcf-vip` and `legacy-formhash-vip` from test-only providers into the default bundled catalog so auth provider families now exist outside test code.
- Default catalog now excludes example auth hosts. Verified auth providers stay in `auth-sites.bundle.json`; template/example auth providers stay in `auth-templates.bundle.json` and require explicit loading.
- Replaced the old formhash demo host with verified `jkpan.com` coverage under `jkpan-vip`.
