import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum RuleEngineError: LocalizedError, Sendable {
    case missingActiveBundle
    case noMatchingProvider(String)
    case invalidRule(String)
    case missingWorkflow(String)
    /// Thrown when a workflow id is declared in more than one of
    /// `downloadWorkflows` / `authWorkflows` / `sharedFragments`.
    /// Compilation only enforces uniqueness within each list, so
    /// this check lives on direct-lookup paths like
    /// `DownloadResolver.runWorkflow(workflowID:)`.
    case ambiguousWorkflow(String)
    case missingCapability(String)
    case missingVariable(String)
    case invalidTemplate(String)
    case noEmittedRequest(String)
    case authMaterialUnavailable(String)
    case authWorkflowRequired(String)
    case authDidNotProduceSession(String)
    case authExpiredAfterRetry(String)
    case httpFailure(String)
    case authCaptchaRejected(String)
    case authCaptchaRetryLimitExceeded(String, Int)
    case authCredentialsRejected(String)

    public var errorDescription: String? {
        switch self {
        case .missingActiveBundle:
            return "No active rule bundle has been activated."
        case .noMatchingProvider(let value):
            return "No provider rule matched \(value)."
        case .invalidRule(let value):
            return "Invalid rule bundle: \(value)"
        case .missingWorkflow(let value):
            return "Missing workflow: \(value)"
        case .ambiguousWorkflow(let value):
            return "Workflow id \(value) is declared in more than one of downloadWorkflows / authWorkflows / sharedFragments."
        case .missingCapability(let value):
            return "Missing capability: \(value)"
        case .missingVariable(let value):
            return "Missing variable: \(value)"
        case .invalidTemplate(let value):
            return "Invalid template: \(value)"
        case .noEmittedRequest(let value):
            return "Workflow did not emit a request: \(value)"
        case .authMaterialUnavailable(let value):
            return "Auth material unavailable: \(value)"
        case .authWorkflowRequired(let value):
            return "Provider requires an auth workflow: \(value)"
        case .authDidNotProduceSession(let value):
            return "Auth workflow did not produce a reusable session: \(value)"
        case .authCaptchaRejected(let value):
            return "Auth captcha was rejected by provider: \(value)"
        case .authCaptchaRetryLimitExceeded(let value, let attempts):
            return "Auth captcha retry limit exceeded after \(attempts) attempts: \(value)"
        case .authCredentialsRejected(let value):
            return "Auth credentials were rejected by provider: \(value)"
        case .authExpiredAfterRetry(let value):
            return "Auth expired again after retry: \(value)"
        case .httpFailure(let value):
            return "HTTP failure: \(value)"
        }
    }
}

public enum RuntimeValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: RuntimeValue])
    case array([RuntimeValue])
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .number(Double(value))
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([RuntimeValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: RuntimeValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported RuntimeValue payload")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    public var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .null:
            return nil
        case .array, .object:
            return nil
        }
    }

    public var objectValue: [String: RuntimeValue]? {
        guard case .object(let value) = self else {
            return nil
        }
        return value
    }

    public var arrayValue: [RuntimeValue]? {
        guard case .array(let value) = self else {
            return nil
        }
        return value
    }

    public var boolValue: Bool? {
        switch self {
        case .bool(let value):
            return value
        case .string(let value):
            return Bool(value)
        default:
            return nil
        }
    }

    public func renderedString() -> String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .null:
            return ""
        case .array(let value):
            return value.map { $0.renderedString() }.joined(separator: ",")
        case .object(let value):
            let data = try? JSONEncoder().encode(value)
            return data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        }
    }

    static func from(jsonObject: Any) -> RuntimeValue? {
        switch jsonObject {
        case let value as String:
            return .string(value)
        case let value as Bool:
            return .bool(value)
        case let value as Int:
            return .number(Double(value))
        case let value as Double:
            return .number(value)
        case let value as NSNumber:
            return .number(value.doubleValue)
        case let value as [String: Any]:
            let mapped = value.compactMapValues { RuntimeValue.from(jsonObject: $0) }
            return .object(mapped)
        case let value as [Any]:
            return .array(value.compactMap(RuntimeValue.from(jsonObject:)))
        case _ as NSNull:
            return .null
        default:
            return nil
        }
    }
}

public struct SerializableCookie: Codable, Sendable, Equatable, Hashable {
    public let name: String
    public let value: String
    public let domain: String
    public let path: String
    public let expiresAt: Date?
    public let secure: Bool
    public let httpOnly: Bool

