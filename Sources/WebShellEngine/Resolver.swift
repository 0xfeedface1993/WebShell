import Foundation

public struct AuthMaterialRequest: Sendable, Equatable {
    public let providerFamily: String
    public let accountID: String
    public let requiredKeys: [String]

    public init(providerFamily: String, accountID: String, requiredKeys: [String]) {
        self.providerFamily = providerFamily
        self.accountID = accountID
        self.requiredKeys = requiredKeys
    }
}

public protocol AuthMaterialProvider: Sendable {
    func materials(for request: AuthMaterialRequest) async throws -> [String: RuntimeValue]
}

public struct NoopAuthMaterialProvider: AuthMaterialProvider {
    public init() { }

    public func materials(for request: AuthMaterialRequest) async throws -> [String: RuntimeValue] {
        if request.requiredKeys.isEmpty {
            return [:]
        }
        throw RuleEngineError.authMaterialUnavailable(
            "No auth material provider configured for \(request.providerFamily)"
        )
    }
}

public struct StaticAuthMaterialProvider: AuthMaterialProvider {
    public let storage: [String: [String: [String: RuntimeValue]]]

    public init(storage: [String: [String: [String: RuntimeValue]]]) {
        self.storage = storage
    }

    public func materials(for request: AuthMaterialRequest) async throws -> [String: RuntimeValue] {
        let providerMaterials = storage[request.providerFamily] ?? [:]
        let candidate = providerMaterials[request.accountID] ?? providerMaterials["default"] ?? [:]
        for key in request.requiredKeys where candidate[key] == nil {
            throw RuleEngineError.authMaterialUnavailable(
                "Missing \(key) for \(request.providerFamily)/\(request.accountID)"
            )
        }
        return candidate
    }
}

public actor AuthSessionStore {
    private var sessions: [AuthSessionKey: AuthSession] = [:]

    public init() { }

    public func session(for key: AuthSessionKey) -> AuthSession? {
        sessions[key]
    }

    public func store(_ session: AuthSession) {
        sessions[session.key] = session
    }

    public func invalidate(_ key: AuthSessionKey) {
        sessions.removeValue(forKey: key)
    }

    public func removeAll() {
        sessions.removeAll()
    }
}

struct CompiledProvider: Sendable {
    let rule: ProviderRule
    let downloadWorkflow: WorkflowDefinition
    let authWorkflow: WorkflowDefinition?

    func matches(_ url: URL) -> Bool {
        rule.matchers.contains { $0.matches(url: url) }
    }

    /// Host-only variant of `matches(_:)`. Lets the standalone
    /// `authenticate(hostURL:)` entry point resolve a provider
    /// from just its host, without needing the caller to invent
    /// a download URL that satisfies the matcher's `pathPattern`.
    func matchesHost(of url: URL) -> Bool {
        rule.matchers.contains { $0.matchesHost(of: url) }
    }
}

/// Public return type of `DownloadResolver.runWorkflow(workflowID:…)`.
/// Holds the final state of a standalone workflow run — the
/// extracted-variables map plus any AuthSession / request the
/// workflow emitted.
///
/// Most Phase 4C callers only read `variables`; they look up the
/// field they explicitly declared in the workflow's last `assign`
/// or `invokeCapability` step (e.g. `parsedArticles`, `pageHTML`).
/// `authSession` surfaces when the workflow's HTTP steps set
/// `persistResponseCookies: true`, so callers can grab a fresh
/// session without a second `authenticate(…)` round-trip.
/// `emittedRequest` is populated if the workflow's last step was
/// `emitRequest` — useful for workflows that mix "fetch-and-parse"
/// with "emit a follow-on download".
public struct RuleEngineRunResult: Sendable {
    public let variables: [String: RuntimeValue]
    public let authSession: AuthSession?
    public let emittedRequest: ResolvedDownloadRequest?

    public init(
        variables: [String: RuntimeValue],
        authSession: AuthSession? = nil,
        emittedRequest: ResolvedDownloadRequest? = nil
    ) {
        self.variables = variables
        self.authSession = authSession
        self.emittedRequest = emittedRequest
    }
}

struct CompiledRuleBundle: Sendable {
    let snapshot: RuleBundleSnapshot
    let providers: [CompiledProvider]

    func provider(matching url: URL) -> CompiledProvider? {
        providers.first { $0.matches(url) }
    }

    /// Host-identity variant of `provider(matching:)`, for
    /// `authenticate(hostURL:)`. Two-tier selection to cope with
    /// bundles where multiple providers legally share a host
    /// (they must differ by `pathPattern` — compile-time
    /// conflict keys include path):
    ///
    /// 1. Prefer strict full match (`matches(url)`). If the
    ///    caller's URL carries a path that only one provider's
    ///    `pathPattern` accepts, this picks that one; if strict
    ///    returns multiple candidates, the rules themselves have
    ///    a conflict — surface it.
    /// 2. Otherwise fall back to host-only (`matchesHost`).
    ///    Single candidate → return it; multiple candidates →
    ///    throw `.ambiguousHostMatch(host)` (the caller has to
    ///    supply a URL with enough path to disambiguate); zero
    ///    → return `nil` so the caller can map to
    ///    `.noMatchingProvider`.
    ///
    /// Throwing rather than silently picking `first` prevents
    /// `authenticate` from running the wrong provider's auth
    /// workflow / persisting sessions under the wrong family
    /// when a bundle has host-overloaded providers.
    func provider(hostMatching url: URL) throws -> CompiledProvider? {
        let strict = providers.filter { $0.matches(url) }
        if strict.count == 1 { return strict.first }
        if strict.count > 1 {
            throw RuleEngineError.ambiguousHostMatch(url.host ?? url.absoluteString)
        }
        let byHost = providers.filter { $0.matchesHost(of: url) }
        if byHost.count == 1 { return byHost.first }
        if byHost.count > 1 {
            throw RuleEngineError.ambiguousHostMatch(url.host ?? url.absoluteString)
        }
        return nil
    }

    /// Return the provider that declares `id` as its
    /// `downloadWorkflowID` or `authWorkflowID`, using
    /// `sourceURL` to disambiguate when multiple providers share
    /// the same workflow ID. Used by `runWorkflow(workflowID:...)`
    /// so capabilities that key on provider identity see the
    /// correct owner (real family / id / metadata) instead of a
    /// synthetic "standalone" stub.
    ///
    /// Selection order:
    ///   1. `candidates = providers whose downloadWorkflowID /
    ///      authWorkflowID == id`
    ///   2. If empty → nil (caller falls back to synthetic).
    ///   3. If one → that provider.
    ///   4. Otherwise disambiguate by `sourceURL`:
    ///      a. strict full match (host + pathPattern)
    ///      b. host-only match (for prewarm-style URLs)
    ///      c. fall back to the first candidate
    ///
    /// Without (4), a shared workflow (e.g. `legacy-sites.bundle`'s
    /// `generic.loadDownAddr1.dlphp`, declared by both `xueqiupan`
    /// and `xunniufile`) would always route to whichever provider
    /// was registered first — the second provider's runWorkflow
    /// calls would inherit the wrong family / metadata and the
    /// wrong default session key.
    func provider(declaringWorkflowID id: String, sourceURL: URL) -> CompiledProvider? {
        let candidates = providers.filter { provider in
            provider.rule.downloadWorkflowID == id
                || provider.rule.authWorkflowID == id
        }
        if candidates.isEmpty { return nil }
        if candidates.count == 1 { return candidates.first }
        if let strict = candidates.first(where: { $0.matches(sourceURL) }) {
            return strict
        }
        if let byHost = candidates.first(where: { $0.matchesHost(of: sourceURL) }) {
            return byHost
        }
        return candidates.first
    }

