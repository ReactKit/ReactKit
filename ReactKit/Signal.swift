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
    public override var description: String
    {
        return "<\(self.name); state=\(self.state.rawValue)>"
    }
    
    ///
    /// Creates a new signal (event-delivery-pipeline over time).
    /// Synonym of "stream", "observable", etc.
    ///
    /// :param: paused Flag to invoke `initClosure` immediately or not. If `paused = true`, signal's initial state will be `.Paused` (lazy, similar to "cold signal") and needs to `resume()` in order to start `.Running`. If `paused = false`, `initClosure` will be invoked immediately.
    ///
    /// :param: initClosure Closure to define returning signal's behavior. Inside this closure, `configure.pause`/`resume`/`cancel` should capture inner logic (player) object. See also comment in `SwiftTask.Task.init()`.
    ///
    /// :returns: New Signal.
    /// 
    public init(paused: Bool, initClosure: Task<T, T, NSError>.InitClosure)
    {
        // NOTE: set weakified=true to avoid "(inner) player -> signal" retaining
        super.init(weakified: true, paused: paused, initClosure: initClosure)
        
        self.name = "DefaultSignal"
        
        #if DEBUG
            println("[init] \(self)")
        #endif
    }
    
    /// creates paused signal
    public convenience init(initClosure: Task<T, T, NSError>.InitClosure)
    {
        self.init(paused: true, initClosure: initClosure)
    }
    
    /// creates fulfilled (progress once) signal
    public convenience init(paused: Bool = true, value: T)
    {
        self.init(paused: paused, initClosure: { progress, fulfill, reject, configure in
            progress(value)
            fulfill(value)
        })
    }
    
    /// creates rejected signal
    public convenience init(paused: Bool = true, error: NSError)
    {
        self.init(paused: paused, initClosure: { progress, fulfill, reject, configure in
            reject(error)
        })
    }
    
    deinit
    {
        #if DEBUG
            println("[deinit] \(self)")
        #endif
        
        let signalName = self.name
        let cancelError = _RKError(.CancelledByDeinit, "Signal=\(signalName) is cancelled via deinit.")
        
        self.cancel(error: cancelError)
    }
    
    /// progress-chaining with auto-resume
    public override func progress(progressClosure: ProgressTuple -> Void) -> Task<T, T, NSError>
    {
        let signal = super.progress(progressClosure)
        self.resume()
        return signal
    }
    
    public func then<U>(thenClosure: (T?, ErrorInfo?) -> U) -> Task<U, U, NSError>
    {
        return self.then { (value: T?, errorInfo: ErrorInfo?) -> Task<U, U, NSError> in
            return Signal<U>(paused: false, value: thenClosure(value, errorInfo))   // non-paused
        }
    }
    
    /// then-chaining with auto-resume
    public func then<U>(thenClosure: (T?, ErrorInfo?) -> Task<U, U, NSError>) -> Task<U, U, NSError>
    {
        let signal = super.then(thenClosure)
        self.resume()
        return signal
    }
    
    public func success<U>(successClosure: T -> U) -> Task<U, U, NSError>
    {
        return self.success { (value: T) -> Task<U, U, NSError> in
            return Signal<U>(paused: false, value: successClosure(value))   // non-paused
        }
    }
    
    /// success-chaining with auto-resume
    public func success<U>(successClosure: T -> Task<U, U, NSError>) -> Task<U, U, NSError>
    {
        let signal = super.success(successClosure)
        self.resume()
        return signal
    }
    
    public override func failure(failureClosure: ErrorInfo -> T) -> Task<T, T, NSError>
    {
        return self.failure { (errorInfo: ErrorInfo) -> Task<T, T, NSError> in
            return Signal(paused: false, value: failureClosure(errorInfo))  // non-paused
        }
    }
    
    /// failure-chaining with auto-resume
    public override func failure(failureClosure: ErrorInfo -> Task<T, T, NSError>) -> Task<T, T, NSError>
    {
        let signal = super.failure(failureClosure)
        self.resume()
        return signal
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
        return Signal<T> { progress, fulfill, reject, configure in
            
            self.progress { (_, progressValue: T) in
                if filterClosure(progressValue) {
                    progress(progressValue)
                }
            }
        
            _bind(fulfill, reject, configure, self)
            
        }.name("\(self.name)-filter")
    }

    /// filter using (oldValue, newValue)
    public func filter2(filterClosure2: (oldValue: T?, newValue: T) -> Bool) -> Signal<T>
    {
        return Signal<T> { progress, fulfill, reject, configure in
            
            self.progress { (progressValues: (oldValue: T?, newValue: T)) in
                if filterClosure2(progressValues) {
                    progress(progressValues.newValue)
                }
            }
        
            _bind(fulfill, reject, configure, self)
            
        }.name("\(self.name)-filter2")
    }
    
    /// map using newValue only
    public func map<U>(transform: T -> U) -> Signal<U>
    {
        return Signal<U> { progress, fulfill, reject, configure in
            
            self.progress { (_, progressValue: T) in
                progress(transform(progressValue))
            }.success { (value: T) -> Void in
                fulfill(transform(value))
            }
            
            _bind(nil, reject, configure, self)
            
        }.name("\(self.name)-map")
    }
    
    /// map using newValue only & bind to transformed Signal
    public func flatMap<U>(transform: T -> Signal<U>) -> Signal<U>
    {
        return Signal<U> { progress, fulfill, reject, configure in
            
            // NOTE: each of `transformToSignal()` needs to be retained outside
            var innerSignals: [Signal<U>] = []
            
            self.progress { (_, progressValue: T) in
                let innerSignal = transform(progressValue)
                innerSignals += [innerSignal]
                
                innerSignal.progress { (_, progressValue: U) in
                    progress(progressValue)
                }
            }.success { (value: T) -> Void in
                let innerSignal = transform(value)
                innerSignals += [innerSignal]
                
                innerSignal.progress { (_, progressValue: U) in
                    fulfill(progressValue)
                }
            }
            
            _bind(nil, reject, configure, self)

        }.name("\(self.name)-flatMap")
        
    }
    
    /// map using (oldValue, newValue)
    public func map2<U>(transform2: (oldValue: T?, newValue: T) -> U) -> Signal<U>
    {
        return Signal<U> { progress, fulfill, reject, configure in
            
            self.progress { (progressValues: (oldValue: T?, newValue: T)) in
                progress(transform2(progressValues))
            }.success { (value: T) -> Void in
                fulfill(transform2(oldValue: value, newValue: value))
            }
            
            _bind(nil, reject, configure, self)
            
        }.name("\(self.name)-map2")
    }
    
    /// map using (accumulatedValue, newValue)
    /// a.k.a `Rx.scan()`
    public func map<U>(accumulate initialValue: U, _ accumulateClosure: (accumulatedValue: U, newValue: T) -> U) -> Signal<U>
    {
        return Signal<U> { progress, fulfill, reject, configure in
            
            var accumulatedValue: U = initialValue
            
            self.progress { p in
                accumulatedValue = accumulateClosure(accumulatedValue: accumulatedValue, newValue: p.newProgress)
                progress(accumulatedValue)
            }.success { _ -> Void in
                fulfill(accumulatedValue)
            }
            
            _bind(nil, reject, configure, self)
            
        }.name("\(self.name)-map(accumulate:)")
    }
    
    public func take(maxCount: Int) -> Signal
    {
        return Signal<T> { progress, fulfill, reject, configure in
            
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
            
        }.name("\(self.name)-take(\(maxCount))")
    }
    
    public func take<U>(until triggerSignal: Signal<U>) -> Signal
    {
        return Signal<T> { [weak triggerSignal] progress, fulfill, reject, configure in
            
            let signalName = self.name
            
            self.progress { (_, progressValue: T) in
                progress(progressValue)
            }

            let triggerSignalName = triggerSignal!.name
            let cancelError = _RKError(.CancelledByTriggerSignal, "Signal=\(signalName) is cancelled by take(until: \(triggerSignalName)).")
            
            triggerSignal?.progress { [weak self] (_, progressValue: U) in
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
            
        }.name("\(self.name)-take(until:)")
    }
    
    public func skip(skipCount: Int) -> Signal
    {
        return Signal<T> { progress, fulfill, reject, configure in
            
            var count = 0
            
            self.progress { (_, progressValue: T) in
                count++
                if count <= skipCount { return }
                
                progress(progressValue)
            }
            
            _bind(fulfill, reject, configure, self)
            
        }.name("\(self.name)-skip(\(skipCount))")
    }
    
    public func skip<U>(until triggerSignal: Signal<U>) -> Signal
    {
        return Signal<T> { [weak triggerSignal] progress, fulfill, reject, configure in
            
            let signalName = self.name
            
            var shouldSkip = true
            
            self.progress { (_, progressValue: T) in
                if !shouldSkip {
                    progress(progressValue)
                }
            }
            
            triggerSignal?.progress { (_, progressValue: U) in
                shouldSkip = false
            }.success { (value: U) -> Void in
                shouldSkip = false
            }.failure { (error: NSError?, isCancelled: Bool) -> Void in
                shouldSkip = false
            }
            
            _bind(fulfill, reject, configure, self)
            
        }.name("\(self.name)-skip(until:)")
    }
    
    public func merge(signal: Signal<T>) -> Signal<T>
    {
        return Signal<T>.merge([signal, self])
    }
    
    public func merge(signals: [Signal<T>]) -> Signal<T>
    {
        return Signal<T>.merge(signals + [self])
    }
    
    public func merge(initial initialValue: T) -> Signal<T>
    {
        return Signal<T>.merge([Signal(value: initialValue), self])
    }
    
    public func buffer(bufferCount: Int) -> Signal<[T]>
    {
        return Signal<[T]> { progress, fulfill, reject, configure in
            
            var buffer: [T] = []
            
            self.progress { (_, progressValue: T) in
                buffer += [progressValue]
                if buffer.count >= bufferCount {
                    progress(buffer)
                    buffer = []
                }
            }.success { _ -> Void in
                fulfill(buffer)
                buffer = []
            }.failure { _ -> Void in
                buffer = []
            }
            
            _bind(nil, reject, configure, self)
            
        }.name("\(self.name)-buffer")
    }
    
    public func buffer<U>(trigger triggerSignal: Signal<U>) -> Signal<[T]>
    {
        return Signal<[T]> { progress, fulfill, reject, configure in
            
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
            
        }.name("\(self.name)-buffer")
    }

    /// limit continuous progress (reaction) for `timeInterval` seconds when first progress is triggered
    /// (see also: underscore.js throttle)
    public func throttle(timeInterval: NSTimeInterval) -> Signal
    {
        return Signal<T> { progress, fulfill, reject, configure in
            
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
            
        }.name("\(self.name)-throttle(\(timeInterval))")
    }
    
    /// delay progress (reaction) for `timeInterval` seconds and truly invoke reaction afterward if not interrupted by continuous progress
    /// (see also: underscore.js debounce)
    public func debounce(timeInterval: NSTimeInterval) -> Signal
    {
        return Signal<T> { progress, fulfill, reject, configure in
            
            var timerSignal: Signal<Void>? = nil    // retained by self via self.progress
            
            self.progress { (_, progressValue: T) in
                // NOTE: overwrite to deinit & cancel old timerSignal
                timerSignal = NSTimer.signal(timeInterval: timeInterval, repeats: false) { _ in }
                
                timerSignal!.progress { _ -> Void in
                    progress(progressValue)
                }
            }
            
            _bind(fulfill, reject, configure, self)
            
        }.name("\(self.name)-debounce(\(timeInterval))")
    }
}

