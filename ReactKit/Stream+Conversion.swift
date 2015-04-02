//
//  Stream+Conversion.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2015/01/08.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import Foundation
import SwiftTask

/// converts Stream<T> to Stream<U>
public func asStream<T, U>(type: U.Type)(upstream: Stream<T>) -> Stream<U>
{
    let stream = upstream |> map { $0 as! U }
    stream.name("\(upstream.name)-asStream(\(type))")
    return stream
}

/// converts Stream<T> to Stream<U?>
public func asStream<T, U>(type: U?.Type)(upstream: Stream<T>) -> Stream<U?>
{
    let stream = upstream |> map { $0 as? U }
    stream.name("\(upstream.name)-asStream(\(type))")
    return stream
}

public extension Stream
{
    //--------------------------------------------------
    /// MARK: - From SwiftTask
    //--------------------------------------------------
    
    ///
    /// Converts `Task<P, V, E>` to `Stream<V>`.
    ///
    /// Task's fulfilled-value (`task.value`) will be interpreted as stream's progress-value (`stream.progress`),
    /// and any task's progress-values (`task.progress`) will be discarded.
    ///
    public class func fromTask<P, V, E>(task: Task<P, V, E>) -> Stream<V>
    {
        return Stream<V> { progress, fulfill, reject, configure in
            
            task.then { value, errorInfo -> Void in
                if let value = value {
                    progress(value)
                    fulfill()
                }
                else if let errorInfo = errorInfo {
                    if let error = errorInfo.error as? NSError {
                        reject(error)
                    }
                    else {
                        let error = _RKError(.RejectedByInternalTask, "`task` is rejected/cancelled while `Stream.fromTask(task)`.")
                        reject(error)
                    }
                }
            }
            
            configure.pause = {
                task.pause()
                return
            }
            configure.resume = {
                task.resume()
                return
            }
            configure.cancel = {
                task.cancel()
                return
            }
            
        }.name("Stream.fromTask")
    }
    
    ///
    /// Converts `Task<P, V, E>` to `Stream<(P?, V?)>`.
    ///
    /// Both task's progress-values (`task.progress`) and fulfilled-value (`task.value`) 
    /// will be interpreted as stream's progress-value (`stream.progress`),
    /// so unlike `Stream.fromTask(_:)`, all `task.progress` will NOT be discarded.
    ///
    public class func fromProgressTask<P, V, E>(task: Task<P, V, E>) -> Stream<(P?, V?)>
    {
        return Stream<(P?, V?)> { progress, fulfill, reject, configure in
            
            task.progress { [weak task] _, progressValue in
                
                progress(progressValue, nil)
                
            }.then { [weak task] value, errorInfo -> Void in
                
                if let value = value {
                    progress(task!.progress, value)
                    fulfill()
                }
                else if let errorInfo = errorInfo {
                    if let error = errorInfo.error as? NSError {
                        reject(error)
                    }
                    else {
                        let error = _RKError(.RejectedByInternalTask, "`task` is rejected/cancelled while `Stream.fromProgressTask(task)`.")
                        reject(error)
                    }
                }
            }
            
            configure.pause = {
                task.pause()
                return
            }
            configure.resume = {
                task.resume()
                return
            }
            configure.cancel = {
                task.cancel()
                return
            }
            
        }.name("Stream.fromProgressTask")
    }
}