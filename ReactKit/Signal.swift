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
    
    /// progress-chaining with auto-resume
    public func react(reactClosure: T -> Void) -> Self
    {
        let signal = super.progress { _, value in reactClosure(value) }
        self.resume()
        return self
    }
    
    // required (Swift compiler fails...)
    public override func cancel(error: NSError? = nil) -> Bool
    {
        return super.cancel(error: error)
    }
    
    /// Easy strong referencing by owner e.g. UIViewController holding its UI component's signal
    /// without explicitly defining signal as property.
    public func ownedBy(owner: NSObject) -> Signal<T>
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
    //
    // NOTE:
    // Bind downstreamSignal's `configure` to upstreamSignal
    // BEFORE performing its `progress()`/`then()`/`success()`/`failure()`
    // so that even when downstream **immediately finishes** on its 1st resume,
    // upstream can know `configure.isFinished = true`
    // while performing its `initClosure`.
    //
    // This is especially important for stopping immediate-infinite-sequence,
    // e.g. `infiniteSignal.take(3)` will stop infinite-while-loop at end of 3rd iteration.
    //

    // NOTE: downstreamSignal should capture upstreamSignal
    let oldPause = configure.pause;
    configure.pause = { oldPause?(); upstreamSignal.pause(); return }
    
    let oldResume = configure.resume;
    configure.resume = { oldResume?(); upstreamSignal.resume(); return }
    
    let oldCancel = configure.cancel;
    configure.cancel = { oldCancel?(); upstreamSignal.cancel(); return }
    
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
                
                if configure.isFinished { break }
            }
            fulfill()
        })
        self.name = "Signal(array:)"
    }
}

//--------------------------------------------------
// MARK: - Single Signal Operations
//--------------------------------------------------

/// useful for injecting side-effects
/// a.k.a Rx.do, tap
public func peek<T>(peekClosure: T -> Void)(upstream: Signal<T>) -> Signal<T>
{
    return Signal<T> { progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, fulfill, reject, configure)
        
        upstream.react { value in
            peekClosure(value)
            progress(value)
        }
        
    }.name("\(upstream.name)-peek")
}

/// creates your own customizable & method-chainable signal without writing `return Signal<U> { ... }`
public func customize<T, U>
    (customizeClosure: (upstreamSignal: Signal<T>, progress: Signal<U>.ProgressHandler, fulfill: Signal<U>.FulfillHandler, reject: Signal<U>.RejectHandler) -> Void)
    (upstream: Signal<T>)
-> Signal<U>
{
    return Signal<U> { progress, fulfill, reject, configure in
        _bindToUpstreamSignal(upstream, nil, nil, configure)
        customizeClosure(upstreamSignal: upstream, progress: progress, fulfill: fulfill, reject: reject)
    }.name("\(upstream.name)-customize")
}

// MARK: transforming

/// map using newValue only
public func map<T, U>(transform: T -> U)(upstream: Signal<T>) -> Signal<U>
{
    return Signal<U> { progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, fulfill, reject, configure)
        
        upstream.react { value in
            progress(transform(value))
        }
        
    }.name("\(upstream.name)-map")
}

/// map using newValue only & bind to transformed Signal
public func flatMap<T, U>(transform: T -> Signal<U>)(upstream: Signal<T>) -> Signal<U>
{
    return Signal<U> { progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, fulfill, reject, configure)
        
        // NOTE: each of `transformToSignal()` needs to be retained outside
        var innerSignals: [Signal<U>] = []
        
        upstream.react { value in
            let innerSignal = transform(value)
            innerSignals += [innerSignal]
            
            innerSignal.react { value in
                progress(value)
            }
        }

    }.name("\(upstream.name)-flatMap")
    
}

/// map using (oldValue, newValue)
public func map2<T, U>(transform2: (oldValue: T?, newValue: T) -> U)(upstream: Signal<T>) -> Signal<U>
{
    var oldValue: T?
    
    let signal = upstream |> map { (newValue: T) -> U in
        let mappedValue = transform2(oldValue: oldValue, newValue: newValue)
        oldValue = newValue
        return mappedValue
    }
    
    signal.name("\(upstream.name)-map2")
    
    return signal
}

