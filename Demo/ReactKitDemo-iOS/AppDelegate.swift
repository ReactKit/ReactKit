//
//  AppDelegate.swift
//  ReactKitDemo-iOS
//
//  Created by Yasuhiro Inami on 2014/09/19.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import UIKit
import ReactKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate
{
    var window: UIWindow?
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool
    {
        if let tabC = self.window?.rootViewController as? UITabBarController {
            tabC.selectedIndex = 1
        }
        
        return true
    }
}