// Multiple Signal Operations
public extension Signal
{
    // TODO: using variadic parameters didn't work when `signal.merge(...)` invoking `Signal.merge(...)`. Swift bug?
    
    ///
    /// Merges multiple signals (`Signal<U>`) into single signal, with force-casting to `Signal<T>`.
    ///
    /// - e.g. `let intSignal: Signal<Int> = Signal<Int>.merge([anySignal1, anySignal2, ...])`,
    ///   where `anySignalX` is `Signal<Any>` and force-casting from Any to Int.
    ///
    /// NOTE: This method is conceptually equal to `Signal<T>.merge2(signals).map { $1 }`.
    ///
    public class func merge<U>(signals: [Signal<U>]) -> Signal<T>
    {
        return Signal<T> { progress, fulfill, reject, configure in
            
            let signalGroup = _SignalGroup(signals: signals)
            
            for signal in signals {
                signal.progress { (_, progressValue: U) in
                    progress(progressValue as T)
                }.then { value, errorInfo -> Void in
                    if let value = value {
                        fulfill(value as T)
                    }
                    else if let errorInfo = errorInfo {
                        if let error = errorInfo.error {
                            reject(error)
                        }
                        else {
                            let error = _RKError(.CancelledByInternalSignal, "One of signal is cancelled in Signal.merge().")
                            reject(error)
                        }
                    }
                }
            }
            
            // NOTE: signals should be captured by class-type signalGroup, which should be captured by new signal
            configure.pause = {
                Signal<U>.pauseAll(signalGroup.signals)
            }
            configure.resume = {
                Signal<U>.resumeAll(signalGroup.signals)
            }
            configure.cancel = {
                Signal<U>.cancelAll(signalGroup.signals)
            }
            
        }.name("Signal.merge")
    }
    
