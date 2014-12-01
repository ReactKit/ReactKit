ReactKit
========

Swift Reactive Programming.


## Example

(For UI Demo, please see [ReactKit/ReactKitCatalog](https://github.com/ReactKit/ReactKitCatalog))

### Key-Value Observing

```swift
// create signal via KVO
self.obj1Signal = KVO.signal(obj1, "value")

// bind signal via KVC (<~ as binding operator)
(obj2, "value") <~ self.obj1Signal

XCTAssertEqual(obj1.value, "initial")
XCTAssertEqual(obj2.value, "initial")

obj1.value = "REACT"

XCTAssertEqual(obj1.value, "REACT")
XCTAssertEqual(obj2.value, "REACT")
```

To remove signal-bindings, just release `signal` itself.

```swift
self.obj1Signal = nil   // release signal & its bindings

obj1.value = "Done"

XCTAssertEqual(obj1.value, "Done")
XCTAssertEqual(obj2.value, "REACT")
```

### NSNotification

```swift
self.signal = Notification.signal("MyNotification", obj1).map { notification -> NSString? in
    return "hello" // convert NSNotification? to NSString?
}

(obj2, "value") <~ self.signal
```

Normally, `NSNotification` itself is useless value for binding with other objects, so use [signal-operations](#signal-operations) e.g. `map(f: T -> U)` to convert it.

### Target-Action

```swift
// UIButton
self.buttonSignal = self.button.buttonSignal("OK")

// UITextField
self.textFieldSignal = self.textField.textChangedSignal()

^{ println($0) } <~ self.buttonSignal     // prints "OK" on tap

// NOTE: ^{ ... } = closure-first operator, same as `signal ~> { ... }`
^{ println($0) } <~ self.textFieldSignal  // prints textField.text on change
```

### Complex example

The example below is taken from

- [iOS - ReactiveCocoaをかじってみた - Qiita](http://qiita.com/paming/items/9ac189ab0fe5b25fe722) (well-illustrated)

where it describes 4 `UITextField`s which enables/disables `UIButton` at certain condition:

```swift
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

    // validation
    let buttonEnabled = username?.length > 0 && email?.length > 0 && password?.length >= MIN_PASSWORD_LENGTH && password? == password2?

    // NOTE: use NSNumber because KVO does not understand Bool
    return NSNumber(bool: buttonEnabled)
}

// REACT: enable/disable okButton
(self.okButton, "enabled") <~ self.buttonEnablingSignal!
```

For more examples, please see XCTest & Demo App.


## How it works

ReactKit is just a bunch of Cocoa helpers over powerful [SwiftTask](https://github.com/inamiy/SwiftTask) (Promise library) as a basis.

By taking special care of retaining flow, `ReactKit.Signal<T>` will seamlessly become a subclass of `SwiftTask.Task<T, T, NSError?>`, and by using `task.progress()` interface (`<~` operator in ReactKit), `signal` will be able to send the underlying Cocoa events (KVO, NSNotification, etc) continuously over time.

Also, because `signal` can also behave like Promise, it can be chained by `then()` to connect asynchronous tasks in series, so there are much less codes & methods to remember comparing to our great pioneer framework [ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa).


## Signal Operations

- Instance Methods
	- `filter(f: T -> Bool)`
	- `map(f: T -> U)`
	- `mapTuple(f: (T?, T) -> U)`
	- `take(maxCount)`
	- `takeUntil(signal)`
	- `throttle(timeInterval)`
	- `debounce(timeInterval)`
- Class Methods
	- `any(signals)`


## Licence

[MIT](https://github.com/inamiy/ReactKit/blob/master/LICENSE)
