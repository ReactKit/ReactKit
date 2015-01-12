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
        
        let signal = KVO.signal(obj1, "value")   // = obj1.signal(keyPath: "value")
        weak var weakSignal = signal
        
        // REACT: obj1.value ~> obj2.value
        (obj2, "value") <~ signal
        
        // REACT: obj1.value ~> println
        ^{ println("[REACT] new value = \($0)") } <~ signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            XCTAssertNotNil(weakSignal)
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "hoge")
            
            weakSignal?.cancel()
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(obj2.value, "hoge", "obj2.value should not be updated because signal is already cancelled.")
            
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
            
            // comment-out: no weakSignal in this test
            // XCTAssertNotNil(weakSignal)
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            
            if self.isAsync {
                XCTAssertEqual(obj2.value, "initial", "obj2.value should not be updated because signal is already deinited.")
            }
            else {
                XCTAssertEqual(obj2.value, "hoge", "obj2.value should be updated.")
            }
            
            expect.fulfill()
            
        }
        
        // NOTE: (obj1, "value") signal is still retained at this point, thanks to dispatch_queue
        
        self.wait()
    }
    
    // MARK: Single Signal Operations
    
    func testKVO_filter()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let signal = KVO.signal(obj1, "value").filter { (value: AnyObject?) -> Bool in
            return value as String == "fuga"
        }
        
        // REACT
        (obj2, "value") <~ signal
        
        // REACT
        ^{ println("[REACT] new value = \($0)") } <~ signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "initial", "obj2.value should not be updated because signal is not sent via filter().")
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(obj2.value, "fuga")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testKVO_filter2()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        
        // NOTE: this is distinct signal
        let signal = KVO.signal(obj1, "value").filter2 { (oldValue: AnyObject??, newValue: AnyObject?) -> Bool in
            
            // don't filter for first value
            if oldValue == nil { return true }
            
            return oldValue as String != newValue as String
        }
        
        var count = 0
        
        // REACT
        signal ~> { _ in count++; return }
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(count, 1)
            
            obj1.value = "fuga"
            
            XCTAssertEqual(count, 2)
            
            obj1.value = "fuga" // same value as before
            
            println(count)
            XCTAssertEqual(count, 2, "`count` should NOT be incremented because previous value was same (should be distinct)")
            
            obj1.value = "hoge"
            
            XCTAssertEqual(count, 3, "`count` should be incremented.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testKVO_map()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let signal = KVO.signal(obj1, "value").map { (value: AnyObject?) -> NSString? in
            return (value as String).uppercaseString
        }
        
        // REACT
        (obj2, "value") <~ signal
        
        // REACT
        ^{ println("[REACT] new value = \($0)") } <~ signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "HOGE")
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(obj2.value, "FUGA")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testKVO_flatMap()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        // NOTE: `mapClosure` is returning Signal
        let signal = KVO.signal(obj1, "value").flatMap { (value: AnyObject?) -> Signal<AnyObject?> in
            // delay sending value for 0.01 sec
            return NSTimer.signal(timeInterval: 0.01, repeats: false) { _ in value }
        }
        
        // REACT
        (obj2, "value") <~ signal
        
        // REACT
        ^{ println("[REACT] new value = \($0)") } <~ signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "initial", "`obj2.value` should NOT be updated because `signal` is delayed.")
            
            // wait for "hoge" to arrive...
            Async.main(after: 0.1) {
                
                XCTAssertEqual(obj1.value, "hoge")
                XCTAssertEqual(obj2.value, "hoge", "`obj2.value` should be updated because delayed `signal` message arrived.")
                
                obj1.value = "fuga"
                
                XCTAssertEqual(obj1.value, "fuga")
                XCTAssertEqual(obj2.value, "hoge", "`obj2.value` should NOT be updated because `signal` is delayed.")
            }
            
            // wait for "fuga" to arrive...
            Async.main(after: 0.2 + SAFE_DELAY) {
                
                XCTAssertEqual(obj1.value, "fuga")
                XCTAssertEqual(obj2.value, "fuga", "`obj2.value` should be updated because delayed `signal` message arrived.")
                
                expect.fulfill()
            }
        }
        
        self.wait()
    }
    
    func testKVO_map2()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let signal = KVO.signal(obj1, "value").map2 { (oldValue: AnyObject??, newValue: AnyObject?) -> NSString? in
            let oldString = (oldValue as? NSString) ?? "empty"
            return "\(oldString) -> \(newValue as String)"
        }
        
        // REACT
        (obj2, "value") <~ signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "empty -> hoge")
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(obj2.value, "hoge -> fuga")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    /// a.k.a `Rx.scan`
    func testKVO_mapAccumulate()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        
        let signal = KVO.signal(obj1, "value").mapAccumulate([]) { accumulatedValue, newValue -> [String] in
            return accumulatedValue + [newValue as String]
        }
        
        var result: [String]?
        
        // REACT
        signal ~> { result = $0 }
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(result!, [ "hoge" ])
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(result!, [ "hoge", "fuga" ])
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testKVO_take()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let signal = KVO.signal(obj1, "value").take(1)  // only take 1 event
        weak var weakSignal = signal
        
        // REACT: obj1.value ~> obj2.value
        (obj2, "value") <~ signal
        
        // REACT: obj1.value ~> println
        ^{ println("[REACT] new value = \($0)") } <~ signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            XCTAssertNotNil(weakSignal)
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "hoge")
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(obj2.value, "hoge", "obj2.value should not be updated because signal is finished via take().")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testKVO_take_fulfilled()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        var progressCount = 0
        var successCount = 0
        
        let obj1 = MyObject()
        
        let sourceSignal = KVO.signal(obj1, "value")
        let takeSignal = sourceSignal.take(1)  // only take 1 event
        
        // REACT 
        ^{ _ in progressCount++; return } <~ takeSignal
        
        // success
        takeSignal.success { value -> Void in
            successCount++
            XCTAssertEqual(value! as String, "hoge")
        }
        
        println("*** Start ***")
        
        XCTAssertEqual(progressCount, 0)
        XCTAssertEqual(successCount, 0)
        
        self.perform {
            
            obj1.value = "hoge"
            XCTAssertEqual(progressCount, 1)
            XCTAssertEqual(successCount, 1)
            
            obj1.value = "fuga"
            XCTAssertEqual(progressCount, 1, "`progress()` will not be invoked because already fulfilled via `take(1)`.")
            XCTAssertEqual(successCount, 1)
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testKVO_take_rejected()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let sourceSignal = KVO.signal(obj1, "value")
        let takeSignal = sourceSignal.take(1)  // only take 1 event
        
        // failure
        takeSignal.failure { errorInfo -> NSString? in
            
            XCTAssertEqual(errorInfo.error!.domain, ReactKitError.Domain, "`sourceSignal` is cancelled before any progress, so `takeSignal` should fail.")
            XCTAssertEqual(errorInfo.error!.code, ReactKitError.CancelledByUpstream.rawValue)
            
            XCTAssertFalse(errorInfo.isCancelled, "Though `sourceSignal` is cancelled, `takeSignal` is rejected rather than cancelled.")
            
            expect.fulfill()
            
            return "DUMMY"
        
        }
        
        self.perform {
            sourceSignal.cancel()
            return
        }
        
        self.wait()
    }
    
    func testKVO_takeUntil()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let stopper = MyObject()
        
        let stoppingSignal = KVO.signal(stopper, "value")    // store stoppingSignal to live until end of runloop
        let signal = KVO.signal(obj1, "value").takeUntil(stoppingSignal)
        
        weak var weakSignal = signal
        
        // REACT
        (obj2, "value") <~ signal
        
        // REACT
        ^{ println("[REACT] new value = \($0)") } <~ signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "hoge")
            
            stopper.value = "DUMMY" // fire stoppingSignal
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(obj2.value, "hoge", "obj2.value should not be updated because signal is stopped via takeUntil(stoppingSignal).")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testKVO_skip()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let signal = KVO.signal(obj1, "value").skip(1)  // skip 1 event
        weak var weakSignal = signal
        
        // REACT: obj1.value ~> obj2.value
        (obj2, "value") <~ signal
        
        // REACT: obj1.value ~> println
        ^{ println("[REACT] new value = \($0)") } <~ signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            XCTAssertNotNil(weakSignal)
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "initial", "obj2.value should not be changed due to `skip(1)`.")
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(obj2.value, "fuga", "obj2.value should be updated because already skipped once.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testKVO_skipUntil()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let stopper = MyObject()
        
        let startingSignal = KVO.signal(stopper, "value")    // store startingSignal to live until end of runloop
        let signal = KVO.signal(obj1, "value").skipUntil(startingSignal)
        
        weak var weakSignal = signal
        
        // REACT
        (obj2, "value") <~ signal
        
        // REACT
        ^{ println("[REACT] new value = \($0)") } <~ signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "initial", "obj2.value should not be changed due to `skipUntil()`.")
            
            stopper.value = "DUMMY" // fire startingSignal
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(obj2.value, "fuga", "obj2.value should be updated because `startingSignal` is triggered so that `skipUntil(startingSignal)` should no longer skip.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testKVO_buffer()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        
        let signal: Signal<[AnyObject?]> = KVO.signal(obj1, "value").buffer(3)
        
        var result: String? = "no result"
        
        // REACT
        signal ~> { (buffer: [AnyObject?]) in
            let buffer_: [String] = buffer.map { $0 as NSString }
            result = "-".join(buffer_)
        }
        
        // REACT
        ^{ println("[REACT] new value = \($0)") } <~ signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(result!, "no result", "`result` should NOT be updated because `signal`'s newValue is buffered.")
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(result!, "no result", "`result` should NOT be updated because `signal`'s newValue is buffered.")
            
            obj1.value = "piyo"
            
            XCTAssertEqual(obj1.value, "piyo")
            XCTAssertEqual(result!, "hoge-fuga-piyo", "`result` should be updated with buffered values because buffer reached maximum count.")
            
            obj1.value = "foo"
            
            XCTAssertEqual(obj1.value, "foo")
            XCTAssertEqual(result!, "hoge-fuga-piyo", "`result` should NOT be updated because `signal`'s newValue is buffered.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testKVO_bufferBy()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let trigger = MyObject()
        
        let triggerSignal = KVO.signal(trigger, "value")
        let signal: Signal<[AnyObject?]> = KVO.signal(obj1, "value").bufferBy(triggerSignal)
        
        var result: String? = "no result"
        
        // REACT
        signal ~> { (buffer: [AnyObject?]) in
            let buffer_: [String] = buffer.map { $0 as NSString }
            result = "-".join(buffer_)
        }
        
        // REACT
        ^{ println("[REACT] new value = \($0)") } <~ signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(result!, "no result", "`result` should NOT be updated because `signal`'s newValue is buffered but `triggerSignal` is not triggered yet.")
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(result!, "no result", "`result` should NOT be updated because `signal`'s newValue is buffered but `triggerSignal` is not triggered yet.")
            
            trigger.value = "DUMMY" // fire triggerSignal
            
            XCTAssertEqual(result!, "hoge-fuga", "`result` should be updated with buffered values.")
            
            trigger.value = "DUMMY2" // fire triggerSignal
            
            XCTAssertEqual(result!, "", "`result` should be updated with NO buffered values.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testKVO_throttle()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
     
        let timeInterval: NSTimeInterval = 0.2
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let signal = KVO.signal(obj1, "value").throttle(timeInterval)
        weak var weakSignal = signal
        
        // REACT: obj1.value ~> obj2.value
        (obj2, "value") <~ signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            XCTAssertNotNil(weakSignal)
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "hoge")
            
            obj1.value = "hoge2"
            
            XCTAssertEqual(obj1.value, "hoge2")
            XCTAssertEqual(obj2.value, "hoge", "obj2.value should not be updated because signal is throttled to \(timeInterval) sec.")
            
            // delay for `timeInterval`*1.05 sec
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1_050_000_000*timeInterval)), dispatch_get_main_queue()) {
                obj1.value = "fuga"
                
                XCTAssertEqual(obj1.value, "fuga")
                XCTAssertEqual(obj2.value, "fuga")
                
                expect.fulfill()
            }
            
        }
        
        self.wait()
    }
    
    func testKVO_debounce()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let timeInterval: NSTimeInterval = 0.2
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let signal = KVO.signal(obj1, "value").debounce(timeInterval)
        weak var weakSignal = signal
        
        // REACT: obj1.value ~> obj2.value
        (obj2, "value") <~ signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            XCTAssertNotNil(weakSignal)
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "initial", "obj2.value should not be updated because of debounce().")
            
            Async.background(after: timeInterval/2) {
                XCTAssertEqual(obj2.value, "initial", "obj2.value should not be updated because it is still debounced.")
            }
            
            Async.background(after: timeInterval+0.1) {
                XCTAssertEqual(obj2.value, "hoge", "obj2.value should be updated after debouncing time.")
                expect.fulfill()
            }
            
        }
        
        self.wait()
    }
    
    // MARK: Multiple Signal Operations
    
    func testKVO_merge()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let obj3 = MyObject()
        
        let signal1 = KVO.signal(obj1, "value")
        let signal2 = KVO.signal(obj2, "number")
        
        var bundledSignal = Signal<AnyObject?>.merge([signal1, signal2]).map { (value: AnyObject?) -> NSString? in
            let valueString: AnyObject = value ?? "nil"
            return "\(valueString)"
        }
        
        // REACT
        (obj3, "value") <~ bundledSignal
        
        println("*** Start ***")
        
        self.perform {
            XCTAssertEqual(obj3.value, "initial")
            
            obj1.value = "test1"
            XCTAssertEqual(obj3.value, "test1")
            
            obj1.value = "test2"
            XCTAssertEqual(obj3.value, "test2")
            
            obj2.value = "test3"
            XCTAssertEqual(obj3.value, "test2", "`obj3.value` should NOT be updated because `bundledSignal` doesn't react to `obj2.value`.")
            
            obj2.number = 123
            XCTAssertEqual(obj3.value, "123")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    //
    // NOTE: 
    // `merge2()` works like both `Rx.merge()` and `Rx.combineLatest()`.
    // This test demonstrates `combineLatest` example.
    //
    func testKVO_merge2()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let obj3 = MyObject()
        
        let signal1 = KVO.signal(obj1, "value")
        let signal2 = KVO.signal(obj2, "number")
        
        let bundledSignal = Signal<AnyObject?>.merge2([signal1, signal2]).map { (values: [AnyObject??], _) -> NSString? in
            let value0: AnyObject = (values[0] ?? "notYet") ?? "nil"
            let value1: AnyObject = (values[1] ?? "notYet") ?? "nil"
            return "\(value0)-\(value1)"
        }
        
        // REACT
        (obj3, "value") <~ bundledSignal
        
        println("*** Start ***")
        
        self.perform {
            XCTAssertEqual(obj3.value, "initial")
            
            obj1.value = "test1"
            XCTAssertEqual(obj3.value, "test1-notYet")
            
            obj1.value = "test2"
            XCTAssertEqual(obj3.value, "test2-notYet")
            
            obj2.value = "test3"
            XCTAssertEqual(obj3.value, "test2-notYet", "`obj3.value` should NOT be updated because `bundledSignal` doesn't react to `obj2.value`.")
            
            obj2.number = 123
            XCTAssertEqual(obj3.value, "test2-123")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    /// almost same as `testKVO_merge2()`
    func testKVO_combineLatest()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let obj3 = MyObject()
        
        let signal1 = KVO.signal(obj1, "value")
        let signal2 = KVO.signal(obj2, "number")
        
        let bundledSignal = Signal<AnyObject?>.combineLatest([signal1, signal2]).map { (values: [AnyObject??]) -> NSString? in
            let value0: AnyObject = (values[0] ?? "notYet") ?? "nil"
            let value1: AnyObject = (values[1] ?? "notYet") ?? "nil"
            return "\(value0)-\(value1)"
        }
        
        // REACT
        (obj3, "value") <~ bundledSignal
        
        println("*** Start ***")
        
        self.perform {
            XCTAssertEqual(obj3.value, "initial")
            
            obj1.value = "test1"
            XCTAssertEqual(obj3.value, "test1-notYet")
            
            obj1.value = "test2"
            XCTAssertEqual(obj3.value, "test2-notYet")
            
            obj2.value = "test3"
            XCTAssertEqual(obj3.value, "test2-notYet", "`obj3.value` should NOT be updated because `bundledSignal` doesn't react to `obj2.value`.")
            
            obj2.number = 123
            XCTAssertEqual(obj3.value, "test2-123")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testKVO_concat()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        
        let signal1: Signal<AnyObject?> = NSTimer.signal(timeInterval: 0.1, userInfo: nil, repeats: false) { _ in "Next" }
        let signal2: Signal<AnyObject?> = NSTimer.signal(timeInterval: 0.3, userInfo: nil, repeats: false) { _ in 123 }
        
        var concatSignal = Signal<AnyObject?>.concat([signal1, signal2]).map { (value: AnyObject?) -> NSString? in
            let valueString: AnyObject = value ?? "nil"
            return "\(valueString)"
        }
        
        // REACT
        (obj1, "value") <~ concatSignal
        
        println("*** Start ***")
        
        self.perform {
            XCTAssertEqual(obj1.value, "initial")
            
            Async.main(after: 0.2) {
                XCTAssertEqual(obj1.value, "Next")
            }
            
            Async.main(after: 0.4) {
                XCTAssertEqual(obj1.value, "123")
                expect.fulfill()
            }
        }
        
        self.wait()
    }

    func testKVO_startWith()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let signal1 = KVO.signal(obj1, "value")
        
        var bundledSignal = signal1.startWith("start!")
        
        // REACT
        (obj2, "value") <~ bundledSignal
        
        println("*** Start ***")
        
        self.perform {
            // NOTE: not "initial"
            XCTAssertEqual(obj2.value, "start!", "`obj2.value` should not stay with 'initial' & `startWith()`'s initialValue should be set.")
            
            obj1.value = "test1"
            XCTAssertEqual(obj2.value, "test1")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    // MARK: Multiple Reactions
    
    func testKVO_multiple_reactions()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let obj3 = MyObject()
        
        let signal = KVO.signal(obj1, "value").map { (value: AnyObject?) -> [NSString?] in
            if let str = value as? NSString? {
                if let str = str {
                    return [ "\(str)-2" as NSString?, "\(str)-3" as NSString? ]
                }
            }
            return []
        }
        weak var weakSignal = signal
        
        // REACT
        [ (obj2, "value"), (obj3, "value") ] <~ signal
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        XCTAssertEqual(obj3.value, "initial")
        
        self.perform {
            
            XCTAssertNotNil(weakSignal)
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "hoge-2")
            XCTAssertEqual(obj3.value, "hoge-3")
            
            weakSignal?.cancel()
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(obj2.value, "hoge-2", "obj2.value should not be updated because signal is already cancelled.")
            XCTAssertEqual(obj3.value, "hoge-3", "obj3.value should not be updated because signal is already cancelled.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
}

class AsyncKVOTests: KVOTests
{
    override var isAsync: Bool { return true }
}