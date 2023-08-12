//
//  WebShellCoreTests.swift
//  WebShellCoreTests
//
//  Created by virus1994 on 2018/12/28.
//  Copyright © 2018 ascp. All rights reserved.
//

import XCTest
@testable import WebShell

class WebShellCoreTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let url = URL(string: "http://sportal.wa54.space/portal/file/download?id=302826")!
        XCTAssert(url.absoluteString == "http://sportal.wa54.space/portal/file/download?id=302826", "错误地址")
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testAsciiMD5() throws {
        XCTAssert("f273dad1289b7bfd1a9be6376813b922".asciiHexMD5String() == "043dab3b1919027b4df82aea32a649b8", "md5 failed!")
    }
}
