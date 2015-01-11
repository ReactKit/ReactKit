//
//  UIGestureRecognizer+Signal.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/10/03.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import UIKit

// NOTE: see also UIControl+Signal
public extension UIGestureRecognizer
{
    public func signal<T>(map: UIGestureRecognizer? -> T) -> Signal<T>
    {
        return Signal { [weak self] progress, fulfill, reject, configure in
            
            let target = _TargetActionProxy { (self_: AnyObject?) in
                progress(map(self_ as? UIGestureRecognizer))
            }
            
            configure.pause = {
                if let self_ = self {
                    self_.removeTarget(target, action: _targetActionSelector)
                }
            }
            configure.resume = {
                if let self_ = self {
                    self_.addTarget(target, action: _targetActionSelector)
                }
            }
            configure.cancel = {
                if let self_ = self {
                    self_.removeTarget(target, action: _targetActionSelector)
                }
            }
            
        }.name("\(NSStringFromClass(self.dynamicType))").takeUntil(self.deinitSignal)
    }
}