/// map using (accumulatedValue, newValue)
/// a.k.a `Rx.scan()`
public func mapAccumulate<T, U>(initialValue: U, accumulateClosure: (accumulatedValue: U, newValue: T) -> U)(upstream: Signal<T>) -> Signal<U>
{
    return Signal<U> { progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, fulfill, reject, configure)
        
        var accumulatedValue: U = initialValue
        
        upstream.react { value in
            accumulatedValue = accumulateClosure(accumulatedValue: accumulatedValue, newValue: value)
            progress(accumulatedValue)
        }
        
    }.name("\(upstream.name)-mapAccumulate")
}

public func buffer<T>(bufferCount: Int)(upstream: Signal<T>) -> Signal<[T]>
{
    precondition(bufferCount > 0)
    
    return Signal<[T]> { progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, nil, reject, configure)
        
        var buffer: [T] = []
        
        upstream.react { value in
            buffer += [value]
            if buffer.count >= bufferCount {
                progress(buffer)
                buffer = []
            }
        }.success { _ -> Void in
            progress(buffer)
            fulfill()
        }
        
    }.name("\(upstream.name)-buffer")
}

public func bufferBy<T, U>(triggerSignal: Signal<U>)(upstream: Signal<T>) -> Signal<[T]>
{
    return Signal<[T]> { [weak triggerSignal] progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, nil, reject, configure)
        
        var buffer: [T] = []
        
        upstream.react { value in
            buffer += [value]
        }.success { _ -> Void in
            progress(buffer)
            fulfill()
        }
        
        triggerSignal?.react { [weak upstream] _ in
            if let upstream = upstream {
                progress(buffer)
                buffer = []
            }
        }.then { [weak upstream] _ -> Void in
            if let upstream = upstream {
                progress(buffer)
                buffer = []
            }
        }
        
    }.name("\(upstream.name)-bufferBy")
}

public func groupBy<T, Key: Hashable>(groupingClosure: T -> Key)(upstream: Signal<T>) -> Signal<(Key, Signal<T>)>
{
    return Signal<(Key, Signal<T>)> { progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, fulfill, reject, configure)
        
        var buffer: [Key : (signal: Signal<T>, progressHandler: Signal<T>.ProgressHandler)] = [:]
        
        upstream.react { value in
            let key = groupingClosure(value)
            
            if buffer[key] == nil {
                var progressHandler: Signal<T>.ProgressHandler?
                let innerSignal = Signal<T> { p, _, _, _ in
                    progressHandler = p;    // steal progressHandler
                    return
                }
                innerSignal.resume()    // resume to steal `progressHandler` immediately
                
                buffer[key] = (innerSignal, progressHandler!) // set innerSignal
                
                progress((key, buffer[key]!.signal) as (Key, Signal<T>))
            }
            
            buffer[key]!.progressHandler(value) // push value to innerSignal
            
        }
        
    }.name("\(upstream.name)-groupBy")
}

// MARK: filtering

/// filter using newValue only
public func filter<T>(filterClosure: T -> Bool)(upstream: Signal<T>) -> Signal<T>
{
    return Signal<T> { progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, fulfill, reject, configure)
        
        upstream.react { value in
            if filterClosure(value) {
                progress(value)
            }
        }
        
    }.name("\(upstream.name)-filter")
}

/// filter using (oldValue, newValue)
public func filter2<T>(filterClosure2: (oldValue: T?, newValue: T) -> Bool)(upstream: Signal<T>) -> Signal<T>
{
    var oldValue: T?
    
    let signal = upstream |> filter { (newValue: T) -> Bool in
        let flag = filterClosure2(oldValue: oldValue, newValue: newValue)
        oldValue = newValue
        return flag
    }
    
    signal.name("\(upstream.name)-filter2")
    
    return signal
}

public func take<T>(maxCount: Int)(upstream: Signal<T>) -> Signal<T>
{
    return Signal<T> { progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, nil, reject, configure)
        
        var count = 0
        
        upstream.react { value in
            count++
            
            if count < maxCount {
                progress(value)
            }
            else if count == maxCount {
                progress(value)
                fulfill()   // successfully reached maxCount
            }
            
        }
        
    }.name("\(upstream.name)-take(\(maxCount))")
}

