//
//  ImmediateSequenceTests.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import XCTest

class ImmediateSequenceTests: _TestCase
{
    func testTake()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        var sourceBuffer = [Int]()
        var takeBuffer = [Int]()
        
        let sourceStream = Stream<Int, DefaultError>.sequence([Int](1...5))
            |> peek { value in
                println("sourceStream new value = \(value)")
                sourceBuffer += [value]
            }
        let takeStream = sourceStream |> take(3)
        
        // REACT
        takeStream ~> { value in
            println("[REACT] takeStream new value = \(value)")
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

class AsyncImmediateSequenceTests: ImmediateSequenceTests
{
    override var isAsync: Bool { return true }
}