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

    /// `authenticate(hostURL:)` must match providers by host
    /// alone, not by full URL matcher (which includes
    /// `pathPattern`). Providers whose matchers pin a download
    /// path — e.g. `jkpan-vip` with `/file-\d+\.html$` — must
    /// still resolve for a plain host URL like
    /// `https://jkpan.com/`, otherwise prewarm/refresh is
    /// unreachable from callers that don't already have a
    /// specific download URL.
    func testAuthenticateMatchesProviderByHostIgnoringPathPattern() async throws {
        let bundle = try RuleBundleFixtures.loadMergedBundle(
            named: [
                "auth-workflows.bundle",
                "auth-sites.bundle",
                "auth-templates.bundle",
            ],
            bundleVersion: "2026.04.20.authenticate-host-only.1"
        )
        let (registry, catalog) = try await makeSyncedCatalog(bundle: bundle)

        // Lenient client: we only care that provider resolution
        // succeeds (no `noMatchingProvider`). The auth workflow
        // for jkpan-vip would need full captcha / formhash
        // mocking to actually complete — that's not what this
        // test exercises.
        let httpClient = StubHTTPClient { request in
            HTTPResponseData(
                statusCode: 200,
                url: request.url,
                headers: [:],
                body: ""
            )
        }
        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authSessionStore: AuthSessionStore(),
            authMaterialProvider: CountingAuthMaterialProvider(counter: MaterialCounter())
        )

        do {
            _ = try await resolver.authenticate(
                hostURL: URL(string: "https://jkpan.com/")!,
                accountID: "demo"
            )
            // A successful return is also fine — means the entire
            // auth flow happened to tolerate the lenient responses.
        } catch RuleEngineError.noMatchingProvider(let info) {
            XCTFail("host-only URL should resolve jkpan-vip via matchesHost; got noMatchingProvider(\(info))")
        } catch {
            // Any other error is fine — we only assert the
            // provider-lookup gate, not the workflow itself.
        }
    }

    /// `runWorkflow(workflowID:)` must preserve the declaring
    /// provider's identity. `WorkflowRuntime` forwards
    /// `provider.rule.providerFamily` into `CapabilityInvocation`
    /// and into the default session key; before the fix those
    /// saw `"standalone"` even when the workflow was declared by
    /// a real provider, so sessions persisted by runWorkflow
    /// couldn't be reused by later `resolve(_:)` calls against
    /// the same provider. This test asserts the session lands
    /// under the owner's family (`secure-demo`), not the
    /// synthetic stub.
    func testRunWorkflowPreservesDeclaringProviderContext() async throws {
        let bundle = try RuleBundleFixtures.loadMergedBundle(
            named: [
                "auth-workflows.bundle",
                "auth-sites.bundle",
                "auth-templates.bundle",
            ],
            bundleVersion: "2026.04.20.runWorkflow-provider-context.1"
        )
        let (registry, catalog) = try await makeSyncedCatalog(bundle: bundle)

        let authStore = AuthSessionStore()
        let httpClient = StubHTTPClient { request in
            switch request.url.absoluteString {
            case "https://secure.example.com/login":
                return HTTPResponseData(
                    statusCode: 200,
                    url: request.url,
                    headers: ["Set-Cookie": "session=owner; Path=/; Domain=secure.example.com"],
                    body: "ok",
                    cookies: [
                        SerializableCookie(
                            name: "session",
                            value: "owner",
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

        _ = try await resolver.runWorkflow(
            workflowID: "secure.auth",
            sourceURL: URL(string: "https://secure.example.com/")!,
            variables: [:],
            materials: [
                "username": .string("demo-user"),
                "password": .string("secret-password"),
            ]
        )

        // With the fix: sessionKey inherits the owning
        // provider's family (`secure-demo`), so the persisted
        // session is reachable under that key. Before the fix,
        // it would only be reachable under
        // `("standalone","default")`.
        let underOwner = await authStore.session(
            for: AuthSessionKey(providerFamily: "secure-demo", accountID: "default")
        )
        XCTAssertEqual(underOwner?.cookies.first?.value, "owner")

        // Cross-check: the synthetic key used by the pre-fix
        // code path should be empty — no session should have
        // leaked there.
        let underStandalone = await authStore.session(
            for: AuthSessionKey(providerFamily: "standalone", accountID: "default")
        )
        XCTAssertNil(underStandalone, "session must not land under the synthetic standalone key")
    }

    /// When a workflow id is declared by more than one provider
    /// (e.g. legacy-sites.bundle has both `xueqiupan-public` and
    /// `xunniufile-public` declaring `generic.loadDownAddr1.dlphp`),
    /// `provider(declaringWorkflowID:sourceURL:)` must use the
    /// caller's `sourceURL` to disambiguate. Hosts that are
    /// completely disjoint between the declaring providers can
    /// be resolved deterministically.
    func testProviderDeclaringWorkflowIDDisambiguatesByURL() async throws {
        let bundle = try makeLegacySitesBundle()
        let (_, catalog) = try await makeSyncedCatalog(bundle: bundle)
        let compiled = await catalog.currentCompiledBundle()
        XCTAssertNotNil(compiled)

        // Full URL with pathPattern hit — strict match should
        // pick the matching provider.
        let xueqiupan = try compiled?.provider(
            declaringWorkflowID: "generic.loadDownAddr1.dlphp",
            sourceURL: URL(string: "http://www.xueqiupan.com/file-672734.html")!
        )
        XCTAssertEqual(xueqiupan?.rule.providerFamily, "xueqiupan")

        let xunniufile = try compiled?.provider(
            declaringWorkflowID: "generic.loadDownAddr1.dlphp",
            sourceURL: URL(string: "http://www.xunniufile.com/file-672734.html")!
        )
        XCTAssertEqual(xunniufile?.rule.providerFamily, "xunniufile")

        // Host-only URL (no pathPattern hit) — must fall through
        // to host match and still pick the right provider.
        let xunniufileHostOnly = try compiled?.provider(
            declaringWorkflowID: "generic.loadDownAddr1.dlphp",
            sourceURL: URL(string: "https://www.xunniufile.com/")!
        )
        XCTAssertEqual(xunniufileHostOnly?.rule.providerFamily, "xunniufile")

        // Unrelated host — neither strict nor host match. No
        // longer falls back to `.first` (that was a silent
        // arbitrary pick flagged by review); returns nil so
        // runWorkflow uses the honestly-labelled synthetic
        // "standalone" stub instead.
        let noHostMatch = try compiled?.provider(
            declaringWorkflowID: "generic.loadDownAddr1.dlphp",
            sourceURL: URL(string: "https://unrelated.example.com/")!
        )
        XCTAssertNil(noHostMatch, "unrelated host should yield nil, not an arbitrary first-candidate")
    }

    /// Compilation enforces uniqueness WITHIN each workflow list
    /// but not across; a bundle can legally declare the same id
    /// in both `downloadWorkflows` and `authWorkflows`.
    /// `workflow(id:)` must surface the ambiguity as
    /// `.ambiguousWorkflow(id)` rather than silently returning
    /// whichever list is scanned first (which would make the
    /// other category's definition unreachable by id through
    /// `runWorkflow`).
    func testWorkflowLookupThrowsOnCrossListAmbiguity() async throws {
        let json = """
        {
          "schemaVersion": 1,
          "bundleVersion": "2026.04.20.ambiguous-workflow.1",
          "providers": [],
          "sharedFragments": [],
          "authWorkflows": [
            {"id": "shared.id", "description": "auth copy", "steps": []}
          ],
          "downloadWorkflows": [
            {"id": "shared.id", "description": "download copy", "steps": []}
          ],
          "capabilityRefs": []
        }
        """
        let bundle = try JSONDecoder().decode(RuleBundle.self, from: Data(json.utf8))
        let (_, catalog) = try await makeSyncedCatalog(bundle: bundle)
        let compiled = await catalog.currentCompiledBundle()
        XCTAssertNotNil(compiled)

        do {
            _ = try compiled?.workflow(id: "shared.id")
            XCTFail("expected ambiguousWorkflow error")
        } catch RuleEngineError.ambiguousWorkflow(let id) {
            XCTAssertEqual(id, "shared.id")
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        // Unknown id still returns nil (not thrown) — callers
        // then map that to `.missingWorkflow`.
        let unknown = try compiled?.workflow(id: "does-not-exist")
        XCTAssertNil(unknown)
    }

    /// `runWorkflow(workflowID:)`'s default session key must
    /// honour the owner's `authPolicy.accountIDTemplate`. Before
    /// the fix, `accountID` was hard-coded to `"default"`, so
    /// sessions prewarmed via `runWorkflow` for a templated
    /// provider landed under a key that `resolve(_:)` would never
    /// look up — breaking session reuse across entry points and
    /// causing different logical accounts to overwrite each
    /// other under the default key.
    func testRunWorkflowDefaultAccountIDAppliesProviderTemplate() async throws {
        let json = """
        {
          "schemaVersion": 1,
          "bundleVersion": "2026.04.20.accountID-template.1",
          "providers": [
            {
              "id": "templated-demo",
              "providerFamily": "templated-demo",
              "accountScope": "providerFamily",
              "matchers": [
                {"hosts": ["templated.example.com"], "hostSuffixes": []}
              ],
              "downloadWorkflowID": "templated.placeholder.download",
              "authWorkflowID": "templated.auth",
              "authPolicy": {
                "expireConditions": [],
                "materialKeys": ["username"],
                "requiresAuthentication": false,
                "accountIDTemplate": "{{input.variables.slug}}"
              },
              "metadata": {}
            }
          ],
          "sharedFragments": [],
          "authWorkflows": [
            {
              "id": "templated.auth",
              "description": "Minimal auth flow just to exercise session persistence keying.",
              "steps": [
                {
                  "type": "http",
                  "http": {
                    "method": "POST",
                    "urlTemplate": "https://templated.example.com/login",
                    "headers": {"Content-Type": "application/x-www-form-urlencoded"},
                    "bodyTemplate": "ok",
                    "output": "loginResponse",
                    "persistResponseCookies": true,
                    "attachAuthSession": false
                  }
                }
              ]
            }
          ],
          "downloadWorkflows": [
            {
              "id": "templated.placeholder.download",
              "description": "Unused; satisfies ProviderRule.downloadWorkflowID.",
              "steps": []
            }
          ],
          "capabilityRefs": []
        }
        """
        let bundle = try JSONDecoder().decode(RuleBundle.self, from: Data(json.utf8))
        let (registry, catalog) = try await makeSyncedCatalog(bundle: bundle)

        let authStore = AuthSessionStore()
        let httpClient = StubHTTPClient { request in
            HTTPResponseData(
                statusCode: 200,
                url: request.url,
                headers: ["Set-Cookie": "session=t; Path=/; Domain=templated.example.com"],
                body: "ok",
                cookies: [
                    SerializableCookie(
                        name: "session",
                        value: "t",
                        domain: "templated.example.com",
                        path: "/"
                    )
                ]
            )
        }
        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: httpClient,
            capabilityRegistry: registry,
            authSessionStore: authStore,
            authMaterialProvider: CountingAuthMaterialProvider(counter: MaterialCounter())
        )

        _ = try await resolver.runWorkflow(
            workflowID: "templated.auth",
            sourceURL: URL(string: "https://templated.example.com/")!,
            variables: ["slug": .string("user42")]
        )

        // accountIDTemplate `{{input.variables.slug}}` resolves
        // to "user42"; the persisted session must land there.
        let underTemplated = await authStore.session(
            for: AuthSessionKey(providerFamily: "templated-demo", accountID: "user42")
        )
        XCTAssertEqual(underTemplated?.cookies.first?.value, "t")

        // Before the fix, the session would be keyed under
        // "default". Cross-assert nothing leaked there.
        let underDefault = await authStore.session(
            for: AuthSessionKey(providerFamily: "templated-demo", accountID: "default")
        )
        XCTAssertNil(underDefault, "session must not land under 'default' when template is configured")
    }

    /// Compilation allows two providers to share a host as long
    /// as their `pathPattern`s differ. For that (legal) shape,
    /// `authenticate(hostURL:)` with a plain host URL can't pick
    /// a single provider — `.ambiguousHostMatch` must be thrown
    /// rather than silently running the first provider's auth
    /// workflow and persisting the session under its family.
    /// A URL whose path hits exactly one provider's pathPattern
    /// must still resolve cleanly.
    func testAuthenticateThrowsAmbiguousHostMatchOnOverloadedHost() async throws {
        let json = """
        {
          "schemaVersion": 1,
          "bundleVersion": "2026.04.20.host-overlap.1",
          "providers": [
            {
              "id": "overlap-a",
              "providerFamily": "overlap-a",
              "accountScope": "providerFamily",
              "matchers": [
                {
                  "hosts": ["overlap.example.com"],
                  "hostSuffixes": [],
                  "pathPattern": "/a/.*"
                }
              ],
              "downloadWorkflowID": "overlap.download",
              "authWorkflowID": "overlap.auth",
              "authPolicy": null,
              "metadata": {}
            },
            {
              "id": "overlap-b",
              "providerFamily": "overlap-b",
              "accountScope": "providerFamily",
              "matchers": [
                {
                  "hosts": ["overlap.example.com"],
                  "hostSuffixes": [],
                  "pathPattern": "/b/.*"
                }
              ],
              "downloadWorkflowID": "overlap.download",
              "authWorkflowID": "overlap.auth",
              "authPolicy": null,
              "metadata": {}
            }
          ],
          "sharedFragments": [],
          "authWorkflows": [
            {"id": "overlap.auth", "description": "", "steps": []}
          ],
          "downloadWorkflows": [
            {"id": "overlap.download", "description": "", "steps": []}
          ],
          "capabilityRefs": []
        }
        """
        let bundle = try JSONDecoder().decode(RuleBundle.self, from: Data(json.utf8))
        let (registry, catalog) = try await makeSyncedCatalog(bundle: bundle)
        let resolver = DownloadResolver(
            catalog: catalog,
            httpClient: StubHTTPClient { r in
                HTTPResponseData(statusCode: 200, url: r.url, headers: [:], body: "")
            },
            capabilityRegistry: registry,
            authSessionStore: AuthSessionStore(),
            authMaterialProvider: CountingAuthMaterialProvider(counter: MaterialCounter())
        )

        // Plain host URL — cannot disambiguate between
        // overlap-a and overlap-b.
        do {
            _ = try await resolver.authenticate(
                hostURL: URL(string: "https://overlap.example.com/")!
            )
            XCTFail("expected ambiguousHostMatch for overloaded host without path")
        } catch RuleEngineError.ambiguousHostMatch(let host) {
            XCTAssertEqual(host, "overlap.example.com")
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        // URL whose path satisfies only overlap-a's pathPattern
        // — strict match picks overlap-a; no ambiguous error.
        do {
            _ = try await resolver.authenticate(
                hostURL: URL(string: "https://overlap.example.com/a/1")!
            )
            // An empty-step auth workflow throws
            // `.authDidNotProduceSession`; that's fine here,
            // we're only asserting provider selection didn't
            // throw `.ambiguousHostMatch`.
        } catch RuleEngineError.ambiguousHostMatch {
            XCTFail("strict pathPattern match should have disambiguated to overlap-a")
        } catch {
            // Any other error (e.g. authDidNotProduceSession) is
            // acceptable — workflow execution isn't under test.
        }
    }

    /// `provider(declaringWorkflowID:sourceURL:)` must surface
    /// ambiguity the same way `provider(hostMatching:)` does.
    /// When multiple providers declare the same workflow id AND
    /// their matcher regexes overlap at runtime for a given
    /// URL, silently picking `first` is a correctness bug
    /// (wrong family / metadata / default session key). Two
    /// providers both accepting `overlap.example.com` + sharing
    /// a `downloadWorkflowID` exercise both the strict-multi
    /// and host-only-multi paths.
    func testProviderDeclaringWorkflowIDThrowsOnAmbiguousSourceURL() async throws {
        // overlap-a: pathPattern /.*      (matches everything)
        // overlap-b: pathPattern /shared/.+ (subset of /.*)
        // sourceURL /shared/x → strict match BOTH → throw
        // sourceURL /          → strict match only overlap-a → clean pick
        let json = """
        {
          "schemaVersion": 1,
          "bundleVersion": "2026.04.20.owner-overlap.1",
          "providers": [
            {
              "id": "overlap-a",
              "providerFamily": "overlap-a",
              "accountScope": "providerFamily",
              "matchers": [
                {"hosts": ["overlap.example.com"], "hostSuffixes": [], "pathPattern": "/.*"}
              ],
              "downloadWorkflowID": "overlap.shared.download",
              "authWorkflowID": null,
              "authPolicy": null,
              "metadata": {}
            },
            {
              "id": "overlap-b",
              "providerFamily": "overlap-b",
              "accountScope": "providerFamily",
              "matchers": [
                {"hosts": ["overlap.example.com"], "hostSuffixes": [], "pathPattern": "/shared/.+"}
              ],
              "downloadWorkflowID": "overlap.shared.download",
              "authWorkflowID": null,
              "authPolicy": null,
              "metadata": {}
            }
          ],
          "sharedFragments": [],
          "authWorkflows": [],
          "downloadWorkflows": [
            {"id": "overlap.shared.download", "description": "", "steps": []}
          ],
          "capabilityRefs": []
        }
        """
        let bundle = try JSONDecoder().decode(RuleBundle.self, from: Data(json.utf8))
        let (_, catalog) = try await makeSyncedCatalog(bundle: bundle)
        let compiled = await catalog.currentCompiledBundle()
        XCTAssertNotNil(compiled)

        // Ambiguous strict match: /shared/x hits both
        // pathPatterns. Must throw.
        do {
            _ = try compiled?.provider(
                declaringWorkflowID: "overlap.shared.download",
                sourceURL: URL(string: "https://overlap.example.com/shared/item")!
            )
            XCTFail("expected ambiguousWorkflowOwner under strict-multi")
        } catch RuleEngineError.ambiguousWorkflowOwner(let id) {
            XCTAssertEqual(id, "overlap.shared.download")
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        // Clean strict pick: / only matches overlap-a's
        // greedy /.* pathPattern, not overlap-b's /shared/.+ .
        let cleanPick = try compiled?.provider(
            declaringWorkflowID: "overlap.shared.download",
            sourceURL: URL(string: "https://overlap.example.com/")!
        )
        XCTAssertEqual(cleanPick?.rule.providerFamily, "overlap-a")
    }
}