    public typealias ChangedValueTuple = (values: [T?], changedValue: T)
    
    ///
    /// Merges multiple signals (`Signal<U>`) into single signal,
    /// combining latest values `[U?]` as well as changed value `U` together as `([U?], U)` tuple,
    /// and finally force-casting to `Signal<([T?], T)>`.
    ///
    /// This is a generalized method for `Rx.merge()` and `Rx.combineLatest()`.
    ///
    public class func merge2<U>(signals: [Signal<U>]) -> Signal<ChangedValueTuple>
    {
        return Signal<ChangedValueTuple> { progress, fulfill, reject, configure in
            
            // wrap with class for weakifying
            let signalGroup = _SignalGroup<U>(signals: signals)
            
            func extractValuesAndHandle(valueSourceTuple tuple: (signalGroup: _SignalGroup<U>?, changedValue: U), #handler: ChangedValueTuple -> Void)
            {
                if let signalGroup = tuple.signalGroup {
                    let signals = signalGroup.signals
                    
                    let values: [T?] = signals.map { $0.progress as? T }
                    let valueTuple = ChangedValueTuple(values: values, changedValue: tuple.changedValue as T)
                    
                    handler(valueTuple)
                }
            }
            
            for signal in signals {
                signal.progress { [weak signalGroup] (_, progressValue: U) in
                    extractValuesAndHandle(valueSourceTuple: (signalGroup, progressValue), handler: progress)
                }.then { [weak signalGroup] value, errorInfo -> Void in
                    if let value = value {
                        extractValuesAndHandle(valueSourceTuple: (signalGroup, value), handler: fulfill)
                    }
                    else if let errorInfo = errorInfo {
                        if let error = errorInfo.error {
                            reject(error)
                        }
                        else {
                            let error = _RKError(.CancelledByInternalSignal, "One of signal is cancelled in Signal.merge2().")
                            reject(error)
                        }
                    }
                }
            }
            
            // NOTE: signals should be captured by class-type signalGroup, which should be captured by new signal
            configure.pause = {
                Signal<U>.pauseAll(signalGroup.signals)
            }
            configure.resume = {
                Signal<U>.resumeAll(signalGroup.signals)
            }
            configure.cancel = {
                Signal<U>.cancelAll(signalGroup.signals)
            }
            
        }.name("Signal.merge2")
    }
    
}

/// Signal + ReactiveExtension Semantics
/// (TODO: move to new file, but doesn't work in Swift 1.1. ERROR = ld: symbol(s) not found for architecture x86_64)
public extension Signal
{
    public func scan<U>(initial initialValue: U, _ accumulateClosure: (accumulatedValue: U, newValue: T) -> U) -> Signal<U>
    {
        return self.map(accumulate: initialValue, accumulateClosure)
    }

    public class func combineLatest<U>(signals: [Signal<U>]) -> Signal<[T?]>
    {
        return self.merge2(signals).map { values, _ in values }
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
