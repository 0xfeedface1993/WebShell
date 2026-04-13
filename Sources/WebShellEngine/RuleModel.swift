import Foundation

public struct RuleBundle: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let bundleVersion: String
    public let providers: [ProviderRule]
    public let sharedFragments: [WorkflowDefinition]
    public let authWorkflows: [WorkflowDefinition]
    public let downloadWorkflows: [WorkflowDefinition]
    public let capabilityRefs: [CapabilityReference]
}

public extension RuleBundle {
    static let supportedSchemaVersion = 1
}

public struct CapabilityReference: Codable, Sendable, Equatable {
    public let name: String
    public let required: Bool
}

public struct WorkflowDefinition: Codable, Sendable, Equatable {
    public let id: String
    public let description: String?
    public let steps: [WorkflowStep]
}

public struct ProviderRule: Codable, Sendable, Equatable {
    public let id: String
    public let providerFamily: String
    public let matchers: [URLMatcher]
    public let accountScope: AccountScope
    public let downloadWorkflowID: String
    public let authWorkflowID: String?
    public let authPolicy: AuthPolicy?
    public let metadata: [String: RuntimeValue]
}

public enum AccountScope: String, Codable, Sendable {
    case providerFamily
    case host
    case explicitGroup
}

public struct URLMatcher: Codable, Sendable, Equatable {
    public let hosts: [String]
    public let hostSuffixes: [String]
    public let pathPattern: String?

    func matches(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }

        let normalizedHosts = Set(hosts.map { $0.lowercased() })
        let normalizedSuffixes = hostSuffixes.map { $0.lowercased() }
        let matchesHost = normalizedHosts.contains(host)
        let matchesSuffix = normalizedSuffixes.contains { suffix in
            host == suffix || host.hasSuffix("." + suffix)
        }
        guard matchesHost || matchesSuffix else {
            return false
        }

        guard let pathPattern else {
            return true
        }
        return url.path.range(of: pathPattern, options: .regularExpression) != nil
    }

    func conflictKeys() -> [String] {
        let exact = hosts.map { "host:\($0.lowercased())|path:\(pathPattern ?? "*")" }
        let suffix = hostSuffixes.map { "suffix:\($0.lowercased())|path:\(pathPattern ?? "*")" }
        return exact + suffix
    }
}

public struct AuthPolicy: Codable, Sendable, Equatable {
    public let requiresAuthentication: Bool
    public let expireConditions: [RuleCondition]
    public let materialKeys: [String]
    public let accountIDTemplate: String?
    public let captchaRetryPolicy: CaptchaRetryPolicy?
    public let successConditions: [RuleCondition]?
    public let credentialRejectConditions: [RuleCondition]?
    public let captchaRejectConditions: [RuleCondition]?
}

public struct CaptchaRetryPolicy: Codable, Sendable, Equatable {
    public let mode: CaptchaRetryMode
    public let maxAttempts: Int?
    public let startAtOutput: String?
}

public enum CaptchaRetryMode: String, Codable, Sendable {
    case fullWorkflow
    case refreshCaptcha
}

public struct RuleCondition: Codable, Sendable, Equatable {
    public enum Comparator: String, Codable, Sendable {
        case exists
        case missing
        case equals
        case notEquals
        case contains
        case matchesRegex
        case anyOf
    }

    public let source: String
    public let comparator: Comparator
    public let expected: RuntimeValue?
    public let expectedValues: [String]?
}

public enum LogicalMode: String, Codable, Sendable {
    case all
    case any
}

public enum AssignStorage: String, Codable, Sendable {
    case runtime
    case authSession
}

public struct HTTPStep: Codable, Sendable, Equatable {
    public let output: String
    public let method: HTTPMethod
    public let urlTemplate: String
    public let headers: [String: String]
    public let bodyTemplate: String?
    public let attachAuthSession: Bool
    public let persistResponseCookies: Bool
    public let followRedirects: Bool

    private enum CodingKeys: String, CodingKey {
        case output
        case method
        case urlTemplate
        case headers
        case bodyTemplate
        case attachAuthSession
        case persistResponseCookies
        case followRedirects
    }

