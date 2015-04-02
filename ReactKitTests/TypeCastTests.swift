//
//  TypeCastTests.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2015/04/02.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import XCTest

class TypeCastTests: _TestCase
{
    func testTypeCast()
    {
        let intStreamProducer: Void -> Stream<Int> = { Stream.once(1) }
        
        let optIntStreamProducer: Void -> Stream<Int?> = intStreamProducer |>> asStream(Int?)
        let numberStreamProducer: Void -> Stream<NSNumber> = intStreamProducer |>> asStream(NSNumber)
        let optNumberStreamProducer: Void -> Stream<NSNumber?> = intStreamProducer |>> asStream(NSNumber?)
        
        let concatStream: Stream<Any?> = [
            optIntStreamProducer() |> asStream(Any?),
            numberStreamProducer() |> asStream(Any?),
            optNumberStreamProducer() |> asStream(Any?)
        ] |> concatAll
        
        var reactCount = 0
        
        // REACT
        concatStream ~> { value in
            println("value = \(value)")
            reactCount++
        }
        
        XCTAssertEqual(reactCount, 3)
    }
}