//
//  ReactKit.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/09/11.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import SwiftTask

public class Stream<T>: Task<T, Void, NSError>
{
    public typealias Producer = Void -> Stream<T>
    
    public override var description: String
    {
        return "<\(self.name); state=\(self.state.rawValue)>"
    }
    
    ///
    /// Creates a new stream (event-delivery-pipeline over time).
    /// Synonym of "signal", "observable", etc.
    ///
    /// :param: initClosure Closure to define returning stream's behavior. Inside this closure, `configure.pause`/`resume`/`cancel` should capture inner logic (player) object. See also comment in `SwiftTask.Task.init()`.
    ///
    /// :returns: New Stream.
    /// 
    public init(initClosure: Task<T, Void, NSError>.InitClosure)
    {
        //
        // NOTE: 
        // - set `weakified = true` to avoid "(inner) player -> stream" retaining
        // - set `paused = true` for lazy evaluation (similar to "cold stream")
        //
        super.init(weakified: true, paused: true, initClosure: initClosure)
        
        self.name = "DefaultStream"
        
//        #if DEBUG
//            println("[init] \(self)")
//        #endif
    }
    
    deinit
    {
//        #if DEBUG
//            println("[deinit] \(self)")
//        #endif
        
        let cancelError = _RKError(.CancelledByDeinit, "Stream=\(self.name) is cancelled via deinit.")
        
        self.cancel(error: cancelError)
    }
    
    /// progress-chaining with auto-resume
    public func react(reactClosure: T -> Void) -> Self
    {
        let stream = super.progress { _, value in reactClosure(value) }
        self.resume()
        return self
    }
    
    // required (Swift compiler fails...)
    public override func cancel(error: NSError? = nil) -> Bool
    {
        return super.cancel(error: error)
    }
    
    /// Easy strong referencing by owner e.g. UIViewController holding its UI component's stream
    /// without explicitly defining stream as property.
    public func ownedBy(owner: NSObject) -> Stream<T>
    {
        var owninigStreams = owner._owninigStreams
        owninigStreams.append(self)
        owner._owninigStreams = owninigStreams
        
        return self
    }
    
}

