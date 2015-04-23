//
//  NSObject+Deinit.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/14.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import Foundation

private var deinitStreamKey: UInt8 = 0

public extension NSObject
{
    private var _deinitStream: Stream<AnyObject?>?
    {
        get {
            return objc_getAssociatedObject(self, &deinitStreamKey) as? Stream<AnyObject?>
        }
        set {
            objc_setAssociatedObject(self, &deinitStreamKey, newValue, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN))  // not OBJC_ASSOCIATION_RETAIN_NONATOMIC
        }
    }
    
    public var deinitStream: Stream<AnyObject?>
    {
        var stream: Stream<AnyObject?>? = self._deinitStream
        
        if stream == nil {
            stream = Stream<AnyObject?> { (progress, fulfill, reject, configure) in
                // do nothing
            }.name("\(NSStringFromClass(self.dynamicType))-deinitStream")
            
//            #if DEBUG
//                stream?.then { value, errorInfo -> Void in
//                    println("[internal] deinitStream finished")
//                }
//            #endif
            
            self._deinitStream = stream
        }
        
        return stream!
    }
}