//
//  ReactKit.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask

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
        let cancelError = _RKError(.CancelledByDeinit, "Signal=\(signalName) is cancelled via deinit.")
        
        self.cancel(error: cancelError)
    }
    
    // required (Swift compiler fails...)
    public override func cancel(error: NSError? = nil) -> Bool
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

/// helper
private func _bind<T>(fulfill: (T -> Void)?, reject: NSError -> Void, configure: TaskConfiguration, upstreamSignal: Signal<T>)
{
    let signalName = upstreamSignal.name

    // fulfill/reject downstream on upstream-fulfill/reject/cancel
    upstreamSignal.then { value, errorInfo -> Void in
        
        if let value = value {
            fulfill?(value)
            return
        }
        else if let errorInfo = errorInfo {
            // rejected
            if let error = errorInfo.error {
                reject(error)
                return
            }
            // cancelled
            else {
                let cancelError = _RKError(.CancelledByUpstream, "Signal=\(signalName) is rejected or cancelled.")
                reject(cancelError)
            }
        }
        
    }
    
    // NOTE: newSignal should capture selfSignal
    configure.pause = { upstreamSignal.pause(); return }
    configure.resume = { upstreamSignal.resume(); return }
    configure.cancel = { upstreamSignal.cancel(); return }
}

// Signal Operations
public extension Signal
{
    /// filter using newValue only
    public func filter(filterClosure: T -> Bool) -> Signal<T>
    {
        return Signal<T>(name: "\(self.name)-filter") { progress, fulfill, reject, configure in
            
            self.progress { (_, progressValue: T) in
                if filterClosure(progressValue) {
                    progress(progressValue)
                }
            }
        
            _bind(fulfill, reject, configure, self)
        }
    }

    /// filter using (oldValue, newValue)
    public func filter2(filterClosure2: (oldValue: T?, newValue: T) -> Bool) -> Signal<T>
    {
        return Signal<T>(name: "\(self.name)-filter2") { progress, fulfill, reject, configure in
            
            self.progress { (progressValues: (oldValue: T?, newValue: T)) in
                if filterClosure2(progressValues) {
                    progress(progressValues.newValue)
                }
            }
        
            _bind(fulfill, reject, configure, self)
        }
    }
    
    /// map using newValue only
    public func map<U>(transform: T -> U) -> Signal<U>
    {
        return Signal<U>(name: "\(self.name)-map") { progress, fulfill, reject, configure in
            
            self.progress { (_, progressValue: T) in
                progress(transform(progressValue))
            }.success { (value: T) -> Void in
                fulfill(transform(value))
            }
            
            _bind(nil, reject, configure, self)
        }
    }
    
    /// map using newValue only & bind to transformed Signal
    /// a.k.a `Rx.flatMap()`
    public func map<U>(transform: T -> Signal<U>) -> Signal<U>
    {
        return Signal<U>(name: "\(self.name)-map(signal)") { progress, fulfill, reject, configure in
            
            var innerSignal: Signal<U>?
            
            self.progress { (_, progressValue: T) in
                innerSignal = transform(progressValue)
                innerSignal?.progress { (_, progressValue: U) in
                    progress(progressValue)
                }
            }.success { (value: T) -> Void in
                innerSignal = transform(value)
                innerSignal?.progress { [weak innerSignal] (_, progressValue: U) in
                    fulfill(progressValue)
                }
            }
            
            _bind(nil, reject, configure, self)
        }
    }
    
    /// map using (oldValue, newValue)
    public func map2<U>(transform2: (oldValue: T?, newValue: T) -> U) -> Signal<U>
    {
        return Signal<U>(name: "\(self.name)-map2") { progress, fulfill, reject, configure in
            
            self.progress { (progressValues: (oldValue: T?, newValue: T)) in
                progress(transform2(progressValues))
            }.success { (value: T) -> Void in
                fulfill(transform2(oldValue: value, newValue: value))
            }
            
            _bind(nil, reject, configure, self)
        }
    }
    
