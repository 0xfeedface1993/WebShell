import Foundation
import XCTest
@testable import WebShell

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class URLSessionHTTPClientTests: XCTestCase {
    func testSendIncludesCookiesAlreadyHeldByURLSessionStorage() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CookieEchoURLProtocol.self]
        let cookieStorage = try XCTUnwrap(configuration.httpCookieStorage)
        let requestURL = try XCTUnwrap(URL(string: "https://redirect-cookie.test/dashboard"))
        let cookie = try XCTUnwrap(
            HTTPCookie(properties: [
                .domain: "redirect-cookie.test",
                .path: "/",
                .name: "session",
                .value: "redirected",
            ])
        )
        cookieStorage.setCookie(cookie)

        let client = URLSessionHTTPClient(configuration: configuration)
        let response = try await client.send(
            HTTPRequestData(
                method: .get,
                url: requestURL,
                headers: [:],
                body: nil
            )
        )

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertTrue(
            response.cookies.contains {
                $0.name == "session"
                && $0.value == "redirected"
                && $0.domain == "redirect-cookie.test"
            },
            "URLSession-held cookies should be surfaced in HTTPResponseData so auth sessions survive redirect-based login flows."
        )
    }
}

private final class CookieEchoURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "redirect-cookie.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [:]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("ok".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}
