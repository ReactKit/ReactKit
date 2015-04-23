//
//  KVO.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import Foundation

// NSNull-to-nil converter for KVO which returns NSNull when nil is set
// https://github.com/ReactKit/ReactKit/pull/18
internal func _nullToNil(value: AnyObject?) -> AnyObject?
{
    return (value is NSNull) ? nil : value
}

public extension NSObject
{
    /// creates new KVO Stream (new value only)
    public func stream(#keyPath: String) -> Stream<AnyObject?>
    {
        let stream = self.detailedStream(keyPath: keyPath)
            |> map { value, _, _ -> AnyObject? in value }
        
        stream.name("KVO.stream(\(NSStringFromClass(self.dynamicType)), \"\(keyPath)\")")
        
        return stream
    }
    
    /// creates new KVO Stream (initial + new value)
    public func startingStream(#keyPath: String) -> Stream<AnyObject?>
    {
        var initial: AnyObject? = self.valueForKeyPath(keyPath)
        
        let stream = self.stream(keyPath: keyPath)
            |> startWith(_nullToNil(initial))
        
        stream.name("KVO.startingStream(\(NSStringFromClass(self.dynamicType)), \"\(keyPath)\")")
        
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
    public func detailedStream(#keyPath: String) -> Stream<(AnyObject?, NSKeyValueChange, NSIndexSet?)>
    {
        return Stream { [weak self] progress, fulfill, reject, configure in
            
            if let self_ = self {
                let observer = _KVOProxy(target: self_, keyPath: keyPath) { value, change, indexSet in
                    progress(_nullToNil(value), change, indexSet)
                }
                
                configure.pause = { observer.stop() }
                configure.resume = { observer.start() }
                configure.cancel = { observer.stop() }
            }
            
        }.name("KVO.detailedStream(\(NSStringFromClass(self.dynamicType)), \"\(keyPath)\")") |> takeUntil(self.deinitStream)
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
//            println("[init] \(self)")
//        #endif
    }
    
    deinit
    {
//        #if DEBUG
//            println("[deinit] \(self)")
//        #endif
        
        self.stop()
    }
    
    internal func start()
    {
        if _isObserving { return }
        
        _isObserving = true
        
//        #if DEBUG
//            println("[KVO] start")
//        #endif
        
        self._target.addObserver(self, forKeyPath: self._keyPath, options: .New, context: &ReactKitKVOContext)
    }
    
    internal func stop()
    {
        if !_isObserving { return }
        
        _isObserving = false
        
//        #if DEBUG
//            println("[KVO] stop")
//        #endif
        
        self._target.removeObserver(self, forKeyPath: self._keyPath)
    }
    
    internal override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<()>)
    {
        if context != &ReactKitKVOContext {
            return super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
        else {
//            #if DEBUG
//                println()
//                println("[KVO] changed keyPath=\(self._keyPath), change=\(change)")
//                println("change[NSKeyValueChangeKindKey] = \(change[NSKeyValueChangeKindKey])")
//                println("change[NSKeyValueChangeNewKey] = \(change[NSKeyValueChangeNewKey])")
//                println("change[NSKeyValueChangeOldKey] = \(change[NSKeyValueChangeOldKey])")
//                println("change[NSKeyValueChangeIndexesKey] = \(change[NSKeyValueChangeIndexesKey])")
//                println()
//            #endif
            
            let newValue: AnyObject? = change[NSKeyValueChangeNewKey]
            let keyValueChange: NSKeyValueChange = NSKeyValueChange(rawValue: (change[NSKeyValueChangeKindKey] as! NSNumber).unsignedLongValue)!
            let indexSet: NSIndexSet? = change[NSKeyValueChangeIndexesKey] as? NSIndexSet
            
            self._handler(value: newValue, change: keyValueChange, indexSet: indexSet)
        }
    }
}

extension NSKeyValueChange: Printable
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
/// e.g. (obj2, "value") <~ stream
public func <~ <T: AnyObject>(tuple: (object: NSObject, keyPath: String), stream: Stream<T?>)
{
    weak var object = tuple.object
    let keyPath = tuple.keyPath
    
    stream.react { value in
        if let object = object {
            object.setValue(value, forKeyPath:keyPath)  // NOTE: don't use `tuple` inside closure, or object will be captured
        }
    }
}

/// Multiple Key-Value Binding
/// e.g. [ (obj1, "value1"), (obj2, "value2") ] <~ stream (sending [value1, value2] array)
public func <~ <T: AnyObject>(tuples: [(object: NSObject, keyPath: String)], stream: Stream<[T?]>)
{
    stream.react { (values: [T?]) in
        for i in 0..<tuples.count {
            if i >= values.count { break }
            
            let tuple = tuples[i]
            let value = values[i]
            
            tuple.object.setValue(value, forKeyPath:tuple.keyPath)
        }
    }
}

/// short-living Key-Value Binding
/// e.g. (obj2, "value") <~ (obj1, "value")
public func <~ (tuple: (object: NSObject, keyPath: String), tuple2: (object: NSObject, keyPath: String))
{
    var stream: Stream<AnyObject?>? = KVO.stream(tuple2.object, tuple2.keyPath)
    tuple <~ stream!
    
    // let stream be captured by dispatch_queue to guarantee its lifetime until next runloop
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue()) {
        stream = nil
    }
}