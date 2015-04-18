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
    
    /// e.g. (obj2, "value") <~ (obj1, "value")
    func testKVO_shortLivingSyntax()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        // REACT: obj1.value ~> obj2.value, until the end of runloop (short-living syntax)
        (obj2, "value") <~ (obj1, "value")
        
        println("*** Start ***")
        
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
    
    // multiple bindings
    func testKVO_multiple_bindings()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let obj3 = MyObject()
        
        let stream = KVO.stream(obj1, "value") |> map { (value: AnyObject?) -> [NSString?] in
            if let str = value as? NSString? {
                if let str = str {
                    return [ "\(str)-2" as NSString?, "\(str)-3" as NSString? ]
                }
            }
            return []
        }
        weak var weakStream = stream
        
        // REACT
        [ (obj2, "value"), (obj3, "value") ] <~ stream
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        XCTAssertEqual(obj3.value, "initial")
        
        self.perform {
            
            XCTAssertNotNil(weakStream)
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "hoge-2")
            XCTAssertEqual(obj3.value, "hoge-3")
            
            weakStream?.cancel()
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(obj2.value, "hoge-2", "obj2.value should not be updated because stream is already cancelled.")
            XCTAssertEqual(obj3.value, "hoge-3", "obj3.value should not be updated because stream is already cancelled.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
}

class AsyncKVOTests: KVOTests
{
    override var isAsync: Bool { return true }
}