    /// Look up a workflow by its string `id` across every list
    /// in the active bundle (`downloadWorkflows`, `authWorkflows`,
    /// `sharedFragments`). Used by `runWorkflow(workflowID:...)`.
    ///
    /// Compilation only enforces uniqueness WITHIN each list;
    /// a bundle can legally declare the same id in more than one
    /// list. Returning `first hit` in that case would silently
    /// pick one category (the download list is scanned first),
    /// making the others unreachable by id — so this method
    /// throws `.ambiguousWorkflow(id)` instead. Returns nil for
    /// ids that don't appear anywhere; callers map that to
    /// `.missingWorkflow` (since "missing" and "ambiguous" are
    /// different error classes for the caller).
    func workflow(id: String) throws -> WorkflowDefinition? {
        var hits: [WorkflowDefinition] = []
        if let hit = snapshot.bundle.downloadWorkflows.first(where: { $0.id == id }) {
            hits.append(hit)
        }
        if let hit = snapshot.bundle.authWorkflows.first(where: { $0.id == id }) {
            hits.append(hit)
        }
        if let hit = snapshot.bundle.sharedFragments.first(where: { $0.id == id }) {
            hits.append(hit)
        }
        if hits.count > 1 {
            throw RuleEngineError.ambiguousWorkflow(id)
        }
        return hits.first
    }
}

public struct RuleCompiler: Sendable {
    public init() { }

    func compile(
        snapshot: RuleBundleSnapshot,
        previous: CompiledRuleBundle? = nil,
        capabilityRegistry: CapabilityRegistry
    ) async throws -> CompiledRuleBundle {
        let bundle = snapshot.bundle
        guard bundle.schemaVersion == RuleBundle.supportedSchemaVersion else {
            throw RuleEngineError.invalidRule(
                "Unsupported schemaVersion \(bundle.schemaVersion), expected \(RuleBundle.supportedSchemaVersion)"
            )
        }

        let authWorkflows = try mapWorkflows(bundle.authWorkflows, label: "auth")
        let downloadWorkflows = try mapWorkflows(bundle.downloadWorkflows, label: "download")
        _ = try mapWorkflows(bundle.sharedFragments, label: "fragment")

        try validateProviders(bundle.providers)
        try await validateCapabilities(bundle: bundle, capabilityRegistry: capabilityRegistry)

        let previousProviders = Dictionary(uniqueKeysWithValues: (previous?.providers ?? []).map { ($0.rule.id, $0) })
        let compiledProviders: [CompiledProvider] = try bundle.providers.map { rule in
            let downloadWorkflow = try requireWorkflow(rule.downloadWorkflowID, from: downloadWorkflows)
            let authWorkflow = try rule.authWorkflowID.map { try requireWorkflow($0, from: authWorkflows) }
            if let reused = previousProviders[rule.id],
               reused.rule == rule,
               reused.downloadWorkflow == downloadWorkflow,
               reused.authWorkflow == authWorkflow {
                return reused
            }
            return CompiledProvider(rule: rule, downloadWorkflow: downloadWorkflow, authWorkflow: authWorkflow)
        }

        return CompiledRuleBundle(snapshot: snapshot, providers: compiledProviders)
    }

    private func mapWorkflows(
        _ workflows: [WorkflowDefinition],
        label: String
    ) throws -> [String: WorkflowDefinition] {
        var result = [String: WorkflowDefinition]()
        for workflow in workflows {
            guard result[workflow.id] == nil else {
                throw RuleEngineError.invalidRule("Duplicate \(label) workflow id \(workflow.id)")
            }
            result[workflow.id] = workflow
        }
        return result
    }

    private func requireWorkflow(
        _ id: String,
        from workflows: [String: WorkflowDefinition]
    ) throws -> WorkflowDefinition {
        guard let workflow = workflows[id] else {
            throw RuleEngineError.missingWorkflow(id)
        }
        return workflow
    }

    private func validateProviders(_ providers: [ProviderRule]) throws {
        var families = Set<String>()
        var matcherOwners = [String: String]()
        for provider in providers {
            try Task.checkCancellation()
            guard families.insert(provider.providerFamily).inserted else {
                throw RuleEngineError.invalidRule("Duplicate providerFamily \(provider.providerFamily)")
            }
            for matcher in provider.matchers {
                try Task.checkCancellation()
                for key in matcher.conflictKeys() {
                    try Task.checkCancellation()
                    if let owner = matcherOwners[key], owner != provider.providerFamily {
                        throw RuleEngineError.invalidRule(
                            "Matcher conflict between \(owner) and \(provider.providerFamily) for \(key)"
                        )
                    }
                    matcherOwners[key] = provider.providerFamily
                }
            }
        }
    }

    private func validateCapabilities(
        bundle: RuleBundle,
        capabilityRegistry: CapabilityRegistry
    ) async throws {
        for reference in bundle.capabilityRefs where reference.required {
            try Task.checkCancellation()
            guard await capabilityRegistry.contains(reference.name) else {
                throw RuleEngineError.missingCapability(reference.name)
            }
        }

        let workflowCapabilities = Set(
            bundle.sharedFragments.flatMap { collectCapabilities(in: $0.steps) }
            + bundle.authWorkflows.flatMap { collectCapabilities(in: $0.steps) }
            + bundle.downloadWorkflows.flatMap { collectCapabilities(in: $0.steps) }
        )

        for capability in workflowCapabilities {
            try Task.checkCancellation()
            guard await capabilityRegistry.contains(capability) else {
                throw RuleEngineError.missingCapability(capability)
            }
        }
    }

    private func collectCapabilities(in steps: [WorkflowStep]) -> [String] {
        steps.flatMap { step in
            switch step {
            case .invokeCapability(let value):
                return [value.capability]
            case .branch(let value):
                return collectCapabilities(in: value.ifSteps) + collectCapabilities(in: value.elseSteps)
            case .loop(let value):
                return collectCapabilities(in: value.steps)
            case .http, .extract, .assign, .template, .emitRequest:
                return []
            }
        }
    }
}

public struct DownloadResolver: Sendable {
    private static let defaultAuthAttemptLimit = 2
    private static let fullWorkflowCaptchaAuthAttemptLimit = 10
    private static let refreshCaptchaAuthAttemptLimit = 50

    private let catalog: RuleCatalog
    private let httpClient: any HTTPClient
    private let capabilityRegistry: CapabilityRegistry
    private let authSessionStore: AuthSessionStore
    private let authMaterialProvider: any AuthMaterialProvider

    public init(
        catalog: RuleCatalog,
        httpClient: any HTTPClient,
        capabilityRegistry: CapabilityRegistry,
        authSessionStore: AuthSessionStore = .init(),
        authMaterialProvider: any AuthMaterialProvider = NoopAuthMaterialProvider()
    ) {
        self.catalog = catalog
        self.httpClient = httpClient
        self.capabilityRegistry = capabilityRegistry
        self.authSessionStore = authSessionStore
        self.authMaterialProvider = authMaterialProvider
    }

