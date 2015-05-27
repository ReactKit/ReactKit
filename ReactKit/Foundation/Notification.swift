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
    /// creates new Stream
    public func stream(#notificationName: String, object: AnyObject? = nil, queue: NSOperationQueue? = nil) -> Stream<NSNotification?>
    {
        return Stream { [weak self] progress, fulfill, reject, configure in
            
            var observer: NSObjectProtocol?
            
            configure.pause = {
                if let self_ = self {
                    if let observer_ = observer {
                        self_.removeObserver(observer_)
                        observer = nil
                    }
                }
            }
            configure.resume = {
                if let self_ = self {
                    if observer == nil {
                        observer = self_.addObserverForName(notificationName, object: object, queue: queue) { notification in
                            progress(notification)
                        }
                    }
                }
            }
            configure.cancel = {
                if let self_ = self {
                    if let observer_ = observer {
                        self_.removeObserver(observer_)
                        observer = nil
                    }
                }
            }
            
            configure.resume?()
            
        }.name("NSNotification.stream(\(notificationName))") |> takeUntil(self.deinitStream)
    }
}

/// NSNotificationCenter helper
public struct Notification
{
    public static func stream(notificationName: String, _ object: AnyObject?) -> Stream<NSNotification?>
    {
        return NSNotificationCenter.defaultCenter().stream(notificationName: notificationName, object: object)
    }
    
    public static func post(notificationName: String, _ object: AnyObject?)
    {
        NSNotificationCenter.defaultCenter().postNotificationName(notificationName, object: object)
    }
}