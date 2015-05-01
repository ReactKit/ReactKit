//
//  Error.swift
//  ReactKit
//
//  Created by Yasuhiro Inami on 2014/12/02.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import Foundation

public let ReactKitErrorDomain = "ReactKitErrorDomain"

public protocol ErrorType
{
    static func cancelledError(message: String?) -> Self
}

extension NSError: ErrorType
{
    public class func cancelledError(message: String?) -> Self
    {
        return self(
            domain: ReactKitErrorDomain,
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey : message ?? "Stream is cancelled."
            ]
        )
    }
}

public struct DefaultError: ErrorType
{
    public static func cancelledError(message: String?) -> DefaultError
    {
        return self()
    }
}