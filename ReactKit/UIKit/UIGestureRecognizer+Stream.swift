//
//  UIGestureRecognizer+Stream.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/10/03.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import UIKit

// NOTE: see also UIControl+Stream
public extension UIGestureRecognizer
{
    public func stream<T>(map: UIGestureRecognizer? -> T) -> Stream<T>
    {
        return Stream<T> { [weak self] progress, fulfill, reject, configure in
            
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
            
            configure.resume?()
            
        }.name("\(_summary(self))") |> takeUntil(self.deinitStream)
    }
}