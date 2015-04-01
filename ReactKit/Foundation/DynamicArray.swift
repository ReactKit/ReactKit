//
//  DynamicArray.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2015/03/21.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import Foundation

///
/// Array-wrapper class to create mutableArrayValueForKey-`proxy` and its `stream`.
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
    /// Proxy array to send changes to `self.stream`.
    ///
    /// NOTE: Make sure to bind `self.stream` first i.e. `self.stream ~> { ... }` (KVO-addObserver) before using this.
    ///
    public var proxy: NSMutableArray
    {
        return self.mutableArrayValueForKey(self._key)
    }
    
    /// creates new stream which sends `(changedValues, changedType, indexSet)` 
    /// via changes in `self.proxy` NSMutableArray
    public func stream() -> Stream<ChangedTuple>
    {
        return KVO.detailedStream(self, self._key)
            |> map { ($0 as? [Element], $1, $2!) }
    }
    
    public init(_ array: [Element] = [])
    {
        // NOTE: `self._array` will be change via `self.proxy`, but immutable `array` won't
        self._array = array
        
        super.init()
        
//        println("[init] \(self)")
    }
    
    deinit
    {
//        println("[deinit] \(self)")
    }
}

///
/// DynamicArray + forwarding changes to original array (either "KVC-compliant model's array" or "raw NSMutableArray")
///
/// e.g.
///
/// ```
/// let dynamicArray = ForwardingDynamicArray(object: myObj, keyPath: "array")
/// dynamicArray.proxy.addObject(newItem)
/// ```
///
/// will also add `newItem` to `myObj.array`, even when this array is NSArray (thanks to KVC magic).
///
public class ForwardingDynamicArray: DynamicArray
{
    ///
    /// Initializer for forwarding changes to KVC-compliant model's array (accessible via `object.valueForKeyPath(keyPath)`).
    ///
    /// :param: object Model object to call `mutableArrayValueForKeyPath()` as its receiver.
    /// :param: keyPath Argument for `mutableArrayValueForKeyPath()`.
    ///
    public convenience init(object: NSObject, keyPath: String)
    {
        let originalMutableArray = object.mutableArrayValueForKeyPath(keyPath)
        
        //
        // NOTE:
        // `originalMutableArray` via `mutableArrayValueForKeyPath()` can't be used as `forwardingStreamOwner`
        // because it doesn't get deinited for some reason (see https://gist.github.com/inamiy/577ae4b222dd38429aa2 ),
        // thus `ForwardingDynamicArray` won't get deinited too since retaining-flow will be like this:
        //
        //     originalMutableArray (owner) -> forwardingStream -> KVOProxy -> ForwardingDynamicArray
        //
        // To avoid this issue, use model `object` as owner instead.
        //
        self.init(original: originalMutableArray, forwardingStreamOwner: object)
    }
    
    ///
    /// Initializer for forwarding changes directly to raw NSMutableArray.
    ///
    /// :param: original Original NSMutableArray. (DO NOT SET NSMutableArray which is created via **mutableArrayValueForKey()**).
    ///
    public convenience init(original originalMutableArray: NSMutableArray)
    {
        self.init(original: originalMutableArray, forwardingStreamOwner: originalMutableArray)
    }
    
    internal init(original originalMutableArray: NSMutableArray, forwardingStreamOwner: NSObject)
    {
        super.init(originalMutableArray as [Element])
        
        let forwardingStream = self.stream().ownedBy(forwardingStreamOwner)
        
        // REACT: forward changes to `originalMutableArray`
        forwardingStream ~> { [weak originalMutableArray] values, change, indexSet in
            
            switch change {
                case .Insertion:
                    originalMutableArray?.insertObjects(values!, atIndexes: indexSet)
                case .Replacement:
                    originalMutableArray?.replaceObjectsAtIndexes(indexSet, withObjects: values!)
                case .Removal:
                    originalMutableArray?.removeObjectsAtIndexes(indexSet)
                default:
                    break
            }
        }
        
    }
}