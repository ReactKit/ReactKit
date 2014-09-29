//
//  _TestCase.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import XCTest

typealias ErrorString = String

class _TestCase: XCTestCase
{
    override func setUp()
    {
        super.setUp()
        println("\n\n\n")
    }
    
    override func tearDown()
    {
        println("\n\n\n")
        super.tearDown()
    }
    
    func wait(handler: (Void -> Void)? = nil)
    {
        self.waitForExpectationsWithTimeout(3) { error in
            
            println("wait error = \(error)")
            
            if let handler = handler {
                handler()
            }
        }
    }
    
    var isAsync: Bool { return false }
    
    func perform(closure: Void -> Void)
    {
        if self.isAsync {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1000_000_000), dispatch_get_main_queue(), closure)
        }
        else {
            closure()
        }
    }
}