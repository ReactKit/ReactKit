//
//  NSMutableIndexSet+Helper.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2015/03/21.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import Foundation

// helper
extension NSMutableIndexSet
{
    public convenience init(indexes: [Int])
    {
        self.init()
        
        for index in indexes {
            self.addIndex(index)
        }
    }
}