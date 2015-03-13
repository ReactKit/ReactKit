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
    /// creates new KVO Signal (new value only)
    public func signal(#keyPath: String) -> Signal<AnyObject?>
    {
        return self.detailedSignal(keyPath: keyPath)
            .map { value, _, _ -> AnyObject? in value }
            .name("KVO-\(NSStringFromClass(self.dynamicType))-\(keyPath)").takeUntil(self.deinitSignal)
    }
    
    /// creates new KVO Signal (initial + new value)
    public func startingSignal(#keyPath: String) -> Signal<AnyObject?>
    {
        var initial: AnyObject? = self.valueForKeyPath(keyPath)
        return self.signal(keyPath: keyPath)
            .startWith(_nullToNil(initial))
            .name("KVO(starting)-\(NSStringFromClass(self.dynamicType))-\(keyPath)").takeUntil(self.deinitSignal)
    }
    
    ///
    /// creates new KVO Signal (new value, keyValueChange, indexSet),
    /// useful for array model with combination of `mutableArrayValueForKey()`.
    ///
    /// e.g.
    /// let itemsSignal = model.detailedSignal("items")
    /// itemsSignal ~> { changedItems, change, indexSet in ... /* do something with changed items */}
    /// let itemsProxy = model.mutableArrayValueForKey("items")
    /// itemsProxy.insertObject(newItem, atIndex: 0) // itemsSignal will send **both** `newItem` and `index`
    ///
    public func detailedSignal(#keyPath: String) -> Signal<(AnyObject?, NSKeyValueChange, NSIndexSet?)>
    {
        return Signal { [weak self] progress, fulfill, reject, configure in
            
            if let self_ = self {
                let observer = _KVOProxy(target: self_, keyPath: keyPath) { value, change, indexSet in
                    progress(_nullToNil(value), change, indexSet)
                }
                
                configure.pause = { observer.stop() }
                configure.resume = { observer.start() }
                configure.cancel = { observer.stop() }
            }
            
        }.name("KVO(detailed)-\(NSStringFromClass(self.dynamicType))-\(keyPath)").takeUntil(self.deinitSignal)
    }
}

/// KVO helper
public struct KVO
{
    /// creates new KVO Signal (new value only)
    public static func signal(object: NSObject, _ keyPath: String) -> Signal<AnyObject?>
    {
        return object.signal(keyPath: keyPath)
    }
    
    /// creates new KVO Signal (initial + new value)
    public static func startingSignal(object: NSObject, _ keyPath: String) -> Signal<AnyObject?>
    {
        return object.startingSignal(keyPath: keyPath)
    }

    /// creates new KVO Signal (new value, keyValueChange, indexSet)
    public static func detailedSignal(object: NSObject, _ keyPath: String) -> Signal<(AnyObject?, NSKeyValueChange, NSIndexSet?)>
    {
        return object.detailedSignal(keyPath: keyPath)
    }
}

private var ReactKitKVOContext = 0

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
            let keyValueChange: NSKeyValueChange = NSKeyValueChange(rawValue: (change[NSKeyValueChangeKindKey] as NSNumber).unsignedLongValue)!
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
/// e.g. (obj2, "value") <~ signal
public func <~ <T: AnyObject>(tuple: (object: NSObject, keyPath: String), signal: Signal<T?>)
{
    weak var object = tuple.object
    let keyPath = tuple.keyPath
    
    signal.progress { (_, value: T?) in
        if let object = object {
            object.setValue(value, forKeyPath:keyPath)  // NOTE: don't use `tuple` inside closure, or object will be captured
        }
    }
}

/// Multiple Key-Value Binding
/// e.g. [ (obj1, "value1"), (obj2, "value2") ] <~ signal (sending [value1, value2] array)
public func <~ <T: AnyObject>(tuples: [(object: NSObject, keyPath: String)], signal: Signal<[T?]>)
{
    signal.progress { (_, values: [T?]) in
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
    var signal: Signal<AnyObject?>? = KVO.signal(tuple2.object, tuple2.keyPath)
    tuple <~ signal!
    
    // let signal be captured by dispatch_queue to guarantee its lifetime until next runloop
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue()) {
        signal = nil
    }
}