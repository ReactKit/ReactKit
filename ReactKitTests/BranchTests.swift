//
//  BranchTests.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2015/05/29.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import XCTest

class AsyncBranchTests: BranchTests
{
    override var isAsync: Bool { return true }
}

class BranchTests: _TestCase
{
    func testNoBranch()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        var mainValue = ""
        var subValue = ""
        
        let source = MyObject()
        let sourceStream = KVO.stream(source, "value")
        
        let mainStream = sourceStream
            |> map { "main = \($0!)" }
        
        let subStream = sourceStream
//            |> branch // comment-out: no branch test
            |> map { "sub = \($0!)" }
        
        XCTAssertTrue(mainStream.state == .Paused)
        XCTAssertTrue(subStream.state == .Paused)
        
        // REACT (sub)
        subStream ~> { print($0); subValue = $0 }
        
        XCTAssertTrue(sourceStream.state == .Running, "Should start running by `subStream ~> {...}`")
        XCTAssertTrue(mainStream.state == .Paused)
        XCTAssertTrue(subStream.state == .Running, "Should start running by `subStream ~> {...}`")
        
        // REACT (main)
        mainStream ~> { print($0); mainValue = $0 }
        
        XCTAssertTrue(sourceStream.state == .Running)
        XCTAssertTrue(mainStream.state == .Running, "Should start running by `mainStream ~> {...}`")
        XCTAssertTrue(subStream.state == .Running)
        
        self.perform() {
            
            source.value = "1"
            source.value = "2"
            source.value = "3"
            
            print("subStream.cancel()")
            subStream.cancel()
            
            XCTAssertEqual(mainValue, "main = 3")
            XCTAssertEqual(subValue, "sub = 3")
            XCTAssertTrue(sourceStream.state == .Cancelled, "`sourceStream` will be cancelled via propagation of `subStream.cancel()`.")
            
            source.value = "4"
            source.value = "5"
            
            XCTAssertEqual(mainValue, "main = 3", "sourceStream")
            XCTAssertEqual(subValue, "sub = 3")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testBranch()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        var mainValue = ""
        var subValue = ""
        
        let source = MyObject()
        let sourceStream = KVO.stream(source, "value")
        
        let mainStream = sourceStream
            |> map { "main = \($0!)" }
        
        let subStream = sourceStream
            |> branch
            |> map { "sub = \($0!)" }
        
        XCTAssertTrue(sourceStream.state == .Paused)
        XCTAssertTrue(mainStream.state == .Paused)
        XCTAssertTrue(subStream.state == .Paused)
        
        // REACT (sub)
        subStream ~> { print($0); subValue = $0 }
        
        XCTAssertTrue(sourceStream.state == .Paused, "Should NOT start running yet.`")
        XCTAssertTrue(mainStream.state == .Paused)
        XCTAssertTrue(subStream.state == .Running, "Should start running by `subStream ~> {...}`")
        
        // REACT (main)
        mainStream ~> { print($0); mainValue = $0 }
        
        XCTAssertTrue(sourceStream.state == .Running, "Should start running by `mainStream ~> {...}`")
        XCTAssertTrue(mainStream.state == .Running, "Should start running by `mainStream ~> {...}`")
        XCTAssertTrue(subStream.state == .Running)
        
        self.perform() {
            
            source.value = "1"
            source.value = "2"
            source.value = "3"
            
            print("subStream.cancel()")
            subStream.cancel()
            
            XCTAssertEqual(mainValue, "main = 3")
            XCTAssertEqual(subValue, "sub = 3")
            XCTAssertTrue(sourceStream.state == .Running, "`sourceStream` should NOT be cancelled via propagation of `subStream.cancel()`.")
            
            source.value = "4"
            source.value = "5"
            
            XCTAssertEqual(mainValue, "main = 5")
            XCTAssertEqual(subValue, "sub = 3")
            
            expect.fulfill()
        }
        
        self.wait()
    }
}