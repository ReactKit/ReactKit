//
//  NSObject+Deinit.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/14.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import Foundation

private var deinitSignalKey: UInt8 = 0

public extension NSObject
{
    private var _deinitSignal: Signal<AnyObject?>?
    {
        get {
            return objc_getAssociatedObject(self, &deinitSignalKey) as? Signal<AnyObject?>
        }
        set {
            objc_setAssociatedObject(self, &deinitSignalKey, newValue, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN))  // not OBJC_ASSOCIATION_RETAIN_NONATOMIC
        }
    }
    
    public var deinitSignal: Signal<AnyObject?>
    {
        var signal: Signal<AnyObject?>? = self._deinitSignal
        
        if signal == nil {
            signal = Signal<AnyObject?> { (progress, fulfill, reject, configure) in
                // do nothing
            }.name("\(NSStringFromClass(self.dynamicType))-deinitSignal")
            
//            #if DEBUG
//                signal?.then { value, errorInfo -> Void in
//                    println("[internal] deinitSignal finished")
//                }
//            #endif
            
            self._deinitSignal = signal
        }
        
        return signal!
    }
}