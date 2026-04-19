import XCTest
@testable import WebShell

private struct StubHTTPClient: HTTPClient {
    let handler: @Sendable (HTTPRequestData) async throws -> HTTPResponseData

    func send(_ request: HTTPRequestData) async throws -> HTTPResponseData {
        try await handler(request)
    }
}

private actor MaterialCounter {
    private var value = 0

    func increment() {
        value += 1
    }

    func current() -> Int {
        value
    }
}

private struct CountingAuthMaterialProvider: AuthMaterialProvider {
    let counter: MaterialCounter

    func materials(for request: AuthMaterialRequest) async throws -> [String: RuntimeValue] {
        await counter.increment()
        return [
            "username": .string("demo-user"),
            "password": .string("secret-password"),
        ]
    }
}

private actor CaptchaRetryRecorder {
    private let values: [String]
    private var captchaIndex = 0
    private var captchaFetches = 0
    private var loginPageFetches = 0
    private var loginBodies: [String] = []

    init(values: [String]) {
        self.values = values
    }

    func nextCaptcha() -> String {
        guard !values.isEmpty else {
            return ""
        }
        let index = min(captchaIndex, max(values.count - 1, 0))
        captchaIndex += 1
        return values[index]
    }

    func recordLoginBody(_ body: String?) {
        loginBodies.append(body ?? "")
    }

    func recordCaptchaFetch() {
        captchaFetches += 1
    }

    func captchaFetchCount() -> Int {
        captchaFetches
    }

    func recordLoginPageFetch() {
        loginPageFetches += 1
    }

    func loginPageFetchCount() -> Int {
        loginPageFetches
    }

    func loginAttemptCount() -> Int {
        loginBodies.count
    }
}

final class DownloadResolverTests: XCTestCase {
    private func makeLegacySitesBundle() throws -> RuleBundle {
        try RuleBundleFixtures.loadMergedBundle(
            named: [
                "legacy-sites.bundle",
            ],
            bundleVersion: "2026.04.11.legacy-sites.1"
        )
    }

    private func makeSyncedCatalog(
        bundle: RuleBundle = RuleBundleFixtures.defaultBundle
    ) async throws -> (CapabilityRegistry, RuleCatalog) {
        let registry = CapabilityRegistry.standard()
        let store = InMemoryRuleBundleStore()
        let catalog = RuleCatalog()
        let client = ConfigSyncClient(
            remoteSource: StaticRuleBundleRemoteSource(bundle: bundle),
            store: store,
            catalog: catalog,
            compiler: RuleCompiler(),
            capabilityRegistry: registry
        )
        _ = try await client.sync()
        return (registry, catalog)
    }

    func testRosefileProviderResolvesDirectDownloadRequest() async throws {
        let (registry, catalog) = try await makeSyncedCatalog(bundle: try makeLegacySitesBundle())

        let httpClient = StubHTTPClient { request in
            if request.url.host?.contains("rosefile.net") == true, request.url.path.hasPrefix("/d/") {
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "<html><body>\"https://cdn.rosefile.net/files/archive.zip\"</body></html>",
                    cookies: []
                )
            }
            XCTFail("Unexpected request: \(request.url.absoluteString)")
            return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry
        )

        let resolved = try await resolver.resolve(
            DownloadResolveRequest(sourceURL: URL(string: "https://rosefile.net/6emc775g2p/apple.rar.html")!)
        )

