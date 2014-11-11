//
//  NSObject+Owner.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/11/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import Foundation

private var owninigSignalsKey: UInt8 = 0

internal extension NSObject
{
    internal typealias AnySignal = AnyObject // NOTE: can't use Signal<AnyObject?>
    
    internal var _owninigSignals: [AnySignal]
    {
        get {
            var owninigSignals = objc_getAssociatedObject(self, &owninigSignalsKey) as? [AnySignal]
            if owninigSignals == nil {
                owninigSignals = []
                self._owninigSignals = owninigSignals!
            }
            return owninigSignals!
        }
        set {
            objc_setAssociatedObject(self, &owninigSignalsKey, newValue, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
        }
    }
}