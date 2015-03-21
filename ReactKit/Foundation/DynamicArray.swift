//
//  DynamicArray.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2015/03/21.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import Foundation

///
/// Array-wrapper class to create mutableArrayValueForKey-`proxy` and its `signal`.
///
/// (NOTE: to forward changes to original array, use `ForwardingDynamicArray` instead)
///
public class DynamicArray: NSObject
{
    // NOTE: can't use generics for `DynamicArray` when collaborating with `mutableArrayValueForKey()`
    public typealias Element = AnyObject
    
    public typealias ChangedTuple = ([Element]?, NSKeyValueChange, NSIndexSet)
    
    // (NOTE: must use non-private for KVC(mutableArrayValueForKey)-compliancy)
    /// original array
    internal private(set) var _array: [Element]
    
    private let _key = "_array"
    
    ///
    /// Proxy array to send changes to `self.signal`.
    ///
    /// NOTE: Make sure to bind `self.signal` first i.e. `self.signal ~> { ... }` (KVO-addObserver) before using this.
    ///
    public var proxy: NSMutableArray
    {
        return self.mutableArrayValueForKey(self._key)
    }
    
    /// sends `(changedValues, changedType, indexSet)` via `self.proxy`
    public private(set) var signal: Signal<ChangedTuple>!
    
    public init(_ array: [Element] = [])
    {
        // NOTE: `self._array` will be change via `self.proxy`, but immutable `array` won't
        self._array = array
        
        super.init()
        
        // NOTE: using `KVO.detailedSignal()` allows to also deliver NSKeyValueChange and NSIndexSet
        // NOTE: `KVO.detailedSignal(self, self.key)` returns `value = nil` when `change = .Removal`
        self.signal = KVO.detailedSignal(self, self._key).map { ($0 as? [Element], $1, $2!) }
    }
}

///
/// Forwards changes in ForwardingDynamicArray to original NSMutableArray
/// (useful when original NSMutableArray is also using `mutableArrayValueForKey`)
///
/// e.g.
///
/// ```
/// let dynamicArray = ForwardingDynamicArray(myObj.mutableArrayValueForKey("array"))
/// dynamicArray.proxy.addObject(newItem)
/// ```
///
/// will also add `newItem` to `myObj.array`, even when this array is NSArray (thanks to KVC magic).
///
public class ForwardingDynamicArray: DynamicArray
{
    public init(original originalMutableArray: NSMutableArray)
    {
        super.init(originalMutableArray)
        
        // REACT: forward changes to `originalMutableArray`
        self.signal ~> { values, change, indexSet in
            switch change {
                case .Insertion:
                    originalMutableArray.insertObjects(values!, atIndexes: indexSet)
                case .Replacement:
                    originalMutableArray.replaceObjectsAtIndexes(indexSet, withObjects: values!)
                case .Removal:
                    originalMutableArray.removeObjectsAtIndexes(indexSet)
                default:
                    break
            }
        }
    }
}