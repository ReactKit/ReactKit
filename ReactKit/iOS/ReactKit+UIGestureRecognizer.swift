//
//  ReactKit+UIGestureRecognizer.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/10/03.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import UIKit

// NOTE: see also ReactKit+UIControl
public extension UIGestureRecognizer
{
    public func signal<T>(#state: UIGestureRecognizerState, map: AnyObject? -> T) -> Signal<T>
    {
        return Signal(name: "\(NSStringFromClass(self.dynamicType))-\(state)") { progress, fulfill, reject, configure in
            
            let target = _TargetActionProxy { (self_: AnyObject?) in
                progress(map(self_))
            }
            
            configure.pause = { [weak self] in
                if let self_ = self {
                    self_.removeTarget(target, action: "_fire:")
                }
            }
            configure.resume = { [weak self] in
                if let self_ = self {
                    self_.addTarget(target, action: "_fire:")
                }
            }
            configure.cancel = { [weak self] in
                if let self_ = self {
                    self_.removeTarget(target, action: "_fire:")
                }
            }
            
            self.addTarget(target, action: "_fire:")
            
        }.takeUntil(self.deinitSignal)
    }
}