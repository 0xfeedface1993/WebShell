import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct RuleBundleSnapshot: Codable, Sendable, Equatable {
    public enum Origin: String, Codable, Sendable {
        case remote
        case local
        case bundled
    }

    public let bundle: RuleBundle
    public let activatedAt: Date
    public let origin: Origin

    public init(bundle: RuleBundle, activatedAt: Date = Date(), origin: Origin) {
        self.bundle = bundle
        self.activatedAt = activatedAt
        self.origin = origin
    }
}

public protocol RuleBundleRemoteSource: Sendable {
    func fetchRuleBundle() async throws -> RuleBundle
}

public protocol RuleBundleStore: Sendable {
    func load() async throws -> RuleBundleSnapshot?
    func save(_ snapshot: RuleBundleSnapshot) async throws
}

public protocol HTTPClient: Sendable {
    func send(_ request: HTTPRequestData) async throws -> HTTPResponseData
}

public actor URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let noRedirectSession: URLSession
    private let noRedirectDelegate: NoRedirectURLSessionDelegate
    private let cookieStorage: HTTPCookieStorage?

    public init(configuration: URLSessionConfiguration = .ephemeral) {
        self.cookieStorage = configuration.httpCookieStorage
        self.session = URLSession(configuration: configuration)
        self.noRedirectDelegate = NoRedirectURLSessionDelegate()
        self.noRedirectSession = URLSession(
            configuration: configuration,
            delegate: noRedirectDelegate,
            delegateQueue: nil
        )
    }

    public func send(_ request: HTTPRequestData) async throws -> HTTPResponseData {
        let urlRequest = request.asURLRequest()
        let activeSession = request.followRedirects ? session : noRedirectSession
        let (data, response) = try await activeSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RuleEngineError.httpFailure("Expected HTTPURLResponse for \(request.url.absoluteString)")
        }

        let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, item in
            result[String(describing: item.key)] = String(describing: item.value)
        }
        let responseCookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: request.url)
            .map(SerializableCookie.init)
        let storedCookies = Self.storedCookies(
            from: cookieStorage,
            requestURL: request.url,
            responseURL: httpResponse.url
        )
        let cookies = Self.mergeCookies(responseCookies + storedCookies)
        let body = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return HTTPResponseData(
            statusCode: httpResponse.statusCode,
            url: httpResponse.url ?? request.url,
            headers: headers,
            body: body,
            bodyBase64: data.base64EncodedString(),
            cookies: cookies
        )
    }

    private static func storedCookies(
        from cookieStorage: HTTPCookieStorage?,
        requestURL: URL,
        responseURL: URL?
    ) -> [SerializableCookie] {
        guard let cookieStorage else {
            return []
        }

        var urls = [requestURL]
        if let responseURL, responseURL != requestURL {
            urls.append(responseURL)
        }

        return urls.flatMap { url in
            cookieStorage.cookies(for: url) ?? []
        }
        .map(SerializableCookie.init)
    }

    private static func mergeCookies(_ cookies: [SerializableCookie]) -> [SerializableCookie] {
        var merged = [CookieIdentity: SerializableCookie]()
        for cookie in cookies {
            merged[CookieIdentity(cookie)] = cookie
        }
        return merged.values.sorted { lhs, rhs in
            lhs.name == rhs.name ? lhs.domain < rhs.domain : lhs.name < rhs.name
        }
    }
}

private final class NoRedirectURLSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
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

public struct StaticRuleBundleRemoteSource: RuleBundleRemoteSource {
    public let bundle: RuleBundle

    public init(bundle: RuleBundle) {
        self.bundle = bundle
    }

    public func fetchRuleBundle() async throws -> RuleBundle {
        bundle
    }
}

public actor InMemoryRuleBundleStore: RuleBundleStore {
    private var snapshot: RuleBundleSnapshot?

    public init() { }

    public func load() async throws -> RuleBundleSnapshot? {
        snapshot
    }

    public func save(_ snapshot: RuleBundleSnapshot) async throws {
        self.snapshot = snapshot
    }
}

public actor FileRuleBundleStore: RuleBundleStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func load() async throws -> RuleBundleSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(RuleBundleSnapshot.self, from: data)
    }

    public func save(_ snapshot: RuleBundleSnapshot) async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }
}

public actor RuleCatalog {
    private var snapshot: RuleBundleSnapshot?
    private var compiledBundle: CompiledRuleBundle?

    public init() { }

    func activate(snapshot: RuleBundleSnapshot, compiled: CompiledRuleBundle) {
        self.snapshot = snapshot
        self.compiledBundle = compiled
    }

    func currentCompiledBundle() -> CompiledRuleBundle? {
        compiledBundle
    }

    public func currentSnapshot() -> RuleBundleSnapshot? {
        snapshot
    }
}

public struct ConfigSyncClient: Sendable {
    private let remoteSource: any RuleBundleRemoteSource
    private let store: any RuleBundleStore
    private let catalog: RuleCatalog
    private let compiler: RuleCompiler
    private let capabilityRegistry: CapabilityRegistry
    private let remoteOrigin: RuleBundleSnapshot.Origin

    public init(
        remoteSource: any RuleBundleRemoteSource,
        store: any RuleBundleStore,
        catalog: RuleCatalog,
        compiler: RuleCompiler = .init(),
        capabilityRegistry: CapabilityRegistry,
        remoteOrigin: RuleBundleSnapshot.Origin = .remote
    ) {
        self.remoteSource = remoteSource
        self.store = store
        self.catalog = catalog
        self.compiler = compiler
        self.capabilityRegistry = capabilityRegistry
        self.remoteOrigin = remoteOrigin
    }

    public func sync() async throws -> RuleBundleSnapshot {
        let bundle = try await remoteSource.fetchRuleBundle()
        let snapshot = RuleBundleSnapshot(bundle: bundle, activatedAt: Date(), origin: remoteOrigin)
        let previous = await catalog.currentCompiledBundle()
        let compiled = try await compiler.compile(
            snapshot: snapshot,
            previous: previous,
            capabilityRegistry: capabilityRegistry
        )
        try await store.save(snapshot)
        await catalog.activate(snapshot: snapshot, compiled: compiled)
        return snapshot
    }

    public func activateStoredSnapshot() async throws -> RuleBundleSnapshot? {
        guard let snapshot = try await store.load() else {
            return nil
        }
        let previous = await catalog.currentCompiledBundle()
        let compiled = try await compiler.compile(
            snapshot: snapshot,
            previous: previous,
            capabilityRegistry: capabilityRegistry
        )
        await catalog.activate(snapshot: snapshot, compiled: compiled)
        return snapshot
    }
}