    /// Standalone authentication-only entry point.
    ///
    /// Matches a provider by `hostURL` (same logic as `resolve`),
    /// verifies the provider has an auth workflow, and runs just
    /// the auth branch through `authenticateWithCaptchaRetry`.
    /// Returns the resulting `AuthSession`; also stored in the
    /// `AuthSessionStore` so subsequent `resolve(...)` calls for
    /// this provider skip re-auth.
    ///
    /// Use when the caller wants to pre-warm a session (e.g. boot
    /// login) or refresh a known-expired one without going through
    /// a download-URL resolve. Callers that resolve a real download
    /// URL should use `resolve(_:)` which triggers auth implicitly
    /// when needed.
    public func authenticate(
        hostURL: URL,
        accountID: String? = nil,
        variables: [String: RuntimeValue] = [:]
    ) async throws -> AuthSession {
        guard let compiledBundle = await catalog.currentCompiledBundle() else {
            throw RuleEngineError.missingActiveBundle
        }
        // Host-identity match: strict full match first (useful
        // when the caller does pass a URL with a distinguishing
        // path), host-only fallback for plain prewarm URLs.
        // Throws `.ambiguousHostMatch` when a host is shared by
        // multiple providers (legal if their pathPatterns
        // differ) and the caller's URL can't narrow it down —
        // surfacing the ambiguity beats silently running the
        // wrong provider's workflow.
        guard let provider = try compiledBundle.provider(hostMatching: hostURL) else {
            throw RuleEngineError.noMatchingProvider(hostURL.absoluteString)
        }
        // Gate on auth-workflow availability only — NOT on whether
        // the provider's auth policy makes auth automatic for
        // `resolve(_:)`. An explicit `authenticate(hostURL:)` call
        // is always "run this provider's auth workflow now",
        // including for optional-auth providers (ones that work
        // logged-out but surface more content / higher quotas when
        // a session is attached). `requiresAuthentication` is the
        // right gate for implicit auth inside `resolve(_:)`, but
        // it's the wrong gate for this explicit entry point.
        guard provider.authWorkflow != nil else {
            throw RuleEngineError.authWorkflowRequired(provider.rule.providerFamily)
        }

        let request = DownloadResolveRequest(
            sourceURL: hostURL,
            accountID: accountID,
            variables: variables
        )
        let resolvedAccountID = try resolveAccountID(for: provider, request: request)
        let sessionKey = AuthSessionKey(
            providerFamily: provider.rule.providerFamily,
            accountID: resolvedAccountID
        )
        let existingSession = await authSessionStore.session(for: sessionKey)
        let maxAttempts = maxAuthenticationAttempts(for: provider)

        let result = try await authenticateWithCaptchaRetry(
            provider: provider,
            request: request,
            sessionKey: sessionKey,
            existingSession: existingSession,
            attempts: 0,
            maxAttempts: maxAttempts
        )
        return result.session
    }

    /// Run an arbitrary workflow by ID without going through provider
    /// URL matching. Use this when the caller already knows *which*
    /// workflow to execute — e.g. a list/detail fetch + parse
    /// pipeline where every URL on the target host flows through the
    /// same named workflow regardless of the specific path. Unlike
    /// `resolve(_:)`, the returned value is the *extracted-variables
    /// map* from the final workflow state; callers pull out the
    /// fields they declared via `extract`/`assign` steps (e.g.
    /// `parsedArticles`, `pageHTML`).
    ///
    /// - Parameters:
    ///   - workflowID: the `WorkflowDefinition.id` in the active
    ///     bundle. Searches `downloadWorkflows` → `authWorkflows` →
    ///     `sharedFragments`. First match wins; throws
    ///     `missingWorkflow` if not found.
    ///   - sourceURL: exposed to the workflow as
    ///     `input.sourceURL`. Typically the page the workflow is
    ///     about to fetch.
    ///   - authSessionKey: pre-existing auth session to attach when
    ///     `http` steps set `attachAuthSession: true`. If nil, a
    ///     synthetic `("standalone", "default")` key is used; the
    ///     workflow still runs but any `persistResponseCookies: true`
    ///     store will go under the synthetic key. Pass the same key
    ///     as `authenticate(...)` produced when you want workflows
    ///     to share session state.
    ///   - variables: extra runtime variables available to the
    ///     workflow via the `{{input.variables.xxx}}` template path.
    ///   - materials: credentials / static values injected into the
    ///     runtime's `{{materials.xxx}}` template slots. Auth
    ///     workflows (reachable through this entry point because
    ///     `workflowID` lookup also searches `authWorkflows`)
    ///     typically require `materials.username` /
    ///     `materials.password` — pass those here when invoking
    ///     one. Fetch+parse workflows that don't template
    ///     materials can leave this empty.
    ///
    /// - Note: unlike `resolve`/`authenticate`, this method does not
    ///   require a provider matcher hit, so any workflow in the
    ///   catalog is reachable. This is deliberate — it lets
    ///   consumer-private bundles ship workflows that are
    ///   invoked directly by the host app without the caller having
    ///   to invent a placeholder URL matcher.
    public func runWorkflow(
        workflowID: String,
        sourceURL: URL,
        authSessionKey: AuthSessionKey? = nil,
        variables: [String: RuntimeValue] = [:],
        materials: [String: RuntimeValue] = [:]
    ) async throws -> RuleEngineRunResult {
        guard let compiledBundle = await catalog.currentCompiledBundle() else {
            throw RuleEngineError.missingActiveBundle
        }
        guard let workflow = try compiledBundle.workflow(id: workflowID) else {
            throw RuleEngineError.missingWorkflow(workflowID)
        }

        // Preserve provider identity when the workflow is
        // declared by a specific provider — `WorkflowRuntime`
        // forwards `provider.rule.providerFamily` / `metadata`
        // into `CapabilityInvocation`, so shared capabilities
        // keyed off provider identity must see the real owner
        // rather than a synthetic stub. For shared-fragment
        // workflows declared by no provider, fall back to a
        // synthetic "standalone" stub (provider-keyed
        // capabilities in those workflows have nothing to key
        // against anyway).
        let stubProvider: CompiledProvider
        if let owner = compiledBundle.provider(
            declaringWorkflowID: workflowID,
            sourceURL: sourceURL
        ) {
            stubProvider = owner
        } else {
            let stubRule = ProviderRule(
                id: "runWorkflow.standalone",
                providerFamily: "standalone",
                matchers: [],
                accountScope: .providerFamily,
                downloadWorkflowID: workflow.id,
                authWorkflowID: nil,
                authPolicy: nil,
                metadata: [:]
            )
            stubProvider = CompiledProvider(
                rule: stubRule,
                downloadWorkflow: workflow,
                authWorkflow: nil
            )
        }
        // Default session key inherits the detected owner's family
        // AND applies the owner's `authPolicy.accountIDTemplate`
        // via the same `resolveAccountID` helper that `resolve(_:)`
        // / `authenticate(_:)` use, so sessions persisted by this
        // call land under the same key `resolve(_:)` would use —
        // making them reusable across entry points. Providers
        // without a template (and synthetic stubs) fall through
        // to `"default"`. Caller-supplied `authSessionKey` always
        // wins.
        let resolvedAccountID: String
        if let key = authSessionKey {
            resolvedAccountID = key.accountID
        } else {
            resolvedAccountID = try resolveAccountID(
                for: stubProvider,
                request: DownloadResolveRequest(
                    sourceURL: sourceURL,
                    accountID: nil,
                    variables: variables
                )
            )
        }
        let sessionKey = authSessionKey ?? AuthSessionKey(
            providerFamily: stubProvider.rule.providerFamily,
            accountID: resolvedAccountID
        )
        let existingSession = await authSessionStore.session(for: sessionKey)
        let request = DownloadResolveRequest(
            sourceURL: sourceURL,
            accountID: resolvedAccountID,
            variables: variables
        )
        var runtime = WorkflowRuntime(
            provider: stubProvider,
            workflow: workflow,
            request: request,
            httpClient: httpClient,
            capabilityRegistry: capabilityRegistry,
            sessionKey: sessionKey,
            authSession: existingSession,
            materials: materials,
            authExpireConditions: []
        )
        let result = try await runtime.run()
        if let refreshed = result.authSession, !refreshed.isEmpty {
            await authSessionStore.store(refreshed)
        }
        return RuleEngineRunResult(
            variables: result.variables,
            authSession: result.authSession,
            emittedRequest: result.emittedRequest
        )
    }

