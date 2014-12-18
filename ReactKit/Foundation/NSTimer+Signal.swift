//
//  NSTimer+Signal.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/10/07.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import Foundation

public extension NSTimer
{
    public class func signal<T>(#timeInterval: NSTimeInterval, userInfo: AnyObject? = nil, repeats: Bool = true, map: NSTimer? -> T) -> Signal<T>
    {
        return Signal { progress, fulfill, reject, configure in
            
            let target = _TargetActionProxy { (self_: AnyObject?) in
                progress(map(self_ as? NSTimer))
            }
            
            var timer: NSTimer?
            
            let createTimer: Void -> NSTimer = {
                return NSTimer.scheduledTimerWithTimeInterval(timeInterval, target: target, selector: _targetActionSelector, userInfo: userInfo, repeats: repeats)
            }
            
            timer = createTimer()
            
            configure.pause = {
                timer?.invalidate()
                timer = nil
            }
            configure.resume = {
                timer = createTimer()
            }
            configure.cancel = {
                timer?.invalidate()
                timer = nil
            }
            
        }.name("\(NSStringFromClass(self))")
    }
}