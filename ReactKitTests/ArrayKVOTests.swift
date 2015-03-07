//
//  ArrayKVOTests.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2015/03/07.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import SwiftTask
import XCTest

/// `mutableArrayValueForKey()` test
class ArrayKVOTests: _TestCase
{
    func testArrayKVO()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let obj3 = MyObject()
        
        // NOTE: by using `mutableArrayValueForKey()`, this signal will send each changed values **separately**
        let obj1ArrayChangedSignal = KVO.signal(obj1, "array")
        
        let obj1ArraySignal = obj1ArrayChangedSignal.map { _ -> AnyObject? in obj1.array }
        
        let obj1ArrayChangedCountSignal = obj1ArrayChangedSignal
            .mapAccumulate(0, { c, _ in c + 1 })    // count up
            .map { $0 as NSNumber? }    // .asSignal(NSNumber?)
        
        // REACT: obj1.array ~> obj2.array (sends )
        (obj2, "array") <~ obj1ArrayChangedSignal
        
        // REACT: obj1.array ~> obj3.array (appending)
        (obj3, "array") <~ obj1ArraySignal
        
        // REACT: arrayChangedCount ~> obj3.number (for counting)
        (obj3, "number") <~ obj1ArrayChangedCountSignal
        
        // REACT: obj1.array ~> println
        ^{ println("[REACT] new array = \($0)") } <~ obj1ArrayChangedSignal
        
        // NOTE: call `mutableArrayValueForKey()` after `<~` binding (KVO-addObserver) is ready
        let obj1ArrayProxy = obj1.mutableArrayValueForKey("array")
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.array.count, 0)
        XCTAssertEqual(obj2.array.count, 0)
        XCTAssertEqual(obj3.array.count, 0)
        XCTAssertEqual(obj3.number, 0)
        
        self.perform {
            
            obj1ArrayProxy.addObject("a")
            XCTAssertEqual(obj1.array, ["a"])
            XCTAssertEqual(obj2.array, ["a"])
            XCTAssertEqual(obj3.array, obj1.array)
            XCTAssertEqual(obj3.number, 1)
            
            obj1ArrayProxy.addObject("b")
            XCTAssertEqual(obj1.array, ["a", "b"])
            XCTAssertEqual(obj2.array, ["b"], "`obj2.array` should be replaced to last-changed value `b`.")
            XCTAssertEqual(obj3.array, obj1.array)
            XCTAssertEqual(obj3.number, 2)
            
            // adding multiple values at once
            // (NOTE: `obj1ArrayChangedSignal` will send each values separately)
            obj1ArrayProxy.addObjectsFromArray(["c", "d"])
            XCTAssertEqual(obj1.array, ["a", "b", "c", "d"])
            XCTAssertEqual(obj2.array, ["d"], "`obj2.array` will be replaced to `c` then `d`, so it should be replaced to last-changed value `d`.")
            XCTAssertEqual(obj3.array, obj1.array)
            XCTAssertEqual(obj3.number, 4, "`obj3.number` should count number of changed elements up to `4` (not `3` in this case).")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
}

class AsyncArrayKVOTests: KVOTests
{
    override var isAsync: Bool { return true }
}