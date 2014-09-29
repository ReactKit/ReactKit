//
//  SecondViewController.swift
//  ReactKitDemo-iOS
//
//  Created by Yasuhiro Inami on 2014/09/19.
//  Copyright (c) 2014年 Yasuhiro Inami. All rights reserved.
//

import UIKit
import ReactKit

private let MIN_PASSWORD_LENGTH = 4

///
/// Original demo:
/// iOS - ReactiveCocoaをかじってみた - Qiita 
/// http://qiita.com/paming/items/9ac189ab0fe5b25fe722
///
class SecondViewController: UIViewController
{
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var emailTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var password2TextField: UITextField!
    
    @IBOutlet var messageLabel: UILabel!
    @IBOutlet var okButton: UIButton!
    
    var buttonEnablingSignal: Signal<NSNumber?>?
    var buttonEnablingSignal2: Signal<[AnyObject?]>?
    var errorMessagingSignal: Signal<NSString?>?
    var buttonTappedSignal: Signal<NSString?>?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self._setupViews()
        self._setupSignals()
    }
    
    func _setupViews()
    {
        self.messageLabel.text = ""
        self.okButton.enabled = false
    }
    
    func _setupSignals()
    {
        //--------------------------------------------------
        // Create Signals
        //--------------------------------------------------
        
        let usernameTextSignal = self.usernameTextField.textChangedSignal()
        let emailTextSignal = self.emailTextField.textChangedSignal()
        let passwordTextSignal = self.passwordTextField.textChangedSignal()
        let password2TextSignal = self.password2TextField.textChangedSignal()
        
        let anyTextSignal = Signal.any([usernameTextSignal, emailTextSignal, passwordTextSignal, password2TextSignal])
        
        // create button-enabling signal via any textField change
        self.buttonEnablingSignal = anyTextSignal.map { (values, changedValue) -> NSNumber? in
            
            let username: NSString? = values[0]?
            let email: NSString? = values[1]?
            let password: NSString? = values[2]?
            let password2: NSString? = values[3]?
            
            println("username=\(username), email=\(email), password=\(password), password2=\(password2)")
            
            // validation
            let buttonEnabled = username?.length > 0 && email?.length > 0 && password?.length >= MIN_PASSWORD_LENGTH && password? == password2?
            
            println("buttonEnabled = \(buttonEnabled)")
            
            return NSNumber(bool: buttonEnabled)    // NOTE: use NSNumber because KVO does not understand Bool
        }
        
        // create error-messaging signal via any textField change
        self.errorMessagingSignal = anyTextSignal.map { (values, changedValue) -> NSString? in
            
            let username: NSString? = values[0]?
            let email: NSString? = values[1]?
            let password: NSString? = values[2]?
            let password2: NSString? = values[3]?
            
            if username?.length <= 0 {
                return "Username is not set."
            }
            else if email?.length <= 0 {
                return "Email is not set."
            }
            else if password?.length < MIN_PASSWORD_LENGTH {
                return "Password requires at least \(MIN_PASSWORD_LENGTH) characters."
            }
            else if password? != password2? {
                return "Password is not same."
            }
        
            return nil
        }
        
        // create button-tapped signal via okButton
        self.buttonTappedSignal = self.okButton.buttonSignal("OK")
        
        //--------------------------------------------------
        // Signal callbacks on finished
        //--------------------------------------------------
        
        self.buttonEnablingSignal?.then { value, errorInfo -> Void in
            println("buttonEnablingSignal finished")
        }
        self.errorMessagingSignal?.then { value, errorInfo -> Void in
            println("errorMessagingSignal finished")
        }
        self.buttonTappedSignal?.then { value, errorInfo -> Void in
            println("buttonTappedSignal finished")
        }
        
        //--------------------------------------------------
        // Bind & React to Signals
        //--------------------------------------------------
        
        // REACT: enable/disable okButton
        (self.okButton, "enabled") <~ self.buttonEnablingSignal!
        
        // REACT: update error-message
        (self.messageLabel, "text") <~ self.errorMessagingSignal!
        
        // REACT: button tap
        self.buttonTappedSignal! ~> { [weak self] (value: NSString?) -> Void in
            if let self_ = self {
                if value == "OK" {
                    // release all signals when receiving "OK" signal
                    self_.buttonEnablingSignal = nil
                    self_.errorMessagingSignal = nil
                    self_.buttonTappedSignal = nil
                }
            }
        }
    }
}