/// helper method to bind downstream's `fulfill`/`reject`/`configure` handlers with upstream
private func _bindToUpstream<T>(upstream: Stream<T>, fulfill: (Void -> Void)?, reject: (NSError -> Void)?, configure: TaskConfiguration?)
{
    //
    // NOTE:
    // Bind downstream's `configure` to upstream
    // BEFORE performing its `progress()`/`then()`/`success()`/`failure()`
    // so that even when downstream **immediately finishes** on its 1st resume,
    // upstream can know `configure.isFinished = true`
    // while performing its `initClosure`.
    //
    // This is especially important for stopping immediate-infinite-sequence,
    // e.g. `infiniteStream.take(3)` will stop infinite-while-loop at end of 3rd iteration.
    //

    // NOTE: downstream should capture upstream
    if let configure = configure {
        let oldPause = configure.pause;
        configure.pause = { oldPause?(); upstream.pause(); return }
        
        let oldResume = configure.resume;
        configure.resume = { oldResume?(); upstream.resume(); return }
        
        let oldCancel = configure.cancel;
        configure.cancel = { oldCancel?(); upstream.cancel(); return }
    }
    
    if fulfill != nil || reject != nil {
        
        let streamName = upstream.name

        // fulfill/reject downstream on upstream-fulfill/reject/cancel
        upstream.then { value, errorInfo -> Void in
            
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
                    let cancelError = _RKError(.CancelledByUpstream, "Stream=\(streamName) is rejected or cancelled.")
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

public extension Stream
{
    /// creates once (progress once & fulfill) stream
    /// NOTE: this method can't move to other file due to Swift 1.1
    public class func once(value: T) -> Stream<T>
    {
        return Stream { progress, fulfill, reject, configure in
            progress(value)
            fulfill()
        }.name("Stream.once")
    }
    
    /// creates never (no progress & fulfill & reject) stream
    public class func never() -> Stream<T>
    {
        return Stream { progress, fulfill, reject, configure in
            // do nothing
        }.name("Stream.never")
    }
    
    /// creates empty (fulfilled without any progress) stream
    public class func fulfilled() -> Stream<T>
    {
        return Stream { progress, fulfill, reject, configure in
            fulfill()
        }.name("Stream.fulfilled")
    }
    
    /// creates error (rejected) stream
    public class func rejected(error: NSError) -> Stream<T>
    {
        return Stream { progress, fulfill, reject, configure in
            reject(error)
        }.name("Stream.rejected")
    }
    
    ///
    /// creates **synchronous** stream from SequenceType (e.g. Array) and fulfills at last,
    /// a.k.a `Rx.fromArray`
    ///
    /// - e.g. Stream.sequence([1, 2, 3])
    ///
    public class func sequence<S: SequenceType where S.Generator.Element == T>(values: S) -> Stream<T>
    {
        return Stream { progress, fulfill, reject, configure in
            for value in values {
                progress(value)
                
                if configure.isFinished { break }
            }
            fulfill()
        }.name("Stream.sequence")
    }
    
    ///
    /// creates **synchronous** stream which can send infinite number of values
    /// by using `initialValue` and `nextClosure`,
    /// a.k.a `Rx.generate`
    ///
    /// :Example:
    /// - `Stream.infiniteSequence(0) { $0 + 1 }` will emit 0, 1, 2, ...
    ///
    /// NOTE: To prevent infinite loop, use `take(maxCount)` to limit the number of value generation.
    ///
    public class func infiniteSequence(initialValue: T, nextClosure: T -> T) -> Stream<T>
    {
        let generator = _InfiniteGenerator<T>(initialValue: initialValue, nextClosure: nextClosure)
        return Stream<T>.sequence(SequenceOf({generator})).name("Stream.infiniteSequence")
    }
}

//--------------------------------------------------
// MARK: - Single Stream Operations
//--------------------------------------------------

/// useful for injecting side-effects
/// a.k.a Rx.do, tap
public func peek<T>(peekClosure: T -> Void)(upstream: Stream<T>) -> Stream<T>
{
    return Stream<T> { progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, fulfill, reject, configure)
        
        upstream.react { value in
            peekClosure(value)
            progress(value)
        }
        
    }.name("\(upstream.name)-peek")
}

/// creates your own customizable & method-chainable stream without writing `return Stream<U> { ... }`
public func customize<T, U>
    (customizeClosure: (upstream: Stream<T>, progress: Stream<U>.ProgressHandler, fulfill: Stream<U>.FulfillHandler, reject: Stream<U>.RejectHandler) -> Void)
    (upstream: Stream<T>)
-> Stream<U>
{
    return Stream<U> { progress, fulfill, reject, configure in
        _bindToUpstream(upstream, nil, nil, configure)
        customizeClosure(upstream: upstream, progress: progress, fulfill: fulfill, reject: reject)
    }.name("\(upstream.name)-customize")
}

// MARK: transforming

/// map using newValue only
public func map<T, U>(transform: T -> U)(upstream: Stream<T>) -> Stream<U>
{
    return Stream<U> { progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, fulfill, reject, configure)
        
        upstream.react { value in
            progress(transform(value))
        }
        
    }.name("\(upstream.name)-map")
}

/// map using newValue only & bind to transformed Stream
public func flatMap<T, U>(transform: T -> Stream<U>)(upstream: Stream<T>) -> Stream<U>
{
    return Stream<U> { progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, fulfill, reject, configure)
        
        // NOTE: each of `transformToStream()` needs to be retained outside
        var innerStreams: [Stream<U>] = []
        
        upstream.react { value in
            let innerStream = transform(value)
            innerStreams += [innerStream]
            
            innerStream.react { value in
                progress(value)
            }
        }

    }.name("\(upstream.name)-flatMap")
    
}

/// map using (oldValue, newValue)
public func map2<T, U>(transform2: (oldValue: T?, newValue: T) -> U)(upstream: Stream<T>) -> Stream<U>
{
    var oldValue: T?
    
    let stream = upstream |> map { (newValue: T) -> U in
        let mappedValue = transform2(oldValue: oldValue, newValue: newValue)
        oldValue = newValue
        return mappedValue
    }
    
    stream.name("\(upstream.name)-map2")
    
    return stream
}

// NOTE: Avoid using curried function. See comments in `startWith()`.
/// map using (accumulatedValue, newValue)
/// a.k.a `Rx.scan()`
public func mapAccumulate<T, U>(initialValue: U, accumulateClosure: (accumulatedValue: U, newValue: T) -> U) -> (upstream: Stream<T>) -> Stream<U>
{
    return { (upstream: Stream<T>) -> Stream<U> in
        return Stream<U> { progress, fulfill, reject, configure in
            
            _bindToUpstream(upstream, fulfill, reject, configure)
            
            var accumulatedValue: U = initialValue
            
            upstream.react { value in
                accumulatedValue = accumulateClosure(accumulatedValue: accumulatedValue, newValue: value)
                progress(accumulatedValue)
            }
            
        }.name("\(upstream.name)-mapAccumulate")
    }
}