    public func resolve(_ request: DownloadResolveRequest) async throws -> ResolvedDownloadRequest {
        guard let compiledBundle = await catalog.currentCompiledBundle() else {
            throw RuleEngineError.missingActiveBundle
        }
        guard let provider = compiledBundle.provider(matching: request.sourceURL) else {
            throw RuleEngineError.noMatchingProvider(request.sourceURL.absoluteString)
        }

        let accountID = try resolveAccountID(for: provider, request: request)
        let sessionKey = AuthSessionKey(providerFamily: provider.rule.providerFamily, accountID: accountID)
        var session = await authSessionStore.session(for: sessionKey)
        let maxAuthAttempts = maxAuthenticationAttempts(for: provider)
        var authAttempts = 0

        if provider.rule.authPolicy?.requiresAuthentication == true && session == nil {
            let authResult = try await authenticateWithCaptchaRetry(
                provider: provider,
                request: request,
                sessionKey: sessionKey,
                existingSession: session,
                attempts: authAttempts,
                maxAttempts: maxAuthAttempts
            )
            session = authResult.session
            authAttempts = authResult.attempts
        }

        while true {
            try Task.checkCancellation()
            let run = try await runDownloadWorkflow(provider: provider, request: request, sessionKey: sessionKey, authSession: session)
            if let refreshedSession = run.authSession, !refreshedSession.isEmpty {
                await authSessionStore.store(refreshedSession)
                session = refreshedSession
            }

            if run.authExpired {
                guard provider.authWorkflow != nil else {
                    throw RuleEngineError.authExpiredAfterRetry(provider.rule.providerFamily)
                }
                guard authAttempts < maxAuthAttempts else {
                    if authWorkflowUsesCaptcha(provider) {
                        throw RuleEngineError.authCaptchaRetryLimitExceeded(provider.rule.providerFamily, maxAuthAttempts)
                    }
                    throw RuleEngineError.authExpiredAfterRetry(provider.rule.providerFamily)
                }

                await authSessionStore.invalidate(sessionKey)
                let authResult = try await authenticateWithCaptchaRetry(
                    provider: provider,
                    request: request,
                    sessionKey: sessionKey,
                    existingSession: run.authSession ?? session,
                    attempts: authAttempts,
                    maxAttempts: maxAuthAttempts
                )
                session = authResult.session
                authAttempts = authResult.attempts
                continue
            }

            guard let resolved = run.emittedRequest else {
                throw RuleEngineError.noEmittedRequest(provider.rule.providerFamily)
            }
            return resolved
        }
    }

    private func resolveAccountID(for provider: CompiledProvider, request: DownloadResolveRequest) throws -> String {
        if let explicit = request.accountID, !explicit.isEmpty {
            return explicit
        }
        if let template = provider.rule.authPolicy?.accountIDTemplate {
            let variables = ["input": request.runtimeValue]
            let value = try renderTemplate(template, variables: variables)
            if !value.isEmpty {
                return value
            }
        }
        return "default"
    }

    private func maxAuthenticationAttempts(for provider: CompiledProvider) -> Int {
        guard authWorkflowUsesCaptcha(provider) else {
            return Self.defaultAuthAttemptLimit
        }
        if let configured = provider.rule.authPolicy?.captchaRetryPolicy?.maxAttempts {
            return max(1, configured)
        }
        if provider.rule.authPolicy?.captchaRetryPolicy?.mode == .refreshCaptcha {
            return Self.refreshCaptchaAuthAttemptLimit
        }
        return Self.fullWorkflowCaptchaAuthAttemptLimit
    }

    private func authWorkflowUsesCaptcha(_ provider: CompiledProvider) -> Bool {
        guard let workflow = provider.authWorkflow else {
            return false
        }
        return workflow.steps.contains { stepContainsCaptchaCapability($0) }
    }

    private func stepContainsCaptchaCapability(_ step: WorkflowStep) -> Bool {
        switch step {
        case .invokeCapability(let value):
            return value.capability == "captcha.ocr"
        case .branch(let value):
            return value.ifSteps.contains { stepContainsCaptchaCapability($0) }
                || value.elseSteps.contains { stepContainsCaptchaCapability($0) }
        case .loop(let value):
            return value.steps.contains { stepContainsCaptchaCapability($0) }
        case .http, .extract, .assign, .template, .emitRequest:
            return false
        }
    }

    private func authenticateWithCaptchaRetry(
        provider: CompiledProvider,
        request: DownloadResolveRequest,
        sessionKey: AuthSessionKey,
        existingSession: AuthSession?,
        attempts: Int,
        maxAttempts: Int
    ) async throws -> (session: AuthSession, attempts: Int) {
        if provider.rule.authPolicy?.captchaRetryPolicy?.mode == .refreshCaptcha {
            return try await authenticateWithRefreshCaptchaRetry(
                provider: provider,
                request: request,
                sessionKey: sessionKey,
                existingSession: existingSession,
                attempts: attempts,
                maxAttempts: maxAttempts
            )
        }

        var currentAttempts = attempts
        while true {
            try Task.checkCancellation()
            guard currentAttempts < maxAttempts else {
                throw RuleEngineError.authCaptchaRetryLimitExceeded(provider.rule.providerFamily, maxAttempts)
            }

            currentAttempts += 1
            do {
                let session = try await authenticate(
                    provider: provider,
                    request: request,
                    sessionKey: sessionKey,
                    existingSession: existingSession
                )
                return (session, currentAttempts)
            } catch {
                guard isRetryableCaptchaAuthError(error, provider: provider) else {
                    throw error
                }
                await authSessionStore.invalidate(sessionKey)
                guard currentAttempts < maxAttempts else {
                    throw RuleEngineError.authCaptchaRetryLimitExceeded(provider.rule.providerFamily, maxAttempts)
                }
            }
        }
    }

    private func authenticateWithRefreshCaptchaRetry(
        provider: CompiledProvider,
        request: DownloadResolveRequest,
        sessionKey: AuthSessionKey,
        existingSession: AuthSession?,
        attempts: Int,
        maxAttempts: Int
    ) async throws -> (session: AuthSession, attempts: Int) {
        let retryStartIndex = try captchaRetryStartIndex(for: provider)
        var runtime = try await makeAuthRuntime(
            provider: provider,
            request: request,
            sessionKey: sessionKey,
            existingSession: existingSession
        )
        var currentAttempts = attempts
        var startIndex = 0
        var ambiguousLoginPageRetries = 0

        while true {
            try Task.checkCancellation()
            guard currentAttempts < maxAttempts else {
                throw RuleEngineError.authCaptchaRetryLimitExceeded(provider.rule.providerFamily, maxAttempts)
            }

            currentAttempts += 1
            var recordedResult = false
            do {
                let result = try await runtime.run(from: startIndex)
                recordAuthAttemptDebug(result: result, provider: provider, attempt: currentAttempts, error: nil)
                recordedResult = true
                if !authDashboardIsAuthenticated(result),
                   let inertiaFailure = authInertiaFailureKind(in: result),
                   case .ambiguousLoginPage = inertiaFailure,
                   ambiguousLoginPageRetries < 2 {
                    ambiguousLoginPageRetries += 1
                    throw RuleEngineError.authCaptchaRejected(provider.rule.providerFamily)
                }
                try validateAuthWorkflowResult(result, provider: provider)
                let session = try authSession(from: result, provider: provider)
                await authSessionStore.store(session)
                return (session, currentAttempts)
            } catch {
                if !recordedResult {
                    recordAuthAttemptDebug(result: nil, provider: provider, attempt: currentAttempts, error: error)
                }
                guard isRetryableCaptchaAuthError(error, provider: provider) else {
                    throw error
                }
                await authSessionStore.invalidate(sessionKey)
                guard currentAttempts < maxAttempts else {
                    throw RuleEngineError.authCaptchaRetryLimitExceeded(provider.rule.providerFamily, maxAttempts)
                }
                startIndex = retryStartIndex
            }
        }
    }

