//
//  UITextField+Signal.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/14.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import UIKit

public extension UITextField
{
    public func textChangedSignal() -> Signal<NSString?>
    {
        return self.signal(controlEvents: .EditingChanged) { (sender: UIControl?) -> NSString? in
            if let sender = sender as? UITextField {
                return sender.text
            }
            return nil
        }.takeUntil(self.deinitSignal)
    }
}