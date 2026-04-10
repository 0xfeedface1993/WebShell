import XCTest
@testable import WebShell

final class RuleCompilerTests: XCTestCase {
    func testFixtureBundleLoadsFromJSONResource() throws {
        let bundle = RuleBundleFixtures.defaultBundle

        XCTAssertEqual(bundle.bundleVersion, "2026.04.10.catalog.1")
        XCTAssertTrue(bundle.providers.contains { $0.providerFamily == "jkpan-vip" })
        XCTAssertFalse(bundle.providers.contains { $0.providerFamily == "xrcf-vip" })
        XCTAssertFalse(bundle.providers.contains { $0.providerFamily == "secure-demo" })
        XCTAssertTrue(bundle.authWorkflows.contains { $0.id == "legacy.vip.xsrfCaptcha.auth" })
        XCTAssertTrue(bundle.authWorkflows.contains { $0.id == "legacy.vip.formhashCaptcha.auth" })
        XCTAssertTrue(bundle.authWorkflows.contains { $0.id == "legacy.vip.fastlogin.auth" })
        XCTAssertFalse(bundle.downloadWorkflows.contains { $0.id == "legacy.vip.generateDownload" })
        XCTAssertTrue(bundle.capabilityRefs.contains { $0.name == "cookies.valueForName" && $0.required })
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
            XCTAssertEqual(name, "cookies.valueForName")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
