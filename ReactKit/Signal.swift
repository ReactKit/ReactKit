//
//  ReactKit.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask

public let ReactKitErrorDomain = "ReactKitErrorDomain"

public class Signal<T>: Task<T, T, NSError>
{
    public let name: String
    
    public init(name: String = "Default", initClosure: Task<T, T, NSError>.InitClosure)
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
        
        let signalName = self.name
        let cancelError = NSError(domain: ReactKitErrorDomain, code: 0, userInfo: [
            NSLocalizedDescriptionKey : "(\(signalName)) is cancelled via deinit."
        ])
        
        self.cancel(error: cancelError)
    }
    
    // required (Swift compiler fails...)
    override public func cancel(error: NSError? = nil) -> Bool
    {
        return super.cancel(error: error)
    }
    
    /// Easy strong referencing by owner e.g. UIViewController holding its UI component's signal
    /// without explicitly defining signal as property.
    public func ownedBy(owner: NSObject) -> Signal
    {
        var owninigSignals = owner._owninigSignals
        owninigSignals.append(self)
        owner._owninigSignals = owninigSignals
        
        return self
    }
    
}

// helper
private func _reject(reject: NSError -> Void, error: NSError?)
{
    if let error = error {
        reject(error)
        return
    }

    let cancelError = NSError(domain: ReactKitErrorDomain, code: 0, userInfo: [
        NSLocalizedDescriptionKey : "Signal is cancelled."
    ])
    reject(cancelError)
}

// helper
private func _configure<T>(configure: TaskConfiguration, capturingSignal: Signal<T>)
{
    // NOTE: newSignal should capture selfSignal
    configure.pause = { capturingSignal.pause(); return }
    configure.resume = { capturingSignal.resume(); return }
    configure.cancel = { capturingSignal.cancel(); return }
}

// Signal Operations
public extension Signal
{
    public func filter(filterClosure: T -> Bool) -> Signal<T>
    {
        return Signal<T>(name: "\(self.name)-filter") { progress, fulfill, reject, configure in
            
            self.progress { (_, progressValue: T) in
                if filterClosure(progressValue) {
                    progress(progressValue)
                }
            }.success { (value: T) -> Void in
                fulfill(value)
            }.failure { (error: NSError?, isCancelled: Bool) -> Void in
                _reject(reject, error)
            }
        
            _configure(configure, self)
        }
    }
    
    /// map + newValue only
    public func map<U>(transform: T -> U) -> Signal<U>
    {
        return Signal<U>(name: "\(self.name)-map") { progress, fulfill, reject, configure in
            
            self.progress { (_, progressValue: T) in
                progress(transform(progressValue))
            }.success { (value: T) -> Void in
                fulfill(transform(value))
            }.failure { (error: NSError?, isCancelled: Bool) -> Void in
                _reject(reject, error)
            }
            
            _configure(configure, self)
        }
    }
    
    /// map + (oldValue, newValue)
    // see also: Rx.scan http://www.introtorx.com/content/v1.0.10621.0/07_Aggregation.html#Scan
    public func mapTuple<U>(tupleTransform: (oldValue: T?, newValue: T) -> U) -> Signal<U>
    {
        return Signal<U>(name: "\(self.name)-map(tupleTransform)") { progress, fulfill, reject, configure in
            
            self.progress { (progressValues: (oldValue: T?, newValue: T)) in
                progress(tupleTransform(progressValues))
            }.success { (value: T) -> Void in
                fulfill(tupleTransform(oldValue: value, newValue: value))
            }.failure { (error: NSError?, isCancelled: Bool) -> Void in
                _reject(reject, error)
            }
            
            _configure(configure, self)
        }
    }
    
