# WebShell

<p align="center">
  <a href="https://github.com/0xfeedface1993/WebShell"><img src="Doc/webshell.png" alt="WebShell" width="210"/></a>
</p>

<p align="center">
  <a href="https://github.com/0xfeedface1993/WebShell"><img src="https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20Linux-red.svg" alt="Platforms" /></a>
  <a href="https://swift.org/package-manager/"><img src="https://img.shields.io/badge/SwiftPM-compatible-4BC51D.svg?style=flat" alt="SwiftPM compatible" /></a>
  <a href="https://github.com/0xfeedface1993/WebShell/issues"><img src="https://img.shields.io/github/issues/0xfeedface1993/WebShell.svg?style=flat" alt="GitHub issues" /></a>
</p>

WebShell is a Swift rule engine for turning provider-specific web download flows into declarative rule bundles. A host app activates a bundle of provider rules, workflows, and capabilities, then asks `DownloadResolver` to produce a direct `ResolvedDownloadRequest` or to run a named workflow.

The current design replaces the old "chain small modules per host" approach with a runtime that can load rules from bundled JSON, a remote control plane, or Swift-constructed fixtures.

## Design

WebShell is organized around five runtime pieces:

| Piece | Role |
| --- | --- |
| `RuleBundle` | Versioned contract that declares providers, URL matchers, auth workflows, download workflows, shared fragments, and required capabilities. |
| `ConfigSyncClient` | Fetches a bundle from a `RuleBundleRemoteSource`, compiles it with `RuleCompiler`, persists it through a `RuleBundleStore`, and activates it in `RuleCatalog`. |
| `RuleCatalog` | Holds the currently active compiled bundle used by every resolver call. |
| `DownloadResolver` | Public entry point for resolving download URLs, prewarming auth sessions, and invoking standalone workflows. |
| `CapabilityRegistry` | Hosts built-in and app-provided capabilities that workflows can call from `invokeCapability` steps. |

Rule execution is data-driven. A provider matches a source URL, points to a workflow ID, and may declare an auth policy. Workflows are made of HTTP, extract, assign, template, branch, loop, capability, and emit-request steps. The resolver runs those steps with a shared session store and returns structured Swift values.

## Installation

Add WebShell with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/0xfeedface1993/WebShell.git", branch: "main")
]
```

Then depend on the main product:

```swift
.product(name: "WebShell", package: "WebShell")
```

Supported platforms are iOS 14+, macOS 11+, tvOS 13+, watchOS 6+, visionOS 1+, and Linux.

## Quick Start

Activate a bundle, create a resolver, and resolve a source URL:

```swift
import Foundation
import WebShell

let bundle = try RuleBundleFixtures.loadMergedBundle(
    named: ["legacy-sites.bundle"],
    bundleVersion: "local-demo"
)

let registry = CapabilityRegistry.standard()
let catalog = RuleCatalog()
let sync = ConfigSyncClient(
    remoteSource: StaticRuleBundleRemoteSource(bundle: bundle),
    store: InMemoryRuleBundleStore(),
    catalog: catalog,
    capabilityRegistry: registry,
    remoteOrigin: .bundled
)

try await sync.sync()

let resolver = DownloadResolver(
    catalog: catalog,
    httpClient: URLSessionHTTPClient(),
    capabilityRegistry: registry
)

let resolved = try await resolver.resolve(
    DownloadResolveRequest(
        sourceURL: URL(string: "http://www.xueqiupan.com/file-672734.html")!
    )
)

print(resolved.method)
print(resolved.url)
print(resolved.headers)
```

`resolve(_:)` returns a `ResolvedDownloadRequest`, not downloaded file bytes. The caller owns the final transfer and can apply the returned method, URL, headers, body, cookies, filename hints, retry hints, and auth context.

## Public API

### Resolve a Download URL

```swift
let request = DownloadResolveRequest(
    sourceURL: sourceURL,
    accountID: "default",
    variables: ["slug": .string("optional-runtime-value")]
)

let resolved = try await resolver.resolve(request)
```

Use this path when the caller has a real provider URL. The resolver selects the matching provider, runs authentication if the provider requires it, executes the provider download workflow, and returns the emitted request.

### Prewarm or Refresh Authentication

```swift
let session = try await resolver.authenticate(
    hostURL: URL(string: "https://example-provider.com/")!,
    accountID: "account-1",
    variables: ["region": .string("cn")]
)
```

`authenticate(hostURL:accountID:variables:)` runs only the matched provider's auth workflow and stores the resulting `AuthSession` in the resolver's `AuthSessionStore`. Later `resolve(_:)` calls can reuse that session.

This entry point is intentionally explicit: it can run an auth workflow even when the provider's `authPolicy.requiresAuthentication` is `false`. That supports optional-login providers that work anonymously but return better content or higher quotas when logged in.

Provider matching is strict first and host-only second. If multiple providers share a host and the URL path does not disambiguate them, WebShell throws `RuleEngineError.ambiguousHostMatch`.

### Run a Named Workflow

```swift
let result = try await resolver.runWorkflow(
    workflowID: "secure.auth",
    sourceURL: URL(string: "https://secure.example.com/")!,
    variables: ["slug": .string("user42")],
    materials: [
        "username": .string("demo-user"),
        "password": .string("secret-password"),
    ]
)

