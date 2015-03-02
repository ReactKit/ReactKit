//
//  ReactKit.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask

public class Signal<T>: Task<T, Void, NSError>
{
    public override var description: String
    {
        return "<\(self.name); state=\(self.state.rawValue)>"
    }
    
    ///
    /// Creates a new signal (event-delivery-pipeline over time).
    /// Synonym of "stream", "observable", etc.
    ///
    /// :param: initClosure Closure to define returning signal's behavior. Inside this closure, `configure.pause`/`resume`/`cancel` should capture inner logic (player) object. See also comment in `SwiftTask.Task.init()`.
    ///
    /// :returns: New Signal.
    /// 
    public init(initClosure: Task<T, Void, NSError>.InitClosure)
    {
        //
        // NOTE: 
        // - set `weakified = true` to avoid "(inner) player -> signal" retaining
        // - set `paused = true` for lazy evaluation (similar to "cold signal")
        //
        super.init(weakified: true, paused: true, initClosure: initClosure)
        
        self.name = "DefaultSignal"
        
//        #if DEBUG
//            println("[init] \(self)")
//        #endif
    }
    
    deinit
    {
//        #if DEBUG
//            println("[deinit] \(self)")
//        #endif
        
        let cancelError = _RKError(.CancelledByDeinit, "Signal=\(self.name) is cancelled via deinit.")
        
        self.cancel(error: cancelError)
    }
    
    /// progress-chaining without auto-resume, useful for injecting side-effects
    /// a.k.a Rx.do, tap
    public func peek(peekClosure: T -> Void) -> Self
    {
        super.progress { _, value in peekClosure(value) }
        return self
    }
    
    /// progress-chaining with auto-resume
    public override func progress(progressClosure: ProgressTuple -> Void) -> Task<T, Void, NSError>
    {
        let signal = super.progress(progressClosure)
        self.resume()
        return signal
    }
    
    /// then(value)-chaining with auto-resume
    public func then(thenClosure: (Void?, ErrorInfo?) -> Void) -> Task<T, Void, NSError>
    {
        return self.then { (value: Void?, errorInfo: ErrorInfo?) -> Task<T, Void, NSError> in
            thenClosure(value, errorInfo)
            return Task<T, Void, NSError>(value: ())
        }
    }
    
    /// then(task)-chaining with auto-resume
    public func then<U>(thenClosure: (Void?, ErrorInfo?) -> Task<U, Void, NSError>) -> Task<U, Void, NSError>
    {
        let signal = super.then(thenClosure)
        self.resume()
        return signal
    }
    
    /// success(value)-chaining with auto-resume
    public func success(successClosure: Void -> Void) -> Task<T, Void, NSError>
    {
        return self.success { _ -> Task<T, Void, NSError> in
            successClosure()
            return Task<T, Void, NSError>(value: ())
        }
    }
    
    /// success(task)-chaining with auto-resume
    public func success<U>(successClosure: Void -> Task<U, Void, NSError>) -> Task<U, Void, NSError>
    {
        let signal = super.success(successClosure)
        self.resume()
        return signal
    }
    
    /// failure(value)-chaining with auto-resume
    public override func failure(failureClosure: ErrorInfo -> Void) -> Task<T, Void, NSError>
    {
        return self.failure { (errorInfo: ErrorInfo) -> Task<T, Void, NSError> in
            failureClosure(errorInfo)
            return Task<T, Void, NSError>(value: ())
        }
    }
    
