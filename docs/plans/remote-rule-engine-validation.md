# Remote Rule Engine Validation Matrix

Parent tracker: `docs/plans/remote-rule-engine-plan.md`

## Truth-Source Order
1. Build/test results produced against the new `WebShell` target
2. Focused contract tests in `Tests/WebShellEngineTests/`
3. Manual fixture-driven inspection of emitted `ResolvedDownloadRequest`
4. Legacy behavior only when used as historical reference

## Validation Lines
| ID | Scenario | Setup | Expected result | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| V1 | Rule bundle decodes and activates from remote source | `StaticRuleBundleRemoteSource` + store + catalog | Snapshot is saved and catalog has an active bundle | Passed | `swift test` 2026-04-09 (`testSyncPersistsAndActivatesBundle`) |
| V2 | Missing capability blocks activation | Compile bundle with registry missing required capability | Compiler throws `missingCapability` before activation | Passed | `swift test` 2026-04-09 (`testCompilerRejectsMissingCapability`) |
| V3 | Host matcher conflict blocks activation | Compile bundle with overlapping host/path ownership | Compiler throws `invalidRule` conflict | Pending | Not run in this session |
| V4 | `rosefile.net` public workflow emits final downloader request | Sync default fixture bundle + stub HTTP client | Output request points at extracted direct link | Passed | `swift test` 2026-04-09 (`testRosefileProviderResolvesDirectDownloadRequest`) |
| V5 | Auth-required provider triggers login workflow on expiry signal | Sync default fixture bundle + stub HTTP client + static credentials | Resolver authenticates, stores session, and reruns download workflow | Passed | `swift test` 2026-04-09 (`testAuthWorkflowRefreshesAndReusesProviderFamilySession`) |
| V6 | Auth session is reused for the same `providerFamily + accountID` | Run the same auth-required resolve twice | Second resolve skips auth-material lookup and uses stored session | Passed | `swift test` 2026-04-09 (`testAuthWorkflowRefreshesAndReusesProviderFamilySession`) |
| V7 | Stored snapshot can be reactivated on cold start | Save bundle, create new catalog, activate from store | Resolver can operate without fetching a fresh remote bundle | Pending | Not run in this session |
| V8 | `xueqiupan` `DownPage + PHPLinks` flow resolves through rules only | Sync default fixture bundle + stub HTTP client | Resolver emits downloader request from `load_down_addr1` + `dl.php` workflow | Passed | `swift test` 2026-04-09 (`testXueqiupanProviderResolvesAjaxDownloadRequest`) |
| V9 | `xingyaoclouds` redirect + `load_down_addr5` flow resolves through rules only | Sync default fixture bundle + stub HTTP client | Resolver follows redirected URL, builds ajax request, and emits downloader request | Passed | `swift test` 2026-04-09 (`testXingyaocloudsProviderResolvesRedirectThenAjaxDownloadRequest`) |
| V10 | `rarp` redirect + page-extracted fileid flow resolves through rules only | Sync default fixture bundle + stub HTTP client | Resolver follows redirect, scrapes `load_down_addr1(...)`, and emits downloader request | Passed | `swift test` 2026-04-09 (`testRarpProviderResolvesRedirectPageFileIDFlow`) |
| V11 | `567file` redirect + sign flow resolves through rules only | Sync default fixture bundle + stub HTTP client | Resolver fetches sign page, posts `load_down_addr10`, and emits downloader request | Passed | `swift test` 2026-04-09 (`test567FileProviderResolvesRedirectSignFlow`) |
| V12 | `iycdn` tower-cookie flow resolves through rules only | Sync default fixture bundle + stub HTTP client | Resolver executes JS-derived cookie setup, attaches transient cookie to ajax request, and emits downloader request | Passed | `swift test` 2026-04-09 (`testIYCDNProviderResolvesTowerFlow`) |
| V13 | Downstream migration guide exists and points callers to the new entrypoints | Read `docs/migration-guide.md` | Caller can map legacy concepts to new API surface without inferring architecture from source | Passed | `docs/migration-guide.md` added on 2026-04-09 |

## Gates
- Do not add more provider families before V1, V4, and V5 pass.
- Do not remove `WebShellLegacy` from the package until build/test evidence exists for the new target.
- If validation fails twice without a material code change, stop rerunning and update the queue with a replan note.

## 2026-04-09 Pending Validation Additions
- V14 pending: bundled JSON fixture loads through `Bundle.module` and preserves workflow/catalog parity.
- V15 pending: legacy XSRF login plus generate-download workflow resolves an authenticated request using only rule-driven auth state.
- V14 passed on 2026-04-09: bundled JSON fixture loads through `Bundle.module` and preserves workflow/catalog parity.
- V15 passed on 2026-04-09: legacy XSRF login plus generate-download workflow resolves an authenticated request using only rule-driven auth state.
- V16 passed on 2026-04-09: legacy formhash + captcha auth flow resolves a protected request using rule-driven auth state and provider-family session reuse.
- V17 passed on 2026-04-09: merged multi-file bundle catalog compiles and loads with the same runtime behavior as the previous single-file fixture catalog.
- V18 passed on 2026-04-09: bundled `xrcf-vip` and `legacy-formhash-vip` providers resolve directly from `RuleBundleFixtures.defaultBundle` without test-local provider injection.
- V19 pending: default catalog excludes example auth hosts and still loads verified auth coverage through `jkpan-vip`.
- V20 pending: template auth coverage remains available only through explicit `auth-templates.bundle` loading.
