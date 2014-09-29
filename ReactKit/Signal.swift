//
//  ReactKit.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask

public class Signal<T>: Task<T, T, NSError?>
{
    public let name: String
    
    public init(name: String = "Default", initClosure: Task<T, T, NSError?>.InitClosure)
    {
        self.name = name
        
        // NOTE: set weakified=true to avoid "proxy -> signal" retaining
        super.init(weakified: true, initClosure: initClosure)
        
        #if DEBUG
            println("[init] \(self) \(self.name)")
        #endif
    }
    
    deinit
    {
        #if DEBUG
            println("[deinit] \(self) \(self.name)")
        #endif
    }
    
    // required (Swift compiler fails...)
    override public func cancel(error: NSError?? = nil) -> Bool
    {
        return super.cancel(error: error)
    }
}

// Signal Operations
public extension Signal
{
    public func filter(filterClosure: T -> Bool) -> Signal<T>
    {
        return Signal<T>(name: "\(self.name)-filter") { progress, fulfill, reject, configure in
            
            self.progress { progressValue in
                if filterClosure(progressValue) {
                    progress(progressValue)
                }
            }.then { (value: T) -> Void in
                fulfill(value)
            }.catch { (error: NSError??, isCancelled: Bool) -> Void in
                if let error = error {
                    reject(error)
                }
                else {
                    reject(nil)
                }
            }
        
            // NOTE: newSignal should capture selfSignal
            configure.pause = { self.pause(); return }
            configure.resume = { self.resume(); return }
            configure.cancel = { self.cancel(); return }
        }
    }
    
    public func map<U>(transform: T -> U) -> Signal<U>
    {
        return Signal<U>(name: "\(self.name)-map") { progress, fulfill, reject, configure in
            
            self.progress { (progressValue: T) in
                progress(transform(progressValue))
            }.then { (value: T) -> Void in
                fulfill(transform(value))
            }.catch { (error: NSError??, isCancelled: Bool) -> Void in
                if let error = error {
                    reject(error)
                }
                else {
                    reject(nil)
                }
            }
            
            configure.pause = { self.pause(); return }
            configure.resume = { self.resume(); return }
            configure.cancel = { self.cancel(); return }
        }
    }
    
    public func take(maxCount: Int) -> Signal
    {
        return Signal<T>(name: "\(self.name)-take(\(maxCount))") { progress, fulfill, reject, configure in
            
            var count = 0
            
            self.progress { progressValue in
                count++
                if count > maxCount {
                    reject(nil)
                }
                else {
                    progress(progressValue)
                }
            }.then { (value: T) -> Void in
                fulfill(value)
            }.catch { (error: NSError??, isCancelled: Bool) -> Void in
                if let error = error {
                    reject(error)
                }
                else {
                    reject(nil)
                }
            }
            
            configure.pause = { self.pause(); return }
            configure.resume = { self.resume(); return }
            configure.cancel = { self.cancel(); return }
            
        }
    }
    
    public func takeUntil<U>(signal: Signal<U>) -> Signal
    {
        return Signal<T>(name: "\(self.name)-takeUntil") { progress, fulfill, reject, configure in
            
            self.progress { progressValue in
                progress(progressValue)
            }.then { (value: T) -> Void in
                fulfill(value)
            }.catch { (error: NSError??, isCancelled: Bool) -> Void in
                if let error = error {
                    reject(error)
                }
                else {
                    reject(nil)
                }
            }
            
            signal.progress { [weak self] (progressValue: U) in
                if let self_ = self {
                    self!.cancel()
                }
            }.then { [weak self] (value: U) -> Void in
                if let self_ = self {
                    self!.cancel()
                }
            }.catch { [weak self] (error: NSError??, isCancelled: Bool) -> Void in
                if let self_ = self {
                    self!.cancel()
                }
            }
            
            configure.pause = { self.pause(); return }
            configure.resume = { self.resume(); return }
            configure.cancel = { self.cancel(); return }
            
        }
    }
    
}

// Multiple Signal Operations
public extension Signal
{
    public typealias ChangedValueTuple = (values: [T?], changedValue: T)
    
    public class func any(signals: [Signal<T>]) -> Signal<ChangedValueTuple>
    {
        return Signal<ChangedValueTuple>(name: "Signal.any") { progress, fulfill, reject, configure in
            
            // wrap with class for weakifying
            let signalGroup = _SignalGroup(signals: signals)
            
            for signal in signals {
                signal.progress { [weak signalGroup] progressValue in
                    if let signalGroup = signalGroup {
                        let signals = signalGroup.signals
                        
                        let values: [T?] = signals.map { $0.progress }
                        let valueTuple = ChangedValueTuple(values: values, changedValue: progressValue)
                        
                        progress(valueTuple)
                    }
                }
            }
            
            // NOTE: signals should be captured by class-type signalGroup, which should be captured by new signal
            configure.pause = {
                self.pauseAll(signalGroup.signals)
            }
            configure.resume = {
                self.resumeAll(signalGroup.signals)
            }
            configure.cancel = {
                self.cancelAll(signalGroup.signals)
            }
            
        }
    }
}

/// wrapper-class for weakifying
internal class _SignalGroup<T>
{
    internal let signals: [Signal<T>]
    
    internal init(signals: [Signal<T>])
    {
        self.signals = signals
    }
}


//--------------------------------------------------
// MARK: - Custom Operators
// + - * / % = < > ! & | ^ ~ .
//--------------------------------------------------

// NOTE: set precedence=255 to avoid "Operator is not a known binary operator" error
infix operator ~> { associativity left precedence 255 }

/// i.e. signal.progress { ... }
public func ~> <T>(signal: Signal<T>, reactClosure: T -> Void) -> Signal<T>
{
    signal.progress(reactClosure)
    return signal
}

infix operator <~ { associativity right }

/// closure-first operator, reversing `signal.progress { ... }`
/// e.g. ^{ ... } <~ signal
public func <~ <T>(reactClosure: T -> Void, signal: Signal<T>)
{
    signal.progress(reactClosure)
}

prefix operator ^ {}

/// Objective-C like 'block operator' to let Swift compiler know closure-type at start of the line
/// e.g. ^{ println($0) } <~ signal
public prefix func ^ <T>(closure: T -> Void) -> (T -> Void)
{
    return closure
}

prefix operator + {}

/// short-living operator for signal not being retained
/// e.g. ^{ println($0) } <~ +KVO.signal(obj1, "value")
public prefix func + <T>(signal: Signal<T>) -> Signal<T>
{
    var holder: Signal<T>? = signal
    
    // let signal be captured by dispatch_queue to guarantee its lifetime until next runloop
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue()) {    // on main-thread
        holder = nil
    }
    
    return signal
}
