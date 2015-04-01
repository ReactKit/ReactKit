//
//  DeinitStreamTests.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import XCTest

class DeinitStreamTests: _TestCase
{
    func testDeinitStream()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        var shortLivedObject: MyObject? = MyObject()
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        // always use `weak` for deinitStream to avoid it being captured by current execution context
        weak var deinitStream: Stream<AnyObject?>? = shortLivedObject!.deinitStream
        
        let obj1Stream = KVO.stream(obj1, "value") |> takeUntil(deinitStream!)
        
        // REACT
        (obj2, "value") <~ obj1Stream
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        obj1.value = "hoge"
        XCTAssertEqual(obj2.value, "hoge")
        
        // deinit shortLivedObject
        shortLivedObject = nil
        
        self.perform {
            
            obj1.value = "fuga"
            XCTAssertEqual(obj2.value, "hoge", "obj2.value should not be updated because deinitStream is deinited so that it stops obj1Stream.")
            
            expect.fulfill()
            
        }
        
        self.wait()
        
    }
    
    func testDeinitStream_failed()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        var shortLivedObject: MyObject? = MyObject()
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        // NOTE: `weak` is not used for this test
        var deinitStream: Stream<AnyObject?>? = shortLivedObject!.deinitStream
        
        let obj1Stream = KVO.stream(obj1, "value") |> takeUntil(deinitStream!)
        
        // REACT
        (obj2, "value") <~ obj1Stream
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        obj1.value = "hoge"
        XCTAssertEqual(obj2.value, "hoge")
        
        // deinit shortLivedObject
        shortLivedObject = nil
        
        self.perform {
            
            obj1.value = "fuga"
            XCTAssertEqual(obj2.value, "fuga", "Unfortunately, obj2.value will be updated because deinitStream is shortly captured by curent execution context so it's still alive and not sending its death stream. You must always use `weak` for deinitStream.")
            
            expect.fulfill()
            
        }
        
        self.wait()
        
    }
    
}

class AsyncDeinitStreamTests: DeinitStreamTests
{
    override var isAsync: Bool { return true }
}