    public init(
        name: String,
        value: String,
        domain: String,
        path: String = "/",
        expiresAt: Date? = nil,
        secure: Bool = false,
        httpOnly: Bool = false
    ) {
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.expiresAt = expiresAt
        self.secure = secure
        self.httpOnly = httpOnly
    }

    public init(_ cookie: HTTPCookie) {
        self.init(
            name: cookie.name,
            value: cookie.value,
            domain: cookie.domain,
            path: cookie.path,
            expiresAt: cookie.expiresDate,
            secure: cookie.isSecure,
            httpOnly: false
        )
    }

    public func matches(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }
        let normalizedDomain = domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let hostMatches = host == normalizedDomain || host.hasSuffix("." + normalizedDomain)
        guard hostMatches else {
            return false
        }

        let pathMatches = url.path.hasPrefix(path)
        let notExpired = expiresAt.map { $0 > Date() } ?? true
        return pathMatches && notExpired
    }

    public var headerValue: String {
        "\(name)=\(value)"
    }

    var runtimeValue: RuntimeValue {
        .object([
            "name": .string(name),
            "value": .string(value),
            "domain": .string(domain),
            "path": .string(path),
            "secure": .bool(secure),
            "httpOnly": .bool(httpOnly),
            "expiresAt": expiresAt.map { .string(ISO8601DateFormatter().string(from: $0)) } ?? .null,
        ])
    }
}

public enum HTTPMethod: String, Codable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
}

public struct HTTPRequestData: Codable, Sendable, Equatable {
    public let method: HTTPMethod
    public let url: URL
    public let headers: [String: String]
    public let body: String?
    public let followRedirects: Bool

    private enum CodingKeys: String, CodingKey {
        case method
        case url
        case headers
        case body
        case followRedirects
    }

    public init(
        method: HTTPMethod,
        url: URL,
        headers: [String: String] = [:],
        body: String? = nil,
        followRedirects: Bool = true
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.followRedirects = followRedirects
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.method = try container.decode(HTTPMethod.self, forKey: .method)
        self.url = try container.decode(URL.self, forKey: .url)
        self.headers = try container.decode([String: String].self, forKey: .headers)
        self.body = try container.decodeIfPresent(String.self, forKey: .body)
        self.followRedirects = try container.decodeIfPresent(Bool.self, forKey: .followRedirects) ?? true
    }
}

public struct HTTPResponseData: Codable, Sendable, Equatable {
    public let statusCode: Int
    public let url: URL
    public let headers: [String: String]
    public let body: String
    public let bodyBase64: String?
    public let cookies: [SerializableCookie]

    public init(
        statusCode: Int,
        url: URL,
        headers: [String: String] = [:],
        body: String,
        bodyBase64: String? = nil,
        cookies: [SerializableCookie] = []
    ) {
        self.statusCode = statusCode
        self.url = url
        self.headers = headers
        self.body = body
        self.bodyBase64 = bodyBase64
        self.cookies = cookies
    }
}

public struct RetryHints: Codable, Sendable, Equatable {
    public let maxAttempts: Int
    public let backoffSeconds: Int
    public let retryableStatusCodes: [Int]

    public init(maxAttempts: Int = 1, backoffSeconds: Int = 0, retryableStatusCodes: [Int] = []) {
        self.maxAttempts = maxAttempts
        self.backoffSeconds = backoffSeconds
        self.retryableStatusCodes = retryableStatusCodes
    }
}

public struct DownloadResolveRequest: Codable, Sendable, Equatable {
    public let sourceURL: URL
    public let accountID: String?
    public let variables: [String: RuntimeValue]

    public init(sourceURL: URL, accountID: String? = nil, variables: [String: RuntimeValue] = [:]) {
        self.sourceURL = sourceURL
        self.accountID = accountID
        self.variables = variables
    }
}

public struct ResolvedAuthContext: Codable, Sendable, Equatable {
    public let providerFamily: String
    public let accountID: String
    public let updatedAt: Date
    public let sessionValues: [String: RuntimeValue]

    public init(providerFamily: String, accountID: String, updatedAt: Date, sessionValues: [String: RuntimeValue]) {
        self.providerFamily = providerFamily
        self.accountID = accountID
        self.updatedAt = updatedAt
        self.sessionValues = sessionValues
    }
}

public struct ResolvedDownloadRequest: Codable, Sendable, Equatable {
    public let method: HTTPMethod
    public let url: URL
    public let headers: [String: String]
    public let body: String?
    public let cookies: [SerializableCookie]
    public let authContext: ResolvedAuthContext?
    public let filenameHints: [String: String]
    public let retryHints: RetryHints

