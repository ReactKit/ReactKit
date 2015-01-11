//
//  UIBarButtonItem+Signal.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/10/08.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import UIKit

public extension UIBarButtonItem
{
    public func signal<T>(map: UIBarButtonItem? -> T) -> Signal<T>
    {
        return Signal { [weak self] progress, fulfill, reject, configure in
            
            let target = _TargetActionProxy { (self_: AnyObject?) in
                progress(map(self_ as? UIBarButtonItem))
            }
            
            let addTargetAction: Void -> Void = {
                if let self_ = self {
                    self_.target = target
                    self_.action = _targetActionSelector
                }
            }
            
            let removeTargetAction: Void -> Void = {
                if let self_ = self {
                    self_.target = nil
                    self_.action = nil
                }
            }
            
            configure.pause = {
                removeTargetAction()
            }
            configure.resume = {
                addTargetAction()
            }
            configure.cancel = {
                removeTargetAction()
            }
            
        }.name("\(NSStringFromClass(self.dynamicType))").takeUntil(self.deinitSignal)
    }
    
    public func signal<T>(mappedValue: T) -> Signal<T>
    {
        return self.signal { _ in mappedValue }
    }
}