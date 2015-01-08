//
//  Error.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/12/02.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import Foundation

public enum ReactKitError: Int
{
    public static let Domain = "ReactKitErrorDomain"
    
    case Cancelled = 0
    case CancelledByDeinit = 1
    case CancelledByUpstream = 2
    case CancelledByTriggerSignal = 3
    case CancelledByInternalSignal = 4
    
    case RejectedByInternalTask = 1000
}

/// helper
internal func _RKError(error: ReactKitError, localizedDescriptionKey: String) -> NSError
{
    return NSError(
        domain: ReactKitError.Domain,
        code: error.rawValue,
        userInfo: [
            NSLocalizedDescriptionKey : localizedDescriptionKey
        ]
    )
}