public func takeUntil<T, U>(triggerSignal: Signal<U>)(upstream: Signal<T>) -> Signal<T>
{
    return Signal<T> { [weak triggerSignal] progress, fulfill, reject, configure in
        
        if let triggerSignal = triggerSignal {
            
            _bindToUpstreamSignal(upstream, fulfill, reject, configure)
            
            upstream.react { value in
                progress(value)
            }

            let cancelError = _RKError(.CancelledByTriggerSignal, "Signal=\(upstream.name) is cancelled by takeUntil(\(triggerSignal.name)).")
            
            triggerSignal.react { [weak upstream] _ in
                if let upstream_ = upstream {
                    upstream_.cancel(error: cancelError)
                }
            }.then { [weak upstream] _ -> Void in
                if let upstream_ = upstream {
                    upstream_.cancel(error: cancelError)
                }
            }
        }
        else {
            let cancelError = _RKError(.CancelledByTriggerSignal, "Signal=\(upstream.name) is cancelled by takeUntil() with `triggerSignal` already been deinited.")
            upstream.cancel(error: cancelError)
        }
        
    }.name("\(upstream.name)-takeUntil")
}

public func skip<T>(skipCount: Int)(upstream: Signal<T>) -> Signal<T>
{
    return Signal<T> { progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, fulfill, reject, configure)
        
        var count = 0
        
        upstream.react { value in
            count++
            if count <= skipCount { return }
            
            progress(value)
        }
        
    }.name("\(upstream.name)-skip(\(skipCount))")
}

public func skipUntil<T, U>(triggerSignal: Signal<U>)(upstream: Signal<T>) -> Signal<T>
{
    return Signal<T> { [weak triggerSignal] progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, fulfill, reject, configure)
        
        var shouldSkip = true
        
        upstream.react { value in
            if !shouldSkip {
                progress(value)
            }
        }
        
        if let triggerSignal = triggerSignal {
            triggerSignal.react { _ in
                shouldSkip = false
            }.then { _ -> Void in
                shouldSkip = false
            }
        }
        else {
            shouldSkip = false
        }
        
    }.name("\(upstream.name)-skipUntil")
}

public func sample<T, U>(triggerSignal: Signal<U>)(upstream: Signal<T>) -> Signal<T>
{
    return Signal<T> { [weak triggerSignal] progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, fulfill, reject, configure)
        
        var lastValue: T?
        
        upstream.react { value in
            lastValue = value
        }
        
        if let triggerSignal = triggerSignal {
            triggerSignal.react { _ in
                if let lastValue = lastValue {
                    progress(lastValue)
                }
            }
        }
        
    }
}

public func distinct<H: Hashable>(upstream: Signal<H>) -> Signal<H>
{
    return Signal<H> { progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, fulfill, reject, configure)
        
        var usedValueHashes = Set<H>()
        
        upstream.react { value in
            if !usedValueHashes.contains(value) {
                usedValueHashes.insert(value)
                progress(value)
            }
        }
        
    }
}

// MARK: combining

public func merge<T>(signal: Signal<T>)(upstream: Signal<T>) -> Signal<T>
{
    return upstream |> merge([signal])
}

public func merge<T>(signals: [Signal<T>])(upstream: Signal<T>) -> Signal<T>
{
    let signal = (signals + [upstream]) |> mergeAll
    return signal.name("\(upstream.name)-merge")
}

public func concat<T>(nextSignal: Signal<T>)(upstream: Signal<T>) -> Signal<T>
{
    return upstream |> concat([nextSignal])
}

public func concat<T>(nextSignals: [Signal<T>])(upstream: Signal<T>) -> Signal<T>
{
    let signal = ([upstream] + nextSignals) |> concatAll
    return signal.name("\(upstream.name)-concat")
}

//
// NOTE:
// Avoid using curried function since `initialValue` seems to get deallocated at uncertain timing
// (especially for T as value-type e.g. String, but also occurs a little in reference-type e.g. NSString).
// Make sure to let `initialValue` be captured by closure explicitly.
//
/// `concat()` initialValue first
public func startWith<T>(initialValue: T) -> (upstream: Signal<T>) -> Signal<T>
{
    return { (upstream: Signal<T>) -> Signal<T> in
        precondition(upstream.state == .Paused)
        
        let signal = [Signal.once(initialValue), upstream] |> concatAll
        return signal.name("\(upstream.name)-startWith")
    }
}
//public func startWith<T>(initialValue: T)(upstream: Signal<T>) -> Signal<T>
//{
//    let signal = [Signal.once(initialValue), upstream] |> concatAll
//    return signal.name("\(upstream.name)-startWith")
//}

public func zip<T>(signal: Signal<T>)(upstream: Signal<T>) -> Signal<[T]>
{
    return upstream |> zip([signal])
}

public func zip<T>(signals: [Signal<T>])(upstream: Signal<T>) -> Signal<[T]>
{
    let signal = ([upstream] + signals) |> zipAll
    return signal.name("\(upstream.name)-zip")
}