    /// failure(task)-chaining with auto-resume
    public override func failure<U>(failureClosure: ErrorInfo -> Task<U, Void, NSError>) -> Task<U, Void, NSError>
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

/// helper method to bind downstream's `fulfill`/`reject`/`configure` handlers with upstream
private func _bindToUpstreamSignal<T>(upstreamSignal: Signal<T>, fulfill: (Void -> Void)?, reject: (NSError -> Void)?, configure: TaskConfiguration)
{
    if fulfill != nil || reject != nil {
        
        let signalName = upstreamSignal.name

        // fulfill/reject downstream on upstream-fulfill/reject/cancel
        upstreamSignal.then { value, errorInfo -> Void in
            
            if value != nil {
                fulfill?()
                return
            }
            else if let errorInfo = errorInfo {
                // rejected
                if let error = errorInfo.error {
                    reject?(error)
                    return
                }
                // cancelled
                else {
                    let cancelError = _RKError(.CancelledByUpstream, "Signal=\(signalName) is rejected or cancelled.")
                    reject?(cancelError)
                }
            }
            
        }
    }
    
    // NOTE: downstreamSignal should capture upstreamSignal
    configure.pause = { upstreamSignal.pause(); return }
    configure.resume = { upstreamSignal.resume(); return }
    configure.cancel = { upstreamSignal.cancel(); return }
}

//--------------------------------------------------
// MARK: - Init Helper
/// (TODO: move to new file, but doesn't work in Swift 1.1. ERROR = ld: symbol(s) not found for architecture x86_64)
//--------------------------------------------------

public extension Signal
{
    /// creates once (progress once & fulfill) signal
    /// NOTE: this method can't move to other file due to Swift 1.1
    public class func once(value: T) -> Signal<T>
    {
        return Signal { progress, fulfill, reject, configure in
            progress(value)
            fulfill()
        }.name("OnceSignal")
    }
    
    /// creates never (no progress & fulfill & reject) signal
    public class func never() -> Signal<T>
    {
        return Signal { progress, fulfill, reject, configure in
            // do nothing
        }.name("NeverSignal")
    }
    
    /// creates empty (fulfilled without any progress) signal
    public class func fulfilled() -> Signal<T>
    {
        return Signal { progress, fulfill, reject, configure in
            fulfill()
        }.name("FulfilledSignal")
    }
    
    /// creates error (rejected) signal
    public class func rejected(error: NSError) -> Signal<T>
    {
        return Signal { progress, fulfill, reject, configure in
            reject(error)
        }.name("RejectedSignal")
    }
    
    ///
    /// creates signal from SequenceType (e.g. Array) and fulfills at last
    ///
    /// - e.g. Signal(values: [1, 2, 3])
    ///
    /// a.k.a `Rx.fromArray`
    ///
    public convenience init<S: SequenceType where S.Generator.Element == T>(values: S)
    {
        self.init(initClosure: { progress, fulfill, reject, configure in
            var generator = values.generate()
            while let value: T = generator.next() {
                progress(value)
            }
            fulfill()
        })
        self.name = "Signal(array:)"
    }
}

//--------------------------------------------------
// MARK: - Signal Operations (Instance Methods)
//--------------------------------------------------

public extension Signal
{
    /// creates your own customizable & method-chainable signal without writing `return Signal<U> { ... }`
    public func customize<U>(
        customizeClosure: (upstreamSignal: Signal<T>, progress: Signal<U>.ProgressHandler, fulfill: Signal<U>.FulfillHandler, reject: Signal<U>.RejectHandler) -> Void
    ) -> Signal<U>
    {
        return Signal<U> { progress, fulfill, reject, configure in
            customizeClosure(upstreamSignal: self, progress: progress, fulfill: fulfill, reject: reject)
            _bindToUpstreamSignal(self, nil, nil, configure)
        }
    }
    
    /// filter using newValue only
    public func filter(filterClosure: T -> Bool) -> Signal<T>
    {
        return Signal<T> { progress, fulfill, reject, configure in
            
            self.progress { (_, progressValue: T) in
                if filterClosure(progressValue) {
                    progress(progressValue)
                }
            }
        
            _bindToUpstreamSignal(self, fulfill, reject, configure)
            
        }.name("\(self.name)-filter")
    }

    /// filter using (oldValue, newValue)
    public func filter2(filterClosure2: (oldValue: T?, newValue: T) -> Bool) -> Signal<T>
    {
        var oldValue: T?
        
        return self.filter { (newValue: T) -> Bool in
            let flag = filterClosure2(oldValue: oldValue, newValue: newValue)
            oldValue = newValue
            return flag
        }.name("\(self.name)-filter2")
    }
    
