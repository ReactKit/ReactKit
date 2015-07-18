//
//  CustomOperatorTests.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import XCTest

class CustomOperatorTests: _TestCase
{
    /// e.g. `let value = stream ~>! ()`
    func testTerminalReactingOperator()
    {
        let sum: Int! = Stream.sequence([1, 2, 3]) |> reduce(100) { $0 + $1 } ~>! ()
        XCTAssertEqual(sum, 106)
        
        let distinctValues: [Int] = Stream.sequence([1, 2, 2, 3]) |> distinct |> buffer() ~>! ()
        XCTAssertEqual(distinctValues, [1, 2, 3])
    }
}

class AsyncCustomOperatorTests: CustomOperatorTests
{
    override var isAsync: Bool { return true }
}