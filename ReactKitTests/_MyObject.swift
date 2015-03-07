//
//  _MyObject.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import XCTest

class MyObject: NSObject
{
    // NOTE: dynamic is required for KVO
    // http://vperi.com/2014/08/11/key-value-observation-in-swift-beta-5/
    dynamic var value: String = "initial"
    
    dynamic var number: NSNumber = 0
    
    dynamic var notification: NSNotification?
    
    dynamic var array: NSArray = []
    
    override init()
    {
        super.init()
//        println("[init] MyObject \(self.hash)")
    }
    
    deinit
    {
//        println("[deinit] MyObject \(self.hash)")
    }
}