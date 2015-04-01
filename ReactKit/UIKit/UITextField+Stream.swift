//
//  UITextField+Stream.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/14.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import UIKit

public extension UITextField
{
    public func textChangedStream() -> Stream<NSString?>
    {
        return self.stream(controlEvents: .EditingChanged) { (sender: UIControl?) -> NSString? in
            if let sender = sender as? UITextField {
                return sender.text
            }
            return nil
        } |> takeUntil(self.deinitStream)
    }
}