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

    public init(configuration: URLSessionConfiguration = .ephemeral) {
        self.session = URLSession(configuration: configuration)
    }

    public func send(_ request: HTTPRequestData) async throws -> HTTPResponseData {
        let urlRequest = request.asURLRequest()
        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RuleEngineError.httpFailure("Expected HTTPURLResponse for \(request.url.absoluteString)")
        }

        let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, item in
            result[String(describing: item.key)] = String(describing: item.value)
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: request.url).map(SerializableCookie.init)
        let body = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return HTTPResponseData(
            statusCode: httpResponse.statusCode,
            url: httpResponse.url ?? request.url,
            headers: headers,
            body: body,
            cookies: cookies
        )
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
