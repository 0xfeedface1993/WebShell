//
//  CCCHOOOTests.swift
//  CCCHOOOTests
//
//  Created by virus1993 on 2018/1/23.
//  Copyright © 2018年 ascp. All rights reserved.
//

import XCTest
@testable import WebShell

class CCCHOOOTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testSiteRecognize() {
        var url : URL!
        var result : WebHostSite!
        
        var items = ["http://www.ccchoo.com/file-72598.html", "http://www.chooyun.com/file-72598.html"]
        items.forEach({
            url = URL(string: $0)!
            result = site(url: url)
            XCTAssertTrue(result == .cchooo, "Can't match feemoo!")
        })
        
        
        items = ["http://www.feemoo.com/file-1897522.html", "http://www.feemoo.com/s/1htfnfyn"]
        items.forEach({
            url = URL(string: $0)!
            result = site(url: url)
            XCTAssertTrue(result == .feemoo, "Can't match feemoo!")
        })
        
        items = ["http://www.666pan.cc/file-533064.html", "http://www.88pan.cc/file-532359.html"]
        items.forEach({
            url = URL(string: $0)!
            result = site(url: url)
            XCTAssertTrue(result == .pan666, "Can't match 666pan!")
        })
    }
    
    
}