public func buffer<T>(_ capacity: Int = Int.max)(upstream: Stream<T>) -> Stream<[T]>
{
    precondition(capacity >= 0)
    
    return Stream<[T]> { progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, nil, reject, configure)
        
        var buffer: [T] = []
        
        upstream.react { value in
            buffer += [value]
            if buffer.count >= capacity {
                progress(buffer)
                buffer = []
            }
        }.success { _ -> Void in
            if buffer.count > 0 {
                progress(buffer)
            }
            fulfill()
        }
        
    }.name("\(upstream.name)-buffer")
}

public func bufferBy<T, U>(triggerStream: Stream<U>)(upstream: Stream<T>) -> Stream<[T]>
{
    return Stream<[T]> { [weak triggerStream] progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, nil, reject, configure)
        
        var buffer: [T] = []
        
        upstream.react { value in
            buffer += [value]
        }.success { _ -> Void in
            progress(buffer)
            fulfill()
        }
        
        triggerStream?.react { [weak upstream] _ in
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

public func groupBy<T, Key: Hashable>(groupingClosure: T -> Key)(upstream: Stream<T>) -> Stream<(Key, Stream<T>)>
{
    return Stream<(Key, Stream<T>)> { progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, fulfill, reject, configure)
        
        var buffer: [Key : (stream: Stream<T>, progressHandler: Stream<T>.ProgressHandler)] = [:]
        
        upstream.react { value in
            let key = groupingClosure(value)
            
            if buffer[key] == nil {
                var progressHandler: Stream<T>.ProgressHandler?
                let innerStream = Stream<T> { p, _, _, _ in
                    progressHandler = p;    // steal progressHandler
                    return
                }
                innerStream.resume()    // resume to steal `progressHandler` immediately
                
                buffer[key] = (innerStream, progressHandler!) // set innerStream
                
                progress((key, buffer[key]!.stream) as (Key, Stream<T>))
            }
            
            buffer[key]!.progressHandler(value) // push value to innerStream
            
        }
        
    }.name("\(upstream.name)-groupBy")
}

// MARK: filtering

/// filter using newValue only
public func filter<T>(filterClosure: T -> Bool)(upstream: Stream<T>) -> Stream<T>
{
    return Stream<T> { progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, fulfill, reject, configure)
        
        upstream.react { value in
            if filterClosure(value) {
                progress(value)
            }
        }
        
    }.name("\(upstream.name)-filter")
}

/// filter using (oldValue, newValue)
public func filter2<T>(filterClosure2: (oldValue: T?, newValue: T) -> Bool)(upstream: Stream<T>) -> Stream<T>
{
    var oldValue: T?
    
    let stream = upstream |> filter { (newValue: T) -> Bool in
        let flag = filterClosure2(oldValue: oldValue, newValue: newValue)
        oldValue = newValue
        return flag
    }
    
    stream.name("\(upstream.name)-filter2")
    
    return stream
}

