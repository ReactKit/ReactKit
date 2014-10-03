//
//  ReactKit+UIButton.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/14.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import UIKit

public extension UIButton
{
    public func buttonSignal<T>(mappedValue: T?) -> Signal<T?>
    {
        return self.signal(controlEvents: .TouchUpInside) { (sender: AnyObject?) -> T? in
            return mappedValue
        }.takeUntil(self.deinitSignal)
    }
}