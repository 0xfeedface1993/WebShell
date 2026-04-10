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
}

struct CompiledRuleBundle: Sendable {
    let snapshot: RuleBundleSnapshot
    let providers: [CompiledProvider]

    func provider(matching url: URL) -> CompiledProvider? {
        providers.first { $0.matches(url) }
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
            guard families.insert(provider.providerFamily).inserted else {
                throw RuleEngineError.invalidRule("Duplicate providerFamily \(provider.providerFamily)")
            }
            for matcher in provider.matchers {
                for key in matcher.conflictKeys() {
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

        if provider.rule.authPolicy?.requiresAuthentication == true && session == nil {
            session = try await authenticate(provider: provider, request: request, sessionKey: sessionKey, existingSession: session)
        }

        let firstRun = try await runDownloadWorkflow(provider: provider, request: request, sessionKey: sessionKey, authSession: session)
        if let session = firstRun.authSession, !session.isEmpty {
            await authSessionStore.store(session)
        }

        if firstRun.authExpired {
            session = try await authenticate(provider: provider, request: request, sessionKey: sessionKey, existingSession: firstRun.authSession)
            let secondRun = try await runDownloadWorkflow(provider: provider, request: request, sessionKey: sessionKey, authSession: session)
            if let session = secondRun.authSession, !session.isEmpty {
                await authSessionStore.store(session)
            }
            guard !secondRun.authExpired else {
                throw RuleEngineError.authExpiredAfterRetry(provider.rule.providerFamily)
            }
            guard let resolved = secondRun.emittedRequest else {
                throw RuleEngineError.noEmittedRequest(provider.rule.providerFamily)
            }
            return resolved
        }

        guard let resolved = firstRun.emittedRequest else {
            throw RuleEngineError.noEmittedRequest(provider.rule.providerFamily)
        }
        return resolved
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

    private func authenticate(
        provider: CompiledProvider,
        request: DownloadResolveRequest,
        sessionKey: AuthSessionKey,
        existingSession: AuthSession?
    ) async throws -> AuthSession {
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

        var runtime = WorkflowRuntime(
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
        let result = try await runtime.run()
        guard let session = result.authSession, !session.isEmpty else {
            throw RuleEngineError.authDidNotProduceSession(provider.rule.providerFamily)
        }
        await authSessionStore.store(session)
        return session
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

    mutating func run() async throws -> WorkflowRunResult {
        try await execute(workflow.steps)
        let authExpired = authExpireConditions.contains { evaluate($0) }
        return WorkflowRunResult(
            emittedRequest: emittedRequest,
            authSession: authSession,
            authExpired: authExpired
        )
    }

    private mutating func execute(_ steps: [WorkflowStep]) async throws {
        for step in steps {
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
        let request = HTTPRequestData(method: step.method, url: url, headers: headers, body: body)
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
