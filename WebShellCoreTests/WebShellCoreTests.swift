//
//  WebShellCoreTests.swift
//  WebShellCoreTests
//
//  Created by virus1994 on 2018/12/28.
//  Copyright © 2018 ascp. All rights reserved.
//

import XCTest

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

    func testXunNiuLinkParser() {
        let fileLink = "http://175.6.244.107:8011/dl2.php?M2FjY3U4WTNYdG5HRXFYK2R4YVl3VTR2M1diOGtDcmRjZlJlNWNCUzkrSmZaU0ZoeGlucXYrcWVsS0JWUzhaMTNaWU0wV29ERDFsQUkvY2pTT3RNa2Myc0Q2c3ZQbHkwdFZReFlabW1XVU9YVCtuUWEvNWhucGtIamV3MTZZL2xSUTdTMk0rU280Qm90S1dia21Xd2lHeWhiZUJYb08zazU0SDdCbGVRSW5pT1lhcGc2QWJjNFRYMEx4QXdGTzU3REk5QjRZNVNCTzV3VUx4czhTNDRuSEQxQSs3ZWs0VUVjQjE3Qk8vUGlIbENJQ0pjV0dv/phpdisk/93e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c994393e2a7c8de6ead0dcc80d4c3b00c9943&sign=4d22324896aa1e623a9cafec08b5d468"
        let body = "true|<a href=\"vip.php?m=3b9dk3KoQ6%2F9HM0nGhWgZuGGSzMMcBM%2B6yAacDsh0Z2R76%2FUbp%2ByQatmlMDfOnwsRqeSbd38BZ%2B5JYMeG7d%2B8N4B5htRIliZQCc\" onclick=\"return confirm('此功能为VIP专用，现在开通VIP？');\" target=\"_blank\" class=\"down_btn\"><span>&nbsp;VIP下载一</span></a><a href=\"vip.php?m=7bc5J%2Fbu8VGhKM6mkOQCzecfo2%2FLLrpLG0Tdz7mN%2F72uIIdHv6Ia68WXtGfbEhnDnaqCRYYL0rKXkm7HEzg3SoLNjQ4GCbbcoO8\" onclick=\"return confirm('此功能为VIP专用，现在开通VIP？');\" target=\"_blank\" class=\"down_btn\"><span>&nbsp;VIP下载二</span></a><a href=\"\(fileLink)\" onclick=\"down_process2('27649');\" target=\"_blank\" class=\"down_btn\" data-placement=\"bottom\" data-rel=\"tooltip\" data-original-title=\"不支持使用迅雷等下载工具\"><span>&nbsp;普通下载</span></a>"
        
        let niu = XunNiu(urlString: "http://www.xun-niu.com/file-27649.html")
        let link = niu.parserFileLink(body: body)
        XCTAssert(link != nil, "未找到地址")
        XCTAssert(link!.absoluteString == fileLink, "地址解析失败：\(link!.absoluteString)")
    }
}