public func take<T>(maxCount: Int)(upstream: Stream<T>) -> Stream<T>
{
    return Stream<T> { progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, nil, reject, configure)
        
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

public func takeUntil<T, U>(triggerStream: Stream<U>)(upstream: Stream<T>) -> Stream<T>
{
    return Stream<T> { [weak triggerStream] progress, fulfill, reject, configure in
        
        if let triggerStream = triggerStream {
            
            _bindToUpstream(upstream, fulfill, reject, configure)
            
            upstream.react { value in
                progress(value)
            }

            let cancelError = _RKError(.CancelledByTriggerStream, "Stream=\(upstream.name) is cancelled by takeUntil(\(triggerStream.name)).")
            
            triggerStream.react { [weak upstream] _ in
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
            let cancelError = _RKError(.CancelledByTriggerStream, "Stream=\(upstream.name) is cancelled by takeUntil() with `triggerStream` already been deinited.")
            upstream.cancel(error: cancelError)
        }
        
    }.name("\(upstream.name)-takeUntil")
}

public func skip<T>(skipCount: Int)(upstream: Stream<T>) -> Stream<T>
{
    return Stream<T> { progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, fulfill, reject, configure)
        
        var count = 0
        
        upstream.react { value in
            count++
            if count <= skipCount { return }
            
            progress(value)
        }
        
    }.name("\(upstream.name)-skip(\(skipCount))")
}

public func skipUntil<T, U>(triggerStream: Stream<U>)(upstream: Stream<T>) -> Stream<T>
{
    return Stream<T> { [weak triggerStream] progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, fulfill, reject, configure)
        
        var shouldSkip = true
        
        upstream.react { value in
            if !shouldSkip {
                progress(value)
            }
        }
        
        if let triggerStream = triggerStream {
            triggerStream.react { _ in
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

public func sample<T, U>(triggerStream: Stream<U>)(upstream: Stream<T>) -> Stream<T>
{
    return Stream<T> { [weak triggerStream] progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, fulfill, reject, configure)
        
        var lastValue: T?
        
        upstream.react { value in
            lastValue = value
        }
        
        if let triggerStream = triggerStream {
            triggerStream.react { _ in
                if let lastValue = lastValue {
                    progress(lastValue)
                }
            }
        }
        
    }
}

public func distinct<H: Hashable>(upstream: Stream<H>) -> Stream<H>
{
    return Stream<H> { progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, fulfill, reject, configure)
        
        var usedValueHashes = Set<H>()
        
        upstream.react { value in
            if !usedValueHashes.contains(value) {
                usedValueHashes.insert(value)
                progress(value)
            }
        }
        
    }
}

public func distinctUntilChanged<E: Equatable>(upstream: Stream<E>) -> Stream<E>
{
    let stream = upstream |> filter2 { $0 != $1 }
    return stream.name("\(upstream.name)-distinctUntilChanged")
}

// MARK: combining

public func merge<T>(stream: Stream<T>)(upstream: Stream<T>) -> Stream<T>
{
    return upstream |> merge([stream])
}

public func merge<T>(streams: [Stream<T>])(upstream: Stream<T>) -> Stream<T>
{
    let stream = (streams + [upstream]) |> mergeInner
    return stream.name("\(upstream.name)-merge")
}

public func concat<T>(nextStream: Stream<T>)(upstream: Stream<T>) -> Stream<T>
{
    return upstream |> concat([nextStream])
}

public func concat<T>(nextStreams: [Stream<T>])(upstream: Stream<T>) -> Stream<T>
{
    let stream = ([upstream] + nextStreams) |> concatInner
    return stream.name("\(upstream.name)-concat")
}

//
// NOTE:
// Avoid using curried function since `initialValue` seems to get deallocated at uncertain timing
// (especially for T as value-type e.g. String, but also occurs a little in reference-type e.g. NSString).
// Make sure to let `initialValue` be captured by closure explicitly.
//
/// `concat()` initialValue first
public func startWith<T>(initialValue: T) -> (upstream: Stream<T>) -> Stream<T>
{
    return { (upstream: Stream<T>) -> Stream<T> in
        precondition(upstream.state == .Paused)
        
        let stream = [Stream.once(initialValue), upstream] |> concatInner
        return stream.name("\(upstream.name)-startWith")
    }
}
//public func startWith<T>(initialValue: T)(upstream: Stream<T>) -> Stream<T>
//{
//    let stream = [Stream.once(initialValue), upstream] |> concatInner
//    return stream.name("\(upstream.name)-startWith")
//}

public func combineLatest<T>(stream: Stream<T>)(upstream: Stream<T>) -> Stream<[T]>
{
    return upstream |> combineLatest([stream])
}

public func combineLatest<T>(streams: [Stream<T>])(upstream: Stream<T>) -> Stream<[T]>
{
    let stream = ([upstream] + streams) |> combineLatestAll
    return stream.name("\(upstream.name)-combineLatest")
}

public func zip<T>(stream: Stream<T>)(upstream: Stream<T>) -> Stream<[T]>
{
    return upstream |> zip([stream])
}

public func zip<T>(streams: [Stream<T>])(upstream: Stream<T>) -> Stream<[T]>
{
    let stream = ([upstream] + streams) |> zipAll
    return stream.name("\(upstream.name)-zip")
}

public func catch<T>(catchHandler: Stream<T>.ErrorInfo -> Stream<T>) -> (upstream: Stream<T>) -> Stream<T>
{
    return { (upstream: Stream<T>) -> Stream<T> in
        return Stream<T> { progress, fulfill, reject, configure in
            
            // required for avoiding "swiftc failed with exit code 1" in Swift 1.2 (Xcode 6.3)
            let configure = configure
            
            upstream.react { value in
                progress(value)
            }.failure { errorInfo in
                let recoveryStream = catchHandler(errorInfo)
                
                _bindToUpstream(recoveryStream, fulfill, reject, configure)
                
                recoveryStream.react { value in
                    progress(value)
                }
            }
        }
    }
}

// MARK: timing

/// delay `progress` and `fulfill` for `timerInterval` seconds
public func delay<T>(timeInterval: NSTimeInterval)(upstream: Stream<T>) -> Stream<T>
{
    return Stream<T> { progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, nil, reject, configure)
        
        upstream.react { value in
            var timerStream: Stream<Void>? = NSTimer.stream(timeInterval: timeInterval, repeats: false) { _ in }
            
            timerStream!.react { _ in
                progress(value)
                timerStream = nil
            }
        }.success { _ -> Void in
            var timerStream: Stream<Void>? = NSTimer.stream(timeInterval: timeInterval, repeats: false) { _ in }
            
            timerStream!.react { _ in
                fulfill()
                timerStream = nil
            }
        }
        
    }.name("\(upstream.name)-delay(\(timeInterval))")
}

/// delay `progress` and `fulfill` for `timerInterval * eachProgressCount` seconds 
/// (incremental delay with start at t = 0sec)
public func interval<T>(timeInterval: NSTimeInterval)(upstream: Stream<T>) -> Stream<T>
{
    return Stream<T> { progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, nil, reject, configure)
        
        var incInterval = 0.0
        
        upstream.react { value in
            var timerStream: Stream<Void>? = NSTimer.stream(timeInterval: incInterval, repeats: false) { _ in }
            
            incInterval += timeInterval
            
            timerStream!.react { _ in
                progress(value)
                timerStream = nil
            }
        }.success { _ -> Void in
            
            incInterval -= timeInterval - 0.01
            
            var timerStream: Stream<Void>? = NSTimer.stream(timeInterval: incInterval, repeats: false) { _ in }
            
            timerStream!.react { _ in
                fulfill()
                timerStream = nil
            }
        }
        
    }.name("\(upstream.name)-interval(\(timeInterval))")
}

