//
//  AsyncTests.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2015/05/23.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import SwiftTask
//import Async
import XCTest


class AsyncTests: _TestCase
{
    override var isAsync: Bool { return true }
    
    func testStartAsync()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let queue0 = dispatch_queue_create("queue0", DISPATCH_QUEUE_SERIAL)
        let queue1 = dispatch_queue_create("queue1", DISPATCH_QUEUE_SERIAL)
        
        var count = 0
        let n = 100
        
        let upstream = Stream.sequence(1...n)
        let downstream = upstream |> startAsync(queue1)
        
        print("*** Start ***")
        
        // starting from queue0
        dispatch_async(queue0) {
            // REACT
            downstream ~> { value in
                count++
                XCTAssertTrue(_isCurrentQueue(queue1), "Must be queue1 thread.")
                
                NSLog("[sink] value = \(value), \(NSThread.currentThread())")
                
                if value == n {
                    expect.fulfill()
                }
            }
        }
        
        self.wait()
        
        XCTAssertEqual(count, n)
    }
    
    func testAsync()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let queue0 = dispatch_queue_create("queue0", DISPATCH_QUEUE_SERIAL)
        let queue1 = dispatch_queue_create("queue1", DISPATCH_QUEUE_SERIAL)
        
        let n = 100
        var count: Int = 0
        
        let upstream = Stream.sequence(1...n)
        let downstream = upstream |> async(queue1)
        
        print("*** Start ***")
        
        // starting from queue0
        dispatch_async(queue0) {
            // REACT
            downstream ~> { value in
                count++
                XCTAssertTrue(_isCurrentQueue(queue1), "Must be queue1 thread.")
                
                NSLog("[sink] value = \(value), \(NSThread.currentThread())")
                
                if value == n {
                    expect.fulfill()
                }
            }
        }
        
        self.wait()
            
        XCTAssertEqual(count, n)
    }
    
    func testBoth_startAsync_async()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let queue0 = dispatch_queue_create("queue0", DISPATCH_QUEUE_SERIAL)
        let queue1 = dispatch_queue_create("queue1", DISPATCH_QUEUE_SERIAL)
        let queue2 = dispatch_queue_create("queue2", DISPATCH_QUEUE_SERIAL)
        
        let n = 100
        let consumerDelay = 0.1 // slow consumer test
        var count: Int = 0
        let lock = NSRecursiveLock()
        
        let upstream = Stream.sequence(1...n)
        let downstream = upstream
            |> startAsync(queue1)
            |> peek { value in
                lock.lock(); count++; lock.unlock();    // count up
                XCTAssertTrue(_isCurrentQueue(queue1), "Must be queue1 thread.")
                
                NSLog("[peek1] value = \(value), \(NSThread.currentThread())")
            }
            |> async(queue2)
            |> peek { value in
                lock.lock(); count++; lock.unlock();    // count up
                XCTAssertTrue(_isCurrentQueue(queue2), "Must be queue2 thread.")
                
                NSLog("[peek2] value = \(value), \(NSThread.currentThread())")
            }
        
        print("*** Start ***")
        
        // starting from queue0
        dispatch_async(queue0) {
            // REACT
            downstream ~> { value in
                lock.lock(); count++; lock.unlock();    // count up
                XCTAssertTrue(_isCurrentQueue(queue2), "Must be queue2 thread.")
                
                NSLog("[sink] value = \(value), \(NSThread.currentThread())")
                
                // sleep for simulating slow consumer
//                NSThread.sleepForTimeInterval(consumerDelay)
                
                if value == n {
                    expect.fulfill()
                }
            }
        }
        
        self.wait(consumerDelay*Double(n)+1)
        
        XCTAssertEqual(count, 3*n)
    }
    
    func testAsyncBackpressureBlock()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let queue0 = dispatch_queue_create("queue0", DISPATCH_QUEUE_SERIAL)
        let queue1 = dispatch_queue_create("queue1", DISPATCH_QUEUE_SERIAL)
        
        let n = 100
        let consumerDelay = 0.01 // 0.1 // slow consumer test
        var count: Int = 0
        let lock = NSRecursiveLock()
        
        let upstream = Stream.sequence(1...n)
        let downstream = upstream
            |> peek { value in
                lock.lock(); count++; lock.unlock();    // count up
                XCTAssertTrue(_isCurrentQueue(queue0), "Must be queue1 thread.")
                
                NSLog("[peek1] value = \(value), \(NSThread.currentThread())")
            }
            |> asyncBackpressureBlock(queue1, high: 5, low: 1)
        
        print("*** Start ***")
        
        // starting from queue0
        dispatch_async(queue0) {
            // REACT
            downstream ~> { value in
                lock.lock(); count++; lock.unlock();    // count up
                XCTAssertTrue(_isCurrentQueue(queue1), "Must be queue1 thread.")
                
                NSLog("[sink] value = \(value), \(NSThread.currentThread())")
                
                // sleep for simulating slow consumer
                NSThread.sleepForTimeInterval(consumerDelay)
                
                if value == n {
                    expect.fulfill()
                }
            }
        }
        
        self.wait(consumerDelay*Double(n)+1)
        
        XCTAssertEqual(count, 2*n)
    }
}