    private func captchaRetryStartIndex(for provider: CompiledProvider) throws -> Int {
        guard let workflow = provider.authWorkflow else {
            throw RuleEngineError.authWorkflowRequired(provider.rule.providerFamily)
        }
        guard let startAtOutput = provider.rule.authPolicy?.captchaRetryPolicy?.startAtOutput,
              !startAtOutput.isEmpty else {
            throw RuleEngineError.invalidRule(
                "Captcha refresh retry for \(provider.rule.providerFamily) requires captchaRetryPolicy.startAtOutput"
            )
        }
        guard let index = workflow.steps.firstIndex(where: { stepProducesOutput($0, output: startAtOutput) }) else {
            throw RuleEngineError.invalidRule(
                "Captcha refresh retry for \(provider.rule.providerFamily) could not find output \(startAtOutput)"
            )
        }
        return index
    }

    private func stepProducesOutput(_ step: WorkflowStep, output: String) -> Bool {
        switch step {
        case .http(let value):
            return value.output == output
        case .extract(let value):
            return value.target == output
        case .assign(let value):
            return value.target == output
        case .template(let value):
            return value.target == output
        case .invokeCapability(let value):
            return value.target == output
        case .branch, .loop, .emitRequest:
            return false
        }
    }

    private func isRetryableCaptchaAuthError(_ error: any Error, provider: CompiledProvider) -> Bool {
        guard authWorkflowUsesCaptcha(provider) else {
            return false
        }

        if let ruleError = error as? RuleEngineError {
            switch ruleError {
            case .authCaptchaRejected:
                return true
            case .authCaptchaRetryLimitExceeded,
                 .authCredentialsRejected,
                 .authMaterialUnavailable,
                 .authWorkflowRequired,
                 .authDidNotProduceSession,
                 .authExpiredAfterRetry,
                 .missingActiveBundle,
                 .noMatchingProvider,
                 .missingWorkflow,
                 .ambiguousWorkflow,
                 .ambiguousHostMatch,
                 .missingCapability,
                 .noEmittedRequest,
                 .httpFailure:
                return false
            case .invalidRule(let message), .invalidTemplate(let message), .missingVariable(let message):
                let lowercased = message.lowercased()
                return lowercased.contains("captcha")
                    && !lowercased.contains("requires a client-side ocr capability handler")
            }
        }

        let description = "\(error) \(error.localizedDescription)".lowercased()
        return description.contains("captcha")
    }

    private func authenticate(
        provider: CompiledProvider,
        request: DownloadResolveRequest,
        sessionKey: AuthSessionKey,
        existingSession: AuthSession?
    ) async throws -> AuthSession {
        var runtime = try await makeAuthRuntime(
            provider: provider,
            request: request,
            sessionKey: sessionKey,
            existingSession: existingSession
        )
        let result = try await runtime.run()
        recordAuthAttemptDebug(result: result, provider: provider, attempt: nil, error: nil)
        try validateAuthWorkflowResult(result, provider: provider)
        let session = try authSession(from: result, provider: provider)
        await authSessionStore.store(session)
        return session
    }

    private func makeAuthRuntime(
        provider: CompiledProvider,
        request: DownloadResolveRequest,
        sessionKey: AuthSessionKey,
        existingSession: AuthSession?
    ) async throws -> WorkflowRuntime {
        guard let workflow = provider.authWorkflow else {
            throw RuleEngineError.authWorkflowRequired(provider.rule.providerFamily)
        }

        let requiredKeys = provider.rule.authPolicy?.materialKeys ?? []
        let materials = try await authMaterialProvider.materials(
            for: AuthMaterialRequest(
                providerFamily: provider.rule.providerFamily,
                accountID: sessionKey.accountID,
                requiredKeys: requiredKeys
            )
        )

        return WorkflowRuntime(
            provider: provider,
            workflow: workflow,
            request: request,
            httpClient: httpClient,
            capabilityRegistry: capabilityRegistry,
            sessionKey: sessionKey,
            authSession: existingSession,
            materials: materials,
            authExpireConditions: []
        )
    }

    private func authSession(from result: WorkflowRunResult, provider: CompiledProvider) throws -> AuthSession {
        guard let session = result.authSession, !session.isEmpty else {
            throw RuleEngineError.authDidNotProduceSession(provider.rule.providerFamily)
        }
        return session
    }

    private func validateAuthWorkflowResult(_ result: WorkflowRunResult, provider: CompiledProvider) throws {
        let bodies = [
            lookup(path: "loginResponse.body", in: result.variables)?.renderedString(),
            lookup(path: "dashboardPage.body", in: result.variables)?.renderedString(),
            lookup(path: "lastResponse.body", in: result.variables)?.renderedString(),
        ].compactMap { $0 }

        guard !bodies.isEmpty else {
            return
        }

        let joined = bodies.joined(separator: "\n")
        if (provider.rule.authPolicy?.credentialRejectConditions ?? []).contains(where: { evaluateRuleCondition($0, variables: result.variables) }) {
            throw RuleEngineError.authCredentialsRejected(provider.rule.providerFamily)
        }
        if (provider.rule.authPolicy?.captchaRejectConditions ?? []).contains(where: { evaluateRuleCondition($0, variables: result.variables) }) {
            throw RuleEngineError.authCaptchaRejected(provider.rule.providerFamily)
        }
        if let successConditions = provider.rule.authPolicy?.successConditions,
           !successConditions.isEmpty {
            guard successConditions.allSatisfy({ evaluateRuleCondition($0, variables: result.variables) }) else {
                throw RuleEngineError.authCredentialsRejected(provider.rule.providerFamily)
            }
            return
        }
        if authDashboardIsAuthenticated(result) {
            return
        }
        if let inertiaFailure = authInertiaFailureKind(in: result) {
            switch inertiaFailure {
            case .captcha:
                throw RuleEngineError.authCaptchaRejected(provider.rule.providerFamily)
            case .credentials:
                throw RuleEngineError.authCredentialsRejected(provider.rule.providerFamily)
            case .ambiguousLoginPage:
                throw RuleEngineError.authCredentialsRejected(provider.rule.providerFamily)
            }
        }
        if containsCredentialRejection(joined) {
            throw RuleEngineError.authCredentialsRejected(provider.rule.providerFamily)
        }
        if containsCaptchaRejection(joined) {
            throw RuleEngineError.authCaptchaRejected(provider.rule.providerFamily)
        }
        if let statusCode = authLoginStatusCode(result), statusCode >= 400 {
            if statusCode == 401 || statusCode == 403 {
                throw RuleEngineError.authCredentialsRejected(provider.rule.providerFamily)
            }
            throw RuleEngineError.httpFailure(
                "Auth workflow login failed with HTTP \(statusCode): \(provider.rule.providerFamily)"
            )
        }
    }

    private func authLoginStatusCode(_ result: WorkflowRunResult) -> Int? {
        guard let rendered = lookup(path: "loginResponse.statusCode", in: result.variables)?.renderedString(),
              !rendered.isEmpty else {
            return nil
        }
        return Int(rendered)
    }

    private enum AuthFailureKind {
        case captcha
        case credentials
        case ambiguousLoginPage
    }

    private func authInertiaFailureKind(in result: WorkflowRunResult) -> AuthFailureKind? {
        [
            lookup(path: "loginResponse.body", in: result.variables)?.renderedString(),
            lookup(path: "dashboardPage.body", in: result.variables)?.renderedString(),
            lookup(path: "lastResponse.body", in: result.variables)?.renderedString(),
        ]
        .compactMap { $0 }
        .compactMap(authFailureKind)
        .first
    }

    private func authDashboardIsAuthenticated(_ result: WorkflowRunResult) -> Bool {
        [
            lookup(path: "dashboardPage.body", in: result.variables)?.renderedString(),
            lookup(path: "lastResponse.body", in: result.variables)?.renderedString(),
            lookup(path: "loginResponse.body", in: result.variables)?.renderedString(),
        ]
        .compactMap { $0 }
        .contains(where: authSuccessKind)
    }