    public init(
        method: HTTPMethod,
        url: URL,
        headers: [String: String] = [:],
        body: String? = nil,
        cookies: [SerializableCookie] = [],
        authContext: ResolvedAuthContext? = nil,
        filenameHints: [String: String] = [:],
        retryHints: RetryHints = .init()
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.cookies = cookies
        self.authContext = authContext
        self.filenameHints = filenameHints
        self.retryHints = retryHints
    }
}

public struct AuthSessionKey: Hashable, Codable, Sendable {
    public let providerFamily: String
    public let accountID: String

    public init(providerFamily: String, accountID: String) {
        self.providerFamily = providerFamily
        self.accountID = accountID
    }
}

public struct AuthSession: Codable, Sendable, Equatable {
    public let key: AuthSessionKey
    public let cookies: [SerializableCookie]
    public let values: [String: RuntimeValue]
    public let updatedAt: Date

    public init(
        key: AuthSessionKey,
        cookies: [SerializableCookie] = [],
        values: [String: RuntimeValue] = [:],
        updatedAt: Date = Date()
    ) {
        self.key = key
        self.cookies = cookies
        self.values = values
        self.updatedAt = updatedAt
    }

    public var isEmpty: Bool {
        cookies.isEmpty && values.isEmpty
    }

    public func cookieHeader(for url: URL) -> String? {
        let matched = cookies.filter { $0.matches(url: url) }
        guard !matched.isEmpty else {
            return nil
        }
        return matched.map(\.headerValue).joined(separator: "; ")
    }

    public func merging(
        cookies newCookies: [SerializableCookie] = [],
        values newValues: [String: RuntimeValue] = [:]
    ) -> AuthSession {
        var mergedCookies = [CookieIdentity: SerializableCookie]()
        for cookie in cookies {
            mergedCookies[CookieIdentity(cookie)] = cookie
        }
        for cookie in newCookies {
            mergedCookies[CookieIdentity(cookie)] = cookie
        }

        var mergedValues = values
        for (key, value) in newValues {
            mergedValues[key] = value
        }

        return AuthSession(
            key: key,
            cookies: Array(mergedCookies.values).sorted { lhs, rhs in
                lhs.name == rhs.name ? lhs.domain < rhs.domain : lhs.name < rhs.name
            },
            values: mergedValues,
            updatedAt: Date()
        )
    }

    public var resolvedContext: ResolvedAuthContext {
        ResolvedAuthContext(
            providerFamily: key.providerFamily,
            accountID: key.accountID,
            updatedAt: updatedAt,
            sessionValues: values
        )
    }

    var runtimeValue: RuntimeValue {
        .object([
            "providerFamily": .string(key.providerFamily),
            "accountID": .string(key.accountID),
            "updatedAt": .string(ISO8601DateFormatter().string(from: updatedAt)),
            "values": .object(values),
            "cookies": .array(cookies.map(\.runtimeValue)),
        ])
    }
}

private struct CookieIdentity: Hashable {
    let name: String
    let domain: String
    let path: String

    init(_ cookie: SerializableCookie) {
        self.name = cookie.name.lowercased()
        self.domain = cookie.domain.lowercased()
        self.path = cookie.path
    }
}

extension HTTPRequestData {
    func asURLRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = headers
        request.httpBody = body?.data(using: .utf8)
        return request
    }

    var runtimeValue: RuntimeValue {
        .object([
            "method": .string(method.rawValue),
            "url": .string(url.absoluteString),
            "headers": .object(headers.mapValues(RuntimeValue.string)),
            "body": body.map(RuntimeValue.string) ?? .null,
            "followRedirects": .bool(followRedirects),
        ])
    }
}

extension HTTPResponseData {
    var runtimeValue: RuntimeValue {
        .object([
            "statusCode": .number(Double(statusCode)),
            "url": .string(url.absoluteString),
            "headers": .object(headers.mapValues(RuntimeValue.string)),
            "body": .string(body),
            "bodyBase64": bodyBase64.map(RuntimeValue.string) ?? .null,
            "cookies": .array(cookies.map(\.runtimeValue)),
        ])
    }
}

extension DownloadResolveRequest {
    var runtimeValue: RuntimeValue {
        .object([
            "sourceURL": .string(sourceURL.absoluteString),
            "accountID": accountID.map(RuntimeValue.string) ?? .null,
            "variables": .object(variables),
        ])
    }
}
