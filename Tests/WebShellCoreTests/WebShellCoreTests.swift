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
    
    func test666PanLinkListPaser() {
        let html = "true|<a href=\"vip.php?m=257c%2BnlgEUtH%2B67pCaP5%2Bn3yTGJtFwQuagofEe5i0jYvrI%2BlUeYWUW6XFoYw2fYjlRuaR%2BHht5e5KPMS5noDvvlDSZo4l%2F8oIJgB\" onclick=\"return confirm('此功能为VIP专用，现在开通VIP？');\" target=\"_blank\" class=\"down_btn\"><span>&nbsp;VIP下载-1</span></a><a href=\"vip.php?m=6855DuU%2Fti%2BbAb%2BHyx9S71vG9GtB9tSFXGV51Lz3JtEAarSPybVc0Q8SbCQckoMnrU5ElCkNUMog1jZaVu%2Bzalyum4fPE2y0o8un\" onclick=\"return confirm('此功能为VIP专用，现在开通VIP？');\" target=\"_blank\" class=\"down_btn\"><span>&nbsp;VIP下载-2</span></a><a href=\"vip.php?m=f895496%2Frv4Po2KKuFGSMRz68iv2btcwfOfuYVM79%2F0ycJfLKVFOak%2B6ceN0psmkNdptHSQyaLNeiJQv5H%2F0RhXkwXv%2FFpHpLsQE\" onclick=\"return confirm('此功能为VIP专用，现在开通VIP？');\" target=\"_blank\" class=\"down_btn\"><span>&nbsp;VIP下载-3</span></a><a href=\"vip.php?m=77dcyqYHlpjZrcY71fTQoMzRLKBH9vGjaSlHcKN5QaYLqbRZbMBi9olJg51J5VaMpHPFWUYlkePI0ZX37vV%2F9k06QX%2BF7L5VBUdc\" onclick=\"return confirm('此功能为VIP专用，现在开通VIP？');\" target=\"_blank\" class=\"down_btn\"><span>&nbsp;VIP下载-4</span></a><a href=\"vip.php?m=20a89%2BjnMPGI6ZRODpE1VCNOzJw2ng4t2AkElUFuDBk5KtkSlMtVTTDKpyEgqETjzDZQEv%2FG1kcgpQYXeUKXPleIzhfVow7lwyPx\" onclick=\"return confirm('此功能为VIP专用，现在开通VIP？');\" target=\"_blank\" class=\"down_btn\"><span>&nbsp;VIP下载-5</span></a><a href=\"vip.php?m=b200lDwYAk%2FHHlcKYO4ZvBHVrLFNzYczMrIo5hQpDm5tDPd98svEKC92Y6s14jBih3e0CL4cWDg1S0icCd6n4V7zuB5E%2F6Z4PUJK\" onclick=\"return confirm('此功能为VIP专用，现在开通VIP？');\" target=\"_blank\" class=\"down_btn\"><span>&nbsp;VIP下载-6</span></a><a href=\"http://pt1.567pan.com/dl.php?YzYxZktzOTNZbDNIMEZxakkzd0RJZ1RVSUxteVBremdwZjRKdVNaVXRJNVNabi9YUWJYVUZncjUzTWptMjBPZ3NMMEZmRytVei9uZzdJU3Y1NnRaSzlPNHd3V1pQYTBNc2Y5Q2J0R0NONUZVTUdjb0xGRk9nS1ZFVEZCWXg0UUZQMWx6NUxFQVc5U1pxcUFmTkhzL0FKeVFSQ0ZodmVQS0dSeDhsV0VmUGNIUDF2RWdXRFpiMXZQbXE5NXA4UE42NmtPUXhGUEE3NTBSL1RVT21GdVVqYkZCQkg0MHJqUmtPbzJjekVpS1BaT3A4S1JP\" onclick=\"down_process2('140318');\" target=\"_blank\" class=\"down_btn\"><span>&nbsp;普通下载-1</span></a><a href=\"http://pt2.567pan.com/dl.php?ODE1M0d1eUJQanlBTW9TZDNhWGlHM3lzSklOYURUcjhUZFlqOGVrQzRmNzd3YmlIazZTTldlVTBlTEJyRkxzbWlPRkN3dGJyNkRXOE9La3M3ak5zYm5MKzJ1VzFUVE5Ybkx5NCsvc0FDbUNINkNhM2t6SnJmRXFsMnU0bnN3cG54dWhSdmViR2ZtUmJBanBQdFlITlFaVm9SeUNyVGRBSitlaXhaa0FXSFNQb2d2RDdpNGxDQ24zRWM3YXJoSXBiK2ZmbmtUb2tCd3cyMnZ6VjU3RFRFM3dpTnBWTUg1VkdJR2tMb3hmbXBHNGdDVXha\" onclick=\"down_process2('140318');\" target=\"_blank\" class=\"down_btn\"><span>&nbsp;普通下载-2</span></a><a href=\"http://pt3.567pan.com/dl.php?NjUxYm96NjdIa2kzMUZmUkt5Rk5xd3JQVGhobnd5Smd0YWlaV05QVjlJWG94OFRKWFY0aDE1c0ljVHlsYTB3OEVJL25NbVRzUWxFY3pRdFVhWHhubll0WmIwVnRDRE9ncDV3SHljZWhGelQvUjVVT3dzdHRwaWpVd1VFcVlkdExBVEUwVndMREhOWXdMQk1sNjJ1SGdMbGdDeGgyd2hrNysxc2sydDY1azhHNWxZLzJHN2V6LzhONS9FNXpjMDUxamFEMEJDWlMxZkM0S2hjd2JCZjlwVXBJNmdUdlVMTVl5eTdXR3EzekJrMXp2RWVh\" onclick=\"down_process2('140318');\" target=\"_blank\" class=\"down_btn\"><span>&nbsp;普通下载-3</span></a><a href=\"http://pt4.567pan.com/dl.php?YzIzNkpRWWgrZ2pxYmtrN2NkbVdqWFFoeWNYbUtGYU5KMmlocS9STGZHU1IxVEttMVFSRnVOa01peWQxUUVLaDlkOCtsaWN1K3dSeFVQMldLK09xQTZWYWFDTWpCdk1nZ2UxeXpBaWFzR1dGeCs0NTRxMFBhUzIvbTJtZkVnamVHVjkzVTV2NWhSTkIzcHBoWDFhMkJ1VGRBdkVMVVBzcGtmMEhLQXA0QWhWYjZuLzdSeHpaQXZWaDJPZ0drOUhuSVRhYzVLQXArc1ZGaytKZVVKb3RKc3hwcWpoYjJRVjBud21nTU5JVHBkV3BOUkdY\" onclick=\"down_process2('140318');\" target=\"_blank\" class=\"down_btn\"><span>&nbsp;普通下载-4</span></a><a href=\"http://pt5.567pan.com/dl.php?YzIyMGVmOEk5N1JSb3ZXd2xkSWorNlJTcEVlRThiYXlyUkFRUDBTTmZ0Zzk0WWJSNmVhc0t4RGxaOVRWenQ5OTVjN0gzZlJkallENGZvSVBRTVM0U0M0QkRXU2lCU0syWC9YcjYxQkxDZVFNWitXTmRjSHNiZ2tpM1RzcXlYNnhtdlpqbEZpMEhxcllOd2VUZlFNV1lSWU1MM1orM2VCemhKOURYODNCOVJyMTdXWWJ1eFFlaXdoT1g2VzdrQXpmcTlONmFKZFc0OVUrMzRPMXltTzVqc29BZHBEOTVHMzZOaXd2ejFCMXNvWHNKWjhJ\" onclick=\"down_process2('140318');\" target=\"_blank\" class=\"down_btn\"><span>&nbsp;普通下载-5</span></a><a href=\"http://pt6.567pan.com/dl.php?ZDcyN2diMjZwT2tTRzhseGNQMXR0MEV6czdkbmpEei9HTldmcHFZNENOai8yMnMrSkwxMUxHZ280WGJwVFF2M1RTWm5mclNrdS9Tc1dCSk9nOXdGY3BPeGdaa1JJYzlseU51eHpDb0kwTUNtb0VDTk5qS0Y4VkZhZXdDTkpXWElUR0Fsa211dEc5anIwcWM2d0VDZnRTM0dUMHZsRkgzMW1YSS9rdktmVVRGVUlRMVF4UFhQa2g1c0Z3QnNzUk5iRCtoZkF3Qis2UXJMcElkK3pzRUl4bDVGQ1BsS1BRZG0zazRwT2pnWEQ3WXlvN0d1\" onclick=\"down_process2('140318');\" target=\"_blank\" class=\"down_btn\"><span>&nbsp;普通下载-6</span></a>"
        
        let pan = Pan666(urlString: "http://www.567pan.com/file-140318.html")
        let list = pan.parserFileLinkList(body: html)
        XCTAssert(list != nil, "未找到地址")
        XCTAssert(list!.count > 0, "未找到地址")
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
