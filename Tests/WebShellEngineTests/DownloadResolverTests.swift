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

final class DownloadResolverTests: XCTestCase {
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
        let (registry, catalog) = try await makeSyncedCatalog()

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
        let (registry, catalog) = try await makeSyncedCatalog()

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
        let (registry, catalog) = try await makeSyncedCatalog()

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
        let (registry, catalog) = try await makeSyncedCatalog()

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
        let (registry, catalog) = try await makeSyncedCatalog()

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
        let (registry, catalog) = try await makeSyncedCatalog()

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
                "public-sites.bundle",
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
                "public-sites.bundle",
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
}