    /// map using (accumulatedValue, newValue)
    /// a.k.a `Rx.scan()`
    public func mapAccumulate<U>(#initial: U, accumulateClosure: (accumulatedValue: U, newValue: T) -> U) -> Signal<U>
    {
        return Signal<U>(name: "\(self.name)-mapAccumulate") { progress, fulfill, reject, configure in
            var accumulatedValue: U = initial
            
            self.progress { p in
                accumulatedValue = accumulateClosure(accumulatedValue: accumulatedValue, newValue: p.newProgress)
                progress(accumulatedValue)
            }.success { _ -> Void in
                fulfill(accumulatedValue)
            }
            
            _bind(nil, reject, configure, self)
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
                
            }
            
            _bind(fulfill, reject, configure, self)
        }
    }
    
    public func takeUntil<U>(takeUntilSignal: Signal<U>) -> Signal
    {
        return Signal<T>(name: "\(self.name)-takeUntil") { [weak takeUntilSignal] progress, fulfill, reject, configure in
            
            let signalName = self.name
            
            self.progress { (_, progressValue: T) in
                progress(progressValue)
            }

            let takeUntilSignalName = takeUntilSignal!.name
            let cancelError = _RKError(.CancelledByTakeUntil, "Signal=\(signalName) is cancelled by takeUntil(\(takeUntilSignalName)).")
            
            takeUntilSignal?.progress { [weak self] (_, progressValue: U) in
                if let self_ = self {
                    self_.cancel(error: cancelError)
                }
            }.success { [weak self] (value: U) -> Void in
                if let self_ = self {
                    self_.cancel(error: cancelError)
                }
            }.failure { [weak self] (error: NSError?, isCancelled: Bool) -> Void in
                if let self_ = self {
                    self_.cancel(error: cancelError)
                }
            }
            
            _bind(fulfill, reject, configure, self)
        }
    }
    
    public func skip(skipCount: Int) -> Signal
    {
        return Signal<T>(name: "\(self.name)-skip(\(skipCount))") { progress, fulfill, reject, configure in
            
            var count = 0
            
            self.progress { (_, progressValue: T) in
                count++
                println("\(count), \(skipCount)")
                if count <= skipCount { return }
                
                progress(progressValue)
                
            }
            
            _bind(fulfill, reject, configure, self)
        }
    }
    
    public func skipUntil<U>(skipUntilSignal: Signal<U>) -> Signal
    {
        return Signal<T>(name: "\(self.name)-skipUntil") { [weak skipUntilSignal] progress, fulfill, reject, configure in
            
            let signalName = self.name
            
            var shouldSkip = true
            
            self.progress { (_, progressValue: T) in
                if !shouldSkip {
                    progress(progressValue)
                }
            }
            
            let skipUntilSignalName = skipUntilSignal!.name
            let cancelError = _RKError(.CancelledBySkipUntil, "Signal=\(signalName) is cancelled by skipUntil(\(skipUntilSignalName)).")
            
            skipUntilSignal?.progress { (_, progressValue: U) in
                shouldSkip = false
            }.success { (value: U) -> Void in
                shouldSkip = false
            }.failure { (error: NSError?, isCancelled: Bool) -> Void in
                shouldSkip = false
            }
            
            _bind(fulfill, reject, configure, self)
        }
    }
    
    public func buffer<U>(triggerSignal: Signal<U>) -> Signal<[T]>
    {
        return Signal<[T]>(name: "\(self.name)-buffer") { progress, fulfill, reject, configure in
            
            var buffer: [T] = []
            
            self.progress { (_, progressValue: T) in
                buffer += [progressValue]
            }.success { _ -> Void in
                fulfill(buffer)
            }
            
            triggerSignal.progress { [weak self] (_, progressValue: U) in
                if let self_ = self {
                    progress(buffer)
                    buffer = []
                }
            }.success { [weak self] (value: U) -> Void in
                if let self_ = self {
                    progress(buffer)
                    buffer = []
                }
            }.failure { [weak self] (error: NSError?, isCancelled: Bool) -> Void in
                if let self_ = self {
                    progress(buffer)
                    buffer = []
                }
            }
            
            _bind(nil, reject, configure, self)
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
            
            _bind(fulfill, reject, configure, self)
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
            
            _bind(fulfill, reject, configure, self)
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
