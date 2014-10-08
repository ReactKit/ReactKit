//
//  UIButton+Signal.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/14.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import UIKit

public extension UIButton
{
    public func buttonSignal<T>(map: UIButton? -> T) -> Signal<T>
    {
        return self.signal(controlEvents: .TouchUpInside) { (sender: UIControl?) -> T in
            return map(sender as? UIButton)
        }
    }
    
    public func buttonSignal<T>(mappedValue: T) -> Signal<T>
    {
        return self.signal(controlEvents: .TouchUpInside) { (sender: UIControl?) -> T in
            return mappedValue
        }
    }
}