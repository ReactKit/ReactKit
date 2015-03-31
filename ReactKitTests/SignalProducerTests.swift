//
//  SignalProducerTests.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2015/03/31.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import XCTest

class SignalProducerTests: _TestCase
{
    func testSignalProducer()
    {
        if !self.isAsync { return }
        
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        // NOTE: `|>>` as signalProducer (signal-returning closure) pipelining operator
        let signalProducer: Void -> Signal<Int> = Signal.once("DUMMY") |>> delay(0.01) |>> map { _ in random() }
        let signal1 = signalProducer()
        let signal2 = signalProducer()
        
        var int1a, int1b, int2: Int?
        
        // REACT
        signal1 ~> { value in
            int1a = value
            println("[REACT] int1a = \(int1a)")
        }
        signal1 ~> { value in
            int1b = value
            println("[REACT] int1b = \(int1b)")
        }
        signal2 ~> { value in
            int2 = value
            println("[REACT] int2 = \(int2)")
        }
        
        println("*** Start ***")
        
        Async.main(after: 0.02) {
            XCTAssertNotNil(int1a)
            XCTAssertNotNil(int1b)
            XCTAssertNotNil(int2)
            
            XCTAssertEqual(int1a!, int1b!)
            XCTAssertNotEqual(int1a!, int2!)
            
            expect.fulfill()
        }
        
        self.wait()
    }
}

class AsyncSignalProducerTests: SignalProducerTests
{
    override var isAsync: Bool { return true }
}