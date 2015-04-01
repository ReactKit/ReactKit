//
//  Stream+Conversion.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2015/01/08.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import Foundation
import SwiftTask

public extension Stream
{
    ///
    /// FIXME:
    /// Currently in Swift 1.1, `stream.asStream(U)` is only available
    /// when both `T` of `stream: Stream<T>` and `U` are non-Optional.
    /// Otherwise, "Swift dynamic cast failure" will occur (bug?).
    ///
    /// To work around this issue, use `map { $0 as U? }` directly
    /// to convert from `Stream<T?>` to `Stream<U?>` as follows:
    ///
    /// ```
    /// let stream: Stream<AnyObject?> = ...`
    /// let convertedStream: Stream<String?> = stream.map { $0 as String? }
    /// ```
    ///
    public func asStream<U>(type: U.Type) -> Stream<U>
    {
        return self |> map { $0 as! U }
    }
    
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