//
//  FirstViewController.swift
//  ReactKitDemo-iOS
//
//  Created by Yasuhiro Inami on 2014/09/19.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import UIKit
import ReactKit

class FirstViewController: UIViewController {

    @IBOutlet var textField: UITextField!
    @IBOutlet var pasteButton: UIButton!
    @IBOutlet var removeButton: UIButton!
    
    var textFieldSignal: Signal<NSString?>?
    var pasteButtonSignal: Signal<NSString?>?
    var removeButtonSignal: Signal<UIControl?>?
    var gestureSignal: Signal<NSString?>?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self._setupTextAndButtonSignals()
        self._setupGestures()
    }
    
    func _setupTextAndButtonSignals()
    {
        //--------------------------------------------------
        // Create Signals
        //--------------------------------------------------
        
        // create textField signal
        self.textFieldSignal = self.textField.textChangedSignal()
        
        // create pasteButton signal
        self.pasteButtonSignal = self.pasteButton.buttonSignal("\(NSDate())")
        
        // create pasteButton signal
        self.removeButtonSignal = self.removeButton.buttonSignal(nil)
        
        //--------------------------------------------------
        // Signal callbacks on finished
        //--------------------------------------------------
        
        self.textFieldSignal?.then { value, errorInfo -> Void in
            println("textFieldSignal finished")
        }
        
        //--------------------------------------------------
        // Bind & React to Signals
        //--------------------------------------------------
        
        // REACT
        ^{ println($0) } <~ self.textFieldSignal!
        
        // REACT
        (self.textField, "text") <~ self.pasteButtonSignal!
        
        // REACT
        self.removeButtonSignal! ~> { [weak self] _ in
            self?.textField?.removeFromSuperview()
            self?.textField = nil
            
            println("textField removed (textFieldSignal should be finished)")
        }
        
        //--------------------------------------------------
        // Experimental
        //--------------------------------------------------
        
//        // Store signals for 5 sec.
//        // After 5 sec has passed, signals will be deinited & bindings will be removed.
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5_000_000_000), dispatch_get_main_queue()) {
//            println("5sec has passed, removing all signals")
//            self.textFieldSignal = nil
//            self.pasteButtonSignal = nil
//            self.removeButtonSignal = nil
//        }
        
    }
    
    func _setupGestures()
    {
        let gesture = UITapGestureRecognizer()
        self.view.addGestureRecognizer(gesture)
        
        // create gesture signal
        self.gestureSignal = gesture.signal(state: .Ended) { sender -> NSString? in
            
            let gesture = sender as UITapGestureRecognizer
            let point = gesture.locationInView(gesture.view)
            return "Tapped at \(point)"
            
        }
        
        // REACT
        ^{ println($0) } <~ self.gestureSignal!
    }
}

