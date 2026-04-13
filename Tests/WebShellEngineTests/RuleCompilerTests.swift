import XCTest
@testable import WebShell

final class RuleCompilerTests: XCTestCase {
    func testFixtureBundleLoadsFromJSONResource() throws {
        let bundle = RuleBundleFixtures.defaultBundle

        XCTAssertEqual(bundle.bundleVersion, "2026.04.13.catalog.koolaayun.3")
        XCTAssertEqual(bundle.providers.map(\.providerFamily).sorted(), ["116pan-vip", "jkpan-vip", "koolaayun-vip"])
        XCTAssertTrue(bundle.providers.contains { $0.providerFamily == "jkpan-vip" })
        XCTAssertTrue(bundle.providers.contains { $0.providerFamily == "116pan-vip" })
        XCTAssertTrue(bundle.providers.contains { $0.providerFamily == "koolaayun-vip" })
        XCTAssertFalse(bundle.providers.contains { $0.providerFamily == "rosefile" })
        XCTAssertFalse(bundle.providers.contains { $0.providerFamily == "xueqiupan" })
        XCTAssertFalse(bundle.providers.contains { $0.providerFamily == "xunniufile" })
        XCTAssertFalse(bundle.providers.contains { $0.providerFamily == "xingyaoclouds" })
        XCTAssertFalse(bundle.providers.contains { $0.providerFamily == "rarp" })
        XCTAssertFalse(bundle.providers.contains { $0.providerFamily == "567file" })
        XCTAssertFalse(bundle.providers.contains { $0.providerFamily == "iycdn" })
        XCTAssertFalse(bundle.providers.contains { $0.providerFamily == "xrcf-vip" })
        XCTAssertFalse(bundle.providers.contains { $0.providerFamily == "secure-demo" })
        XCTAssertEqual(bundle.authWorkflows.map(\.id).sorted(), ["116pan.vip.captcha.auth", "koolaayun.account.form.auth", "legacy.vip.formhashCaptcha.auth"])
        XCTAssertTrue(bundle.authWorkflows.contains { $0.id == "116pan.vip.captcha.auth" })
        XCTAssertTrue(bundle.authWorkflows.contains { $0.id == "koolaayun.account.form.auth" })
        XCTAssertTrue(bundle.authWorkflows.contains { $0.id == "legacy.vip.formhashCaptcha.auth" })
        XCTAssertFalse(bundle.authWorkflows.contains { $0.id == "secure.auth" })
        XCTAssertFalse(bundle.authWorkflows.contains { $0.id == "legacy.vip.xsrfCaptcha.auth" })
        XCTAssertFalse(bundle.authWorkflows.contains { $0.id == "legacy.vip.fastlogin.auth" })
        XCTAssertTrue(bundle.downloadWorkflows.contains { $0.id == "116pan.vip.generateDownload" })
        XCTAssertTrue(bundle.downloadWorkflows.contains { $0.id == "koolaayun.vip.ptRedirectDownload" })
        XCTAssertFalse(bundle.downloadWorkflows.contains { $0.id == "legacy.vip.generateDownload" })
        XCTAssertEqual(
            bundle.providers.first { $0.providerFamily == "116pan-vip" }?.authPolicy?.materialKeys,
            ["username", "password"]
        )
        XCTAssertEqual(
            bundle.providers.first { $0.providerFamily == "116pan-vip" }?.authPolicy?.captchaRetryPolicy?.mode,
            .refreshCaptcha
        )
        XCTAssertEqual(
            bundle.providers.first { $0.providerFamily == "116pan-vip" }?.authPolicy?.captchaRetryPolicy?.startAtOutput,
            "captchaImage"
        )
        XCTAssertEqual(
            bundle.providers.first { $0.providerFamily == "116pan-vip" }?.authPolicy?.captchaRetryPolicy?.maxAttempts,
            50
        )
        XCTAssertEqual(bundle.capabilityRefs.map(\.name), ["captcha.ocr", "cookies.valueForName", "payload.formURLEncoded", "url.origin", "url.percentDecode"])
    }

    func test116PanProviderMatchesCanonicalXyzAndComHosts() throws {
        let provider = try XCTUnwrap(
            RuleBundleFixtures.defaultBundle.providers.first { $0.providerFamily == "116pan-vip" }
        )

        XCTAssertTrue(provider.matchers.contains { $0.matches(url: URL(string: "https://www.116pan.xyz/f/0V02j0lxvpSl")!) })
        XCTAssertTrue(provider.matchers.contains { $0.matches(url: URL(string: "https://116pan.xyz/f/0V02j0lxvpSl")!) })
        XCTAssertTrue(provider.matchers.contains { $0.matches(url: URL(string: "https://www.116pan.com/f/0V02j0lxvpSl")!) })
        XCTAssertTrue(provider.matchers.contains { $0.matches(url: URL(string: "https://116pan.com/f/0V02j0lxvpSl")!) })
        XCTAssertFalse(provider.matchers.contains { $0.matches(url: URL(string: "https://www.116pan.com/viewfile.php?file_id=471463")!) })
    }

    func testKoolaayunProviderMatchesVerifiedZipPathOnly() throws {
        let provider = try XCTUnwrap(
            RuleBundleFixtures.defaultBundle.providers.first { $0.providerFamily == "koolaayun-vip" }
        )

        XCTAssertTrue(provider.matchers.contains { $0.matches(url: URL(string: "https://koolaayun.com/cf6163a33d9e6555/A17684.zip")!) })
        XCTAssertTrue(provider.matchers.contains { $0.matches(url: URL(string: "https://www.koolaayun.com/cf6163a33d9e6555/A17684.zip")!) })
        XCTAssertFalse(provider.matchers.contains { $0.matches(url: URL(string: "https://koolaayun.com/cf6163a33d9e6555")!) })
        XCTAssertFalse(provider.matchers.contains { $0.matches(url: URL(string: "https://koolaayun.com/account/login")!) })
    }

    func testSyncPersistsAndActivatesBundle() async throws {
        let registry = CapabilityRegistry.standard()
        let store = InMemoryRuleBundleStore()
        let catalog = RuleCatalog()
        let client = ConfigSyncClient(
            remoteSource: StaticRuleBundleRemoteSource(bundle: RuleBundleFixtures.defaultBundle),
            store: store,
            catalog: catalog,
            compiler: RuleCompiler(),
            capabilityRegistry: registry
        )

        let snapshot = try await client.sync()
        let loaded = try await store.load()
        let active = await catalog.currentSnapshot()

        XCTAssertEqual(snapshot.bundle.bundleVersion, loaded?.bundle.bundleVersion)
        XCTAssertEqual(snapshot.bundle.bundleVersion, active?.bundle.bundleVersion)
    }

    func testCompilerRejectsMissingCapability() async throws {
        let compiler = RuleCompiler()
        let registry = CapabilityRegistry(registerBuiltins: false)
        let snapshot = RuleBundleSnapshot(bundle: RuleBundleFixtures.defaultBundle, origin: .bundled)

        do {
            _ = try await compiler.compile(snapshot: snapshot, previous: nil, capabilityRegistry: registry)
            XCTFail("Expected missing capability error")
        } catch let RuleEngineError.missingCapability(name) {
            XCTAssertTrue(
                ["captcha.ocr", "cookies.valueForName", "payload.formURLEncoded", "url.origin", "url.percentDecode"].contains(name)
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
