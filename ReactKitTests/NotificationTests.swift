//
//  NotificationTests.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import XCTest

class NotificationTests: _TestCase
{
    func testNotificationCenter()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        
        var stream = Notification.stream("MyNotification", obj1)
        
        // REACT
        (obj2, "notification") <~ stream
        
        // REACT
        ^{ println("[REACT] new value = \($0)") } <~ stream
        
        println("*** Start ***")
        
        XCTAssertNil(obj2.notification, "obj2.notification=nil at start.")
        
        self.perform {
            
            Notification.post("MyNotification", "DUMMY")
            
            XCTAssertNil(obj2.notification, "obj2.notification should not be updated because only obj1's MyNotification can be streamled.")
            
            Notification.post("MyNotification", obj1)
            
            XCTAssertNotNil(obj2.notification, "obj2.notification should be updated.")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
}

class AsyncNotificationTests: NotificationTests
{
    override var isAsync: Bool { return true }
}