//
//  NSObject+Owner.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/11/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import Foundation

private var owninigStreamsKey: UInt8 = 0

internal extension NSObject
{
    internal typealias AnyStream = AnyObject // NOTE: can't use Stream<AnyObject?>
    
    internal var _owninigStreams: [AnyStream]
    {
        get {
            var owninigStreams = objc_getAssociatedObject(self, &owninigStreamsKey) as? [AnyStream]
            if owninigStreams == nil {
                owninigStreams = []
                self._owninigStreams = owninigStreams!
            }
            return owninigStreams!
        }
        set {
            objc_setAssociatedObject(self, &owninigStreamsKey, newValue, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
        }
    }
}