/// limit continuous progress (reaction) for `timeInterval` seconds when first progress is triggered
/// (see also: underscore.js throttle)
public func throttle<T>(timeInterval: NSTimeInterval)(upstream: Stream<T>) -> Stream<T>
{
    return Stream<T> { progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, fulfill, reject, configure)
        
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
public func debounce<T>(timeInterval: NSTimeInterval)(upstream: Stream<T>) -> Stream<T>
{
    return Stream<T> { progress, fulfill, reject, configure in
        
        _bindToUpstream(upstream, fulfill, reject, configure)
        
        var timerStream: Stream<Void>? = nil    // retained by upstream via upstream.react()
        
        upstream.react { value in
            // NOTE: overwrite to deinit & cancel old timerStream
            timerStream = NSTimer.stream(timeInterval: timeInterval, repeats: false) { _ in }
            
            timerStream!.react { _ in
                progress(value)
            }
        }
        
    }.name("\(upstream.name)-debounce(\(timeInterval))")
}

// MARK: collecting

public func reduce<T, U>(initialValue: U, accumulateClosure: (accumulatedValue: U, newValue: T) -> U)(upstream: Stream<T>) -> Stream<U>
{
    return Stream<U> { progress, fulfill, reject, configure in
        
        let accumulatingStream = upstream
            |> mapAccumulate(initialValue, accumulateClosure)
        
        _bindToUpstream(accumulatingStream, nil, nil, configure)
        
        var lastAccValue: U = initialValue   // last accumulated value
        
        accumulatingStream.react { value in
            lastAccValue = value
        }.then { value, errorInfo -> Void in
            if value != nil {
                progress(lastAccValue)
                fulfill()
            }
            else if let errorInfo = errorInfo {
                if let error = errorInfo.error {
                    reject(error)
                }
                else {
                    let cancelError = _RKError(.CancelledByUpstream, "Upstream is cancelled before performing `reduce()`.")
                    reject(cancelError)
                }
            }
        }
        
    }.name("\(upstream.name)-reduce")
}

//--------------------------------------------------
// MARK: - Array Streams Operations
//--------------------------------------------------

/// Merges multiple streams into single stream.
/// See also: mergeInner
public func mergeAll<T>(streams: [Stream<T>]) -> Stream<T>
{
    let stream = Stream.sequence(streams) |> mergeInner
    return stream.name("mergeAll")
}

///
/// Merges multiple streams into single stream,
/// combining latest values `[T?]` as well as changed value `T` together as `([T?], T)` tuple.
///
/// This is a generalized method for `Rx.merge()` and `Rx.combineLatest()`.
///
public func merge2All<T>(streams: [Stream<T>]) -> Stream<(values: [T?], changedValue: T)>
{
    return Stream { progress, fulfill, reject, configure in
        
        configure.pause = {
            Stream<T>.pauseAll(streams)
        }
        configure.resume = {
            Stream<T>.resumeAll(streams)
        }
        configure.cancel = {
            Stream<T>.cancelAll(streams)
        }
        
        var states = [T?](count: streams.count, repeatedValue: nil)
        
        for i in 0..<streams.count {
            
            let stream = streams[i]
            
            stream.react { value in
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
                        let error = _RKError(.CancelledByInternalStream, "One of stream is cancelled in `merge2All()`.")
                        reject(error)
                    }
                }
            }
        }
        
    }.name("merge2All")
}