let variables = result.variables
let authSession = result.authSession
let emittedRequest = result.emittedRequest
```

Use `runWorkflow(workflowID:sourceURL:authSessionKey:variables:materials:)` when the caller already knows the workflow ID and does not want provider URL routing to choose it. This is useful for list/detail fetch-and-parse pipelines, standalone auth workflows, or host-app-private workflows.

The result type is `RuleEngineRunResult`:

| Field | Meaning |
| --- | --- |
| `variables` | Final workflow variable map after extract, assign, template, and capability steps. |
| `authSession` | Session produced by HTTP steps with `persistResponseCookies: true`, if any. |
| `emittedRequest` | Request produced by the final `emitRequest` step, if any. |

When the workflow is declared by a provider, `runWorkflow` preserves that provider's family, metadata, and default session-key behavior. If more than one provider declares the same workflow ID, `sourceURL` is used to disambiguate. Ambiguous ownership throws `RuleEngineError.ambiguousWorkflowOwner`.

### Build Bundles in Swift

`RuleBundle` and `CapabilityReference` expose public initializers so downstream packages can assemble or merge bundles directly in Swift:

```swift
let bundle = RuleBundle(
    schemaVersion: RuleBundle.supportedSchemaVersion,
    bundleVersion: "2026.04.20.local",
    providers: providers,
    sharedFragments: sharedFragments,
    authWorkflows: authWorkflows,
    downloadWorkflows: downloadWorkflows,
    capabilityRefs: [
        CapabilityReference(name: "extract.regexLinks", required: true)
    ]
)
```

This avoids a JSON encode/decode round trip when a host app wants to combine remote rules with local fixtures or generated workflows.

### Register Custom Capabilities

Workflows can call built-in capabilities such as `extract.regexLinks`, `json.lookup`, `payload.formURLEncoded`, cookie helpers, URL helpers, and token helpers. Apps can add their own capabilities at startup:

```swift
let registry = CapabilityRegistry.standard()

await registry.register("app.parseArticleList") { invocation in
    let html = invocation.arguments["html"]?.stringValue ?? ""
    let provider = invocation.providerFamily

    return .object([
        "provider": .string(provider),
        "count": .number(Double(html.count)),
    ])
}
```

Capability handlers receive the provider family, the step arguments, and the current workflow variables. That keeps provider-specific parsing, OCR, signing, or app-owned integration code outside the declarative bundle while still making it callable from workflows.

## Bundle Model

A bundle has this top-level shape:

```json
{
  "schemaVersion": 1,
  "bundleVersion": "2026.04.20.example",
  "providers": [],
  "sharedFragments": [],
  "authWorkflows": [],
  "downloadWorkflows": [],
  "capabilityRefs": []
}
```

Provider rules declare URL matchers, provider identity, workflow IDs, auth policy, account scope, and metadata. Workflow definitions declare ordered steps. The bundled examples live under:

```text
Sources/WebShellEngine/Resources/RuleBundles/
```

The current bundled fixtures include:

| Bundle | Purpose |
| --- | --- |
| `legacy-sites.bundle.json` | Public download flows migrated from the old module-chain implementation. |
| `auth-workflows.bundle.json` | Reusable auth workflows, including captcha/form flows. |
| `auth-sites.bundle.json` | Provider bindings for authenticated site examples. |
| `auth-templates.bundle.json` | Template-focused auth and workflow fixtures used by tests. |

## Error Semantics

Important resolver errors are surfaced as `RuleEngineError`:

| Error | Meaning |
| --- | --- |
| `missingActiveBundle` | No bundle has been synced or activated in `RuleCatalog`. |
| `noMatchingProvider` | `resolve` or `authenticate` could not match the supplied URL to a provider. |
| `missingWorkflow` | `runWorkflow` could not find the requested workflow ID. |
| `ambiguousWorkflow` | The same workflow ID exists in more than one workflow list. |
| `ambiguousHostMatch` | Host-only auth routing matched multiple providers. Supply a more specific path. |
| `ambiguousWorkflowOwner` | Multiple providers declare the workflow ID and `sourceURL` cannot choose one owner. |
| `authMaterialUnavailable` | Required auth material such as username or password was not provided. |
| `authDidNotProduceSession` | An auth workflow ran but did not persist a reusable session. |

## Legacy Compatibility

The old Combine/module-chain implementation is still exposed through temporary products:

```swift
.product(name: "WebShellLegacy", package: "WebShell")
.product(name: "Durex", package: "WebShell")
.product(name: "AnyErase", package: "WebShell")
.product(name: "hmjs", package: "WebShell")
```

These products exist only to keep downstream consumers compiling while they migrate to the rule-engine API. New work should depend on `WebShell` and use `DownloadResolver`.

## Status

WebShell is still evolving. The rule bundle schema is currently `RuleBundle.supportedSchemaVersion == 1`, and the bundled site rules should be treated as fixtures and migration examples unless your app explicitly chooses to ship them.
