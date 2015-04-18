//
//  OperationTests.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2015/04/04.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import Async
import XCTest

class OperationTests: _TestCase
{
    //--------------------------------------------------
    // MARK: - Single Stream Operations
    //--------------------------------------------------
    
    // MARK: transforming
    
    func testMap()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let stream = KVO.stream(obj1, "value") |> map { (value: AnyObject?) -> NSString? in
            return (value as! String).uppercaseString
        }
        
        // REACT
        (obj2, "value") <~ stream
        
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
    
    func testFlatMap()
    {
        // NOTE: this is async test
        if !self.isAsync { return }
        
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        // NOTE: `mapClosure` is returning Stream
        let stream = KVO.stream(obj1, "value") |> flatMap { (value: AnyObject?) -> Stream<AnyObject?> in
            // delay sending value for 0.01 sec
            return NSTimer.stream(timeInterval: 0.01, repeats: false) { _ in value }
        }
        
        // REACT
        (obj2, "value") <~ stream
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "initial", "`obj2.value` should NOT be updated because `stream` is delayed.")
            
            // wait for "hoge" to arrive...
            Async.main(after: 0.1) {
                
                XCTAssertEqual(obj1.value, "hoge")
                XCTAssertEqual(obj2.value, "hoge", "`obj2.value` should be updated because delayed `stream` message arrived.")
                
                obj1.value = "fuga"
                
                XCTAssertEqual(obj1.value, "fuga")
                XCTAssertEqual(obj2.value, "hoge", "`obj2.value` should NOT be updated because `stream` is delayed.")
            }
            
