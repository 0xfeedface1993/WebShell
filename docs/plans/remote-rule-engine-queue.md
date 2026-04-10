# Remote Rule Engine Queue

Parent tracker: `docs/plans/remote-rule-engine-plan.md`

## Queue Legend
- `Queue`: `ready`, `blocked`, `later`
- `Dev`: `Todo`, `In Progress`, `Done`
- `Measure`: `Pending`, `Passed`, `Failed`, `Not Run`
- `Priority`: `P0`, `P1`, `P2`, `P3`

## Active Queue
| ID | Task | Priority | Queue | Dev | Measure | Write Surface | Done when |
| --- | --- | --- | --- | --- | --- | --- | --- |
| B0.1 | Repoint the default `WebShell` product target to the new engine directory | P0 | ready | Done | Not Run | `Package.swift`, `Sources/WebShellEngine/` | Consumers import the new API by default |
| B0.2 | Mark old improvement tracker docs as superseded | P1 | ready | Done | Not Run | `docs/plans/webshell-improvement-*` | Handoff can no longer resume from legacy queue items |
| B1.1 | Define rule schema, public request/response contracts, and workflow step model | P0 | ready | Done | Not Run | `Sources/WebShellEngine/RuleModel.swift`, `CoreTypes.swift` | Rule bundle contracts exist and are codable |
| B1.2 | Define capability contract and registry | P0 | ready | Done | Not Run | `Sources/WebShellEngine/CapabilityRegistry.swift` | Capabilities can be registered and invoked by name |
| B2.1 | Implement snapshot store, remote source, and activation catalog | P0 | ready | Done | Not Run | `Sources/WebShellEngine/StorageAndSync.swift` | Bundles can be loaded, saved, and activated |
| B2.2 | Implement compile-time validation for schema, workflow references, capabilities, and matcher conflicts | P0 | ready | Done | Not Run | `Sources/WebShellEngine/Resolver.swift` | Invalid bundles fail before activation |
| B3.1 | Implement resolver runtime for `http`, `extract`, `assign`, `template`, `branch`, `loop`, `invokeCapability`, and `emitRequest` | P0 | ready | Done | Not Run | `Sources/WebShellEngine/Resolver.swift` | Download workflows execute without legacy pipeline code |
| B4.1 | Implement provider-family auth session store and auth-material boundary | P0 | ready | Done | Not Run | `Sources/WebShellEngine/Resolver.swift`, `CoreTypes.swift` | Sessions are reused by `providerFamily + accountID` |
| B4.2 | Add auth-triggered rerun after expiry detection | P0 | ready | Done | Not Run | `Sources/WebShellEngine/Resolver.swift` | Resolver retries after auth workflow populates a session |
| B5.1 | Add a real public provider-family rule fixture for `rosefile.net` | P1 | ready | Done | Not Run | `Sources/WebShellEngine/Fixtures.swift` | A real host family resolves through rules |
| B5.2 | Add an auth-required provider-family rule fixture for validation and contract tests | P1 | ready | Done | Not Run | `Sources/WebShellEngine/Fixtures.swift` | Auth path can be exercised without changing engine code |
| B5.3 | Add new engine contract tests | P1 | ready | Done | Not Run | `Tests/WebShellEngineTests/` | Core sync / resolve / auth-reuse scenarios have tests |
| B6.1 | Execute package build and test validation on the new target | P0 | ready | Done | Passed | runtime + tests | New target compiles cleanly and tests pass |
| B6.2 | Expand provider coverage beyond the initial public/auth pair | P1 | ready | Done | Passed | `Fixtures.swift`, future provider bundles | New sites ship as rule changes, not engine changes |
| B6.3 | Write migration guidance for downstream consumers still using legacy APIs | P2 | ready | Done | Passed | docs | Consumers know the new entrypoints and legacy boundary |

## Sequence Notes
- B6.1 passed via `swift test` on 2026-04-09.
- B6.2 passed by adding real provider-family rules for `xueqiupan`, `xunniufile`, `xingyaoclouds`, `rarp`, `567file`, and `iycdn` without changing the public API.
- B6.3 passed by adding `docs/migration-guide.md`.

## Handoff Notes
- Current state: new engine source tree is validated, provider coverage has expanded, and a downstream migration guide now exists.
- Exact next action: move fixture rules toward external JSON bundles or continue migrating any remaining site families without changing engine APIs.
- Main write boundary already established: `Sources/WebShellEngine/`, `Tests/WebShellEngineTests/`, `docs/plans/`, `Package.swift`.

## 2026-04-09 Update
- B6.4 Done/Unverified: default fixture rules now load from bundled JSON instead of embedded Swift constants.
- B6.5 Done/Unverified: legacy login workflow templates from `LoginXSRFVerifyCode`, `LoginNoCode`, and `GenerateDownloadRequest` are represented in the bundled rule set.
- B6.6 Done/Passed: formhash + captcha legacy login branch is now represented as `legacy.vip.formhashCaptcha.auth` in the bundled rule set and validated through a protected provider-family test.
- B6.7 Done/Unverified: default bundled catalog is now composed from three JSON bundles instead of one monolith.
- B6.8 Done/Unverified: `xrcf-vip` and `legacy-formhash-vip` auth provider families are now part of the default bundled catalog rather than test-local bundle augmentation.
- B6.9 Done/Unverified: moved example auth providers out of the default catalog into `auth-templates.bundle.json`.
- B6.10 Done/Unverified: replaced the default formhash demo host with verified `jkpan-vip` host matching `jkpan.com` login shape.
- B6.11 Done/Unverified: documented multi-bundle ownership and promotion rules in `docs/rule-bundle-organization.md`.
