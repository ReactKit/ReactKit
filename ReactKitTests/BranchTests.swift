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
        
        XCTAssertEqual(sourceStream.state, .Paused)
        XCTAssertEqual(mainStream.state, .Paused)
        XCTAssertEqual(subStream.state, .Paused)
        
        // REACT (sub)
        subStream ~> { println($0); subValue = $0 }
        
        XCTAssertEqual(sourceStream.state, .Running, "Should start running by `subStream ~> {...}`")
        XCTAssertEqual(mainStream.state, .Paused)
        XCTAssertEqual(subStream.state, .Running, "Should start running by `subStream ~> {...}`")
        
        // REACT (main)
        mainStream ~> { println($0); mainValue = $0 }
        
        XCTAssertEqual(sourceStream.state, .Running)
        XCTAssertEqual(mainStream.state, .Running, "Should start running by `mainStream ~> {...}`")
        XCTAssertEqual(subStream.state, .Running)
        
        self.perform() {
            
            source.value = "1"
            source.value = "2"
            source.value = "3"
            
            println("subStream.cancel()")
            subStream.cancel()
            
            XCTAssertEqual(mainValue, "main = 3")
            XCTAssertEqual(subValue, "sub = 3")
            XCTAssertEqual(sourceStream.state, .Cancelled, "`sourceStream` will be cancelled via propagation of `subStream.cancel()`.")
            
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
        
        XCTAssertEqual(sourceStream.state, .Paused)
        XCTAssertEqual(mainStream.state, .Paused)
        XCTAssertEqual(subStream.state, .Paused)
        
        // REACT (sub)
        subStream ~> { println($0); subValue = $0 }
        
        XCTAssertEqual(sourceStream.state, .Paused, "Should NOT start running yet.`")
        XCTAssertEqual(mainStream.state, .Paused)
        XCTAssertEqual(subStream.state, .Running, "Should start running by `subStream ~> {...}`")
        
        // REACT (main)
        mainStream ~> { println($0); mainValue = $0 }
        
        XCTAssertEqual(sourceStream.state, .Running, "Should start running by `mainStream ~> {...}`")
        XCTAssertEqual(mainStream.state, .Running, "Should start running by `mainStream ~> {...}`")
        XCTAssertEqual(subStream.state, .Running)
        
        self.perform() {
            
            source.value = "1"
            source.value = "2"
            source.value = "3"
            
            println("subStream.cancel()")
            subStream.cancel()
            
            XCTAssertEqual(mainValue, "main = 3")
            XCTAssertEqual(subValue, "sub = 3")
            XCTAssertEqual(sourceStream.state, .Running, "`sourceStream` should NOT be cancelled via propagation of `subStream.cancel()`.")
            
            source.value = "4"
            source.value = "5"
            
            XCTAssertEqual(mainValue, "main = 5")
            XCTAssertEqual(subValue, "sub = 3")
            
            expect.fulfill()
        }
        
        self.wait()
    }
}