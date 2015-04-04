//
//  StreamProducerTests.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2015/03/31.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import XCTest

class StreamProducerTests: _TestCase
{
    func testStreamProducer()
    {
        if !self.isAsync { return }
        
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        //
        // NOTE: `|>>` as streamProducer (stream-returning closure) pipelining operator
        //
        // In the below example, 
        //
        //   `let streamProducer = createStream() |>> map { $0 }`
        //
        // is equivalent to:
        //
        //   `let streamProducer = { createStream() } |>> map { $0 }`   // by @autoclosure
        //
        // which is NOT equivalent to:
        //
        //   ```
        //   let stream = createStream()
        //   let streamProducer = { stream } |>> map { $0 }     // reusing same stream!
        //   ```
        //
        let streamProducer: Void -> Stream<Int>
        streamProducer = NSTimer.stream(timeInterval: 0.01, repeats: false) { _ in random() }
            |>> map { $0 }
        
        // NOTE: these two streams do not send same values!
        let stream1 = streamProducer()
        let stream2 = streamProducer()
        
        var int1a, int1b, int2: Int?
        
        // REACT
        stream1 ~> { value in
            int1a = value
            println("[REACT] int1a = \(int1a)")
        }
        stream1 ~> { value in
            int1b = value
            println("[REACT] int1b = \(int1b)")
        }
        
        // REACT (start after 1st check)
        Async.main(after: 0.1) {
            stream2 ~> { value in
                int2 = value
                println("[REACT] int2 = \(int2)")
            }
        }
        
        println("*** Start ***")
        
        // 1st check
        Async.main(after: 0.05) {
            XCTAssertNotNil(int1a)
            XCTAssertNotNil(int1b)
            XCTAssertEqual(int1a!, int1b!)
            
            XCTAssertNil(int2, "`stream2` is not started yet, so `int2` is not set.")
        }
        
        // 2nd check
        Async.main(after: 0.15) {
            XCTAssertNotNil(int2, "`int2` should be set after delay.")
            
            XCTAssertNotEqual(int1a!, int2!, "`int2` is set via `stream2` and `int1a` is set via `stream1`, so these values should not be shared (equal).")
            
            expect.fulfill()
        }
        
        self.wait()
    }
}

class AsyncStreamProducerTests: StreamProducerTests
{
    override var isAsync: Bool { return true }
}