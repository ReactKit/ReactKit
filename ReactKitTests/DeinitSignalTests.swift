//
//  DeinitSignalTests.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import XCTest

class DeinitSignalTests: _TestCase
{
    func testDeinitSignal()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        var shortLivedObject: MyObject? = MyObject()
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        // always use `weak` for deinitSignal to avoid it being captured by current execution context
        weak var deinitSignal: Signal<AnyObject?>? = shortLivedObject!.deinitSignal
        
        let obj1Signal = KVO.signal(obj1, "value") |> takeUntil(deinitSignal!)
        
        // REACT
        (obj2, "value") <~ obj1Signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        obj1.value = "hoge"
        XCTAssertEqual(obj2.value, "hoge")
        
        // deinit shortLivedObject
        shortLivedObject = nil
        
        self.perform {
            
            obj1.value = "fuga"
            XCTAssertEqual(obj2.value, "hoge", "obj2.value should not be updated because deinitSignal is deinited so that it stops obj1Signal.")
            
            expect.fulfill()
            
        }
        
        self.wait()
        
    }
    
    func testDeinitSignal_failed()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        var shortLivedObject: MyObject? = MyObject()
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        // NOTE: `weak` is not used for this test
        var deinitSignal: Signal<AnyObject?>? = shortLivedObject!.deinitSignal
        
        let obj1Signal = KVO.signal(obj1, "value") |> takeUntil(deinitSignal!)
        
        // REACT
        (obj2, "value") <~ obj1Signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        obj1.value = "hoge"
        XCTAssertEqual(obj2.value, "hoge")
        
        // deinit shortLivedObject
        shortLivedObject = nil
        
        self.perform {
            
            obj1.value = "fuga"
            XCTAssertEqual(obj2.value, "fuga", "Unfortunately, obj2.value will be updated because deinitSignal is shortly captured by curent execution context so it's still alive and not sending its death signal. You must always use `weak` for deinitSignal.")
            
            expect.fulfill()
            
        }
        
        self.wait()
        
    }
    
}

class AsyncDeinitSignalTests: DeinitSignalTests
{
    override var isAsync: Bool { return true }
}