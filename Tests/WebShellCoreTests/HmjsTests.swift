import Testing
@testable import hmjs

struct HmjsTests {
    // Fixture mirrors the hm.js config shape for regex extraction.
    private let sampleJS = """
    (function() {
        var c = {
            id: \"fe102b73da12a08f8aee7f4b96f4709a\",
            dm: [\"koalaclouds.com\", \".example.net\"],
            hca: '24F8A216812BCA2E'
        };
    })();
    """

    @Test("extractHMAccount parses hca from the js snippet")
    func testExtractHMAccount() throws {
        let account = try extractHMAccount(sampleJS)
        #expect(account == "24F8A216812BCA2E")
    }

    @Test("extractID parses id from the js snippet")
    func testExtractID() throws {
        let id = try extractID(sampleJS)
        #expect(id == "fe102b73da12a08f8aee7f4b96f4709a")
    }

    @Test("extractDomains parses domain array from the js snippet")
    func testExtractDomains() throws {
        let domains = try extractDomains(sampleJS)
        #expect(domains == ["koalaclouds.com", ".example.net"])
    }

    @Test("fallback: extractHMAccount uses NSRegularExpression")
    func testExtractHMAccountFallback() throws {
        let account = try extractHMAccountFallback(sampleJS)
        #expect(account == "24F8A216812BCA2E")
    }

    @Test("fallback: extractID uses NSRegularExpression")
    func testExtractIDFallback() throws {
        let id = try extractIDFallback(sampleJS)
        #expect(id == "fe102b73da12a08f8aee7f4b96f4709a")
    }

    @Test("fallback: extractDomains uses NSRegularExpression")
    func testExtractDomainsFallback() throws {
        let domains = try extractDomainsFallback(sampleJS)
        #expect(domains == ["koalaclouds.com", ".example.net"])
    }

    @Test("updateHmCookies appends a new session and trims to maxEntries")
    func testUpdateHmCookiesAppendsAndTrims() {
        let result = updateHmCookies(
            siteId: "site",
            existingLvt: "1,2,3,4",
            existingLpvt: "0",
            nowSeconds: 10,
            vdur: 1,
            maxEntries: 3,
            windowSeconds: 9_999,
            ageSeconds: 60,
            domain: "example.com"
        )
        #expect(result.lvt == "3,4,10")
        #expect(result.lpvt == "10")
        #expect(result.cookies.count == 2)
        let names = result.cookies.map(\.name).sorted()
        #expect(names == ["Hm_lpvt_site", "Hm_lvt_site"])
        #expect(result.cookies.allSatisfy { $0.domain == "example.com" })
    }

    @Test("updateHmCookies keeps lvt when within vdur window")
    func testUpdateHmCookiesSameSessionKeepsLvt() {
        let result = updateHmCookies(
            siteId: "site",
            existingLvt: "100,200",
            existingLpvt: "2000",
            nowSeconds: 2005,
            vdur: 10,
            maxEntries: 4,
            windowSeconds: 9_999,
            ageSeconds: 60,
            domain: "example.com"
        )
        #expect(result.lvt == "100,200")
        #expect(result.lpvt == "2005")
    }
}
