//
//  UIButton+Stream.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/14.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import UIKit

public extension UIButton
{
    public func buttonStream<T>(map: UIButton? -> T) -> Stream<T>
    {
        return self.stream(controlEvents: .TouchUpInside) { (sender: UIControl?) -> T in
            return map(sender as? UIButton)
        }
    }
    
    public func buttonStream<T>(mappedValue: T) -> Stream<T>
    {
        return self.stream(controlEvents: .TouchUpInside) { (sender: UIControl?) -> T in
            return mappedValue
        }
    }
}