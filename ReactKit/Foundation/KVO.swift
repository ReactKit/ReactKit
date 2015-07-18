//
//  KVO.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import Foundation
import SwiftTask

// NSNull-to-nil converter for KVO which returns NSNull when nil is set
// https://github.com/ReactKit/ReactKit/pull/18
internal func _nullToNil(value: AnyObject?) -> AnyObject?
{
    return (value is NSNull) ? nil : value
}

public extension NSObject
{
    /// creates new KVO Stream (new value only)
    public func stream(keyPath keyPath: String) -> Stream<AnyObject?>
    {
        let stream = self.detailedStream(keyPath: keyPath)
            |> map { value, _, _ -> AnyObject? in value }
        
        stream.name("KVO.stream(\(_summary(self)), \"\(keyPath)\")")
        
        return stream
    }
    
    /// creates new KVO Stream (initial + new value)
    public func startingStream(keyPath keyPath: String) -> Stream<AnyObject?>
    {
        let initial: AnyObject? = self.valueForKeyPath(keyPath)
        
        let stream = self.stream(keyPath: keyPath)
            |> startWith(_nullToNil(initial))
        
        stream.name("KVO.startingStream(\(_summary(self)), \"\(keyPath)\")")
        
        return stream
    }
    
    ///
    /// creates new KVO Stream (new value, keyValueChange, indexSet),
    /// useful for array model with combination of `mutableArrayValueForKey()`.
    ///
    /// e.g.
    /// let itemsStream = model.detailedStream("items")
    /// itemsStream ~> { changedItems, change, indexSet in ... /* do something with changed items */}
    /// let itemsProxy = model.mutableArrayValueForKey("items")
    /// itemsProxy.insertObject(newItem, atIndex: 0) // itemsStream will send **both** `newItem` and `index`
    ///
    public func detailedStream(keyPath keyPath: String) -> Stream<(AnyObject?, NSKeyValueChange, NSIndexSet?)>
    {
        return Stream { [weak self] progress, fulfill, reject, configure in
            
            if let self_ = self {
                let observer = _KVOProxy(target: self_, keyPath: keyPath) { value, change, indexSet in
                    progress(_nullToNil(value), change, indexSet)
                }
                
                configure.pause = { observer.stop() }
                configure.resume = { observer.start() }
                configure.cancel = { observer.stop() }
                
                configure.resume?()
            }
            
        }.name("KVO.detailedStream(\(_summary(self)), \"\(keyPath)\")") |> takeUntil(self.deinitStream)
    }
}

/// KVO helper
public struct KVO
{
    /// creates new KVO Stream (new value only)
    public static func stream(object: NSObject, _ keyPath: String) -> Stream<AnyObject?>
    {
        return object.stream(keyPath: keyPath)
    }
    
    /// creates new KVO Stream (initial + new value)
    public static func startingStream(object: NSObject, _ keyPath: String) -> Stream<AnyObject?>
    {
        return object.startingStream(keyPath: keyPath)
    }

    /// creates new KVO Stream (new value, keyValueChange, indexSet)
    public static func detailedStream(object: NSObject, _ keyPath: String) -> Stream<(AnyObject?, NSKeyValueChange, NSIndexSet?)>
    {
        return object.detailedStream(keyPath: keyPath)
    }
}

private var ReactKitKVOContext = 0

// NOTE: KVO won't work if generics is used in this class
internal class _KVOProxy: NSObject
{
    internal typealias _Handler = (value: AnyObject?, change: NSKeyValueChange, indexSet: NSIndexSet?) -> Void
    
    internal let _target: NSObject
    internal let _keyPath: String
    internal let _handler: _Handler
    
    internal var _isObserving: Bool = false
    
    internal init(target: NSObject, keyPath: String, handler: _Handler)
    {
        self._target = target
        self._keyPath = keyPath
        self._handler = handler
        
        super.init()
        
        self.start()
        
//        #if DEBUG
//            print("[init] \(self)")
//        #endif
    }
    
    deinit
    {
//        #if DEBUG
//            print("[deinit] \(self)")
//        #endif
        
        self.stop()
    }
    
    internal func start()
    {
        if _isObserving { return }
        
        _isObserving = true
        
//        #if DEBUG
//            print("[KVO] start")
//        #endif
        
        self._target.addObserver(self, forKeyPath: self._keyPath, options: .New, context: &ReactKitKVOContext)
    }
    
    internal func stop()
    {
        if !_isObserving { return }
        
        _isObserving = false
        
//        #if DEBUG
//            print("[KVO] stop")
//        #endif
        
        self._target.removeObserver(self, forKeyPath: self._keyPath)
    }
    
    internal override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>)
    {
        if context != &ReactKitKVOContext {
            return super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
        else {
            let newValue: AnyObject? = change?[NSKeyValueChangeNewKey]
            let keyValueChange: NSKeyValueChange = NSKeyValueChange(rawValue: (change?[NSKeyValueChangeKindKey] as! NSNumber).unsignedLongValue)!
            let indexSet: NSIndexSet? = change?[NSKeyValueChangeIndexesKey] as? NSIndexSet
            
            self._handler(value: newValue, change: keyValueChange, indexSet: indexSet)
        }
    }
}

extension NSKeyValueChange: CustomStringConvertible
{
    public var description: String
    {
        switch self {
            case .Setting:      return "Setting"
            case .Insertion:    return "Insertion"
            case .Removal:      return "Removal"
            case .Replacement:  return "Replacement"
        }
    }
}

//--------------------------------------------------
// MARK: - Custom Operators
// + - * / % = < > ! & | ^ ~ .
//--------------------------------------------------

infix operator <~ { associativity right }

/// Key-Value Binding
/// e.g. `(obj2, "value") <~ stream`
public func <~ <T: AnyObject>(tuple: (object: NSObject, keyPath: String), stream: Stream<T?>) -> Canceller?
{
    return _reactLeft(tuple, stream)
}

public func <~ (tuple: (object: NSObject, keyPath: String), stream: Stream<String?>) -> Canceller?
{
    return _reactLeft(tuple, stream)
}

public func <~ (tuple: (object: NSObject, keyPath: String), stream: Stream<Int?>) -> Canceller?
{
    return _reactLeft(tuple, stream)
}

public func <~ (tuple: (object: NSObject, keyPath: String), stream: Stream<Float?>) -> Canceller?
{
    return _reactLeft(tuple, stream)
}

public func <~ (tuple: (object: NSObject, keyPath: String), stream: Stream<Double?>) -> Canceller?
{
    return _reactLeft(tuple, stream)
}

private func _reactLeft <T>(tuple: (object: NSObject, keyPath: String), _ stream: Stream<T?>) -> Canceller?
{
    weak var object = tuple.object
    let keyPath = tuple.keyPath
    var canceller: Canceller? = nil
    
    stream.react(&canceller) { value in
        if let object = object {
            object.setValue(value as? AnyObject, forKeyPath:keyPath)  // NOTE: don't use `tuple` inside closure, or object will be captured
        }
    }
    
    return canceller
}