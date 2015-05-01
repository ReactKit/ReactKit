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
        let intStreamProducer: Stream<Int, DefaultError>.Producer = { Stream.once(1) }
        
        let optIntStreamProducer: Stream<Int?, DefaultError>.Producer = intStreamProducer |>> asStream(Int?)
        let numberStreamProducer: Stream<NSNumber, DefaultError>.Producer = intStreamProducer |>> asStream(NSNumber)
        let optNumberStreamProducer: Stream<NSNumber?, DefaultError>.Producer = intStreamProducer |>> asStream(NSNumber?)
        
        let concatStream: Stream<Any?, DefaultError> = [
            optIntStreamProducer() |> asStream(Any?),
            numberStreamProducer() |> asStream(Any?),
            optNumberStreamProducer() |> asStream(Any?)
        ] |> concatInner
        
        var reactCount = 0
        
        // REACT
        concatStream ~> { value in
            println("value = \(value)")
            reactCount++
        }
        
        XCTAssertEqual(reactCount, 3)
    }
}