// MARK: timing

/// delay `progress` and `fulfill` for `timerInterval` seconds
public func delay<T>(timeInterval: NSTimeInterval)(upstream: Signal<T>) -> Signal<T>
{
    return Signal<T> { progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, nil, reject, configure)
        
        upstream.react { value in
            var timerSignal: Signal<Void>? = NSTimer.signal(timeInterval: timeInterval, repeats: false) { _ in }
            
            timerSignal!.react { _ in
                progress(value)
                timerSignal = nil
            }
        }.success { _ -> Void in
            var timerSignal: Signal<Void>? = NSTimer.signal(timeInterval: timeInterval, repeats: false) { _ in }
            
            timerSignal!.react { _ in
                fulfill()
                timerSignal = nil
            }
        }
        
    }.name("\(upstream.name)-delay(\(timeInterval))")
}

/// limit continuous progress (reaction) for `timeInterval` seconds when first progress is triggered
/// (see also: underscore.js throttle)
public func throttle<T>(timeInterval: NSTimeInterval)(upstream: Signal<T>) -> Signal<T>
{
    return Signal<T> { progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, fulfill, reject, configure)
        
        var lastProgressDate = NSDate(timeIntervalSince1970: 0)
        
        upstream.react { value in
            let now = NSDate()
            let timeDiff = now.timeIntervalSinceDate(lastProgressDate)
            
            if timeDiff > timeInterval {
                lastProgressDate = now
                progress(value)
            }
        }
        
    }.name("\(upstream.name)-throttle(\(timeInterval))")
}

/// delay progress (reaction) for `timeInterval` seconds and truly invoke reaction afterward if not interrupted by continuous progress
/// (see also: underscore.js debounce)
public func debounce<T>(timeInterval: NSTimeInterval)(upstream: Signal<T>) -> Signal<T>
{
    return Signal<T> { progress, fulfill, reject, configure in
        
        _bindToUpstreamSignal(upstream, fulfill, reject, configure)
        
        var timerSignal: Signal<Void>? = nil    // retained by upstream via upstream.react()
        
        upstream.react { value in
            // NOTE: overwrite to deinit & cancel old timerSignal
            timerSignal = NSTimer.signal(timeInterval: timeInterval, repeats: false) { _ in }
            
            timerSignal!.react { _ in
                progress(value)
            }
        }
        
    }.name("\(upstream.name)-debounce(\(timeInterval))")
}

//--------------------------------------------------
// MARK: - Array Signals Operations
//--------------------------------------------------

