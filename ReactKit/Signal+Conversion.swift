//
//  Signal+Conversion.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2015/01/08.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import Foundation
import SwiftTask

public extension Signal
{
    public func asSignal<U>(type: U.Type) -> Signal<U>
    {
        return self.map { $0 as U }
    }
    
    ///
    /// Converts `Task<P, V, E>` to `Signal<V>`.
    ///
    /// Task's fulfilled-value (`task.value`) will be interpreted as signal's progress-value (`signal.progress`),
    /// and any task's progress-values (`task.progress`) will be discarded.
    ///
    public class func fromTask<P, V, E>(task: Task<P, V, E>) -> Signal<V>
    {
        return Signal<V> { progress, fulfill, reject, configure in
            
            task.then { value, errorInfo -> Void in
                if let value = value {
                    progress(value)
                    fulfill(value)
                }
                else if let errorInfo = errorInfo {
                    if let error = errorInfo.error as? NSError {
                        reject(error)
                    }
                    else {
                        let error = _RKError(.RejectedByInternalTask, "`task` is rejected/cancelled while `Signal.fromTask(task)`.")
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
        }
    }
    
    ///
    /// Converts `Task<P, V, E>` to `Signal<(P?, V?)>`.
    ///
    /// Both task's progress-values (`task.progress`) and fulfilled-value (`task.value`) 
    /// will be interpreted as signal's progress-value (`signal.progress`),
    /// so unlike `Signal.fromTask(_:)`, all `task.progress` will NOT be discarded.
    ///
    public class func fromProgressTask<P, V, E>(task: Task<P, V, E>) -> Signal<(P?, V?)>
    {
        return Signal<(P?, V?)> { progress, fulfill, reject, configure in
            
            task.progress { [weak task] _, progressValue in
                
                progress(progressValue, nil)
                
            }.then { [weak task] value, errorInfo -> Void in
                
                if let value = value {
                    progress(task!.progress, value)
                    fulfill(task!.progress, value)
                }
                else if let errorInfo = errorInfo {
                    if let error = errorInfo.error as? NSError {
                        reject(error)
                    }
                    else {
                        let error = _RKError(.RejectedByInternalTask, "`task` is rejected/cancelled while `Signal.fromProgressTask(task)`.")
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
        }
    }
    
}