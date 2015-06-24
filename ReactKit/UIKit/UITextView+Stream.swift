//
//  UITextView+Stream.swift
//  ReactKit
//
//  Created by ToKoRo on 2015-06-24.
//  Copyright (c) 2015年 Yuta ToKoRo. All rights reserved.
//

import UIKit

public extension UITextView
{
    public func textChangedStream() -> Stream<String?>
    {
        return Notification.stream(UITextViewTextDidChangeNotification, self)
            |> map { notification -> String? in
                if let textView = notification?.object as? UITextView {
                    return textView.text
                }
                return nil
            }
            |> takeUntil(self.deinitStream)
    }
}
