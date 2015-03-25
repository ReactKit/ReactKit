//
//  NSIndexSet+Helper.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2015/03/21.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import Foundation

extension NSIndexSet
{
    public convenience init<S: SequenceType where S.Generator.Element == Int>(indexes: S)
    {
        let indexSet = NSMutableIndexSet()
        for index in indexes {
            indexSet.addIndex(index)
        }
        
        self.init(indexSet: indexSet)
    }
}