//
//  OperationTests.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2015/04/04.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import SwiftTask
import XCTest

class OperationTests: _TestCase
{
    // MARK: Collecting
    
    func testReduce()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        var stream = Stream(values: [1, 2, 3])
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
    
}

class AsyncOperationTests: OperationTests
{
    override var isAsync: Bool { return true }
}