///
/// Merges multiple signals into single signal,
/// combining latest values `[U?]` as well as changed value `U` together as `([U?], U)` tuple.
///
/// This is a generalized method for `Rx.merge()` and `Rx.combineLatest()`.
///
public func merge2All<T>(signals: [Signal<T>]) -> Signal<(values: [T?], changedValue: T)>
{
    return Signal { progress, fulfill, reject, configure in
        
        configure.pause = {
            Signal<T>.pauseAll(signals)
        }
        configure.resume = {
            Signal<T>.resumeAll(signals)
        }
        configure.cancel = {
            Signal<T>.cancelAll(signals)
        }
        
        var states = [T?](count: signals.count, repeatedValue: nil)
        
        for i in 0..<signals.count {
            
            let signal = signals[i]
            
            signal.react { value in
                states[i] = value
                progress(values: states, changedValue: value)
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
        
    }.name("merge2All")
}

public func combineLatestAll<T>(signals: [Signal<T>]) -> Signal<[T]>
{
    let signal = merge2All(signals)
        |> filter { values, _ in
            var areAllNonNil = true
            for value in values {
                if value == nil {
                    areAllNonNil = false
                    break
                }
            }
            return areAllNonNil
        }
        |> map { values, _ in values.map { $0! } }
    
    return signal.name("combineLatestAll")
}

public func zipAll<T>(signals: [Signal<T>]) -> Signal<[T]>
{
    precondition(signals.count > 1)
    
    return Signal<[T]> { progress, fulfill, reject, configure in
        
        configure.pause = {
            Signal<T>.pauseAll(signals)
        }
        configure.resume = {
            Signal<T>.resumeAll(signals)
        }
        configure.cancel = {
            Signal<T>.cancelAll(signals)
        }
        
        let signalCount = signals.count

        var storedValuesArray: [[T]] = []
        for i in 0..<signalCount {
            storedValuesArray.append([])
        }
        
        for i in 0..<signalCount {
            
            signals[i].react { value in
                
                storedValuesArray[i] += [value]
                
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
        
    }.name("zipAll")
}

//--------------------------------------------------
// MARK: - Nested Signal<Signal<T>> Operations
//--------------------------------------------------

///
/// Merges multiple signals into single signal.
///
/// - e.g. `let mergedSignal = [signal1, signal2, ...] |> mergeAll`
///
/// NOTE: This method is conceptually equal to `signals |> merge2(signals) |> map { $1 }`.
///
public func mergeAll<T>(nestedSignal: Signal<Signal<T>>) -> Signal<T>
{
    return Signal<T> { progress, fulfill, reject, configure in
        
        configure.pause = {
            nestedSignal.pause()
        }
        configure.resume = {
            nestedSignal.resume()
        }
        configure.cancel = {
            nestedSignal.cancel()
        }
        
        nestedSignal.react { (innerSignal: Signal<T>) in
            
            _bindToUpstreamSignal(innerSignal, nil, nil, configure)

            innerSignal.react { value in
                progress(value)
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
        
    }.name("mergeAll")
}

/// fixed-point combinator
private func _fix<T, U>(f: (T -> U) -> T -> U) -> T -> U
{
    return { f(_fix(f))($0) }
}

public func concatAll<T>(nestedSignal: Signal<Signal<T>>) -> Signal<T>
{
    return Signal<T> { progress, fulfill, reject, configure in
        
        var pendingSignals = [Signal<T>]()
        
        configure.pause = {
            nestedSignal.pause()
        }
        configure.resume = {
            nestedSignal.resume()
        }
        configure.cancel = {
            nestedSignal.cancel()
        }
        
        let performRecursively: Void -> Void = _fix { recurse in
            return {
                if let signal = pendingSignals.first {
                    if pendingSignals.count == 1 {
                        _bindToUpstreamSignal(signal, nil, nil, configure)
                        
                        signal.react { value in
                            progress(value)
                        }.success {
                            pendingSignals.removeAtIndex(0)
                            recurse()
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
                }
            }
        }
        
        nestedSignal.react { (signal: Signal<T>) in
            pendingSignals += [signal]
            performRecursively()
        }
        
    }.name("concatAll")
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
        return self |> mapAccumulate(initialValue, accumulateClosure)
    }
}


//--------------------------------------------------
// MARK: - Custom Operators
// + - * / % = < > ! & | ^ ~ .
//--------------------------------------------------

infix operator |> { associativity left precedence 95}

/// single-signal pipelining operator
public func |> <T, U>(signal: Signal<T>, transform: Signal<T> -> U) -> U
{
    return transform(signal)
}

/// array-signals pipelining operator
public func |> <T, U, S: SequenceType where S.Generator.Element == Signal<T>>(signals: S, transform: S -> U) -> U
{
    return transform(signals)
}

/// nested-signals pipelining operator
public func |> <T, U, S: SequenceType where S.Generator.Element == Signal<T>>(signals: S, transform: Signal<Signal<T>> -> U) -> U
{
    return transform(Signal(values: signals))
}

infix operator |>> { associativity left precedence 95}

/// signalProducer pipelining operator
public func |>> <T, U>(signalProducer: Void -> Signal<T>, transform: Signal<T> -> U) -> Void -> U
{
    return { transform(signalProducer()) }
}

public func |>> <T, U>(@autoclosure(escaping) signalProducer: Void -> Signal<T>, transform: Signal<T> -> U) -> Void -> U
{
    return { transform(signalProducer()) }
}

// NOTE: set precedence=255 to avoid "Operator is not a known binary operator" error
infix operator ~> { associativity left precedence 255 }

/// i.e. signal.react { ... }
public func ~> <T>(signal: Signal<T>, reactClosure: T -> Void) -> Signal<T>
{
    signal.react { value in reactClosure(value) }
    return signal
}

infix operator <~ { associativity right precedence 50 }

/// closure-first operator, reversing `signal.react { ... }`
/// e.g. ^{ ... } <~ signal
public func <~ <T>(reactClosure: T -> Void, signal: Signal<T>)
{
    signal.react { value in reactClosure(value) }
}

prefix operator ^ {}

/// Objective-C like 'block operator' to let Swift compiler know closure-type at start of the line
/// e.g. ^{ println($0) } <~ signal
public prefix func ^ <T, U>(closure: T -> U) -> (T -> U)
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
