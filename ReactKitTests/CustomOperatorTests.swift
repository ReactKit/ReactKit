//
//  CustomOperatorTests.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import XCTest

class CustomOperatorTests: _TestCase
{
    /// e.g. (obj2, "value") <~ +KVO.stream(obj1, "value")
    func testShortLivingSyntax()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        // REACT: obj1.value ~> obj2.value, until the end of runloop (short-living syntax)
        // equivalent to (obj2, "value") <~ (obj1, "value"), but can be used for non-KVO temporal streams as well
        (obj2, "value") <~ +KVO.stream(obj1, "value")
        
        print("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            // comment-out: no weakStream in this test
            // XCTAssertNotNil(weakStream)
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            
            if self.isAsync {
                XCTAssertEqual(obj2.value, "initial", "obj2.value should not be updated because stream is already deinited.")
            }
            else {
                XCTAssertEqual(obj2.value, "hoge", "obj2.value should be updated.")
            }
            
            expect.fulfill()
            
        }
        
        // NOTE: (obj1, "value") stream is still retained at this point, thanks to dispatch_queue
        
        self.wait()
    }
    
    /// e.g. `let value = stream ~>! ()`
    func testTerminalReactingOperator()
    {
        let sum: Int! = Stream.sequence([1, 2, 3]) |> reduce(100) { $0 + $1 } ~>! ()
        XCTAssertEqual(sum, 106)
        
        let distinctValues: [Int] = Stream.sequence([1, 2, 2, 3]) |> distinct |> buffer() ~>! ()
        XCTAssertEqual(distinctValues, [1, 2, 3])
    }
}

class AsyncCustomOperatorTests: CustomOperatorTests
{
    override var isAsync: Bool { return true }
}