    private func authSuccessKind(in body: String) -> Bool {
        guard let page = parseInertiaPage(from: body) else {
            return containsAny(body, [
                #""isAuthenticated":true"#,
                #"&quot;isAuthenticated&quot;:true"#,
                #""isVip":true"#,
                #"&quot;isVip&quot;:true"#,
            ])
        }
        let component = page["component"] as? String ?? ""
        guard component != "Auth/Login" else {
            return false
        }
        if component.localizedCaseInsensitiveContains("dashboard") {
            return true
        }
        if let props = page["props"] as? [String: Any],
           authUserPresent(from: props["auth"]) {
            return true
        }
        return false
    }

    private func authFailureKind(in body: String) -> AuthFailureKind? {
        guard let page = parseInertiaPage(from: body),
              let component = page["component"] as? String,
              component == "Auth/Login" else {
            return nil
        }
        guard let props = page["props"] as? [String: Any] else {
            return .credentials
        }

        if let captchaError = props["captchaError"] as? String, !captchaError.isEmpty {
            return .captcha
        }

        let keys = Set(errorKeys(from: props["errors"]))
        if keys.contains("captcha") {
            return .captcha
        }
        if keys.contains("login") || keys.contains("password") {
            return .credentials
        }

        let messages = errorMessages(from: props["errors"])
        if messages.contains(where: containsCaptchaRejection) {
            return .captcha
        }
        if messages.contains(where: containsCredentialRejection) {
            return .credentials
        }
        return .ambiguousLoginPage
    }

    private func containsCredentialRejection(_ body: String) -> Bool {
        let lowercased = body.lowercased()
        return body.contains("密码错误")
            || body.contains("密碼錯誤")
            || body.contains("账号或密码")
            || body.contains("賬號或密碼")
            || body.contains("帐号或密码")
            || body.contains("帳號或密碼")
            || lowercased.contains("invalid password")
            || lowercased.contains("incorrect password")
    }

    private func containsCaptchaRejection(_ body: String) -> Bool {
        let lowercased = body.lowercased()
        return lowercased.contains("captchaerror")
            || body.contains("验证码错误")
            || body.contains("驗證碼錯誤")
            || body.contains("验证码")
            || body.contains("驗證碼")
            || (lowercased.contains("errors") && lowercased.contains("captcha"))
    }

    private func recordAuthAttemptDebug(
        result: WorkflowRunResult?,
        provider: CompiledProvider,
        attempt: Int?,
        error: (any Error)?
    ) {
        guard let rawDirectory = ProcessInfo.processInfo.environment["WEBSHELL_AUTH_DEBUG_DIR"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawDirectory.isEmpty else {
            return
        }

        var record: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "provider": provider.rule.providerFamily,
        ]
        if let attempt {
            record["attempt"] = attempt
        }
        if let error {
            record["error"] = String(describing: error)
            record["localized_error"] = error.localizedDescription
        }
        if let result {
            record.merge(authDebugFields(from: result), uniquingKeysWith: { _, new in new })
        }

        let directory = URL(fileURLWithPath: rawDirectory, isDirectory: true)
        let filename = "auth-attempts-\(debugFileComponent(provider.rule.providerFamily)).ndjson"
        let fileURL = directory.appendingPathComponent(filename)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            data.append(0x0a)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: fileURL, options: .atomic)
            }
        } catch {
            // Debug-only path: never let auth diagnostics change resolver behavior.
        }
    }

    private func authDebugFields(from result: WorkflowRunResult) -> [String: Any] {
        let loginBody = lookup(path: "loginResponse.body", in: result.variables)?.renderedString()
        let dashboardBody = lookup(path: "dashboardPage.body", in: result.variables)?.renderedString()
        let lastBody = lookup(path: "lastResponse.body", in: result.variables)?.renderedString()
        let bodies = [loginBody, dashboardBody, lastBody].compactMap { $0 }
        let joined = bodies.joined(separator: "\n")

        var fields: [String: Any] = [
            "contains_captcha_rejection": containsCaptchaRejection(joined),
            "contains_credential_rejection": containsCredentialRejection(joined),
            "body_count": bodies.count,
            "captcha_text": lookup(path: "captchaText", in: result.variables)?.renderedString() ?? "",
            "auth_cookie_names": cookieNames(path: "auth.cookies", in: result.variables),
            "login_cookie_names": cookieNames(path: "loginResponse.cookies", in: result.variables),
            "login_status": lookup(path: "loginResponse.statusCode", in: result.variables)?.renderedString() ?? "",
            "login_url": lookup(path: "loginResponse.url", in: result.variables)?.renderedString() ?? "",
            "login_body_length": loginBody?.count ?? 0,
            "dashboard_status": lookup(path: "dashboardPage.statusCode", in: result.variables)?.renderedString() ?? "",
            "dashboard_url": lookup(path: "dashboardPage.url", in: result.variables)?.renderedString() ?? "",
            "dashboard_body_length": dashboardBody?.count ?? 0,
            "dashboard_authenticated": authDashboardIsAuthenticated(result),
            "material_value_lengths": materialValueLengths(in: result.variables),
            "inertia_is_authenticated_true": containsAny(joined, [
                #""isAuthenticated":true"#,
                #"&quot;isAuthenticated&quot;:true"#,
            ]),
            "inertia_is_authenticated_false": containsAny(joined, [
                #""isAuthenticated":false"#,
                #"&quot;isAuthenticated&quot;:false"#,
            ]),
        ]

        if let page = loginBody.flatMap(parseInertiaPage) ?? lastBody.flatMap(parseInertiaPage) {
            fields["inertia_component"] = page["component"] as? String ?? ""
            fields["inertia_url"] = page["url"] as? String ?? ""
            if let props = page["props"] as? [String: Any] {
                fields["inertia_props_keys"] = props.keys.sorted()
                fields["inertia_captcha_error"] = props["captchaError"] as? String ?? ""
                fields["inertia_error_keys"] = errorKeys(from: props["errors"])
                fields["inertia_error_messages"] = errorMessages(from: props["errors"]).map {
                    truncatedDebugString($0, maxLength: 160)
                }
                fields["inertia_flash_error"] = debugString(props["flash"].flatMap(flashErrorValue)) ?? ""
                fields["inertia_status"] = debugString(props["status"]) ?? ""
                fields["inertia_auth_user_present"] = authUserPresent(from: props["auth"])
            }
        }
        if let page = dashboardBody.flatMap(parseInertiaPage) {
            fields["dashboard_inertia_component"] = page["component"] as? String ?? ""
            fields["dashboard_inertia_url"] = page["url"] as? String ?? ""
            if let props = page["props"] as? [String: Any] {
                fields["dashboard_inertia_props_keys"] = props.keys.sorted()
                fields["dashboard_inertia_auth_user_present"] = authUserPresent(from: props["auth"])
            }
        }
        return fields
    }

    private func materialValueLengths(in variables: [String: RuntimeValue]) -> [String: Int] {
        guard let materials = lookup(path: "materials", in: variables)?.objectValue else {
            return [:]
        }
        return Dictionary(
            uniqueKeysWithValues: materials.map { key, value in
                (key, value.renderedString().count)
            }
        )
    }

    private func flashErrorValue(from value: Any) -> Any? {
        guard let object = value as? [String: Any] else {
            return nil
        }
        return object["error"]
    }

    private func debugString(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return truncatedDebugString(string, maxLength: 160)
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private func truncatedDebugString(_ value: String, maxLength: Int) -> String {
        guard value.count > maxLength else {
            return value
        }
        let endIndex = value.index(value.startIndex, offsetBy: maxLength)
        return String(value[..<endIndex]) + "..."
    }

    private func cookieNames(path: String, in variables: [String: RuntimeValue]) -> [String] {
        lookup(path: path, in: variables)?.arrayValue?.compactMap { item in
            item.objectValue?["name"]?.stringValue
        } ?? []
    }

    private func parseInertiaPage(from body: String) -> [String: Any]? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"),
           let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           object["component"] != nil {
            return object
        }

        guard let range = body.range(of: #"data-page="([^"]+)""#, options: .regularExpression) else {
            return nil
        }
        let matched = String(body[range])
        guard let start = matched.firstIndex(of: "\""),
              let end = matched.lastIndex(of: "\""),
              start < end else {
            return nil
        }
        let encoded = String(matched[matched.index(after: start)..<end])
        let decoded = encoded
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        guard let data = decoded.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private func errorKeys(from value: Any?) -> [String] {
        if let object = value as? [String: Any] {
            return object.keys.sorted()
        }
        if let array = value as? [Any], !array.isEmpty {
            return ["array"]
        }
        return []
    }

    private func errorMessages(from value: Any?) -> [String] {
        if let string = value as? String {
            return [string]
        }
        if let strings = value as? [String] {
            return strings
        }
        if let array = value as? [Any] {
            return array.flatMap(errorMessages)
        }
        if let object = value as? [String: Any] {
            return object.values.flatMap(errorMessages)
        }
        return []
    }

    private func authUserPresent(from value: Any?) -> Bool {
        guard let object = value as? [String: Any], let user = object["user"] else {
            return false
        }
        return !(user is NSNull)
    }

    private func containsAny(_ body: String, _ needles: [String]) -> Bool {
        needles.contains { body.contains($0) }
    }

    private func debugFileComponent(_ rawValue: String) -> String {
        rawValue.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_"
                ? String(scalar)
                : "-"
        }.joined()
    }

    private func runDownloadWorkflow(
        provider: CompiledProvider,
        request: DownloadResolveRequest,
        sessionKey: AuthSessionKey,
        authSession: AuthSession?
    ) async throws -> WorkflowRunResult {
        var runtime = WorkflowRuntime(
            provider: provider,
            workflow: provider.downloadWorkflow,
            request: request,
            httpClient: httpClient,
            capabilityRegistry: capabilityRegistry,
            sessionKey: sessionKey,
            authSession: authSession,
            materials: [:],
            authExpireConditions: provider.rule.authPolicy?.expireConditions ?? []
        )
        return try await runtime.run()
    }
}