        XCTAssertEqual(resolved.url.absoluteString, "https://cdn.rosefile.net/files/archive.zip")
        XCTAssertEqual(resolved.headers["Referer"], "https://rosefile.net/6emc775g2p/apple.rar.html")
        XCTAssertNil(resolved.authContext)
    }

    func testXueqiupanProviderResolvesAjaxDownloadRequest() async throws {
        let (registry, catalog) = try await makeSyncedCatalog(bundle: try makeLegacySitesBundle())

        let httpClient = StubHTTPClient { request in
            if request.url.absoluteString == "http://www.xueqiupan.com/ajax.php" {
                XCTAssertEqual(request.body, "action=load_down_addr1&file_id=672734")
                XCTAssertEqual(request.headers["Referer"], "http://www.xueqiupan.com/file-672734.html")
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "http://www.xueqiupan.com/dl.php?file=672734&from=ajax",
                    cookies: []
                )
            }
            XCTFail("Unexpected request: \(request.url.absoluteString)")
            return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry
        )

        let resolved = try await resolver.resolve(
            DownloadResolveRequest(sourceURL: URL(string: "http://www.xueqiupan.com/file-672734.html")!)
        )

        XCTAssertEqual(resolved.url.absoluteString, "http://www.xueqiupan.com/dl.php?file=672734&from=ajax")
        XCTAssertEqual(resolved.headers["Referer"], "http://www.xueqiupan.com")
        XCTAssertNil(resolved.authContext)
    }

    func testXingyaocloudsProviderResolvesRedirectThenAjaxDownloadRequest() async throws {
        let (registry, catalog) = try await makeSyncedCatalog(bundle: try makeLegacySitesBundle())

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://www.xingyaoclouds.com/start/landing":
                return HTTPResponseData(
                    statusCode: 200,
                    url: URL(string: "https://www.xingyaoclouds.com/down/xy1234")!,
                    headers: [:],
                    body: "redirected",
                    cookies: []
                )
            case "https://www.xingyaoclouds.com/ajax.php":
                XCTAssertEqual(request.body, "action=load_down_addr5&file_id=xy1234")
                XCTAssertEqual(request.headers["Referer"], "https://www.xingyaoclouds.com/down/xy1234")
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "https://www.xingyaoclouds.com/dl.php?file=xy1234&slot=5",
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry
        )

        let resolved = try await resolver.resolve(
            DownloadResolveRequest(sourceURL: URL(string: "https://www.xingyaoclouds.com/start/landing")!)
        )

        XCTAssertEqual(resolved.url.absoluteString, "https://www.xingyaoclouds.com/dl.php?file=xy1234&slot=5")
        XCTAssertEqual(resolved.headers["Referer"], "https://www.xingyaoclouds.com")
        XCTAssertNil(resolved.authContext)
    }

    func testRarpProviderResolvesRedirectPageFileIDFlow() async throws {
        let (registry, catalog) = try await makeSyncedCatalog(bundle: try makeLegacySitesBundle())

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "http://www.rarp.cc/share/abc":
                return HTTPResponseData(
                    statusCode: 200,
                    url: URL(string: "http://www.rarp.cc/file-1002.html")!,
                    headers: [:],
                    body: "redirected",
                    cookies: []
                )
            case "http://www.rarp.cc/down/file-1002.html":
                XCTAssertEqual(request.headers["Referer"], "http://www.rarp.cc/file-1002.html")
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "<script>load_down_addr1('1002')</script>",
                    cookies: []
                )
            case "http://www.rarp.cc/ajax.php":
                XCTAssertEqual(request.body, "action=load_down_addr1&file_id=1002")
                XCTAssertEqual(request.headers["Referer"], "http://www.rarp.cc/file-1002.html")
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "http://www.rarp.cc/dl.php?file=1002&token=rarp",
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry
        )

        let resolved = try await resolver.resolve(
            DownloadResolveRequest(sourceURL: URL(string: "http://www.rarp.cc/share/abc")!)
        )

        XCTAssertEqual(resolved.url.absoluteString, "http://www.rarp.cc/dl.php?file=1002&token=rarp")
        XCTAssertEqual(resolved.headers["Referer"], "http://www.rarp.cc")
        XCTAssertNil(resolved.authContext)
    }

    func test567FileProviderResolvesRedirectSignFlow() async throws {
        let (registry, catalog) = try await makeSyncedCatalog(bundle: try makeLegacySitesBundle())

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://www.567file.com/share/start":
                return HTTPResponseData(
                    statusCode: 200,
                    url: URL(string: "https://www.567file.com/file-9988.html")!,
                    headers: [:],
                    body: "redirected",
                    cookies: []
                )
            case "https://www.567file.com/down-9988.html":
                XCTAssertEqual(request.headers["Referer"], "https://www.567file.com/file-9988.html")
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "foo&sign=abcdef123&bar",
                    cookies: []
                )
            case "https://www.567file.com/ajax.php":
                XCTAssertEqual(request.body, "action=load_down_addr10&sign=abcdef123&file_id=9988")
                XCTAssertEqual(request.headers["Referer"], "https://www.567file.com/file-9988.html")
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "https://www.567file.com/dl.php?file=9988&slot=10",
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry
        )

        let resolved = try await resolver.resolve(
            DownloadResolveRequest(sourceURL: URL(string: "https://www.567file.com/share/start")!)
        )

        XCTAssertEqual(resolved.url.absoluteString, "https://www.567file.com/dl.php?file=9988&slot=10")
        XCTAssertEqual(resolved.headers["Referer"], "https://www.567file.com")
        XCTAssertNil(resolved.authContext)
    }

    func testIYCDNProviderResolvesTowerFlow() async throws {
        let (registry, catalog) = try await makeSyncedCatalog(bundle: try makeLegacySitesBundle())

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://www.iycdn.com/file-abc123.html":
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "<script src=\"/tower.js\"></script>",
                    cookies: []
                )
            case "https://www.iycdn.com/tower.js":
                XCTAssertEqual(request.headers["Referer"], "https://www.iycdn.com/file-abc123.html")
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "\"/tower_cookie?type=img&key=\" key=\"towerKey\" value=\"towerValue\"",
                    cookies: []
                )
            case "https://www.iycdn.com/tower_cookie?type=img&key=towerKey&value=e28ac6100dcc143e73ee5511c87e7cc2":
                XCTAssertEqual(request.headers["Referer"], "https://www.iycdn.com/file-abc123.html")
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "tower=ok; Path=/; Domain=www.iycdn.com"],
                    body: "cookie updated",
                    cookies: [SerializableCookie(name: "tower", value: "ok", domain: "www.iycdn.com", path: "/")]
                )
            case "https://www.iycdn.com/ajax.php":
                XCTAssertEqual(request.body, "action=load_down_addr1&file_id=abc123")
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("tower=ok"))
                XCTAssertEqual(request.headers["Referer"], "https://www.iycdn.com")
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "https://www.iycdn.com/dl.php?file=abc123&tower=1",
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry
        )

        let resolved = try await resolver.resolve(
            DownloadResolveRequest(sourceURL: URL(string: "https://www.iycdn.com/file-abc123.html")!)
        )

        XCTAssertEqual(resolved.url.absoluteString, "https://www.iycdn.com/dl.php?file=abc123&tower=1")
        XCTAssertEqual(resolved.headers["Referer"], "https://www.iycdn.com")
        XCTAssertNil(resolved.authContext)
    }

    func testAuthWorkflowRefreshesAndReusesProviderFamilySession() async throws {
        let bundle = try RuleBundleFixtures.loadMergedBundle(
            named: [
                "auth-workflows.bundle",
                "auth-sites.bundle",
                "auth-templates.bundle",
            ],
            bundleVersion: "2026.04.10.catalog.with-templates.1"
        )
        let (registry, catalog) = try await makeSyncedCatalog(bundle: bundle)

        let counter = MaterialCounter()
        let authStore = AuthSessionStore()
        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://secure.example.com/login":
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "session=valid; Path=/; Domain=secure.example.com"],
                    body: "ok",
                    cookies: [SerializableCookie(name: "session", value: "valid", domain: "secure.example.com", path: "/")]
                )
            case "https://secure.example.com/resource/42":
                let cookie = request.headers["Cookie"] ?? ""
                if cookie.contains("session=valid") {
                    return HTTPResponseData(
                        statusCode: 200,
                        url: request.url,
                        headers: [:],
                        body: "<div data-direct=\"https://cdn.example.com/file.bin\"></div>",
                        cookies: []
                    )
                }
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "AUTH_REQUIRED",
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authSessionStore: authStore,
            authMaterialProvider: CountingAuthMaterialProvider(counter: counter)
        )

        let input = DownloadResolveRequest(
            sourceURL: URL(string: "https://secure.example.com/resource/42")!,
            accountID: "demo"
        )

        let first = try await resolver.resolve(input)
        let second = try await resolver.resolve(input)
        let stored = await authStore.session(for: AuthSessionKey(providerFamily: "secure-demo", accountID: "demo"))
        let materialCount = await counter.current()

        XCTAssertEqual(first.url.absoluteString, "https://cdn.example.com/file.bin")
        XCTAssertEqual(second.url.absoluteString, first.url.absoluteString)
        XCTAssertEqual(materialCount, 1)
        XCTAssertEqual(stored?.cookies.first?.name, "session")
        XCTAssertEqual(first.authContext?.providerFamily, "secure-demo")
        XCTAssertEqual(first.authContext?.accountID, "demo")
    }

    func testLegacyXSRFLoginAndGenerateDownloadWorkflowResolvesAuthenticatedRequest() async throws {
        let bundle = try RuleBundleFixtures.loadMergedBundle(
            named: [
                "auth-workflows.bundle",
                "auth-sites.bundle",
                "auth-templates.bundle",
            ],
            bundleVersion: "2026.04.10.catalog.with-templates.1"
        )
        let (registry, catalog) = try await makeSyncedCatalog(bundle: bundle)

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://vip.example.com/login" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "XSRF-TOKEN=xsrf-456; Path=/; Domain=vip.example.com"],
                    body: #"<meta name="csrf-token" content="csrf-123">"#,
                    cookies: [SerializableCookie(name: "XSRF-TOKEN", value: "xsrf-456", domain: "vip.example.com", path: "/")]
                )
            case "https://vip.example.com/login" where request.method == .post:
                XCTAssertEqual(
                    request.body,
                    #"{"login":"demo-user","password":"secret-password","captcha":"7261","remember":false}"#
                )
                XCTAssertEqual(request.headers["X-CSRF-TOKEN"], "csrf-123")
                XCTAssertEqual(request.headers["X-XSRF-TOKEN"], "xsrf-456")
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("XSRF-TOKEN=xsrf-456"))
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "session=vip-session; Path=/; Domain=vip.example.com"],
                    body: #"{"ok":true}"#,
                    cookies: [SerializableCookie(name: "session", value: "vip-session", domain: "vip.example.com", path: "/")]
                )
            case "https://vip.example.com/f/abc123/generate-download":
                XCTAssertEqual(
                    request.body,
                    #"{"type":"vip","click_pos":"690,689","screen":"1920x1080","ref":"download_vip"}"#
                )
                XCTAssertEqual(request.headers["X-CSRF-TOKEN"], "csrf-123")
                XCTAssertEqual(request.headers["X-XSRF-TOKEN"], "xsrf-456")
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("session=vip-session"))
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"{"download_url":"https://cdn.vip.example.com/file.bin","success":true,"is_repeated":false}"#,
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.method.rawValue) \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authMaterialProvider: StaticAuthMaterialProvider(
                storage: [
                    "xrcf-vip": [
                        "vip-demo": [
                            "username": .string("demo-user"),
                            "password": .string("secret-password"),
                            "captcha": .string("7261"),
                        ]
                    ]
                ]
            )
        )

        let resolved = try await resolver.resolve(
            DownloadResolveRequest(
                sourceURL: URL(string: "https://vip.example.com/f/abc123")!,
                accountID: "vip-demo"
            )
        )

        XCTAssertEqual(resolved.url.absoluteString, "https://cdn.vip.example.com/file.bin")
        XCTAssertEqual(resolved.headers["Referer"], "https://vip.example.com/f/abc123")
        XCTAssertEqual(resolved.authContext?.providerFamily, "xrcf-vip")
        XCTAssertEqual(resolved.authContext?.accountID, "vip-demo")
        XCTAssertEqual(resolved.authContext?.sessionValues["csrfToken"], .string("csrf-123"))
        XCTAssertEqual(resolved.authContext?.sessionValues["xsrfToken"], .string("xsrf-456"))
    }

    func testLegacyFormhashCaptchaAuthWorkflowResolvesProtectedRequest() async throws {
        let (registry, catalog) = try await makeSyncedCatalog()

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "http://www.jkpan.com/account.php?action=login&ref=/mydisk.php?item=profile&menu=cp":
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "login_page=1; Path=/; Domain=www.jkpan.com"],
                    body: #"<input type="hidden" name="formhash" value="fh-789">"#,
                    cookies: [SerializableCookie(name: "login_page", value: "1", domain: "www.jkpan.com", path: "/")]
                )
            case "http://www.jkpan.com/account.php":
                XCTAssertEqual(
                    request.body,
                    "action=login&task=login&ref=http://www.jkpan.com&formhash=fh-789&verycode=9012&username=demo-user&password=secret-password"
                )
                XCTAssertEqual(request.headers["Referer"], "http://www.jkpan.com/account.php?action=login")
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("login_page=1"))
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "session=formhash-valid; Path=/; Domain=www.jkpan.com"],
                    body: "ok",
                    cookies: [SerializableCookie(name: "session", value: "formhash-valid", domain: "www.jkpan.com", path: "/")]
                )
            case "http://www.jkpan.com/file-7.html":
                let cookie = request.headers["Cookie"] ?? ""
                if cookie.contains("session=formhash-valid") {
                    return HTTPResponseData(
                        statusCode: 200,
                        url: request.url,
                        headers: [:],
                        body: #"<div data-direct="https://download.jkpan.com/vip.bin"></div>"#,
                        cookies: []
                    )
                }
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "AUTH_REQUIRED",
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.method.rawValue) \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authMaterialProvider: StaticAuthMaterialProvider(
                storage: [
                    "jkpan-vip": [
                        "formhash-demo": [
                            "username": .string("demo-user"),
                            "password": .string("secret-password"),
                            "captcha": .string("9012"),
                        ]
                    ]
                ]
            )
        )

        let resolved = try await resolver.resolve(
            DownloadResolveRequest(
                sourceURL: URL(string: "http://www.jkpan.com/file-7.html")!,
                accountID: "formhash-demo"
            )
        )

        XCTAssertEqual(resolved.url.absoluteString, "https://download.jkpan.com/vip.bin")
        XCTAssertEqual(resolved.headers["Referer"], "http://www.jkpan.com/file-7.html")
        XCTAssertEqual(resolved.authContext?.providerFamily, "jkpan-vip")
        XCTAssertEqual(resolved.authContext?.accountID, "formhash-demo")
        XCTAssertEqual(resolved.authContext?.sessionValues["formhash"], .string("fh-789"))
    }

    func test116PanVIPAuthWorkflowResolvesGenerateDownloadRequest() async throws {
        let (registry, catalog) = try await makeSyncedCatalog()
        await registry.register("captcha.ocr") { invocation in
            XCTAssertEqual(invocation.arguments["imageBase64"], .string(Data("captcha-image".utf8).base64EncodedString()))
            return .string("H2YY")
        }

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://www.116pan.xyz/login" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "XSRF-TOKEN=xsrf-116; Path=/; Domain=www.116pan.xyz"],
                    body: #"<meta name="csrf-token" content="csrf-116">"#,
                    cookies: [SerializableCookie(name: "XSRF-TOKEN", value: "xsrf-116", domain: "www.116pan.xyz", path: "/")]
                )
            case "https://www.116pan.xyz/captcha/20" where request.method == .get:
                XCTAssertEqual(request.headers["Referer"], "https://www.116pan.xyz/login")
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("XSRF-TOKEN=xsrf-116"))
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "captcha-image",
                    bodyBase64: Data("captcha-image".utf8).base64EncodedString(),
                    cookies: []
                )
            case "https://www.116pan.xyz/login" where request.method == .post:
                XCTAssertEqual(
                    request.body,
                    #"{"login":"demo-user","password":"secret-password","captcha":"H2YY","remember":false}"#
                )
                XCTAssertEqual(request.headers["Content-Type"], "application/json")
                XCTAssertEqual(request.headers["X-CSRF-TOKEN"], "csrf-116")
                XCTAssertEqual(request.headers["X-XSRF-TOKEN"], "xsrf-116")
                XCTAssertEqual(request.headers["X-Requested-With"], "XMLHttpRequest")
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("XSRF-TOKEN=xsrf-116"))
                return HTTPResponseData(
                    statusCode: 200,
                    url: URL(string: "https://www.116pan.xyz/dashboard")!,
                    headers: ["Set-Cookie": "116_session=session-116; Path=/; Domain=www.116pan.xyz"],
                    body: #"<div id="app" data-page="{&quot;component&quot;:&quot;Dashboard\/Index&quot;}"></div>"#,
                    cookies: [SerializableCookie(name: "116_session", value: "session-116", domain: "www.116pan.xyz", path: "/")]
                )
            case "https://www.116pan.xyz/dashboard" where request.method == .get:
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("116_session=session-116"))
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"<div id="app" data-page="{&quot;component&quot;:&quot;Dashboard\/Index&quot;,&quot;props&quot;:{&quot;auth&quot;:{&quot;user&quot;:{&quot;id&quot;:1}},&quot;isVip&quot;:true}}"></div>"#,
                    cookies: []
                )
            case "https://www.116pan.xyz/f/0V02j0lxvpSl" where request.method == .get:
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("116_session=session-116"))
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "XSRF-TOKEN=xsrf-file; Path=/; Domain=www.116pan.xyz"],
                    body: #"<meta name="csrf-token" content="csrf-file"><div id="app" data-page="{&quot;isAuthenticated&quot;:true,&quot;isVip&quot;:true,&quot;file&quot;:{&quot;file_short_url&quot;:&quot;0V02j0lxvpSl&quot;}}"></div>"#,
                    cookies: [SerializableCookie(name: "XSRF-TOKEN", value: "xsrf-file", domain: "www.116pan.xyz", path: "/")]
                )
            case "https://www.116pan.xyz/f/0V02j0lxvpSl/generate-download" where request.method == .post:
                XCTAssertEqual(
                    request.body,
                    #"{"type":"vip","click_pos":"690,689","screen":"1920x1080","ref":"download_vip"}"#
                )
                XCTAssertEqual(request.headers["X-CSRF-TOKEN"], "csrf-file")
                XCTAssertEqual(request.headers["X-XSRF-TOKEN"], "xsrf-file")
                XCTAssertEqual(request.headers["Referer"], "https://www.116pan.xyz/f/0V02j0lxvpSl")
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("116_session=session-116"))
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"{"success":true,"download_url":"https:\/\/vip-n2.116pan.xyz\/2026\/02\/18\/archive.zip?sig=abc&expires=1775869623000&dlname=A14639.zip","is_repeated":false}"#,
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.method.rawValue) \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authMaterialProvider: StaticAuthMaterialProvider(
                storage: [
                    "116pan-vip": [
                        "116pan-demo": [
                            "username": .string("demo-user"),
                            "password": .string("secret-password"),
                        ]
                    ]
                ]
            )
        )

        let resolved = try await resolver.resolve(
            DownloadResolveRequest(
                sourceURL: URL(string: "https://www.116pan.xyz/f/0V02j0lxvpSl")!,
                accountID: "116pan-demo"
            )
        )

        XCTAssertEqual(
            resolved.url.absoluteString,
            "https://vip-n2.116pan.xyz/2026/02/18/archive.zip?sig=abc&expires=1775869623000&dlname=A14639.zip"
        )
        XCTAssertEqual(resolved.headers["Accept"], "*/*")
        XCTAssertEqual(resolved.headers["Accept-Encoding"], "gzip, deflate, br, zstd")
        XCTAssertEqual(resolved.headers["Accept-Language"], "zh-CN")
        XCTAssertEqual(resolved.headers["Connection"], "keep-alive")
        XCTAssertEqual(resolved.headers["Priority"], "u=3, i")
        XCTAssertEqual(resolved.headers["Referer"], "https://www.116pan.xyz/f/0V02j0lxvpSl")
        XCTAssertEqual(resolved.headers["Sec-CH-UA"], "\"Chromium\";v=\"146\", \"Not-A.Brand\";v=\"24\", \"Google Chrome\";v=\"146\"")
        XCTAssertEqual(resolved.headers["Sec-CH-UA-Mobile"], "?0")
        XCTAssertEqual(resolved.headers["Sec-CH-UA-Platform"], "\"macOS\"")
        XCTAssertEqual(resolved.headers["Sec-Fetch-Dest"], "empty")
        XCTAssertEqual(resolved.headers["Sec-Fetch-Mode"], "cors")
        XCTAssertEqual(resolved.headers["Sec-Fetch-Site"], "same-origin")
        XCTAssertEqual(
            resolved.headers["User-Agent"],
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
        )
        XCTAssertEqual(resolved.filenameHints["provider"], "116pan-vip")
        XCTAssertNil(resolved.authContext)
    }

    func test116PanComCanonicalFileURLUsesRedirectedOriginForGenerateDownload() async throws {
        let (registry, catalog) = try await makeSyncedCatalog()
        let authStore = AuthSessionStore()
        let sessionKey = AuthSessionKey(providerFamily: "116pan-vip", accountID: "default-116")
        await authStore.store(
            AuthSession(
                key: sessionKey,
                cookies: [
                    SerializableCookie(
                        name: "116_session",
                        value: "session-116",
                        domain: "www.116pan.xyz",
                        path: "/"
                    )
                ]
            )
        )

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://www.116pan.xyz/f/Jo89da23lsy5" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: URL(string: "https://www.116pan.xyz/f/Jo89da23lsy5")!,
                    headers: ["Set-Cookie": "XSRF-TOKEN=xsrf-file; Path=/; Domain=www.116pan.xyz"],
                    body: #"<meta name="csrf-token" content="csrf-file"><div id="app" data-page="{&quot;isAuthenticated&quot;:true,&quot;isVip&quot;:true,&quot;file&quot;:{&quot;file_short_url&quot;:&quot;Jo89da23lsy5&quot;}}"></div>"#,
                    cookies: [SerializableCookie(name: "XSRF-TOKEN", value: "xsrf-file", domain: "www.116pan.xyz", path: "/")]
                )
            case "https://www.116pan.xyz/f/Jo89da23lsy5/generate-download" where request.method == .post:
                XCTAssertEqual(request.headers["Origin"], "https://www.116pan.xyz")
                XCTAssertEqual(request.headers["Referer"], "https://www.116pan.xyz/f/Jo89da23lsy5")
                XCTAssertEqual(request.headers["X-CSRF-TOKEN"], "csrf-file")
                XCTAssertEqual(request.headers["X-XSRF-TOKEN"], "xsrf-file")
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("116_session=session-116"))
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("XSRF-TOKEN=xsrf-file"))
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"{"success":true,"download_url":"https:\/\/vip-n2.116pan.xyz\/factory.zip?sig=abc","is_repeated":false}"#,
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.method.rawValue) \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authSessionStore: authStore
        )

        let resolved = try await resolver.resolve(
            DownloadResolveRequest(
                sourceURL: URL(string: "https://www.116pan.com/f/Jo89da23lsy5")!,
                accountID: "default-116"
            )
        )

        XCTAssertEqual(resolved.url.absoluteString, "https://vip-n2.116pan.xyz/factory.zip?sig=abc")
        XCTAssertEqual(resolved.headers["Referer"], "https://www.116pan.xyz/f/Jo89da23lsy5")
        XCTAssertEqual(resolved.filenameHints["provider"], "116pan-vip")
    }

    func test116PanGenerateDownloadMissingURLFailsBeforeEmitRequest() async throws {
        let (registry, catalog) = try await makeSyncedCatalog()
        let authStore = AuthSessionStore()
        let sessionKey = AuthSessionKey(providerFamily: "116pan-vip", accountID: "default-116")
        await authStore.store(
            AuthSession(
                key: sessionKey,
                cookies: [
                    SerializableCookie(
                        name: "116_session",
                        value: "session-116",
                        domain: "www.116pan.xyz",
                        path: "/"
                    )
                ]
            )
        )

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://www.116pan.xyz/f/Jo89da23lsy5" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: URL(string: "https://www.116pan.xyz/f/Jo89da23lsy5")!,
                    headers: ["Set-Cookie": "XSRF-TOKEN=xsrf-file; Path=/; Domain=www.116pan.xyz"],
                    body: #"<meta name="csrf-token" content="csrf-file"><div id="app" data-page="{&quot;isAuthenticated&quot;:true,&quot;isVip&quot;:true,&quot;file&quot;:{&quot;file_short_url&quot;:&quot;Jo89da23lsy5&quot;}}"></div>"#,
                    cookies: [SerializableCookie(name: "XSRF-TOKEN", value: "xsrf-file", domain: "www.116pan.xyz", path: "/")]
                )
            case "https://www.116pan.xyz/f/Jo89da23lsy5/generate-download" where request.method == .post:
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"{"success":false,"message":"provider returned an intermediate page"}"#,
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.method.rawValue) \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authSessionStore: authStore
        )

        do {
            _ = try await resolver.resolve(
                DownloadResolveRequest(
                    sourceURL: URL(string: "https://www.116pan.com/f/Jo89da23lsy5")!,
                    accountID: "default-116"
                )
            )
            XCTFail("Expected URL validation failure when download_url is missing.")
        } catch let RuleEngineError.invalidTemplate(message) {
            XCTAssertEqual(message, "url.origin requires a valid sourceURL")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test116PanVIPAuthWorkflowRetriesCaptchaRejectionsBeforeGenerateDownload() async throws {
        let (registry, catalog) = try await makeSyncedCatalog()
        let recorder = CaptchaRetryRecorder(values: ["BAD1", "BAD2", "H2YY"])
        await registry.register("captcha.ocr") { _ in
            .string(await recorder.nextCaptcha())
        }

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://www.116pan.xyz/login" where request.method == .get:
                await recorder.recordLoginPageFetch()
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "XSRF-TOKEN=xsrf-116; Path=/; Domain=www.116pan.xyz"],
                    body: #"<meta name="csrf-token" content="csrf-116">"#,
                    cookies: [SerializableCookie(name: "XSRF-TOKEN", value: "xsrf-116", domain: "www.116pan.xyz", path: "/")]
                )
            case "https://www.116pan.xyz/captcha/20" where request.method == .get:
                await recorder.recordCaptchaFetch()
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "captcha-image",
                    bodyBase64: Data("captcha-image".utf8).base64EncodedString(),
                    cookies: []
                )
            case "https://www.116pan.xyz/login" where request.method == .post:
                await recorder.recordLoginBody(request.body)
                if request.body?.contains(#""captcha":"H2YY""#) == true {
                    return HTTPResponseData(
                        statusCode: 200,
                        url: URL(string: "https://www.116pan.xyz/dashboard")!,
                        headers: ["Set-Cookie": "116_session=session-116; Path=/; Domain=www.116pan.xyz"],
                        body: #"<div id="app" data-page="{&quot;component&quot;:&quot;Dashboard\/Index&quot;}"></div>"#,
                        cookies: [SerializableCookie(name: "116_session", value: "session-116", domain: "www.116pan.xyz", path: "/")]
                    )
                }
                return HTTPResponseData(
                    statusCode: 422,
                    url: request.url,
                    headers: [:],
                    body: #"<div id="app" data-page="{&quot;component&quot;:&quot;Auth\/Login&quot;,&quot;props&quot;:{&quot;captchaError&quot;:&quot;验证码错误&quot;,&quot;login&quot;:&quot;demo-user&quot;,&quot;password&quot;:&quot;&quot;}}"></div>"#,
                    cookies: []
                )
            case "https://www.116pan.xyz/dashboard" where request.method == .get:
                if (request.headers["Cookie"] ?? "").contains("116_session=session-116") {
                    return HTTPResponseData(
                        statusCode: 200,
                        url: request.url,
                        headers: [:],
                        body: #"<div id="app" data-page="{&quot;component&quot;:&quot;Dashboard\/Index&quot;,&quot;props&quot;:{&quot;auth&quot;:{&quot;user&quot;:{&quot;id&quot;:1}},&quot;isVip&quot;:true}}"></div>"#,
                        cookies: []
                    )
                }
                return HTTPResponseData(
                    statusCode: 200,
                    url: URL(string: "https://www.116pan.xyz/login")!,
                    headers: [:],
                    body: #"<div id="app" data-page="{&quot;component&quot;:&quot;Auth\/Login&quot;,&quot;props&quot;:{&quot;errors&quot;:{},&quot;auth&quot;:{&quot;user&quot;:null}}}"></div>"#,
                    cookies: []
                )
            case "https://www.116pan.xyz/f/0V02j0lxvpSl" where request.method == .get:
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("116_session=session-116"))
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "XSRF-TOKEN=xsrf-file; Path=/; Domain=www.116pan.xyz"],
                    body: #"<meta name="csrf-token" content="csrf-file"><div id="app" data-page="{&quot;isAuthenticated&quot;:true,&quot;isVip&quot;:true,&quot;file&quot;:{&quot;file_short_url&quot;:&quot;0V02j0lxvpSl&quot;}}"></div>"#,
                    cookies: [SerializableCookie(name: "XSRF-TOKEN", value: "xsrf-file", domain: "www.116pan.xyz", path: "/")]
                )
            case "https://www.116pan.xyz/f/0V02j0lxvpSl/generate-download" where request.method == .post:
                XCTAssertEqual(request.headers["X-CSRF-TOKEN"], "csrf-file")
                XCTAssertEqual(request.headers["X-XSRF-TOKEN"], "xsrf-file")
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("116_session=session-116"))
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"{"success":true,"download_url":"https:\/\/vip-n2.116pan.xyz\/archive.zip?sig=abc","is_repeated":false}"#,
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.method.rawValue) \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authMaterialProvider: StaticAuthMaterialProvider(
                storage: [
                    "116pan-vip": [
                        "116pan-demo": [
                            "username": .string("demo-user"),
                            "password": .string("secret-password"),
                        ]
                    ]
                ]
            )
        )

        let resolved = try await resolver.resolve(
            DownloadResolveRequest(
                sourceURL: URL(string: "https://www.116pan.xyz/f/0V02j0lxvpSl")!,
                accountID: "116pan-demo"
            )
        )

        XCTAssertEqual(resolved.url.absoluteString, "https://vip-n2.116pan.xyz/archive.zip?sig=abc")
        let loginPageFetchCount = await recorder.loginPageFetchCount()
        XCTAssertEqual(loginPageFetchCount, 1)
        let captchaFetchCount = await recorder.captchaFetchCount()
        XCTAssertEqual(captchaFetchCount, 3)
        let loginAttemptCount = await recorder.loginAttemptCount()
        XCTAssertEqual(loginAttemptCount, 3)
    }

    func test116PanVIPAuthWorkflowRejectsInertiaCredentialErrors() async throws {
        let (registry, catalog) = try await makeSyncedCatalog()
        await registry.register("captcha.ocr") { _ in
            .string("H2YY")
        }

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://www.116pan.xyz/login" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "XSRF-TOKEN=xsrf-116; Path=/; Domain=www.116pan.xyz"],
                    body: #"<meta name="csrf-token" content="csrf-116"><div id="app" data-page="{&quot;version&quot;:&quot;fixture-version&quot;}"></div>"#,
                    cookies: [SerializableCookie(name: "XSRF-TOKEN", value: "xsrf-116", domain: "www.116pan.xyz", path: "/")]
                )
            case "https://www.116pan.xyz/captcha/20" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "captcha-image",
                    bodyBase64: Data("captcha-image".utf8).base64EncodedString(),
                    cookies: []
                )
            case "https://www.116pan.xyz/login" where request.method == .post:
                XCTAssertEqual(request.headers["Accept"], "text/html, application/xhtml+xml")
                XCTAssertEqual(request.headers["X-Inertia"], "true")
                XCTAssertEqual(request.headers["X-Inertia-Version"], "fixture-version")
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"{"component":"Auth/Login","props":{"errors":{"login":"賬號或密碼錯誤"}}}"#,
                    cookies: []
                )
            case "https://www.116pan.xyz/dashboard" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: URL(string: "https://www.116pan.xyz/login")!,
                    headers: [:],
                    body: #"<div id="app" data-page="{&quot;component&quot;:&quot;Auth\/Login&quot;,&quot;props&quot;:{&quot;errors&quot;:{},&quot;auth&quot;:{&quot;user&quot;:null}}}"></div>"#,
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.method.rawValue) \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authMaterialProvider: StaticAuthMaterialProvider(
                storage: [
                    "116pan-vip": [
                        "116pan-demo": [
                            "username": .string("demo-user"),
                            "password": .string("secret-password"),
                        ]
                    ]
                ]
            )
        )

        do {
            _ = try await resolver.resolve(
                DownloadResolveRequest(
                    sourceURL: URL(string: "https://www.116pan.xyz/f/0V02j0lxvpSl")!,
                    accountID: "116pan-demo"
                )
            )
            XCTFail("Expected credentials rejection")
        } catch let RuleEngineError.authCredentialsRejected(providerFamily) {
            XCTAssertEqual(providerFamily, "116pan-vip")
        }
    }

    func test116PanVIPAuthWorkflowRetriesBlankInertiaLoginPage() async throws {
        let (registry, catalog) = try await makeSyncedCatalog()
        let recorder = CaptchaRetryRecorder(values: ["BAD1", "H2YY"])
        await registry.register("captcha.ocr") { _ in
            .string(await recorder.nextCaptcha())
        }

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://www.116pan.xyz/login" where request.method == .get:
                await recorder.recordLoginPageFetch()
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "XSRF-TOKEN=xsrf-116; Path=/; Domain=www.116pan.xyz"],
                    body: #"<meta name="csrf-token" content="csrf-116"><div id="app" data-page="{&quot;version&quot;:&quot;fixture-version&quot;}"></div>"#,
                    cookies: [SerializableCookie(name: "XSRF-TOKEN", value: "xsrf-116", domain: "www.116pan.xyz", path: "/")]
                )
            case "https://www.116pan.xyz/captcha/20" where request.method == .get:
                await recorder.recordCaptchaFetch()
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "captcha-image",
                    bodyBase64: Data("captcha-image".utf8).base64EncodedString(),
                    cookies: []
                )
            case "https://www.116pan.xyz/login" where request.method == .post:
                await recorder.recordLoginBody(request.body)
                if request.body?.contains(#""captcha":"H2YY""#) == true {
                    return HTTPResponseData(
                        statusCode: 200,
                        url: URL(string: "https://www.116pan.xyz/dashboard")!,
                        headers: ["Set-Cookie": "116_session=session-116; Path=/; Domain=www.116pan.xyz"],
                        body: #"<div id="app" data-page="{&quot;component&quot;:&quot;Dashboard\/Index&quot;}"></div>"#,
                        cookies: [SerializableCookie(name: "116_session", value: "session-116", domain: "www.116pan.xyz", path: "/")]
                    )
                }
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"{"component":"Auth/Login","props":{"errors":{},"auth":{"user":null},"flash":{"success":null,"error":null},"status":null},"url":"/login"}"#,
                    cookies: []
                )
            case "https://www.116pan.xyz/dashboard" where request.method == .get:
                if (request.headers["Cookie"] ?? "").contains("116_session=session-116") {
                    return HTTPResponseData(
                        statusCode: 200,
                        url: request.url,
                        headers: [:],
                        body: #"<div id="app" data-page="{&quot;component&quot;:&quot;Dashboard\/Index&quot;,&quot;props&quot;:{&quot;auth&quot;:{&quot;user&quot;:{&quot;id&quot;:1}},&quot;isVip&quot;:true}}"></div>"#,
                        cookies: []
                    )
                }
                return HTTPResponseData(
                    statusCode: 200,
                    url: URL(string: "https://www.116pan.xyz/login")!,
                    headers: [:],
                    body: #"<div id="app" data-page="{&quot;component&quot;:&quot;Auth\/Login&quot;,&quot;props&quot;:{&quot;errors&quot;:{},&quot;auth&quot;:{&quot;user&quot;:null}}}"></div>"#,
                    cookies: []
                )
            case "https://www.116pan.xyz/f/0V02j0lxvpSl" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "XSRF-TOKEN=xsrf-file; Path=/; Domain=www.116pan.xyz"],
                    body: #"<meta name="csrf-token" content="csrf-file"><div id="app" data-page="{&quot;isAuthenticated&quot;:true,&quot;isVip&quot;:true,&quot;file&quot;:{&quot;file_short_url&quot;:&quot;0V02j0lxvpSl&quot;}}"></div>"#,
                    cookies: [SerializableCookie(name: "XSRF-TOKEN", value: "xsrf-file", domain: "www.116pan.xyz", path: "/")]
                )
            case "https://www.116pan.xyz/f/0V02j0lxvpSl/generate-download" where request.method == .post:
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"{"success":true,"download_url":"https:\/\/vip-n2.116pan.xyz\/archive.zip?sig=abc","is_repeated":false}"#,
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.method.rawValue) \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authMaterialProvider: StaticAuthMaterialProvider(
                storage: [
                    "116pan-vip": [
                        "116pan-demo": [
                            "username": .string("demo-user"),
                            "password": .string("secret-password"),
                        ]
                    ]
                ]
            )
        )

        let resolved = try await resolver.resolve(
            DownloadResolveRequest(
                sourceURL: URL(string: "https://www.116pan.xyz/f/0V02j0lxvpSl")!,
                accountID: "116pan-demo"
            )
        )

        XCTAssertEqual(resolved.url.absoluteString, "https://vip-n2.116pan.xyz/archive.zip?sig=abc")
        let loginPageFetchCount = await recorder.loginPageFetchCount()
        XCTAssertEqual(loginPageFetchCount, 1)
        let captchaFetchCount = await recorder.captchaFetchCount()
        XCTAssertEqual(captchaFetchCount, 2)
        let loginAttemptCount = await recorder.loginAttemptCount()
        XCTAssertEqual(loginAttemptCount, 2)
    }

    func test116PanVIPAuthWorkflowAcceptsDashboardAfterBlankLoginResponse() async throws {
        let (registry, catalog) = try await makeSyncedCatalog()
        let recorder = CaptchaRetryRecorder(values: ["H2YY"])
        await registry.register("captcha.ocr") { _ in
            .string(await recorder.nextCaptcha())
        }

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://www.116pan.xyz/login" where request.method == .get:
                await recorder.recordLoginPageFetch()
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "XSRF-TOKEN=xsrf-116; Path=/; Domain=www.116pan.xyz"],
                    body: #"<meta name="csrf-token" content="csrf-116"><div id="app" data-page="{&quot;version&quot;:&quot;fixture-version&quot;}"></div>"#,
                    cookies: [SerializableCookie(name: "XSRF-TOKEN", value: "xsrf-116", domain: "www.116pan.xyz", path: "/")]
                )
            case "https://www.116pan.xyz/captcha/20" where request.method == .get:
                await recorder.recordCaptchaFetch()
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "captcha-image",
                    bodyBase64: Data("captcha-image".utf8).base64EncodedString(),
                    cookies: []
                )
            case "https://www.116pan.xyz/login" where request.method == .post:
                await recorder.recordLoginBody(request.body)
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "116_session=session-116; Path=/; Domain=www.116pan.xyz"],
                    body: #"{"component":"Auth/Login","props":{"errors":{},"auth":{"user":null},"flash":{"success":null,"error":null},"status":null},"url":"/login"}"#,
                    cookies: [SerializableCookie(name: "116_session", value: "session-116", domain: "www.116pan.xyz", path: "/")]
                )
            case "https://www.116pan.xyz/dashboard" where request.method == .get:
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("116_session=session-116"))
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"<div id="app" data-page="{&quot;component&quot;:&quot;Dashboard\/Index&quot;,&quot;props&quot;:{&quot;auth&quot;:{&quot;user&quot;:{&quot;id&quot;:1}},&quot;isVip&quot;:true}}"></div>"#,
                    cookies: []
                )
            case "https://www.116pan.xyz/f/0V02j0lxvpSl" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "XSRF-TOKEN=xsrf-file; Path=/; Domain=www.116pan.xyz"],
                    body: #"<meta name="csrf-token" content="csrf-file"><div id="app" data-page="{&quot;isAuthenticated&quot;:true,&quot;isVip&quot;:true,&quot;file&quot;:{&quot;file_short_url&quot;:&quot;0V02j0lxvpSl&quot;}}"></div>"#,
                    cookies: [SerializableCookie(name: "XSRF-TOKEN", value: "xsrf-file", domain: "www.116pan.xyz", path: "/")]
                )
            case "https://www.116pan.xyz/f/0V02j0lxvpSl/generate-download" where request.method == .post:
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"{"success":true,"download_url":"https:\/\/vip-n2.116pan.xyz\/archive.zip?sig=abc","is_repeated":false}"#,
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.method.rawValue) \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authMaterialProvider: StaticAuthMaterialProvider(
                storage: [
                    "116pan-vip": [
                        "116pan-demo": [
                            "username": .string("demo-user"),
                            "password": .string("secret-password"),
                        ]
                    ]
                ]
            )
        )

        let resolved = try await resolver.resolve(
            DownloadResolveRequest(
                sourceURL: URL(string: "https://www.116pan.xyz/f/0V02j0lxvpSl")!,
                accountID: "116pan-demo"
            )
        )

        XCTAssertEqual(resolved.url.absoluteString, "https://vip-n2.116pan.xyz/archive.zip?sig=abc")
        let loginPageFetchCount = await recorder.loginPageFetchCount()
        XCTAssertEqual(loginPageFetchCount, 1)
        let captchaFetchCount = await recorder.captchaFetchCount()
        XCTAssertEqual(captchaFetchCount, 1)
        let loginAttemptCount = await recorder.loginAttemptCount()
        XCTAssertEqual(loginAttemptCount, 1)
    }

    func test116PanVIPAuthWorkflowStopsAfterRepeatedBlankInertiaLoginPages() async throws {
        let (registry, catalog) = try await makeSyncedCatalog()
        let recorder = CaptchaRetryRecorder(values: ["BAD1", "BAD2", "BAD3"])
        await registry.register("captcha.ocr") { _ in
            .string(await recorder.nextCaptcha())
        }

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://www.116pan.xyz/login" where request.method == .get:
                await recorder.recordLoginPageFetch()
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "XSRF-TOKEN=xsrf-116; Path=/; Domain=www.116pan.xyz"],
                    body: #"<meta name="csrf-token" content="csrf-116"><div id="app" data-page="{&quot;version&quot;:&quot;fixture-version&quot;}"></div>"#,
                    cookies: [SerializableCookie(name: "XSRF-TOKEN", value: "xsrf-116", domain: "www.116pan.xyz", path: "/")]
                )
            case "https://www.116pan.xyz/captcha/20" where request.method == .get:
                await recorder.recordCaptchaFetch()
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "captcha-image",
                    bodyBase64: Data("captcha-image".utf8).base64EncodedString(),
                    cookies: []
                )
            case "https://www.116pan.xyz/login" where request.method == .post:
                await recorder.recordLoginBody(request.body)
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"{"component":"Auth/Login","props":{"errors":{},"auth":{"user":null},"flash":{"success":null,"error":null},"status":null},"url":"/login"}"#,
                    cookies: []
                )
            case "https://www.116pan.xyz/dashboard" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: URL(string: "https://www.116pan.xyz/login")!,
                    headers: [:],
                    body: #"<div id="app" data-page="{&quot;component&quot;:&quot;Auth\/Login&quot;,&quot;props&quot;:{&quot;errors&quot;:{},&quot;auth&quot;:{&quot;user&quot;:null}}}"></div>"#,
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.method.rawValue) \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authMaterialProvider: StaticAuthMaterialProvider(
                storage: [
                    "116pan-vip": [
                        "116pan-demo": [
                            "username": .string("demo-user"),
                            "password": .string("secret-password"),
                        ]
                    ]
                ]
            )
        )

        do {
            _ = try await resolver.resolve(
                DownloadResolveRequest(
                    sourceURL: URL(string: "https://www.116pan.xyz/f/0V02j0lxvpSl")!,
                    accountID: "116pan-demo"
                )
            )
            XCTFail("Expected credentials rejection")
        } catch let RuleEngineError.authCredentialsRejected(providerFamily) {
            XCTAssertEqual(providerFamily, "116pan-vip")
        }

        let loginPageFetchCount = await recorder.loginPageFetchCount()
        XCTAssertEqual(loginPageFetchCount, 1)
        let captchaFetchCount = await recorder.captchaFetchCount()
        XCTAssertEqual(captchaFetchCount, 3)
        let loginAttemptCount = await recorder.loginAttemptCount()
        XCTAssertEqual(loginAttemptCount, 3)
    }

    func test116PanVIPAuthWorkflowStopsAfterFiftyLightweightCaptchaRejections() async throws {
        let (registry, catalog) = try await makeSyncedCatalog()
        let recorder = CaptchaRetryRecorder(values: (1...50).map { "BAD\($0)" })
        await registry.register("captcha.ocr") { _ in
            .string(await recorder.nextCaptcha())
        }

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://www.116pan.xyz/login" where request.method == .get:
                await recorder.recordLoginPageFetch()
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "XSRF-TOKEN=xsrf-116; Path=/; Domain=www.116pan.xyz"],
                    body: #"<meta name="csrf-token" content="csrf-116">"#,
                    cookies: [SerializableCookie(name: "XSRF-TOKEN", value: "xsrf-116", domain: "www.116pan.xyz", path: "/")]
                )
            case "https://www.116pan.xyz/captcha/20" where request.method == .get:
                await recorder.recordCaptchaFetch()
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: "captcha-image",
                    bodyBase64: Data("captcha-image".utf8).base64EncodedString(),
                    cookies: []
                )
            case "https://www.116pan.xyz/login" where request.method == .post:
                await recorder.recordLoginBody(request.body)
                return HTTPResponseData(
                    statusCode: 422,
                    url: request.url,
                    headers: [:],
                    body: #"<div id="app" data-page="{&quot;component&quot;:&quot;Auth\/Login&quot;,&quot;props&quot;:{&quot;captchaError&quot;:&quot;验证码错误&quot;,&quot;login&quot;:&quot;demo-user&quot;,&quot;password&quot;:&quot;&quot;}}"></div>"#,
                    cookies: []
                )
            case "https://www.116pan.xyz/dashboard" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: URL(string: "https://www.116pan.xyz/login")!,
                    headers: [:],
                    body: #"<div id="app" data-page="{&quot;component&quot;:&quot;Auth\/Login&quot;,&quot;props&quot;:{&quot;errors&quot;:{},&quot;auth&quot;:{&quot;user&quot;:null}}}"></div>"#,
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.method.rawValue) \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authMaterialProvider: StaticAuthMaterialProvider(
                storage: [
                    "116pan-vip": [
                        "116pan-demo": [
                            "username": .string("demo-user"),
                            "password": .string("secret-password"),
                        ]
                    ]
                ]
            )
        )

        do {
            _ = try await resolver.resolve(
                DownloadResolveRequest(
                    sourceURL: URL(string: "https://www.116pan.xyz/f/0V02j0lxvpSl")!,
                    accountID: "116pan-demo"
                )
            )
            XCTFail("Expected captcha retry limit error")
        } catch let RuleEngineError.authCaptchaRetryLimitExceeded(providerFamily, attempts) {
            XCTAssertEqual(providerFamily, "116pan-vip")
            XCTAssertEqual(attempts, 50)
        }

        let loginAttemptCount = await recorder.loginAttemptCount()
        XCTAssertEqual(loginAttemptCount, 50)
        let captchaFetchCount = await recorder.captchaFetchCount()
        XCTAssertEqual(captchaFetchCount, 50)
        let loginPageFetchCount = await recorder.loginPageFetchCount()
        XCTAssertEqual(loginPageFetchCount, 1)
    }

    func testKoolaayunVIPAuthWorkflowResolvesRedirectDownloadRequest() async throws {
        let (registry, catalog) = try await makeSyncedCatalog()
        let filePageURL = "https://koolaayun.com/cf6163a33d9e6555/A17684.zip"
        let ptURL = "https://koolaayun.com/cf6163a33d9e6555?pt=encoded-token"
        let tokenURL = "https://koolaayun.com/cf6163a33d9e6555/A17684.zip?download_token=download-token"
        let directURL = "https://xzs2.koalaclouds.com/bf/bf87bc4e90430784836e429cda3996fd?response-content-disposition=attachment;filename%3DA17684.zip"

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://koolaayun.com/account/login" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "filehosting=session-koola; Path=/"],
                    body: #"<form method="post" action="https://koolaayun.com/account/login"><input name="username"><input name="password"></form>"#,
                    cookies: [SerializableCookie(name: "filehosting", value: "session-koola", domain: "koolaayun.com", path: "/")]
                )
            case "https://koolaayun.com/account/login" where request.method == .post:
                XCTAssertFalse(request.followRedirects)
                XCTAssertEqual(request.headers["Content-Type"], "application/x-www-form-urlencoded")
                XCTAssertEqual(request.headers["Origin"], "https://koolaayun.com")
                XCTAssertEqual(request.headers["Referer"], "https://koolaayun.com/account/login")
                XCTAssertEqual(request.body, "password=secret%20password%26x%3D1&submitme=1&username=demo-user")
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("filehosting=session-koola"))
                return HTTPResponseData(
                    statusCode: 302,
                    url: request.url,
                    headers: ["Location": "https://koolaayun.com/account"],
                    body: "",
                    cookies: []
                )
            case "https://koolaayun.com/account" where request.method == .get:
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("filehosting=session-koola"))
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"<a href="https://koolaayun.com/account/logout">登出</a><span>您的文件</span>"#,
                    cookies: []
                )
            case let url where url == filePageURL && request.method == .get:
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("filehosting=session-koola"))
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"<button onclick='window.location.href = "https://koolaayun.com/cf6163a33d9e6555?pt=encoded-token"; return false;'>Download</button>"#,
                    cookies: []
                )
            case let url where url == ptURL && request.method == .get:
                XCTAssertFalse(request.followRedirects)
                XCTAssertEqual(request.headers["Referer"], filePageURL)
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("filehosting=session-koola"))
                return HTTPResponseData(
                    statusCode: 302,
                    url: request.url,
                    headers: ["Location": tokenURL],
                    body: "",
                    cookies: []
                )
            case let url where url == tokenURL && request.method == .head:
                XCTAssertFalse(request.followRedirects)
                XCTAssertEqual(request.headers["Referer"], filePageURL)
                XCTAssertTrue((request.headers["Cookie"] ?? "").contains("filehosting=session-koola"))
                return HTTPResponseData(
                    statusCode: 302,
                    url: request.url,
                    headers: [
                        "Content-Disposition": #"attachment; filename="A17684.zip""#,
                        "Content-Length": "636980123",
                        "Location": directURL,
                    ],
                    body: "",
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.method.rawValue) \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authMaterialProvider: StaticAuthMaterialProvider(
                storage: [
                    "koolaayun-vip": [
                        "koola-demo": [
                            "username": .string("demo-user"),
                            "password": .string("secret password&x=1"),
                        ]
                    ]
                ]
            )
        )

        let resolved = try await resolver.resolve(
            DownloadResolveRequest(
                sourceURL: URL(string: filePageURL)!,
                accountID: "koola-demo"
            )
        )

        XCTAssertEqual(resolved.url.absoluteString, directURL)
        XCTAssertEqual(resolved.headers["Referer"], filePageURL)
        XCTAssertEqual(resolved.filenameHints["provider"], "koolaayun-vip")
        XCTAssertEqual(resolved.filenameHints["directType"], "koolaayun.vip.pt-redirect")
        XCTAssertTrue(resolved.cookies.isEmpty)
        XCTAssertNil(resolved.authContext)
    }

    func testKoolaayunVIPMissingFinalRedirectLocationTriggersAuthRetryNotInvalidTemplate() async throws {
        let (registry, catalog) = try await makeSyncedCatalog()
        let filePageURL = "https://koolaayun.com/cf6163a33d9e6555/A17684.zip"
        let ptURL = "https://koolaayun.com/cf6163a33d9e6555?pt=encoded-token"
        let tokenURL = "https://koolaayun.com/cf6163a33d9e6555/A17684.zip?download_token=download-token"

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://koolaayun.com/account/login" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "filehosting=session-koola; Path=/"],
                    body: #"<form method="post" action="https://koolaayun.com/account/login"><input name="username"><input name="password"></form>"#,
                    cookies: [SerializableCookie(name: "filehosting", value: "session-koola", domain: "koolaayun.com", path: "/")]
                )
            case "https://koolaayun.com/account/login" where request.method == .post:
                return HTTPResponseData(
                    statusCode: 302,
                    url: request.url,
                    headers: ["Location": "https://koolaayun.com/account"],
                    body: "",
                    cookies: []
                )
            case "https://koolaayun.com/account" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"<a href="https://koolaayun.com/account/logout">登出</a><span>您的文件</span>"#,
                    cookies: []
                )
            case let url where url == filePageURL && request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"<button onclick='window.location.href = "https://koolaayun.com/cf6163a33d9e6555?pt=encoded-token"; return false;'>Download</button>"#,
                    cookies: []
                )
            case let url where url == ptURL && request.method == .get:
                XCTAssertFalse(request.followRedirects)
                return HTTPResponseData(
                    statusCode: 302,
                    url: request.url,
                    headers: ["Location": tokenURL],
                    body: "",
                    cookies: []
                )
            case let url where url == tokenURL && request.method == .head:
                XCTAssertFalse(request.followRedirects)
                return HTTPResponseData(
                    statusCode: 302,
                    url: request.url,
                    headers: [
                        "Content-Disposition": #"attachment; filename="A17684.zip""#,
                        "Content-Length": "636980123",
                    ],
                    body: "",
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.method.rawValue) \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authMaterialProvider: StaticAuthMaterialProvider(
                storage: [
                    "koolaayun-vip": [
                        "koola-demo": [
                            "username": .string("demo-user"),
                            "password": .string("secret password"),
                        ]
                    ]
                ]
            )
        )

        do {
            _ = try await resolver.resolve(
                DownloadResolveRequest(
                    sourceURL: URL(string: filePageURL)!,
                    accountID: "koola-demo"
                )
            )
            XCTFail("Expected auth retry exhaustion when the final redirect Location is missing.")
        } catch let RuleEngineError.authExpiredAfterRetry(providerFamily) {
            XCTAssertEqual(providerFamily, "koolaayun-vip")
        } catch let RuleEngineError.invalidTemplate(message) {
            XCTFail("Missing redirect Location must not reach url.origin as an invalid template: \(message)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testKoolaayunVIPAuthWorkflowRejectsInvalidCredentialsUsingConfiguredCondition() async throws {
        let (registry, catalog) = try await makeSyncedCatalog()

        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://koolaayun.com/account/login" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "filehosting=session-koola; Path=/"],
                    body: #"<form method="post" action="https://koolaayun.com/account/login"></form>"#,
                    cookies: [SerializableCookie(name: "filehosting", value: "session-koola", domain: "koolaayun.com", path: "/")]
                )
            case "https://koolaayun.com/account/login" where request.method == .post:
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: [:],
                    body: #"<div class="alert__body">Your username and password are invalid</div>"#,
                    cookies: []
                )
            case "https://koolaayun.com/account" where request.method == .get:
                return HTTPResponseData(
                    statusCode: 200,
                    url: URL(string: "https://koolaayun.com/account/login")!,
                    headers: [:],
                    body: #"<h2>登录</h2>"#,
                    cookies: []
                )
            default:
                XCTFail("Unexpected request: \(request.method.rawValue) \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }

        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authMaterialProvider: StaticAuthMaterialProvider(
                storage: [
                    "koolaayun-vip": [
                        "koola-demo": [
                            "username": .string("demo-user"),
                            "password": .string("bad-password"),
                        ]
                    ]
                ]
            )
        )

        do {
            _ = try await resolver.resolve(
                DownloadResolveRequest(
                    sourceURL: URL(string: "https://koolaayun.com/cf6163a33d9e6555/A17684.zip")!,
                    accountID: "koola-demo"
                )
            )
            XCTFail("Expected credential rejection")
        } catch let RuleEngineError.authCredentialsRejected(providerFamily) {
            XCTAssertEqual(providerFamily, "koolaayun-vip")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Regression coverage for review feedback (2026-04-20)

    /// `authenticate(hostURL:)` must NOT gate on
    /// `authPolicy.requiresAuthentication == true`. The explicit
    /// entry point is always "run this provider's auth workflow
    /// now"; optional-auth providers (workflow configured + policy
    /// relaxed) should still be able to prewarm / refresh through
    /// it. `secure-demo` in the templates fixture has exactly
    /// this shape (authWorkflowID: "secure.auth",
    /// requiresAuthentication: false).
    func testAuthenticateRunsAuthWorkflowForOptionalAuthProvider() async throws {
        let bundle = try RuleBundleFixtures.loadMergedBundle(
            named: [
                "auth-workflows.bundle",
                "auth-sites.bundle",
                "auth-templates.bundle",
            ],
            bundleVersion: "2026.04.20.optional-auth-authenticate.1"
        )
        let (registry, catalog) = try await makeSyncedCatalog(bundle: bundle)

        let authStore = AuthSessionStore()
        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://secure.example.com/login":
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "session=valid; Path=/; Domain=secure.example.com"],
                    body: "ok",
                    cookies: [
                        SerializableCookie(
                            name: "session",
                            value: "valid",
                            domain: "secure.example.com",
                            path: "/"
                        )
                    ]
                )
            default:
                XCTFail("Unexpected request: \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }
        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authSessionStore: authStore,
            authMaterialProvider: CountingAuthMaterialProvider(counter: MaterialCounter())
        )

        let session = try await resolver.authenticate(
            hostURL: URL(string: "https://secure.example.com/")!,
            accountID: "demo"
        )

        XCTAssertEqual(session.cookies.first?.name, "session")
        XCTAssertEqual(session.cookies.first?.value, "valid")
        let stored = await authStore.session(
            for: AuthSessionKey(providerFamily: "secure-demo", accountID: "demo")
        )
        XCTAssertEqual(stored?.cookies.first?.value, "valid")
    }

    /// `runWorkflow(workflowID:)` walks `authWorkflows` during id
    /// lookup, so auth workflows are reachable through this entry
    /// point. Those workflows template `{{materials.username}}` /
    /// `{{materials.password}}`; without a pluggable `materials`
    /// dict, they deterministically throw `.missingVariable`.
    /// Verifies the caller can thread credentials in directly.
    func testRunWorkflowInjectsMaterialsIntoAuthWorkflow() async throws {
        let bundle = try RuleBundleFixtures.loadMergedBundle(
            named: [
                "auth-workflows.bundle",
                "auth-sites.bundle",
                "auth-templates.bundle",
            ],
            bundleVersion: "2026.04.20.runWorkflow-materials.1"
        )
        let (registry, catalog) = try await makeSyncedCatalog(bundle: bundle)

        let authStore = AuthSessionStore()
        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://secure.example.com/login":
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "session=valid; Path=/; Domain=secure.example.com"],
                    body: "ok",
                    cookies: [
                        SerializableCookie(
                            name: "session",
                            value: "valid",
                            domain: "secure.example.com",
                            path: "/"
                        )
                    ]
                )
            default:
                XCTFail("Unexpected request: \(request.url.absoluteString)")
                return HTTPResponseData(statusCode: 500, url: request.url, headers: [:], body: "unexpected")
            }
        }
        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authSessionStore: authStore,
            authMaterialProvider: CountingAuthMaterialProvider(counter: MaterialCounter())
        )

        let result = try await resolver.runWorkflow(
            workflowID: "secure.auth",
            sourceURL: URL(string: "https://secure.example.com/")!,
            variables: [:],
            materials: [
                "username": .string("demo-user"),
                "password": .string("secret-password"),
            ]
        )

        // `secure.auth`: template → http POST /login
        // (persistResponseCookies: true) → assign. Without the
        // materials fix, the first template step throws
        // .missingVariable. With the fix, the workflow completes
        // and surfaces the session cookie in the result.
        XCTAssertEqual(result.authSession?.cookies.first?.name, "session")
        XCTAssertEqual(result.authSession?.cookies.first?.value, "valid")
    }
}
