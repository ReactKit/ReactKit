//
//  SyncTests.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2015/05/22.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import XCTest

class SyncTests: _TestCase
{
    func testFizzBuzz()
    {
        var results = [String]()
        results += ["zero"] // add dummy for index=0

        Stream.sequence(1...100)
            |> map { x -> String in
                switch x {
                    case _ where x % 15 == 0:
                        return "FizzBuzz"
                    case _ where x % 3 == 0:
                        return "Fizz"
                    case _ where x % 5 == 0:
                        return "Buzz"
                    default:
                        return "\(x)"
                }
            }
//            ~>! print
            ~>! { x in
                print(x)
                results += [x]
            }
        
        XCTAssertEqual(results.count, 101, "1 dummy insertion + 100 side effects.")
        XCTAssertEqual(results[1], "1")
        XCTAssertEqual(results[2], "2")
        XCTAssertEqual(results[3], "Fizz")
        XCTAssertEqual(results[4], "4")
        XCTAssertEqual(results[5], "Buzz")
        XCTAssertEqual(results[6], "Fizz")
        XCTAssertEqual(results[7], "7")
        XCTAssertEqual(results[15], "FizzBuzz")
        XCTAssertEqual(results[99], "Fizz")
    }
    
    func testFibonacci()
    {
        let fibArray = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181, 6765, 10946]
        
        let fib = Stream.infiniteSequence((0, 1)) { a in (a.1, a.0 + a.1) }
            |> map { a in a.0 }
            |> take(fibArray.count)
            |> buffer()     // similar to `.collect(Collectors.toList())` in Java 8 Stream API
            ~>! ()          // `~>! ()` as terminal operation for synchronous get

        XCTAssertEqual(fib, fibArray)
    }
}