private struct WorkflowRunResult {
    let emittedRequest: ResolvedDownloadRequest?
    let authSession: AuthSession?
    let authExpired: Bool
    let variables: [String: RuntimeValue]
}

private struct WorkflowRuntime {
    private let provider: CompiledProvider
    private let workflow: WorkflowDefinition
    private let request: DownloadResolveRequest
    private let httpClient: any HTTPClient
    private let capabilityRegistry: CapabilityRegistry
    private let sessionKey: AuthSessionKey
    private let materials: [String: RuntimeValue]
    private let authExpireConditions: [RuleCondition]

    private var authSession: AuthSession?
    private var variables: [String: RuntimeValue]
    private var emittedRequest: ResolvedDownloadRequest?

    init(
        provider: CompiledProvider,
        workflow: WorkflowDefinition,
        request: DownloadResolveRequest,
        httpClient: any HTTPClient,
        capabilityRegistry: CapabilityRegistry,
        sessionKey: AuthSessionKey,
        authSession: AuthSession?,
        materials: [String: RuntimeValue],
        authExpireConditions: [RuleCondition]
    ) {
        self.provider = provider
        self.workflow = workflow
        self.request = request
        self.httpClient = httpClient
        self.capabilityRegistry = capabilityRegistry
        self.sessionKey = sessionKey
        self.authSession = authSession
        self.materials = materials
        self.authExpireConditions = authExpireConditions

        var initialVariables = [String: RuntimeValue]()
        initialVariables["input"] = request.runtimeValue
        initialVariables["materials"] = .object(materials)
        initialVariables["provider"] = .object([
            "id": .string(provider.rule.id),
            "family": .string(provider.rule.providerFamily),
            "metadata": .object(provider.rule.metadata),
        ])
        initialVariables["auth"] = (authSession ?? AuthSession(key: sessionKey)).runtimeValue
        self.variables = initialVariables
    }

    mutating func run(from startIndex: Int = 0) async throws -> WorkflowRunResult {
        let clampedStartIndex = min(max(startIndex, 0), workflow.steps.count)
        try await execute(Array(workflow.steps.dropFirst(clampedStartIndex)))
        let authExpired = authExpireConditions.contains { evaluate($0) }
        return WorkflowRunResult(
            emittedRequest: emittedRequest,
            authSession: authSession,
            authExpired: authExpired,
            variables: variables
        )
    }

    private mutating func execute(_ steps: [WorkflowStep]) async throws {
        for step in steps {
            try Task.checkCancellation()
            switch step {
            case .http(let value):
                try await executeHTTP(value)
            case .extract(let value):
                try executeExtract(value)
            case .assign(let value):
                try executeAssign(value)
            case .template(let value):
                try executeTemplate(value)
            case .branch(let value):
                if evaluate(value.conditions, mode: value.mode) {
                    try await execute(value.ifSteps)
                } else {
                    try await execute(value.elseSteps)
                }
            case .loop(let value):
                var iteration = 0
                while iteration < value.maxIterations && evaluate(value.conditions, mode: value.mode) {
                    try Task.checkCancellation()
                    try await execute(value.steps)
                    iteration += 1
                }
            case .invokeCapability(let value):
                try await executeCapability(value)
            case .emitRequest(let value):
                try executeEmit(value)
            }
        }
    }

    private mutating func executeHTTP(_ step: HTTPStep) async throws {
        let urlString = try renderTemplate(step.urlTemplate, variables: variables)
        guard let url = URL(string: urlString) else {
            throw RuleEngineError.invalidTemplate("Invalid URL \(urlString)")
        }

        var headers = try step.headers.mapValues { try renderTemplate($0, variables: variables) }
        if step.attachAuthSession, let cookieHeader = authSession?.cookieHeader(for: url), !cookieHeader.isEmpty {
            headers["Cookie"] = cookieHeader
        }
        let body = try step.bodyTemplate.map { try renderTemplate($0, variables: variables) }
        let request = HTTPRequestData(
            method: step.method,
            url: url,
            headers: headers,
            body: body,
            followRedirects: step.followRedirects
        )
        let response = try await httpClient.send(request)

        if step.persistResponseCookies, !response.cookies.isEmpty {
            let session = (authSession ?? AuthSession(key: sessionKey)).merging(cookies: response.cookies)
            authSession = session
            variables["auth"] = session.runtimeValue
        }

        variables[step.output] = response.runtimeValue
        variables["lastRequest"] = request.runtimeValue
        variables["lastResponse"] = response.runtimeValue
    }

