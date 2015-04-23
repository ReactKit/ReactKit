<img src="https://avatars3.githubusercontent.com/u/8986128" width="36" height="36"> ReactKit
========

Swift Reactive Programming.

#### Ver 0.10.0 Changelog (2015/04/23)

- [x] Rename `Signal<T>` to `Stream<T>`
- [x] Rename Stream-operations e.g. `merge`, `mergeAll`, `mergeInner` & always use `**All` (stream-array) and `**Inner` (nested-stream) naming conventions
- [x] Add stream pipe operator `|>` and stream-producer pipe operator `|>>` in replace of dot-method-chaining syntax.
- [x] Add many useful Stream operations (e.g. `distinct`). 

This is a **breaking change**.
See [#26](https://github.com/ReactKit/ReactKit/pull/26) and [Ver 0.10.0 Release Notes](https://github.com/ReactKit/ReactKit/releases/tag/0.10.0) for more information.


## How to install

See [Wiki page](https://github.com/ReactKit/ReactKit/wiki/How-to-install).


## Example

For UI Demo, please see [ReactKit/ReactKitCatalog](https://github.com/ReactKit/ReactKitCatalog).

### Key-Value Observing

```swift
// create stream via KVO
self.obj1Stream = KVO.stream(obj1, "value")

// bind stream via KVC (`<~` as binding operator)
(obj2, "value") <~ self.obj1Stream

XCTAssertEqual(obj1.value, "initial")
XCTAssertEqual(obj2.value, "initial")

obj1.value = "REACT"

XCTAssertEqual(obj1.value, "REACT")
XCTAssertEqual(obj2.value, "REACT")
```

To remove stream-bindings, just release `stream` itself (or call `stream.cancel()`).

```swift
self.obj1Stream = nil   // release stream & its bindings

obj1.value = "Done"

XCTAssertEqual(obj1.value, "Done")
XCTAssertEqual(obj2.value, "REACT")
```

If you want to observe changes in `Swift.Array` or `NSMutableArray`,
use `DynamicArray` feature in [Pull Request #23](https://github.com/ReactKit/ReactKit/pull/23).

### NSNotification

```swift
self.stream = Notification.stream("MyNotification", obj1)
    |> map { notification -> NSString? in
        return "hello" // convert NSNotification? to NSString?
    }

(obj2, "value") <~ self.stream
```

Normally, `NSNotification` itself is useless value for binding with other objects, so use [Stream Operations](#stream-operations) e.g. `map(f: T -> U)` to convert it.

To understand more about `|>` pipelining operator, see [Stream Pipelining](#stream-pipelining).

### Target-Action

```swift
// UIButton
self.buttonStream = self.button.buttonStream("OK")

// UITextField
self.textFieldStream = self.textField.textChangedStream()

^{ println($0) } <~ self.buttonStream     // prints "OK" on tap

// NOTE: ^{ ... } = closure-first operator, same as `stream ~> { ... }`
^{ println($0) } <~ self.textFieldStream  // prints textField.text on change
```

### Complex example

The example below is taken from

- [iOS - ReactiveCocoaをかじってみた - Qiita](http://qiita.com/paming/items/9ac189ab0fe5b25fe722) (well-illustrated)

where it describes 4 `UITextField`s which enables/disables `UIButton` at certain condition (demo available in [ReactKit/ReactKitCatalog](https://github.com/ReactKit/ReactKitCatalog)):

```swift
let usernameTextStream = self.usernameTextField.textChangedStream()
let emailTextStream = self.emailTextField.textChangedStream()
let passwordTextStream = self.passwordTextField.textChangedStream()
let password2TextStream = self.password2TextField.textChangedStream()

let allTextStreams = [usernameTextStream, emailTextStream, passwordTextStream, password2TextStream]

let combinedTextStream = allTextStreams |> merge2All

// create button-enabling stream via any textField change
self.buttonEnablingStream = combinedTextStream
    |> map { (values, changedValue) -> NSNumber? in

        let username: NSString? = values[0] ?? nil
        let email: NSString? = values[1] ?? nil
        let password: NSString? = values[2] ?? nil
        let password2: NSString? = values[3] ?? nil

        // validation
        let buttonEnabled = username?.length > 0 && email?.length > 0 && password?.length >= MIN_PASSWORD_LENGTH && password == password2

        // NOTE: use NSNumber because KVO does not understand Bool
        return NSNumber(bool: buttonEnabled)
    }

// REACT: enable/disable okButton
(self.okButton, "enabled") <~ self.buttonEnablingStream!
```

For more examples, please see XCTestCases.


## How it works

ReactKit is based on powerful [SwiftTask](https://github.com/ReactKit/SwiftTask) (JavaScript Promise-like) library, allowing to start & deliver multiple events (KVO, NSNotification, Target-Action, etc) continuously over time using its **resume & progress** feature (`react()` or `<~` operator in ReactKit).

Unlike [Reactive Extensions (Rx)](https://github.com/Reactive-Extensions) libraries which has a basic concept of "hot" and "cold" [observables](http://reactivex.io/documentation/observable.html), ReactKit gracefully integrated them into one **hot + paused (lazy) stream** `Stream<T>` class. Lazy streams will be auto-resumed via `react()` & `<~` operator.

Here are some differences in architecture:

| | Reactive Extensions (Rx) | ReactKit |
|:---:|:---:|:---:|
| Basic Classes | Hot Observable (broadcasting)<br>Cold Observable (laziness) | `Stream<T>` |
| Generating | Cold Observable (cloneability) | `Void -> Stream<T>`<br>(= `Stream<T>.Producer`) |
| Subscribing | `observable.subscribe(onNext, onError, onComplete)` | `stream.react {...}.then {...}`<br>(method-chainable) |
| Pausing | `pausableObservable.pause()` | `stream.pause()` |
| Disposing | `disposable.dispose()` | `stream.cancel()` |

### Stream Pipelining

Streams can be composed by using `|>` **stream-pipelining operator** and [Stream Operations](#stream-operations).

For example, a very common [incremental search technique](http://en.wikipedia.org/wiki/Incremental_search) using `searchTextStream` will look like this:

```
let searchResultsStream: Stream<[Result]> = searchTextStream
    |> debounce(0.3)
    |> distinctUntilChanged
    |> map { text -> Stream<[Result]> in
        return API.getSearchResultsStream(text)
    }
    |> switchLatestInner
```

There are some scenarios (e.g. `repeat()`) when you want to use a cloneable `Stream<T>.Producer` (`Void -> Stream<T>`) rather than plain `Stream<T>`. In this case, you can use `|>>` **streamProducer-pipelining operator** instead.

```
// first, wrap stream with closure
let timerProducer: Void -> Stream<Int> = {
    return createTimerStream(interval: 1)
        |> map { ... }
        |> filter { ... }
}

// then, use `|>>`  (streamProducer-pipelining operator)
let repeatTimerProducer = timerProducer |>> repeat(3)
```

But in the above case, wrapping with closure will always become cumbersome, so you can also use `|>>` operator for `Stream` & [Stream Operations](#stream-operations) as well (thanks to `@autoclosure`).

```
let repeatTimerProducer = createTimerStream(interval: 1)
    |>> map { ... }
    |>> filter { ... }
    |>> repeat(3)
```


## Functions

### Stream Operations

- For Single Stream
  - Transforming
    - `asStream(ValueType)`
    - `map(f: T -> U)`
    - `flatMap(f: T -> Stream<U>)`
    - `map2(f: (old: T?, new: T) -> U)`
    - `mapAccumulate(initialValue, accumulator)` (alias: `scan`)
    - `buffer(count)`
    - `bufferBy(stream)`
    - `groupBy(classifier: T -> Key)`
  - Filtering
    - `filter(f: T -> Bool)`
    - `filter2(f: (old: T?, new: T) -> Bool)`
    - `take(count)`
    - `takeUntil(stream)`
    - `skip(count)`
    - `skipUntil(stream)`
    - `sample(stream)`
    - `distinct()`
    - `distinctUntilChanged()`
  - Combining
    - `merge(stream)`
    - `concat(stream)`
    - `startWith(initialValue)`
    - `combineLatest(stream)`
    - `zip(stream)`
    - `catch(stream)`
  - Timing
    - `delay(timeInterval)`
    - `interval(timeInterval)`
    - `throttle(timeInterval)`
    - `debounce(timeInterval)`
  - Collecting
    - `reduce(initialValue, accumulator)`
  - Other Utilities
    - `peek(f: T -> Void)` (for injecting side effects e.g. debug-logging)
    - `customize(...)`

- For Array Streams
  - `mergeAll(streams)`
  - `merge2All(streams)` (generalized method for `mergeAll` & `combineLatestAll`)
  - `combineLatestAll(streams)`
  - `zipAll(streams)`

- For Nested Stream (`Stream<Stream<T>>`)
  - `mergeInner(nestedStream)`
  - `concatInner(nestedStream)`
  - `switchLatestInner(nestedStream)`

- For Stream Producer (`Void -> Stream<T>`)
  - `prestart(bufferCapacity)` (alias: `replay`)
  - `repeat(count)`
  - `retry(count)`

### Helpers

- Creating
  - `Stream.once(value)` (alias: `just`)
  - `Stream.never()`
  - `Stream.fulfilled()` (alias: `empty`)
  - `Stream.rejected()` (alias: `error`)
  - `Stream.sequence(values)` (a.k.a Rx.fromArray)
  - `Stream.infiniteSequence(initialValue, iterator)` (a.k.a Rx.iterate)

- Other Utilities
  - `ownedBy(owner: NSObject)` (easy strong referencing to keep streams alive)


## Dependencies

- [SwiftTask](https://github.com/ReactKit/SwiftTask)


## References

- [Introducing ReactKit // Speaker Deck](https://speakerdeck.com/inamiy/introducing-reactkit) (ver 0.3.0)


## Licence

[MIT](https://github.com/ReactKit/ReactKit/blob/master/LICENSE)