    public func take(maxCount: Int) -> Signal
    {
        return Signal<T>(name: "\(self.name)-take(\(maxCount))") { progress, fulfill, reject, configure in
            
            var count = 0
            
            self.progress { (_, progressValue: T) in
                count++
                
                if count < maxCount {
                    progress(progressValue)
                }
                else if count == maxCount {
                    progress(progressValue)
                    fulfill(progressValue)  // successfully reached maxCount
                }
                else {
                    _reject(reject, nil)
                }
                
            }.then { (value, errorInfo) -> Void in
                
                // NOTE: always `reject` because when `then()` is called, it means `count` is not reaching maxCount.
                
                if let errorInfo = errorInfo {
                    if let error = errorInfo.error {
                        reject(error)
                        return
                    }
                }
                
                let domainError = NSError(domain: ReactKitErrorDomain, code: 0, userInfo: [
                    NSLocalizedDescriptionKey : "Signal is rejected or cancelled before reaching `maxCount`."
                ])
                reject(domainError)
                
            }
            
            _configure(configure, self)
        }
    }
    
    public func takeUntil<U>(signal: Signal<U>) -> Signal
    {
        return Signal<T>(name: "\(self.name)-takeUntil") { progress, fulfill, reject, configure in
            
            self.progress { (_, progressValue: T) in
                progress(progressValue)
            }.success { (value: T) -> Void in
                fulfill(value)
            }.failure { (error: NSError?, isCancelled: Bool) -> Void in
                _reject(reject, error)
            }

            let signalName = signal.name
            let cancelError = NSError(domain: ReactKitErrorDomain, code: 0, userInfo: [
                NSLocalizedDescriptionKey : "Signal is cancelled by takeUntil(\(signalName))."
            ])
            
            signal.progress { [weak self] (_, progressValue: U) in
                if let self_ = self {
                    self!.cancel(error: cancelError)
                }
            }.success { [weak self] (value: U) -> Void in
                if let self_ = self {
                    self!.cancel(error: cancelError)
                }
            }.failure { [weak self] (error: NSError?, isCancelled: Bool) -> Void in
                if let self_ = self {
                    self!.cancel(error: cancelError)
                }
            }
            
            _configure(configure, self)
        }
    }

    /// limit continuous progress (reaction) for `timeInterval` seconds when first progress is triggered
    /// (see also: underscore.js throttle)
    public func throttle(timeInterval: NSTimeInterval) -> Signal
    {
        return Signal<T>(name: "\(self.name)-throttle(\(timeInterval))") { progress, fulfill, reject, configure in
            
            var lastProgressDate = NSDate(timeIntervalSince1970: 0)
            
            self.progress { (_, progressValue: T) in
                let now = NSDate()
                let timeDiff = now.timeIntervalSinceDate(lastProgressDate)
                
                if timeDiff > timeInterval {
                    lastProgressDate = now
                    progress(progressValue)
                }
            }
            
            _configure(configure, self)
        }
    }
    
    /// delay progress (reaction) for `timeInterval` seconds and truly invoke reaction afterward if not interrupted by continuous progress
    /// (see also: underscore.js debounce)
    public func debounce(timeInterval: NSTimeInterval) -> Signal
    {
        return Signal<T>(name: "\(self.name)-debounce(\(timeInterval))") { progress, fulfill, reject, configure in
            
            var timerSignal: Signal<Void>? = nil    // retained by self via self.progress
            
            self.progress { (_, progressValue: T) in
                // NOTE: overwrite to deinit & cancel old timerSignal
                timerSignal = NSTimer.signal(timeInterval: timeInterval, repeats: false) { _ in }
                
                timerSignal!.progress { _ -> Void in
                    progress(progressValue)
                }
            }
            
            _configure(configure, self)
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
                signal.progress { [weak signalGroup] (_, progressValue: T) in
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
    signal.progress { _, progress in reactClosure(progress) }
    return signal
}

infix operator <~ { associativity right }

/// closure-first operator, reversing `signal.progress { ... }`
/// e.g. ^{ ... } <~ signal
public func <~ <T>(reactClosure: T -> Void, signal: Signal<T>)
{
    signal.progress { _, progress in reactClosure(progress) }
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
