//
//  ReactKit+KVO.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import Foundation

public extension NSObject
{
    /// creates new Signal
    public func signal(#keyPath: String) -> Signal<AnyObject?>
    {
        return Signal(name: "KVO-\(NSStringFromClass(self.dynamicType))-\(keyPath)") { progress, fulfill, reject, configure in
            
            let observer = _KVOProxy(target: self, keyPath: keyPath) { value in
                progress(value)
            }
            
            configure.pause = { observer.stop() }
            configure.resume = { observer.start() }
            configure.cancel = { observer.stop() }
            
        }.takeUntil(self.deinitSignal)
    }
}

/// KVO helper
public struct KVO
{
    public static func signal(object: NSObject, _ keyPath: String) -> Signal<AnyObject?>
    {
        return object.signal(keyPath: keyPath)
    }
}

private var ReactKitKVOContext = 0

internal class _KVOProxy: NSObject
{
    internal let _target: NSObject
    internal let _keyPath: String
    internal let _handler: (AnyObject -> Void)
    
    internal var _isObserving: Bool = false
    
    internal init(target: NSObject, keyPath: String, handler: (AnyObject -> Void))
    {
        self._target = target
        self._keyPath = keyPath
        self._handler = handler
        
        super.init()
        
        self.start()
        
        #if DEBUG
            println("[init] \(self)")
        #endif
    }
    
    deinit
    {
        #if DEBUG
            println("[deinit] \(self)")
        #endif
        
        self.stop()
    }
    
    internal func start()
    {
        if _isObserving { return }
        
        _isObserving = true
        
        #if DEBUG
            println("[KVO] start")
        #endif
        
        self._target.addObserver(self, forKeyPath: self._keyPath, options: .New, context: &ReactKitKVOContext)
    }
    
    internal func stop()
    {
        if !_isObserving { return }
        
        _isObserving = false
        
        #if DEBUG
            println("[KVO] stop")
        #endif
        
        self._target.removeObserver(self, forKeyPath: self._keyPath)
    }
    
    internal override func observeValueForKeyPath(keyPath: String!, ofObject object: AnyObject!, change: [NSObject : AnyObject]!, context: UnsafeMutablePointer<()>)
    {
        if context != &ReactKitKVOContext {
            return super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
        else {
            #if DEBUG
                println("[KVO] changed keyPath=\(self._keyPath), change=\(change)")
            #endif
            
            let newValue: AnyObject? = change[NSKeyValueChangeNewKey]
            self._handler(newValue!)
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
    
    signal.progress { (value: T?) in
        if let object = object {
            object.setValue(value, forKeyPath:keyPath)  // NOTE: don't use `tuple` inside closure, or object will be captured
        }
    }
}

/// Multiple Key-Value Binding
/// e.g. [ (obj1, "value1"), (obj2, "value2") ] <~ signal (sending [value1, value2] array)
public func <~ <T: AnyObject>(tuples: [(object: NSObject, keyPath: String)], signal: Signal<[T?]>)
{
    signal.progress { (values: [T?]) in
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