    public init(
        output: String,
        method: HTTPMethod,
        urlTemplate: String,
        headers: [String: String],
        bodyTemplate: String?,
        attachAuthSession: Bool,
        persistResponseCookies: Bool,
        followRedirects: Bool = true
    ) {
        self.output = output
        self.method = method
        self.urlTemplate = urlTemplate
        self.headers = headers
        self.bodyTemplate = bodyTemplate
        self.attachAuthSession = attachAuthSession
        self.persistResponseCookies = persistResponseCookies
        self.followRedirects = followRedirects
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.output = try container.decode(String.self, forKey: .output)
        self.method = try container.decode(HTTPMethod.self, forKey: .method)
        self.urlTemplate = try container.decode(String.self, forKey: .urlTemplate)
        self.headers = try container.decode([String: String].self, forKey: .headers)
        self.bodyTemplate = try container.decodeIfPresent(String.self, forKey: .bodyTemplate)
        self.attachAuthSession = try container.decode(Bool.self, forKey: .attachAuthSession)
        self.persistResponseCookies = try container.decode(Bool.self, forKey: .persistResponseCookies)
        self.followRedirects = try container.decodeIfPresent(Bool.self, forKey: .followRedirects) ?? true
    }
}

public struct ExtractStep: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case regexFirst
        case regexAll
        case jsonPath
        case responseHeader
        case responseStatus
        case urlHost
        case urlPath
        case bodyString
    }

    public let kind: Kind
    public let source: String
    public let target: String
    public let pattern: String?
    public let group: Int?
    public let path: [String]?
    public let header: String?
}

public struct AssignStep: Codable, Sendable, Equatable {
    public let target: String
    public let source: String?
    public let value: RuntimeValue?
    public let storage: AssignStorage
}

public struct TemplateStep: Codable, Sendable, Equatable {
    public let target: String
    public let template: String
}

public struct BranchStep: Codable, Sendable, Equatable {
    public let mode: LogicalMode
    public let conditions: [RuleCondition]
    public let ifSteps: [WorkflowStep]
    public let elseSteps: [WorkflowStep]
}

public struct LoopStep: Codable, Sendable, Equatable {
    public let mode: LogicalMode
    public let conditions: [RuleCondition]
    public let maxIterations: Int
    public let steps: [WorkflowStep]
}

public struct CapabilityStep: Codable, Sendable, Equatable {
    public let capability: String
    public let arguments: [String: RuntimeValue]
    public let bindings: [String: String]
    public let target: String?
}

public struct EmitRequestStep: Codable, Sendable, Equatable {
    public let method: HTTPMethod
    public let urlTemplate: String
    public let headers: [String: String]
    public let bodyTemplate: String?
    public let attachAuthSession: Bool
    public let filenameHints: [String: String]
    public let retryHints: RetryHints
}

public enum WorkflowStep: Sendable, Equatable {
    case http(HTTPStep)
    case extract(ExtractStep)
    case assign(AssignStep)
    case template(TemplateStep)
    case branch(BranchStep)
    case loop(LoopStep)
    case invokeCapability(CapabilityStep)
    case emitRequest(EmitRequestStep)
}

extension WorkflowStep: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case http
        case extract
        case assign
        case template
        case branch
        case loop
        case invokeCapability
        case emitRequest
    }

    private enum Kind: String, Codable {
        case http
        case extract
        case assign
        case template
        case branch
        case loop
        case invokeCapability
        case emitRequest
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
        case .http:
            self = .http(try container.decode(HTTPStep.self, forKey: .http))
        case .extract:
            self = .extract(try container.decode(ExtractStep.self, forKey: .extract))
        case .assign:
            self = .assign(try container.decode(AssignStep.self, forKey: .assign))
        case .template:
            self = .template(try container.decode(TemplateStep.self, forKey: .template))
        case .branch:
            self = .branch(try container.decode(BranchStep.self, forKey: .branch))
        case .loop:
            self = .loop(try container.decode(LoopStep.self, forKey: .loop))
        case .invokeCapability:
            self = .invokeCapability(try container.decode(CapabilityStep.self, forKey: .invokeCapability))
        case .emitRequest:
            self = .emitRequest(try container.decode(EmitRequestStep.self, forKey: .emitRequest))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .http(let value):
            try container.encode(Kind.http, forKey: .type)
            try container.encode(value, forKey: .http)
        case .extract(let value):
            try container.encode(Kind.extract, forKey: .type)
            try container.encode(value, forKey: .extract)
        case .assign(let value):
            try container.encode(Kind.assign, forKey: .type)
            try container.encode(value, forKey: .assign)
        case .template(let value):
            try container.encode(Kind.template, forKey: .type)
            try container.encode(value, forKey: .template)
        case .branch(let value):
            try container.encode(Kind.branch, forKey: .type)
            try container.encode(value, forKey: .branch)
        case .loop(let value):
            try container.encode(Kind.loop, forKey: .type)
            try container.encode(value, forKey: .loop)
        case .invokeCapability(let value):
            try container.encode(Kind.invokeCapability, forKey: .type)
            try container.encode(value, forKey: .invokeCapability)
        case .emitRequest(let value):
            try container.encode(Kind.emitRequest, forKey: .type)
            try container.encode(value, forKey: .emitRequest)
        }
    }
}