    private mutating func executeExtract(_ step: ExtractStep) throws {
        guard let source = lookup(path: step.source, in: variables) else {
            throw RuleEngineError.missingVariable(step.source)
        }
        let extracted: RuntimeValue
        switch step.kind {
        case .regexFirst:
            let text = try requiredString(from: source, name: step.source)
            guard let pattern = step.pattern else {
                throw RuleEngineError.invalidRule("regexFirst requires pattern")
            }
            let matches = try regexMatches(in: text, pattern: pattern, group: step.group ?? 1)
            extracted = matches.first.map(RuntimeValue.string) ?? .null
        case .regexAll:
            let text = try requiredString(from: source, name: step.source)
            guard let pattern = step.pattern else {
                throw RuleEngineError.invalidRule("regexAll requires pattern")
            }
            extracted = .array(try regexMatches(in: text, pattern: pattern, group: step.group ?? 1).map(RuntimeValue.string))
        case .jsonPath:
            guard let path = step.path else {
                throw RuleEngineError.invalidRule("jsonPath requires path")
            }
            let root = try jsonRoot(from: source)
            extracted = lookup(path: path, from: root) ?? .null
        case .responseHeader:
            guard let header = step.header else {
                throw RuleEngineError.invalidRule("responseHeader requires header")
            }
            let headers = source.objectValue?["headers"]?.objectValue ?? [:]
            let match = headers.first { $0.key.caseInsensitiveCompare(header) == .orderedSame }?.value
            extracted = match ?? .null
        case .responseStatus:
            extracted = source.objectValue?["statusCode"] ?? .null
        case .urlHost:
            let urlValue = try sourceURLString(from: source)
            extracted = URL(string: urlValue).flatMap { $0.host.map(RuntimeValue.string) } ?? .null
        case .urlPath:
            let urlValue = try sourceURLString(from: source)
            extracted = URL(string: urlValue).map { .string($0.path) } ?? .null
        case .bodyString:
            extracted = .string(source.objectValue?["body"]?.stringValue ?? source.renderedString())
        }
        variables[step.target] = extracted
    }

    private mutating func executeAssign(_ step: AssignStep) throws {
        let value: RuntimeValue
        if let source = step.source {
            guard let lookedUp = lookup(path: source, in: variables) else {
                throw RuleEngineError.missingVariable(source)
            }
            value = lookedUp
        } else {
            value = step.value ?? .null
        }

        switch step.storage {
        case .runtime:
            variables[step.target] = value
        case .authSession:
            let session = (authSession ?? AuthSession(key: sessionKey)).merging(values: [step.target: value])
            authSession = session
            variables["auth"] = session.runtimeValue
        }
    }

    private mutating func executeTemplate(_ step: TemplateStep) throws {
        variables[step.target] = .string(try renderTemplate(step.template, variables: variables))
    }

    private mutating func executeCapability(_ step: CapabilityStep) async throws {
        var arguments = step.arguments
        for (key, source) in step.bindings {
            try Task.checkCancellation()
            guard let value = lookup(path: source, in: variables) else {
                throw RuleEngineError.missingVariable(source)
            }
            arguments[key] = value
        }
        let invocation = CapabilityInvocation(
            providerFamily: provider.rule.providerFamily,
            arguments: arguments,
            variables: variables
        )
        let output = try await capabilityRegistry.invoke(step.capability, invocation: invocation)
        if let target = step.target {
            variables[target] = output
        }
    }

    private mutating func executeEmit(_ step: EmitRequestStep) throws {
        let urlString = try renderTemplate(step.urlTemplate, variables: variables)
        guard let url = URL(string: urlString) else {
            throw RuleEngineError.invalidTemplate("Invalid emitted request URL \(urlString)")
        }
        var headers = try step.headers.mapValues { try renderTemplate($0, variables: variables) }
        if step.attachAuthSession, let cookieHeader = authSession?.cookieHeader(for: url), !cookieHeader.isEmpty {
            headers["Cookie"] = cookieHeader
        }
        let body = try step.bodyTemplate.map { try renderTemplate($0, variables: variables) }
        emittedRequest = ResolvedDownloadRequest(
            method: step.method,
            url: url,
            headers: headers,
            body: body,
            cookies: step.attachAuthSession ? authSession?.cookies ?? [] : [],
            authContext: step.attachAuthSession ? authSession?.resolvedContext : nil,
            filenameHints: step.filenameHints,
            retryHints: step.retryHints
        )
    }

    private func evaluate(_ conditions: [RuleCondition], mode: LogicalMode) -> Bool {
        switch mode {
        case .all:
            return conditions.allSatisfy(evaluate)
        case .any:
            return conditions.contains(where: evaluate)
        }
    }

    private func evaluate(_ condition: RuleCondition) -> Bool {
        evaluateRuleCondition(condition, variables: variables)
    }
}

private func evaluateRuleCondition(_ condition: RuleCondition, variables: [String: RuntimeValue]) -> Bool {
    let value = lookup(path: condition.source, in: variables)
    switch condition.comparator {
    case .exists:
        return value != nil && value != .null
    case .missing:
        return value == nil || value == .null
    case .equals:
        guard let value, let expected = condition.expected else {
            return false
        }
        return value == expected || value.renderedString() == expected.renderedString()
    case .notEquals:
        guard let value, let expected = condition.expected else {
            return false
        }
        return value != expected && value.renderedString() != expected.renderedString()
    case .contains:
        guard let value, let expected = condition.expected?.renderedString() else {
            return false
        }
        return value.renderedString().contains(expected)
    case .matchesRegex:
        guard let value, let pattern = condition.expected?.renderedString() else {
            return false
        }
        return value.renderedString().range(of: pattern, options: .regularExpression) != nil
    case .anyOf:
        guard let value, let expectedValues = condition.expectedValues else {
            return false
        }
        return expectedValues.contains(value.renderedString())
    }
}

private func regexMatches(in text: String, pattern: String, group: Int) throws -> [String] {
    let regex = try NSRegularExpression(pattern: pattern)
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.matches(in: text, range: range).compactMap { match in
        let range = match.numberOfRanges > group ? match.range(at: group) : match.range
        guard let swiftRange = Range(range, in: text) else {
            return nil
        }
        return String(text[swiftRange])
    }
}

private func jsonRoot(from value: RuntimeValue) throws -> RuntimeValue {
    if case .object = value {
        return value
    }
    guard let string = value.stringValue,
          let data = string.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data),
          let runtime = RuntimeValue.from(jsonObject: object) else {
        throw RuleEngineError.invalidRule("Expected JSON-compatible value")
    }
    return runtime
}

private func requiredString(from value: RuntimeValue, name: String) throws -> String {
    if let string = value.stringValue {
        return string
    }
    if let object = value.objectValue, let body = object["body"]?.stringValue {
        return body
    }
    throw RuleEngineError.invalidRule("Expected string-like source for \(name)")
}

private func sourceURLString(from value: RuntimeValue) throws -> String {
    if let string = value.stringValue {
        return string
    }
    if let object = value.objectValue, let url = object["url"]?.stringValue {
        return url
    }
    throw RuleEngineError.invalidRule("Expected URL-like value")
}

private func renderTemplate(_ template: String, variables: [String: RuntimeValue]) throws -> String {
    let regex = try NSRegularExpression(pattern: #"\{\{\s*([A-Za-z0-9_\.]+)\s*\}\}"#)
    let range = NSRange(template.startIndex..<template.endIndex, in: template)
    let matches = regex.matches(in: template, range: range)
    var rendered = template
    for match in matches.reversed() {
        guard match.numberOfRanges > 1,
              let tokenRange = Range(match.range(at: 1), in: template),
              let fullRange = Range(match.range(at: 0), in: rendered) else {
            continue
        }
        let token = String(template[tokenRange])
        guard let value = lookup(path: token, in: variables) else {
            throw RuleEngineError.missingVariable(token)
        }
        rendered.replaceSubrange(fullRange, with: value.renderedString())
    }
    return rendered
}

private func lookup(path: String, in variables: [String: RuntimeValue]) -> RuntimeValue? {
    let parts = path.split(separator: ".").map(String.init)
    guard let first = parts.first, let root = variables[first] else {
        return nil
    }
    return lookup(path: Array(parts.dropFirst()), from: root)
}

private func lookup(path: [String], from root: RuntimeValue) -> RuntimeValue? {
    guard !path.isEmpty else {
        return root
    }

    var current = root
    for segment in path {
        if let index = Int(segment), let array = current.arrayValue, array.indices.contains(index) {
            current = array[index]
            continue
        }
        guard let object = current.objectValue, let next = object[segment] else {
            return nil
        }
        current = next
    }
    return current
}
