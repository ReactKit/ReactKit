//
//  InfiniteSequenceTests.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import XCTest

class InfiniteSequenceTests: _TestCase
{
    func testTake()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let sourceSignal = Signal(values: [Int](1...5))
        let takeSignal = sourceSignal.take(3)
        
        var sourceBuffer = [Int]()
        var takeBuffer = [Int]()
        
        // NOTE: peek = progress without auto-resume
        sourceSignal.peek { value in
            println("sourceSignal new value = \(value)")
            sourceBuffer += [value]
        }
        
        // REACT
        takeSignal ~> { value in
            println("[REACT] takeSignal new value = \(value)")
            takeBuffer += [value]
        }
        
        println("*** Start ***")
        
        self.perform {
            
            XCTAssertEqual(takeBuffer, [1, 2, 3])
            XCTAssertEqual(sourceBuffer, [1, 2, 3], "`sourceBuffer` should return 3 elements and not iterating all immediate-sequence values.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
}

class AsyncInfiniteSequenceTests: InfiniteSequenceTests
{
    override var isAsync: Bool { return true }
}