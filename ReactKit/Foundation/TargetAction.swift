//
//  TargetAction.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/10/03.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import Foundation

internal let _targetActionSelector: Selector = Selector("_fire:")

internal class _TargetActionProxy
{
    // NOTE: can't use generics
    internal typealias T = AnyObject
    
    internal typealias Handler = T -> Void
    
    internal var handler: Handler
    
    internal init(handler: Handler)
    {
        self.handler = handler
        
//        #if DEBUG
//            println("[init] \(self)")
//        #endif
    }
    
    deinit
    {
//        #if DEBUG
//            println("[deinit] \(self)")
//        #endif
    }
    
    // NOTE: add @objc for 'does not implement methodSignatureForSelector' error
    // NOTE: can't use 'private' due to unrecognized selector
    @objc internal func _fire(sender: T)
    {
        self.handler(sender)
    }
}