public func combineLatestAll<T>(streams: [Stream<T>]) -> Stream<[T]>
{
    let stream = merge2All(streams)
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
    
    return stream.name("combineLatestAll")
}

public func zipAll<T>(streams: [Stream<T>]) -> Stream<[T]>
{
    precondition(streams.count > 1)
    
    return Stream<[T]> { progress, fulfill, reject, configure in
        
        configure.pause = {
            Stream<T>.pauseAll(streams)
        }
        configure.resume = {
            Stream<T>.resumeAll(streams)
        }
        configure.cancel = {
            Stream<T>.cancelAll(streams)
        }
        
        let streamCount = streams.count

        var storedValuesArray: [[T]] = []
        for i in 0..<streamCount {
            storedValuesArray.append([])
        }
        
        for i in 0..<streamCount {
            
            streams[i].react { value in
                
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
                    
                    for i in 0..<streamCount {
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
// MARK: - Nested Stream Operations
//--------------------------------------------------

///
/// Merges multiple streams into single stream.
///
/// - e.g. `let mergedStream = [stream1, stream2, ...] |> mergeInner`
///
/// NOTE: This method is conceptually equal to `streams |> merge2All(streams) |> map { $1 }`.
///
public func mergeInner<T>(nestedStream: Stream<Stream<T>>) -> Stream<T>
{
    return Stream<T> { progress, fulfill, reject, configure in
        
        // NOTE: don't bind nestedStream's fulfill with returning mergeInner-stream's fulfill
        _bindToUpstream(nestedStream, nil, reject, configure)
        
        nestedStream.react { (innerStream: Stream<T>) in
            
            _bindToUpstream(innerStream, nil, nil, configure)

            innerStream.react { value in
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
                        let error = _RKError(.CancelledByInternalStream, "One of stream is cancelled in `mergeInner()`.")
                        reject(error)
                    }
                }
            }
        }
        
    }.name("mergeInner")
}

/// fixed-point combinator
private func _fix<T, U>(f: (T -> U) -> T -> U) -> T -> U
{
    return { f(_fix(f))($0) }
}

public func concatInner<T>(nestedStream: Stream<Stream<T>>) -> Stream<T>
{
    return Stream<T> { progress, fulfill, reject, configure in
        
        _bindToUpstream(nestedStream, nil, reject, configure)
        
        var pendingInnerStreams = [Stream<T>]()
        
        let performRecursively: Void -> Void = _fix { recurse in
            return {
                if let innerStream = pendingInnerStreams.first {
                    if pendingInnerStreams.count == 1 {
                        _bindToUpstream(innerStream, nil, nil, configure)
                        
                        innerStream.react { value in
                            progress(value)
                        }.success {
                            pendingInnerStreams.removeAtIndex(0)
                            recurse()
                        }.failure { errorInfo -> Void in
                            if let error = errorInfo.error {
                                reject(error)
                            }
                            else {
                                let error = _RKError(.CancelledByInternalStream, "One of stream is cancelled in `concatInner()`.")
                                reject(error)
                            }
                        }
                    }
                }
            }
        }
        
        nestedStream.react { (innerStream: Stream<T>) in
            pendingInnerStreams += [innerStream]
            performRecursively()
        }
        
    }.name("concatInner")
}

/// uses the latest innerStream and cancels previous innerStreams
/// a.k.a Rx.switchLatest
public func switchLatestInner<T>(nestedStream: Stream<Stream<T>>) -> Stream<T>
{
    return Stream<T> { progress, fulfill, reject, configure in
        
        _bindToUpstream(nestedStream, nil, reject, configure)
        
        var currentInnerStream: Stream<T>?
        
        nestedStream.react { (innerStream: Stream<T>) in
            
            _bindToUpstream(innerStream, nil, nil, configure)
            
            currentInnerStream?.cancel()
            currentInnerStream = innerStream
            
            innerStream.react { value in
                progress(value)
            }
        }
        
    }.name("switchLatestInner")
}

//--------------------------------------------------
// MARK: - Stream Producer Operations
//--------------------------------------------------

///
/// Creates an upstream from `upstreamProducer`, resumes it (prestart),
/// and caches its emitted values (`capacity` as max buffer count) for future "replay"
/// when returning streamProducer creates a new stream & resumes it,
/// a.k.a. Rx.replay().
///
/// NOTE: `downstream`'s `pause()`/`resume()`/`cancel()` will not affect `upstream`.
///
/// :Usage:
///     let cachedStreamProducer = networkStream |>> prestart(capacity: 1)
///     let cachedStream1 = cachedStreamProducer()
///     cachedStream1 ~> { ... }
///     let cachedStream2 = cachedStreamProducer() // can produce many cached streams
///     ...
///
/// :param: capacity max buffer count for prestarted stream
///
public func prestart<T>(capacity: Int = Int.max) -> (upstreamProducer: Stream<T>.Producer) -> Stream<T>.Producer
{
    return { (upstreamProducer: Stream<T>.Producer) -> Stream<T>.Producer in
        
        var buffer = [T]()
        let upstream = upstreamProducer()
        
        // REACT
        upstream ~> { value in
            buffer += [value]
            while buffer.count > capacity {
                buffer.removeAtIndex(0)
            }
        }
        
        return {
            return Stream<T> { progress, fulfill, reject, configure in
                
                // NOTE: downstream's `configure` should not bind to upstream
                _bindToUpstream(upstream, fulfill, reject, nil)
                
                for b in buffer {
                    progress(b)
                }
                
                upstream.react { value in
                    progress(value)
                }
                
            }.name("\(upstream.name)-prestart")
        }
    }
}

public func repeat<T>(repeatCount: Int) -> (upstreamProducer: Stream<T>.Producer) -> Stream<T>.Producer
{
    return { (upstreamProducer: Stream<T>.Producer) -> Stream<T>.Producer in
        
        if repeatCount <= 0 {
            return { Stream.empty() }
        }
        if repeatCount == 1 {
            return upstreamProducer
        }
        
        return {
            
            let upstreamName = upstreamProducer().name
            
            return Stream<T> { progress, fulfill, reject, configure in
                
                var countDown = repeatCount
                
                let performRecursively: Void -> Void = _fix { recurse in
                    return {
                        let upstream = upstreamProducer()
                        
                        _bindToUpstream(upstream, nil, reject, configure)
                        
                        upstream.react { value in
                            progress(value)
                        }.success { _ -> Void in
                            countDown--
                            countDown > 0 ? recurse() : fulfill()
                        }
                    }
                }
                
                performRecursively()
                
            }.name("\(upstreamName)-repeat")
        }
    }
}

public func retry<T>(retryCount: Int)(upstreamProducer: Stream<T>.Producer) -> Stream<T>.Producer
{
    precondition(retryCount >= 0)
    
    if retryCount == 0 {
        return upstreamProducer
    }
    else {
        return upstreamProducer |>> catch { _ -> Stream<T> in
            return (upstreamProducer |>> retry(retryCount - 1))()
        }
    }
}

//--------------------------------------------------
/// MARK: - Rx Semantics
/// (TODO: move to new file, but doesn't work in Swift 1.1. ERROR = ld: symbol(s) not found for architecture x86_64)
//--------------------------------------------------

public extension Stream
{
    /// alias for `Stream.fulfilled()`
    public class func just(value: T) -> Stream<T>
    {
        return self.once(value)
    }
    
    /// alias for `Stream.fulfilled()`
    public class func empty() -> Stream<T>
    {
        return self.fulfilled()
    }
    
    /// alias for `Stream.rejected()`
    public class func error(error: NSError) -> Stream<T>
    {
        return self.rejected(error)
    }
}

/// alias for `mapAccumulate()`
public func scan<T, U>(initialValue: U, accumulateClosure: (accumulatedValue: U, newValue: T) -> U)(upstream: Stream<T>) -> Stream<U>
{
    return mapAccumulate(initialValue, accumulateClosure)(upstream: upstream)
}

/// alias for `prestart()`
public func replay<T>(capacity: Int = Int.max) -> (upstreamProducer: Stream<T>.Producer) -> Stream<T>.Producer
{
    return prestart(capacity: capacity)
}

//--------------------------------------------------
// MARK: - Custom Operators
// + - * / % = < > ! & | ^ ~ .
//--------------------------------------------------

// MARK: |> (stream pipelining)

infix operator |> { associativity left precedence 95}

/// single-stream pipelining operator
public func |> <T, U>(stream: Stream<T>, transform: Stream<T> -> Stream<U>) -> Stream<U>
{
    return transform(stream)
}

/// array-streams pipelining operator
public func |> <T, U, S: SequenceType where S.Generator.Element == Stream<T>>(streams: S, transform: S -> Stream<U>) -> Stream<U>
{
    return transform(streams)
}

/// nested-streams pipelining operator
public func |> <T, U, S: SequenceType where S.Generator.Element == Stream<T>>(streams: S, transform: Stream<Stream<T>> -> Stream<U>) -> Stream<U>
{
    return transform(Stream.sequence(streams))
}

/// stream-transform pipelining operator
public func |> <T, U, V>(transform1: Stream<T> -> Stream<U>, transform2: Stream<U> -> Stream<V>) -> Stream<T> -> Stream<V>
{
    return { transform2(transform1($0)) }
}

// MARK: |>> (streamProducer pipelining)

infix operator |>> { associativity left precedence 95}

/// streamProducer lifting & pipelining operator
public func |>> <T, U>(streamProducer: Stream<T>.Producer, transform: Stream<T> -> Stream<U>) -> Stream<U>.Producer
{
    return { transform(streamProducer()) }
}

/// streamProducer(autoclosured) lifting & pipelining operator
public func |>> <T, U>(@autoclosure(escaping) streamProducer: Stream<T>.Producer, transform: Stream<T> -> Stream<U>) -> Stream<U>.Producer
{
    return { transform(streamProducer()) }
}

/// streamProducer pipelining operator
public func |>> <T, U>(streamProducer: Stream<T>.Producer, transform: Stream<T>.Producer -> Stream<U>.Producer) -> Stream<U>.Producer
{
    return transform(streamProducer)
}

/// streamProducer(autoclosured) pipelining operator
public func |>> <T, U>(@autoclosure(escaping) streamProducer: Stream<T>.Producer, transform: Stream<T>.Producer -> Stream<U>.Producer) -> Stream<U>.Producer
{
    return transform(streamProducer)
}

/// streamProducer-transform pipelining operator
public func |>> <T, U, V>(transform1: Stream<T>.Producer -> Stream<U>.Producer, transform2: Stream<U>.Producer -> Stream<V>.Producer) -> Stream<T>.Producer -> Stream<V>.Producer
{
    return { transform2(transform1($0)) }
}

// MARK: ~> (right reacting operator)

// NOTE: `infix operator ~>` is already declared in Swift
//infix operator ~> { associativity left precedence 255 }

/// right-closure reacting operator, i.e. `stream.react { ... }`
public func ~> <T>(stream: Stream<T>, reactClosure: T -> Void) -> Stream<T>
{
    stream.react(reactClosure)
    return stream
}

// MARK: ~> (left reacting operator)

infix operator <~ { associativity right precedence 50 }

/// left-closure (closure-first) reacting operator, reversing `stream.react { ... }`
/// e.g. ^{ ... } <~ stream
public func <~ <T>(reactClosure: T -> Void, stream: Stream<T>) -> Stream<T>
{
    return stream ~> reactClosure
}

// MARK: ~>! (terminal reacting operator)

infix operator ~>! { associativity left precedence 50 }

///
/// terminal reacting operator, which returns synchronously-emitted last value
/// to gain similar functionality as Java 8's Stream API,
///
/// e.g. 
/// let sum = Stream.sequence([1, 2, 3]) |> reduce(0) { $0 + $1 } ~>! ()
/// let distinctSequence = Stream.sequence([1, 2, 2, 3]) |> distinct |> buffer() ~>! () // NOTE: use `buffer()` whenever necessary
///
public func ~>! <T>(stream: Stream<T>, void: Void) -> T!
{
    var ret: T!
    stream.react { value in
        ret = value
    }
    return ret
}

/// terminal reacting operator (less precedence for '~>')
public func ~>! <T>(stream: Stream<T>, reactClosure: T -> Void)
{
    stream ~> reactClosure
}

prefix operator ^ {}

/// Objective-C like 'block operator' to let Swift compiler know closure-type at start of the line
/// e.g. ^{ println($0) } <~ stream
public prefix func ^ <T, U>(closure: T -> U) -> (T -> U)
{
    return closure
}

prefix operator + {}

/// short-living operator for stream not being retained
/// e.g. ^{ println($0) } <~ +KVO.stream(obj1, "value")
public prefix func + <T>(stream: Stream<T>) -> Stream<T>
{
    var holder: Stream<T>? = stream
    
    // let stream be captured by dispatch_queue to guarantee its lifetime until next runloop
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue()) {    // on main-thread
        holder = nil
    }
    
    return stream
}

//--------------------------------------------------
// MARK: - Utility
//--------------------------------------------------

private struct _InfiniteGenerator<T>: GeneratorType
{
    let initialValue: T
    let nextClosure: T -> T
    
    var currentValue: T?
    
    init(initialValue: T, nextClosure: T -> T)
    {
        self.initialValue = initialValue
        self.nextClosure = nextClosure
    }
    
    mutating func next() -> T?
    {
        if let currentValue = self.currentValue {
            self.currentValue = self.nextClosure(currentValue)
        }
        else {
            self.currentValue = self.initialValue
        }
        
        return self.currentValue
    }
}
