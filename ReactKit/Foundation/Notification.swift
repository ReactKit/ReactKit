//
//  Notification.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import Foundation

public extension NSNotificationCenter
{
    /// creates new Signal
    public func signal(#notificationName: String, object: AnyObject? = nil) -> Signal<NSNotification?>
    {
        return Signal(name: "NSNotification-\(notificationName)") { progress, fulfill, reject, configure in
            
            let observer = self.addObserverForName(notificationName, object: object, queue: nil) { notification in
                progress(notification)
            }
            
            configure.cancel = {
                self.removeObserver(observer)
            }
            
        }.take(until: self.deinitSignal)
    }
}

/// NSNotificationCenter helper
public struct Notification
{
    public static func signal(notificationName: String, _ object: AnyObject?) -> Signal<NSNotification?>
    {
        return NSNotificationCenter.defaultCenter().signal(notificationName: notificationName, object: object)
    }
    
    public static func post(notificationName: String, _ object: AnyObject?)
    {
        NSNotificationCenter.defaultCenter().postNotificationName(notificationName, object: object)
    }
}