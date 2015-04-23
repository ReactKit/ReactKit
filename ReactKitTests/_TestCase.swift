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
    var timeInterval: NSTimeInterval = 0.0
    
    var isAsync: Bool { return false }
    
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
    
    func perform(after: NSTimeInterval = 0.01, closure: Void -> Void)
    {
        self.timeInterval = after
        
        if self.isAsync {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1_000_000_000 * self.timeInterval)), dispatch_get_main_queue(), closure)
        }
        else {
            closure()
        }
    }
    
    func wait(filename: String = __FILE__, functionName: String = __FUNCTION__, line: Int = __LINE__)
    {
        self.waitForExpectationsWithTimeout(self.timeInterval + 1) { error in
            if let error = error {
                println()
                println("*** Wait Error ***")
                println("file = \(filename.lastPathComponent), \(functionName), line \(line)")
                println("error = \(error)")
                println()
            }
        }
    }
}