    /// map using newValue only
    public func map<U>(transform: T -> U) -> Signal<U>
    {
        return Signal<U> { progress, fulfill, reject, configure in
            
            self.progress { (_, progressValue: T) in
                progress(transform(progressValue))
            }.success {
                fulfill()
            }
            
            _bindToUpstreamSignal(self, nil, reject, configure)
            
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
            }.success {
                fulfill()
            }
            
            _bindToUpstreamSignal(self, nil, reject, configure)

        }.name("\(self.name)-flatMap")
        
    }
    
    /// map using (oldValue, newValue)
    public func map2<U>(transform2: (oldValue: T?, newValue: T) -> U) -> Signal<U>
    {
        var oldValue: T?
        
        return self.map { (newValue: T) -> U in
            let mappedValue = transform2(oldValue: oldValue, newValue: newValue)
            oldValue = newValue
            return mappedValue
        }.name("\(self.name)-map2")
    }
    
    /// map using (accumulatedValue, newValue)
    /// a.k.a `Rx.scan()`
    public func mapAccumulate<U>(initialValue: U, _ accumulateClosure: (accumulatedValue: U, newValue: T) -> U) -> Signal<U>
    {
        return Signal<U> { progress, fulfill, reject, configure in
            
            var accumulatedValue: U = initialValue
            
            self.progress { p in
                accumulatedValue = accumulateClosure(accumulatedValue: accumulatedValue, newValue: p.newProgress)
                progress(accumulatedValue)
            }.success {
                fulfill()
            }
            
            _bindToUpstreamSignal(self, nil, reject, configure)
            
        }.name("\(self.name)-mapAccumulate")
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
                    fulfill()   // successfully reached maxCount
                }
                
            }
            
            _bindToUpstreamSignal(self, fulfill, reject, configure)
            
        }.name("\(self.name)-take(\(maxCount))")
    }
    
    public func takeUntil<U>(triggerSignal: Signal<U>) -> Signal
    {
        return Signal<T> { [weak triggerSignal] progress, fulfill, reject, configure in
            
            if let triggerSignal = triggerSignal {

                self.progress { (_, progressValue: T) in
                    progress(progressValue)
                }

                let cancelError = _RKError(.CancelledByTriggerSignal, "Signal=\(self.name) is cancelled by takeUntil(\(triggerSignal.name)).")
                
                triggerSignal.progress { [weak self] _ in
                    if let self_ = self {
                        self_.cancel(error: cancelError)
                    }
                }.then { [weak self] _ -> Void in
                    if let self_ = self {
                        self_.cancel(error: cancelError)
                    }
                }
                
                _bindToUpstreamSignal(self, fulfill, reject, configure)
            }
            else {
                let cancelError = _RKError(.CancelledByTriggerSignal, "Signal=\(self.name) is cancelled by takeUntil() with `triggerSignal` already been deinited.")
                self.cancel(error: cancelError)
            }
            
        }.name("\(self.name)-takeUntil")
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
            
            _bindToUpstreamSignal(self, fulfill, reject, configure)
            
        }.name("\(self.name)-skip(\(skipCount))")
    }
    
    public func skipUntil<U>(triggerSignal: Signal<U>) -> Signal
    {
        return Signal<T> { [weak triggerSignal] progress, fulfill, reject, configure in
            
            var shouldSkip = true
            
            self.progress { (_, progressValue: T) in
                if !shouldSkip {
                    progress(progressValue)
                }
            }
            
            if let triggerSignal = triggerSignal {
                triggerSignal.progress { _ in
                    shouldSkip = false
                }.then { _ -> Void in
                    shouldSkip = false
                }
            }
            else {
                shouldSkip = false
            }
            
            _bindToUpstreamSignal(self, fulfill, reject, configure)
            
        }.name("\(self.name)-skipUntil")
    }
    
    public func merge(signal: Signal<T>) -> Signal<T>
    {
        return self.merge([signal])
    }
    
    public func merge(signals: [Signal<T>]) -> Signal<T>
    {
        return Signal<T>.merge(signals + [self])
            .name("\(self.name)-merge")
    }
    
    public func concat(nextSignal: Signal<T>) -> Signal<T>
    {
        return self.concat([nextSignal])
    }
    
    public func concat(nextSignals: [Signal<T>]) -> Signal<T>
    {
        return Signal<T>.concat([self] + nextSignals)
            .name("\(self.name)-concat")
    }
    
    /// `concat()` initialValue first
    public func startWith(initialValue: T) -> Signal<T>
    {
        return Signal<T>.concat([Signal.once(initialValue), self])
            .name("\(self.name)-startWith")
    }
    
    public func zip(signal: Signal<T>) -> Signal<[T]>
    {
        return self.zip([signal])
    }
    
    public func zip(signals: [Signal<T>]) -> Signal<[T]>
    {
        return Signal<T>.zip([self] + signals)
            .name("\(self.name)-zip")
    }
    
    public func buffer(bufferCount: Int) -> Signal<[T]>
    {
        precondition(bufferCount > 0)
        
        return Signal<[T]> { progress, fulfill, reject, configure in
            
            var buffer: [T] = []
            
            self.progress { (_, progressValue: T) in
                buffer += [progressValue]
                if buffer.count >= bufferCount {
                    progress(buffer)
                    buffer = []
                }
            }.success { _ -> Void in
                progress(buffer)
                fulfill()
            }
            
            _bindToUpstreamSignal(self, nil, reject, configure)
            
        }.name("\(self.name)-buffer")
    }
    
    public func bufferBy<U>(triggerSignal: Signal<U>) -> Signal<[T]>
    {
        return Signal<[T]> { [weak triggerSignal] progress, fulfill, reject, configure in
            
            var buffer: [T] = []
            
            self.progress { (_, progressValue: T) in
                buffer += [progressValue]
            }.success { _ -> Void in
                progress(buffer)
                fulfill()
            }
            
            triggerSignal?.progress { [weak self] _ in
                if let self_ = self {
                    progress(buffer)
                    buffer = []
                }
            }.then { [weak self] _ -> Void in
                if let self_ = self {
                    progress(buffer)
                    buffer = []
                }
            }
            
            _bindToUpstreamSignal(self, nil, reject, configure)
            
        }.name("\(self.name)-bufferBy")
    }
    
    /// delay `progress` and `fulfill` for `timerInterval` seconds
    public func delay(timeInterval: NSTimeInterval) -> Signal<T>
    {
        return Signal<T> { progress, fulfill, reject, configure in
            
            self.progress { (_, progressValue: T) in
                var timerSignal: Signal<Void>? = NSTimer.signal(timeInterval: timeInterval, repeats: false) { _ in }
                
                timerSignal!.progress { _ -> Void in
                    progress(progressValue)
                    timerSignal = nil
                }
            }.success { _ -> Void in
                var timerSignal: Signal<Void>? = NSTimer.signal(timeInterval: timeInterval, repeats: false) { _ in }
                
                timerSignal!.progress { _ -> Void in
                    fulfill()
                    timerSignal = nil
                }
            }
            
            _bindToUpstreamSignal(self, nil, reject, configure)
            
        }.name("\(self.name)-delay(\(timeInterval))")
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
            
            _bindToUpstreamSignal(self, fulfill, reject, configure)
            
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
            
            _bindToUpstreamSignal(self, fulfill, reject, configure)
            
        }.name("\(self.name)-debounce(\(timeInterval))")
    }
}

