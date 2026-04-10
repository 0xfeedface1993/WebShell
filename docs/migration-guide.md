# WebShell Legacy API Migration Guide

## Purpose
- This guide is for consumers still using the legacy `Condom` / `Dirtyware` / `KeyStore` / `AsyncSession` pipeline.
- The default `WebShell` library target now exports the remote-rule engine API.
- Legacy implementation remains in the package as `WebShellLegacy`, but it is no longer the main path and should not receive new feature work.

## Read this first
- New default target: `WebShell`
- Legacy target: `WebShellLegacy`
- New entrypoints live under `Sources/WebShellEngine/`
- Current rule-engine tracker:
  - `docs/plans/remote-rule-engine-plan.md`
  - `docs/plans/remote-rule-engine-queue.md`
  - `docs/plans/remote-rule-engine-validation.md`

## What changed

### Old model
- Callers assembled a download flow in code:
  - `DownPage(...).join(PHPLinks()).join(Saver(...))`
- Site-specific behavior lived in Swift types and request builders.
- Session and intermediate state were passed through `KeyStore`, `SessionKey`, and legacy async wrappers.
- Adding or changing a site flow required shipping new app code.

### New model
- Callers resolve a download request through a rule engine:
  - sync rule bundle
  - activate compiled bundle
  - resolve a `DownloadResolveRequest`
  - hand the resulting `ResolvedDownloadRequest` to the downloader
- Site-specific behavior lives in rule bundles plus local capabilities.
- Auth reuse is keyed by `providerFamily + accountID`.
- Changing a supported site flow should be done by updating rules, not by editing engine code.

## API mapping

| Legacy concept | New concept | Notes |
| --- | --- | --- |
| `DownPage`, `ActionDownPage`, `RedirectEnablePage`, `TowerGroup`, `PHPLinks`, `GeneralLinks`, `SignFileListURLRequestGenerator` | `WorkflowDefinition` + `ProviderRule` | Site flow moves from hard-coded Swift pipeline to rule steps |
| `Condom` / `Dirtyware` composition | `DownloadResolver.resolve(_:)` | Resolution is now one engine entrypoint |
| `KeyStore` intermediate values | runtime variables inside workflow execution | Internal to resolver; no public caller dependency |
| `SessionKey` / `AsyncSession` | `AuthSessionStore` | Scoped by `providerFamily + accountID` |
| login modules in `VIP/` | `AuthPolicy` + auth workflow + `AuthMaterialProvider` | Auth HTTP steps remain in rules; credential material stays outside |
| ad-hoc parser helpers | capabilities in `CapabilityRegistry` | Add capabilities only when a rule cannot be expressed by existing steps |
| direct download `URLRequestBuilder` output | `ResolvedDownloadRequest` | Stable downloader contract |

## Replace the old call site

### Legacy shape
```swift
let link = "http://www.xueqiupan.com/file-672734.html"

cancellable = DownPage(.default)
    .join(PHPLinks())
    .join(Saver(.override))
    .publisher(for: link)
    .sink { completion in
        // ...
    } receiveValue: { url in
        print(url)
    }
```

### New shape
```swift
let registry = CapabilityRegistry.standard()
let catalog = RuleCatalog()
let store = InMemoryRuleBundleStore()

let syncClient = ConfigSyncClient(
    remoteSource: StaticRuleBundleRemoteSource(bundle: RuleBundleFixtures.defaultBundle),
    store: store,
    catalog: catalog,
    capabilityRegistry: registry
)

_ = try await syncClient.sync()

let resolver = DownloadResolver(
    catalog: catalog,
    httpClient: URLSessionHTTPClient(),
    capabilityRegistry: registry,
    authSessionStore: AuthSessionStore(),
    authMaterialProvider: NoopAuthMaterialProvider()
)

let resolved = try await resolver.resolve(
    DownloadResolveRequest(
        sourceURL: URL(string: "http://www.xueqiupan.com/file-672734.html")!
    )
)

// pass `resolved` into your downloader
```

## Migration steps

### 1. Stop building new flows on `WebShellLegacy`
- Do not add new `Dirtyware` types, request builders, or `VIP/*` modules.
- Treat legacy code as behavior reference only.

### 2. Move flow ownership from code to rules
- For each supported site family:
  - define a `ProviderRule`
  - bind it to one download workflow
  - add an auth workflow only if needed
  - keep all site-specific request sequencing in rule steps

### 3. Move request parsing into fixed steps or capabilities
- Prefer built-in steps:
  - `http`
  - `extract`
  - `assign`
  - `template`
  - `branch`
  - `loop`
  - `emitRequest`
- Add a capability only when the flow needs a reusable transformation not expressible by those steps.

### 4. Replace session coupling
- Remove direct caller dependence on `SessionKey`, `KeyStore`, and legacy async session types.
- Supply `accountID` on `DownloadResolveRequest` when the site requires account-scoped session reuse.
- Use `AuthMaterialProvider` to supply username/password/OTP/captcha results when auth workflows demand them.

### 5. Split resolution from download execution
- The resolver’s only job is to produce `ResolvedDownloadRequest`.
- The downloader should consume:
  - `method`
  - `url`
  - `headers`
  - `body`
  - `cookies`
  - `retryHints`
- Do not reintroduce HTML parsing or auth branching into the downloader layer.

## When to add a capability
- Add one when:
  - a transformation is reused by multiple provider families
  - the logic is deterministic and safe to expose by name
  - it would otherwise force awkward rule duplication
- Do not add one when:
  - the need is only a one-off string template
  - the behavior is really just another HTTP step or regex/json extraction
  - the feature would turn the rule engine into arbitrary code execution

## Current migrated provider families
- `rosefile`
- `xueqiupan`
- `xunniufile`
- `xingyaoclouds`
- `rarp`
- `567file`
- `iycdn`
- `secure-demo` (auth-required demo provider)

## Recommended migration order for downstream consumers
1. Switch imports and entrypoints to the new `WebShell` API.
2. Move one existing public site flow to `DownloadResolver`.
3. Replace legacy downloader input assumptions with `ResolvedDownloadRequest`.
4. Move authenticated flows onto `AuthMaterialProvider`.
5. Delete consumer-side dependencies on `KeyStore`, `SessionKey`, and legacy combinators.

## What not to migrate
- Do not preserve the old pipeline builder style as a compatibility layer.
- Do not map rule runtime variables back into `KeyStore`.
- Do not keep site support duplicated in both rules and legacy Swift request builders.
- Do not add new public APIs that expose internal workflow execution state.

## Current gap list
- Rule bundles are still embedded in Swift fixtures; they should move to external JSON bundles.
- Cold-start reactivation from stored snapshot exists in code but is not yet covered by a focused validation line.
- Remaining site families should continue to be added without changing engine APIs.