            // wait for "fuga" to arrive...
            Async.main(after: 0.2 + SAFE_DELAY) {
                
                XCTAssertEqual(obj1.value, "fuga")
                XCTAssertEqual(obj2.value, "fuga", "`obj2.value` should be updated because delayed `stream` message arrived.")
                
                expect.fulfill()
            }
        }
        
        self.wait()
    }
    
    func testMap2()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let stream = KVO.stream(obj1, "value") |> map2 { (oldValue: AnyObject??, newValue: AnyObject?) -> NSString? in
            let oldString = (oldValue as? NSString) ?? "empty"
            return "\(oldString) -> \(newValue as! String)"
        }
        
        // REACT
        (obj2, "value") <~ stream
        
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
    func testMapAccumulate()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        
        let stream = KVO.stream(obj1, "value") |> mapAccumulate([]) { accumulatedValue, newValue -> [String] in
            return accumulatedValue + [newValue as! String]
        }
        
        var result: [String]?
        
        // REACT
        stream ~> { result = $0 }
        
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
    
    func testBuffer()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        
        let stream: Stream<[AnyObject?]> = KVO.stream(obj1, "value") |> buffer(3)
        
        var result: String? = "no result"
        
        // REACT
        stream ~> { (buffer: [AnyObject?]) in
            let buffer_: [String] = buffer.map { $0 as! String }
            result = "-".join(buffer_)
        }
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(result!, "no result", "`result` should NOT be updated because `stream`'s newValue is buffered.")
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(result!, "no result", "`result` should NOT be updated because `stream`'s newValue is buffered.")
            
            obj1.value = "piyo"
            
            XCTAssertEqual(obj1.value, "piyo")
            XCTAssertEqual(result!, "hoge-fuga-piyo", "`result` should be updated with buffered values because buffer reached maximum count.")
            
            obj1.value = "foo"
            
            XCTAssertEqual(obj1.value, "foo")
            XCTAssertEqual(result!, "hoge-fuga-piyo", "`result` should NOT be updated because `stream`'s newValue is buffered.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testBufferBy()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let trigger = MyObject()
        
        let triggerStream = KVO.stream(trigger, "value")
        let stream: Stream<[AnyObject?]> = KVO.stream(obj1, "value") |> bufferBy(triggerStream)
        
        var result: String? = "no result"
        
        // REACT
        stream ~> { (buffer: [AnyObject?]) in
            let buffer_: [String] = buffer.map { $0 as! String }
            result = "-".join(buffer_)
        }
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(result!, "no result", "`result` should NOT be updated because `stream`'s newValue is buffered but `triggerStream` is not triggered yet.")
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(result!, "no result", "`result` should NOT be updated because `stream`'s newValue is buffered but `triggerStream` is not triggered yet.")
            
            trigger.value = "DUMMY" // fire triggerStream
            
            XCTAssertEqual(result!, "hoge-fuga", "`result` should be updated with buffered values.")
            
            trigger.value = "DUMMY2" // fire triggerStream
            
            XCTAssertEqual(result!, "", "`result` should be updated with NO buffered values.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testGroupBy()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        
        // group by `key = countElement(value)`
        let stream: Stream<(Int, Stream<AnyObject?>)> = KVO.stream(obj1, "value") |> groupBy { count($0! as! String) }
        
        var lastKey: Int?
        var lastValue: String?
        
        // REACT
        stream ~> { (key: Int, groupedStream: Stream<AnyObject?>) in
            lastKey = key
            
            // REACT
            groupedStream ~> { value in
                lastValue = value as? String
                return
            }
        }
        
        println("*** Start ***")
        
        XCTAssertNil(lastKey)
        XCTAssertNil(lastValue)
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(lastKey!, 4)
            XCTAssertEqual(lastValue!, "hoge")
            
            obj1.value = "fuga"
            
            XCTAssertEqual(lastKey!, 4)
            XCTAssertEqual(lastValue!, "fuga")
            
            obj1.value = "foo"
            
            XCTAssertEqual(lastKey!, 3)
            XCTAssertEqual(lastValue!, "foo")
            
            obj1.value = "&"
            
            XCTAssertEqual(lastKey!, 1)
            XCTAssertEqual(lastValue!, "&")
            
            obj1.value = "bar"
            
            XCTAssertEqual(lastKey!, 1, "`groupedStream` with key=3 is already emitted, so `lastKey` will not be updated.")
            XCTAssertEqual(lastValue!, "bar")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    // MARK: filtering
    
    func testFilter()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let stream = KVO.stream(obj1, "value") |> filter { (value: AnyObject?) -> Bool in
            return value as! String == "fuga"
        }
        
        // REACT
        (obj2, "value") <~ stream
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "initial", "obj2.value should not be updated because stream is not sent via filter().")
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(obj2.value, "fuga")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testFilter2()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        
        // NOTE: this is distinct stream
        let stream = KVO.stream(obj1, "value") |> filter2 { (oldValue: AnyObject??, newValue: AnyObject?) -> Bool in
            
            // don't filter for first value
            if oldValue == nil { return true }
            
            return oldValue as! String != newValue as! String
        }
        
        var count = 0
        
        // REACT
        stream ~> { _ in count++; return }
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(count, 1)
            
            obj1.value = "fuga"
            
            XCTAssertEqual(count, 2)
            
            obj1.value = "fuga" // same value as before
            
            XCTAssertEqual(count, 2, "`count` should NOT be incremented because previous value was same (should be distinct)")
            
            obj1.value = "hoge"
            
            XCTAssertEqual(count, 3, "`count` should be incremented.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testTake()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let stream = KVO.stream(obj1, "value") |> take(1)  // only take 1 event
        
        // REACT
        (obj2, "value") <~ stream
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "hoge")
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(obj2.value, "hoge", "obj2.value should not be updated because stream is finished via take().")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testTake_fulfilled()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        var progressCount = 0
        var successCount = 0
        
        let obj1 = MyObject()
        
        let sourceStream = KVO.stream(obj1, "value")
        let takeStream = sourceStream |> take(1)  // only take 1 event
        
        // REACT 
        ^{ _ in progressCount++; return } <~ takeStream
        
        // success
        takeStream.success {
            successCount++
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
    
    func testTake_rejected()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        
        let sourceStream = KVO.stream(obj1, "value")
        let takeStream = sourceStream |> take(1)   // only take 1 event
        
        // failure
        takeStream.failure { errorInfo -> Void in
            
            XCTAssertEqual(errorInfo.error!.domain, ReactKitError.Domain, "`sourceStream` is cancelled before any progress, so `takeStream` should fail.")
            XCTAssertEqual(errorInfo.error!.code, ReactKitError.CancelledByUpstream.rawValue)
            
            XCTAssertFalse(errorInfo.isCancelled, "Though `sourceStream` is cancelled, `takeStream` is rejected rather than cancelled.")
            
            expect.fulfill()
        
        }
        
        takeStream.resume() // NOTE: resume manually
        
        self.perform { [weak sourceStream] in
            sourceStream?.cancel()
            return
        }
        
        self.wait()
    }
    
    func testTakeUntil()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let stopper = MyObject()
        
        let stoppingStream = KVO.stream(stopper, "value")    // store stoppingStream to live until end of runloop
        let stream = KVO.stream(obj1, "value") |> takeUntil(stoppingStream)
        
        // REACT
        (obj2, "value") <~ stream
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "hoge")
            
            stopper.value = "DUMMY" // fire stoppingStream
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(obj2.value, "hoge", "obj2.value should not be updated because stream is stopped via takeUntil(stoppingStream).")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testSkip()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let stream = KVO.stream(obj1, "value") |> skip(1)  // skip 1 event
        
        // REACT
        (obj2, "value") <~ stream
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
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
    
    func testSkipUntil()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let stopper = MyObject()
        
        let startingStream = KVO.stream(stopper, "value")
        let stream = KVO.stream(obj1, "value") |> skipUntil(startingStream)
        
        // REACT
        (obj2, "value") <~ stream
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "initial", "obj2.value should not be changed due to `skipUntil()`.")
            
            stopper.value = "DUMMY" // fire startingStream
            
            obj1.value = "fuga"
            
            XCTAssertEqual(obj1.value, "fuga")
            XCTAssertEqual(obj2.value, "fuga", "obj2.value should be updated because `startingStream` is triggered so that `skipUntil(startingStream)` should no longer skip.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testSample()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let sampler = MyObject()
        
        let samplingStream = KVO.stream(sampler, "value")
        let stream = KVO.stream(obj1, "value") |> sample(samplingStream)

        var reactCount = 0
        
        // REACT
        (obj2, "value") <~ stream
        stream ~> { _ in reactCount++; return }
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            sampler.value = "DUMMY"  // fire samplingStream
            XCTAssertEqual(obj2.value, "initial", "`obj2.value` should not be updated because `obj1.value` has not sent yet.")
            XCTAssertEqual(reactCount, 0)
            
            obj1.value = "hoge"
            XCTAssertEqual(obj2.value, "initial", "`obj2.value` should not be updated because although `obj1` has changed, `samplingStream` has not triggered yet.")
            XCTAssertEqual(reactCount, 0)
            
            sampler.value = "DUMMY"
            XCTAssertEqual(obj2.value, "hoge", "`obj2.value` should be updated, triggered by `samplingStream` using latest `obj1.value`.")
            XCTAssertEqual(reactCount, 1)

            sampler.value = "DUMMY"
            XCTAssertEqual(obj2.value, "hoge")
            XCTAssertEqual(reactCount, 2)
            
            obj1.value = "fuga"
            obj1.value = "piyo"
            
            sampler.value = "** check ** "
            XCTAssertEqual(obj2.value, "piyo")
            XCTAssertEqual(reactCount, 3)
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
    func testDistinct()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let stream = KVO.stream(obj1, "value")
            |> map { (($0 as? NSString) ?? "") }    // create stream with Hashable value-type for `distinct()`
            |> distinct
            |> map { $0 as NSString? }  // convert: Stream<NSString> -> Stream<NSString?>
        
        var reactCount = 0
        
        // REACT
        (obj2, "value") <~ stream
        stream ~> { _ in reactCount++; return }
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            XCTAssertEqual(obj2.value, "hoge")
            XCTAssertEqual(reactCount, 1)
            
            obj1.value = "fuga"
            XCTAssertEqual(obj2.value, "fuga")
            XCTAssertEqual(reactCount, 2)

            obj1.value = "hoge"
            XCTAssertEqual(obj2.value, "fuga")
            XCTAssertEqual(reactCount, 2, "`reactCount` should not be incremented because `hoge` is already sent thus filtered by `distinct()` method.")
            
            obj1.value = "fuga"
            XCTAssertEqual(obj2.value, "fuga")
            XCTAssertEqual(reactCount, 2, "`reactCount` should not be incremented because `fuga` is already sent thus filtered by `distinct()` method.")

            obj1.value = "piyo"
            XCTAssertEqual(obj2.value, "piyo")
            XCTAssertEqual(reactCount, 3)
            
            expect.fulfill()
            
        }
        
        self.wait()
    }

    // MARK: combining
    
    func testStartWith()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let stream1 = KVO.stream(obj1, "value")
        
        var bundledStream = stream1 |> startWith("start!")
        
        // REACT
        (obj2, "value") <~ bundledStream
        
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
    
    func testCombineLatest()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let obj3 = MyObject()
        
        let stream1 = KVO.stream(obj1, "value")
        let stream2 = KVO.stream(obj2, "number")
        
        let bundledStream = stream1 |> combineLatest(stream2) |> map { (values: [AnyObject?]) -> NSString? in
            let value0: AnyObject = values[0]!
            let value1: AnyObject = values[1]!
            return "\(value0)-\(value1)"
        }
        
        // REACT
        (obj3, "value") <~ bundledStream
        
        println("*** Start ***")
        
        XCTAssertEqual(obj3.value, "initial")
        
        self.perform {
            
            obj1.value = "test1"
            XCTAssertEqual(obj3.value, "initial")
            
            obj1.value = "test2"
            XCTAssertEqual(obj3.value, "initial")
            
            obj2.value = "test3"
            XCTAssertEqual(obj3.value, "initial", "`obj3.value` should NOT be updated because `bundledStream` doesn't react to `obj2.value` (reacts to `obj2.number`).")
            
            obj2.number = 123
            XCTAssertEqual(obj3.value, "test2-123")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testZip()
    {
        if self.isAsync { return }
        
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        // create streams which will never be fulfilled/rejected
        let stream1: Stream<Any> = Stream.sequence([0, 1, 2, 3, 4])
            |> concat(Stream.never())
        let stream2: Stream<Any> = Stream.sequence(["A", "B", "C"])
            |> concat(Stream.never())
        
        var bundledStream = stream1 |> zip(stream2) |> map { (values: [Any]) -> String in
            let valueStrings = values.map { "\($0)" }
            return "-".join(valueStrings)
        }
        
        println("*** Start ***")
        
        var reactCount = 0
        
        // REACT
        bundledStream ~> { value in
            reactCount++
            
            println(value)
            
            switch reactCount {
                case 1:
                    XCTAssertEqual(value, "0-A")
                case 2:
                    XCTAssertEqual(value, "1-B")
                case 3:
                    XCTAssertEqual(value, "2-C")
                default:
                    XCTFail("Should never reach here.")
            }
        }
        
        bundledStream.then { _ -> Void in
            XCTAssertEqual(reactCount, 3)
            expect.fulfill()
        }
        
        // force-cancel after zip-test complete
        Async.main(after: 0.1) {
            bundledStream.cancel()
        }
        
        self.wait()
        
        XCTAssertEqual(reactCount, 3)
    }
    
    // MARK: timing
    
    func testInterval()
    {
        if !self.isAsync { return }
        
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let faster: NSTimeInterval = 0.1
        
        let stream = Stream.sequence(0...2) |> interval(1.0 * faster)
        
        var results = [Int]()
        
        // REACT
        stream ~> { value in
            results += [value]
            println("[REACT] value = \(value)")
        }
        
        println("*** Start ***")
        
        XCTAssertEqual(results, [])
        
        self.perform() {
            
            Async.main(after: 0.01 * faster) {
                XCTAssertEqual(results, [0])
            }
            
            Async.main(after: 1.01 * faster) {
                XCTAssertEqual(results, [0, 1])
            }
            
            Async.main(after: 2.01 * faster) {
                XCTAssertEqual(results, [0, 1, 2])
                expect.fulfill()
            }
            
        }
        
        self.wait()
    }
    
    func testThrottle()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
     
        let timeInterval: NSTimeInterval = 0.2
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let stream = KVO.stream(obj1, "value") |> throttle(timeInterval)
        
        // REACT
        (obj2, "value") <~ stream
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
            obj1.value = "hoge"
            
            XCTAssertEqual(obj1.value, "hoge")
            XCTAssertEqual(obj2.value, "hoge")
            
            obj1.value = "hoge2"
            
            XCTAssertEqual(obj1.value, "hoge2")
            XCTAssertEqual(obj2.value, "hoge", "obj2.value should not be updated because stream is throttled to \(timeInterval) sec.")
            
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
    
    func testDebounce()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let timeInterval: NSTimeInterval = 0.2
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        let stream = KVO.stream(obj1, "value") |> debounce(timeInterval)
        
        // REACT
        (obj2, "value") <~ stream
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.value, "initial")
        XCTAssertEqual(obj2.value, "initial")
        
        self.perform {
            
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
    
    // MARK: collecting
    
    func testReduce()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        var stream = Stream.sequence([1, 2, 3])
        if self.isAsync {
            stream = stream |> delay(0.01)
        }
        stream = stream |> reduce(100) { $0 + $1 }
        
        var result: Int?
        
        // REACT
        stream ~> { result = $0 }
        
        println("*** Start ***")
        
        self.perform(after: 0.1) {
            XCTAssertEqual(result!, 106, "`result` should be 106 (100 + 1 + 2 + 3).")
            expect.fulfill()
        }
        
        self.wait()
    }
    
    //--------------------------------------------------
    // MARK: - Array Streams Operations
    //--------------------------------------------------
    
    //
    // NOTE: 
    // `merge2All()` works like both `Rx.merge()` and `Rx.combineLatest()`.
    // This test demonstrates `combineLatest` example.
    //
    func testMerge2All()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let obj3 = MyObject()
        
        let stream1 = KVO.stream(obj1, "value")
        let stream2 = KVO.stream(obj2, "number")
        
        let bundledStream = [stream1, stream2] |> merge2All |> map { (values: [AnyObject??], _) -> NSString? in
            let value0: AnyObject = (values[0] ?? "notYet") ?? "nil"
            let value1: AnyObject = (values[1] ?? "notYet") ?? "nil"
            return "\(value0)-\(value1)"
        }
        
        // REACT
        (obj3, "value") <~ bundledStream
        
        println("*** Start ***")
        
        self.perform {
            XCTAssertEqual(obj3.value, "initial")
            
            obj1.value = "test1"
            XCTAssertEqual(obj3.value, "test1-notYet")
            
            obj1.value = "test2"
            XCTAssertEqual(obj3.value, "test2-notYet")
            
            obj2.value = "test3"
            XCTAssertEqual(obj3.value, "test2-notYet", "`obj3.value` should NOT be updated because `bundledStream` doesn't react to `obj2.value` (reacts to `obj2.number`).")
            
            obj2.number = 123
            XCTAssertEqual(obj3.value, "test2-123")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testCombineLatestAll()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let obj3 = MyObject()
        
        let stream1 = KVO.stream(obj1, "value")
        let stream2 = KVO.stream(obj2, "number")
        
        let combinedStream = [stream1, stream2] |> combineLatestAll |> map { (values: [AnyObject?]) -> NSString? in
            let value0: AnyObject = (values[0] ?? "nil")
            let value1: AnyObject = (values[1] ?? "nil")
            return "\(value0)-\(value1)"
        }
        
        // REACT
        (obj3, "value") <~ combinedStream
        
        println("*** Start ***")
        
        self.perform {
            XCTAssertEqual(obj3.value, "initial")
            
            obj1.value = "test1"
            XCTAssertEqual(obj3.value, "initial", "`combinedStream` should not send value because only `obj1.value` is changed.")
            
            obj1.value = "test2"
            XCTAssertEqual(obj3.value, "initial", "`combinedStream` should not send value because only `obj1.value` is changed.")
            
            obj2.number = 123
            XCTAssertEqual(obj3.value, "test2-123", "`obj3.value` should be updated for the first time because both `obj1.value` & `obj2.number` has been changed.")
            
            obj2.number = 456
            XCTAssertEqual(obj3.value, "test2-456")
            
            obj1.value = "test4"
            XCTAssertEqual(obj3.value, "test4-456")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
    func testConcatInner()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        
        let stream1: Stream<AnyObject?> = NSTimer.stream(timeInterval: 0.1, userInfo: nil, repeats: false) { _ in "Next" }
        let stream2: Stream<AnyObject?> = NSTimer.stream(timeInterval: 0.3, userInfo: nil, repeats: false) { _ in 123 }
        
        var concatStream = [stream1, stream2] |> concatInner |> map { (value: AnyObject?) -> NSString? in
            let valueString: AnyObject = value ?? "nil"
            return "\(valueString)"
        }
        
        // REACT
        (obj1, "value") <~ concatStream
        
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
    
    func testSwitchLatestInner()
    {
        if !self.isAsync { return }
        
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let faster: NSTimeInterval = 0.1
        
        ///
        /// - innerStream0: starts at `t = 0`
        ///     - emits 1 at `t = 0.0`
        ///     - emits 2 at `t = 0.6`
        ///     - emits 3 at `t = 1.2` (will be ignored by switchLatestInner)
        /// - innerStream1: starts at `t = 1`
        ///     - emits 4 at `t = 0.0 + 1`
        ///     - emits 5 at `t = 0.6 + 1`
        ///     - emits 6 at `t = 1.2 + 1` (will be ignored by switchLatestInner)
        /// - innerStream2: starts at `t = 2`
        ///     - emits 7 at `t = 0.0 + 2`
        ///     - emits 8 at `t = 0.6 + 2`
        ///     - emits 9 at `t = 1.2 + 2`
        ///
        let nestedStream: Stream<Stream<Int>>
        nestedStream = Stream.sequence(0...2)
            |> interval(1.0 * faster)
            |> map { (v: Int) -> Stream<Int> in
                let innerStream = Stream.sequence((3*v+1)...(3*v+3))
                    |> interval(0.6 * faster)
                innerStream.name = "innerStream\(v)"
                return innerStream
            }
        
        let switchingStream = nestedStream |> switchLatestInner
        
        var results = [Int]()
        
        // REACT
        switchingStream ~> { value in
            results += [value]
            println("[REACT] value = \(value)")
        }
        
        println("*** Start ***")
        
        self.perform(after: 4.0 * faster) {
            XCTAssertEqual(results, [1, 2, 4, 5, 7, 8, 9], "Some of values sent by `switchingStream`'s `innerStream`s should be ignored.")
            expect.fulfill()
        }
        
        self.wait()
    }
    
    //--------------------------------------------------
    // MARK: - Nested Stream<Stream<T>> Operations
    //--------------------------------------------------
    
    func testMergeInner()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let obj3 = MyObject()
        
        let stream1 = KVO.stream(obj1, "value")
        let stream2 = KVO.stream(obj2, "number")
        
        var bundledStream = [stream1, stream2] |> mergeInner |> map { (value: AnyObject?) -> NSString? in
            let valueString: AnyObject = value ?? "nil"
            return "\(valueString)"
        }
        
        // REACT
        (obj3, "value") <~ bundledStream
        
        println("*** Start ***")
        
        self.perform {
            XCTAssertEqual(obj3.value, "initial")
            
            obj1.value = "test1"
            XCTAssertEqual(obj3.value, "test1")
            
            obj1.value = "test2"
            XCTAssertEqual(obj3.value, "test2")
            
            obj2.value = "test3"
            XCTAssertEqual(obj3.value, "test2", "`obj3.value` should NOT be updated because `bundledStream` doesn't react to `obj2.value` (reacts to `obj2.number`).")
            
            obj2.number = 123
            XCTAssertEqual(obj3.value, "123")
            
            expect.fulfill()
        }
        
        self.wait()
    }
    
}

class AsyncOperationTests: OperationTests
{
    override var isAsync: Bool { return true }
}