//--------------------------------------------------
// MARK: - Signal Operations (Class Methods)
//--------------------------------------------------

public extension Signal
{
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
            
            for signal in signals {
                signal.progress { (_, progressValue: U) in
                    progress(progressValue as T)
                }.then { value, errorInfo -> Void in
                    if value != nil {
                        fulfill()
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
            
            // NOTE: signals should be captured by new signal
            configure.pause = {
                Signal<U>.pauseAll(signals)
            }
            configure.resume = {
                Signal<U>.resumeAll(signals)
            }
            configure.cancel = {
                Signal<U>.cancelAll(signals)
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
            
            var states = [U?](count: signals.count, repeatedValue: nil)
            
            for i in 0..<signals.count {
                
                let signal = signals[i]
                
                signal.progress { (_, progressValue: U) in
                    states[i] = progressValue
                    progress((states.map { $0 as? T }, progressValue as T))
                }.then { value, errorInfo -> Void in
                    if value != nil {
                        fulfill()
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
            
            configure.pause = {
                Signal<U>.pauseAll(signals)
            }
            configure.resume = {
                Signal<U>.resumeAll(signals)
            }
            configure.cancel = {
                Signal<U>.cancelAll(signals)
            }
            
        }.name("Signal.merge2")
    }
    
    public class func combineLatest<U>(signals: [Signal<U>]) -> Signal<[T]>
    {
        return self.merge2(signals).filter { values, _ in
            var areAllNonNil = true
            for value in values {
                if value == nil {
                    areAllNonNil = false
                    break
                }
            }
            return areAllNonNil
        }.map { values, _ in values.map { $0! } }
    }
    
    public class func concat<U>(signals: [Signal<U>]) -> Signal<T>
    {
        precondition(signals.count > 1)
        
        return Signal<T> { progress, fulfill, reject, configure in
            
            // NOTE: to call this method recursively, local-closure must be declared first (as Optional) before assignment
            var concatRecursively: (([Signal<U>]) -> Void)!
            
            concatRecursively = { signals in
                
                if let signal = signals.first {
                    
                    signal.progress { _, progressValue in
                        progress(progressValue as T)
                    }.success {
                        concatRecursively(Array(signals[1..<signals.count]))
                    }.failure { errorInfo -> Void in
                        if let error = errorInfo.error {
                            reject(error)
                        }
                        else {
                            let error = _RKError(.CancelledByInternalSignal, "One of signal is cancelled in Signal.concat().")
                            reject(error)
                        }
                    }
                }
                else {
                    fulfill()
                }
                
            }
            
            concatRecursively(signals)
            
            configure.pause = {
                Signal<U>.pauseAll(signals)
            }
            configure.resume = {
                Signal<U>.resumeAll(signals)
            }
            configure.cancel = {
                Signal<U>.cancelAll(signals)
            }
            
        }.name("Signal.concat")
    }
    
    public class func zip<U>(signals: [Signal<U>]) -> Signal<[T]>
    {
        precondition(signals.count > 1)
        
        return Signal<[T]> { progress, fulfill, reject, configure in
           
            let signalCount = signals.count

            var storedValuesArray: [[T]] = []
            for i in 0..<signalCount {
                storedValuesArray.append([])
            }
            
            for i in 0..<signalCount {
                
                signals[i].progress { (_, progressValue: U) in
                    
                    storedValuesArray[i] += [progressValue as T]
                    
                    var canProgress: Bool = true
                    for storedValues in storedValuesArray {
                        if storedValues.count == 0 {
                            canProgress = false
                            break
                        }
                    }
                    
                    if canProgress {
                        var firstStoredValues: [T] = []
                        
                        for i in 0..<signalCount {
                            let firstStoredValue = storedValuesArray[i].removeAtIndex(0)
                            firstStoredValues.append(firstStoredValue)
                        }
                        
                        progress(firstStoredValues)
                    }
                    
                }.success { _ -> Void in
                    fulfill()
                }
            }
            
            configure.pause = {
                Signal<U>.pauseAll(signals)
            }
            configure.resume = {
                Signal<U>.resumeAll(signals)
            }
            configure.cancel = {
                Signal<U>.cancelAll(signals)
            }
            
        }.name("Signal.zip")
    }
    
}


//--------------------------------------------------
/// MARK: - Rx Semantics
/// (TODO: move to new file, but doesn't work in Swift 1.1. ERROR = ld: symbol(s) not found for architecture x86_64)
//--------------------------------------------------

public extension Signal
{
    /// alias for `Signal.fulfilled()`
    public class func just(value: T) -> Signal<T>
    {
        return self.once(value)
    }
    
    /// alias for `Signal.fulfilled()`
    public class func empty() -> Signal<T>
    {
        return self.fulfilled()
    }
    
    /// alias for `Signal.rejected()`
    public class func error(error: NSError) -> Signal<T>
    {
        return self.rejected(error)
    }
    
    /// alias for `signal.mapAccumulate()`
    public func scan<U>(initialValue: U, _ accumulateClosure: (accumulatedValue: U, newValue: T) -> U) -> Signal<U>
    {
        return self.mapAccumulate(initialValue, accumulateClosure)
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
