//
//  KVOTests.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import XCTest

let SAFE_DELAY = 0.5

class KVOTests: _TestCase
{
    func testKVO()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let stream = KVO.stream(obj1, "value")   // = obj1.stream(keyPath: "value")
        weak var weakStream = stream
        
        // REACT: obj1.value ~> obj2.value
        (obj2, "value") <~ stream
        
        // REACT: obj1.value ~> println
        ^{ println("[REACT] new value = \($0)") } <~ stream
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            XCTAssertNotNil(weakStream)
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "hoge")
            
            weakStream?.cancel()
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(obj2.value, "hoge", "obj2.value should not be updated because stream is already cancelled.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testKVO_nil()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let stream = KVO.stream(obj1, "optionalValue")
        (obj2, "optionalValue") <~ stream   // REACT
        
        println("*** Start ***")
        
        XCTAssertNil(obj1.optionalValue)
        XCTAssertNil(obj2.optionalValue)
        
        self.perform {
            
            obj1.optionalValue = "hoge"
            
            XCTAssertEqual(obj1.optionalValue!, "hoge")
            XCTAssertEqual(obj2.optionalValue!, "hoge")
            
            obj1.optionalValue = nil
            
            XCTAssertNil(obj1.optionalValue)
            XCTAssertNil(obj2.optionalValue, "nil should be set instead of NSNull.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }

    func testKVO_startingStream()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        obj2.optionalValue = "initial"  // set initial optionalValue

        XCTAssertNil(obj1.optionalValue)
        XCTAssertEqual(obj2.optionalValue!, "initial")
        
        let startingStream = KVO.startingStream(obj1, "optionalValue")
        (obj2, "optionalValue") <~ startingStream   // REACT

        println("*** Start ***")
        
        XCTAssertNil(obj1.optionalValue)
        XCTAssertNil(obj2.optionalValue, "`KVO.startingStream()` sets initial `obj1.optionalValue` (nil) to `obj2.optionalValue` on `<~` binding.")
        
        self.perform {
            
            obj1.optionalValue = "hoge"
            
            XCTAssertEqual(obj1.optionalValue!, "hoge")
            XCTAssertEqual(obj2.optionalValue!, "hoge")
            
            obj1.optionalValue = nil
            
            XCTAssertNil(obj1.optionalValue)
            XCTAssertNil(obj2.optionalValue)
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
}

class AsyncKVOTests: KVOTests
{
    override var isAsync: Bool { return true }
}