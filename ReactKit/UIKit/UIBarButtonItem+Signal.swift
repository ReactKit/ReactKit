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
        return Signal(name: "\(NSStringFromClass(self.dynamicType))") { progress, fulfill, reject, configure in
            
            let target = _TargetActionProxy { (self_: AnyObject?) in
                progress(map(self_ as? UIBarButtonItem))
            }
            
            let addTargetAction: Void -> Void = {
                self.target = target
                self.action = _targetActionSelector
            }
            
            let removeTargetAction: Void -> Void = {
                self.target = nil
                self.action = nil
            }
            
            configure.pause = { [weak self] in
                if let self_ = self {
                    removeTargetAction()
                }
            }
            configure.resume = { [weak self] in
                if let self_ = self {
                    addTargetAction()
                }
            }
            configure.cancel = { [weak self] in
                if let self_ = self {
                    removeTargetAction()
                }
            }
            
            addTargetAction()
            
        }.take(until: self.deinitSignal)
    }
    
    public func signal<T>(mappedValue: T) -> Signal<T>
    {
        return self.signal { _ in mappedValue }
    }
}