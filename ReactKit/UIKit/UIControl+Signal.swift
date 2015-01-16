//
//  UIControl+Signal.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/14.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import UIKit

public extension UIControl
{
    public func signal<T>(#controlEvents: UIControlEvents, map: UIControl? -> T) -> Signal<T>
    {
        return Signal { [weak self] progress, fulfill, reject, configure in
            
            let target = _TargetActionProxy { (self_: AnyObject?) in
                
                //
                // WARN:
                //
                // NEVER send `self_` to `progress()`, or incoming new signal e.g. `signal.filter()`
                // will capture `self_` if 1st progress is invoked, which will then cause 
                // self_.deinitSignal not able to invoked at right place.
                //
                // To avoid this issue, use `map` closure (given as argument) to change
                // the sending value at very first place.
                //
                //progress(self_)
                
                progress(map(self_ as? UIControl))
            }
            
            //
            // NOTE:
            // Set copies of same closure when using `[weak self]`,
            // or swift-compiler will fail with exit 1 in Swift 1.1.
            //
            configure.pause = {
                if let self_ = self {
                    self_.removeTarget(target, action: _targetActionSelector, forControlEvents: controlEvents)
                }
            }
            configure.resume = {
                if let self_ = self {
                    self_.addTarget(target, action: _targetActionSelector, forControlEvents: controlEvents)
                }
            }
            configure.cancel = {
                if let self_ = self {
                    self_.removeTarget(target, action: _targetActionSelector, forControlEvents: controlEvents)
                }
            }
            
        }.name("\(NSStringFromClass(self.dynamicType))-\(controlEvents)").takeUntil(self.deinitSignal)
    }
}