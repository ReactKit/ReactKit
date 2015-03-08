//
//  ArrayKVOTests.swift
//  ReactKitTests
//
//  Created by Yasuhiro Inami on 2015/03/07.
//  Copyright (c) 2015年 Yasuhiro Inami. All rights reserved.
//

import ReactKit
import SwiftTask
import XCTest

/// `mutableArrayValueForKey()` test
class ArrayKVOTests: _TestCase
{
    func testArrayKVO()
    {
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        let obj2 = MyObject()
        let obj3 = MyObject()
        
        // NOTE: by using `mutableArrayValueForKey()`, this signal will send each changed values **separately**
        let obj1ArrayChangedSignal = KVO.signal(obj1, "array")
        
        let obj1ArraySignal = obj1ArrayChangedSignal.map { _ -> AnyObject? in obj1.array }
        
        let obj1ArrayChangedCountSignal = obj1ArrayChangedSignal
            .mapAccumulate(0, { c, _ in c + 1 })    // count up
            .map { $0 as NSNumber? }    // .asSignal(NSNumber?)
        
        // REACT: obj1.array ~> obj2.array (only sends changed values in `obj1.array`)
        (obj2, "array") <~ obj1ArrayChangedSignal
        
        // REACT: obj1.array ~> obj3.array (sends whole `obj1.array`)
        (obj3, "array") <~ obj1ArraySignal
        
        // REACT: arrayChangedCount ~> obj3.number (for counting)
        (obj3, "number") <~ obj1ArrayChangedCountSignal
        
        // REACT: obj1.array ~> println
        ^{ println("[REACT] new array = \($0)") } <~ obj1ArrayChangedSignal
        
        // NOTE: call `mutableArrayValueForKey()` after `<~` binding (KVO-addObserver) is ready
        let obj1ArrayProxy = obj1.mutableArrayValueForKey("array")
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.array.count, 0)
        XCTAssertEqual(obj2.array.count, 0)
        XCTAssertEqual(obj3.array.count, 0)
        XCTAssertEqual(obj3.number, 0)
        
        self.perform {
            
            obj1ArrayProxy.addObject("a")
            XCTAssertEqual(obj1.array, ["a"])
            XCTAssertEqual(obj2.array, ["a"])
            XCTAssertEqual(obj3.array, obj1.array)
            XCTAssertEqual(obj3.number, 1)
            
            obj1ArrayProxy.addObject("b")
            XCTAssertEqual(obj1.array, ["a", "b"])
            XCTAssertEqual(obj2.array, ["b"], "`obj2.array` should be replaced to last-changed value `b`.")
            XCTAssertEqual(obj3.array, obj1.array)
            XCTAssertEqual(obj3.number, 2)
            
            // adding multiple values at once
            // (NOTE: `obj1ArrayChangedSignal` will send each values separately)
            obj1ArrayProxy.addObjectsFromArray(["c", "d"])
            XCTAssertEqual(obj1.array, ["a", "b", "c", "d"])
            XCTAssertEqual(obj2.array, ["d"], "`obj2.array` will be replaced to `c` then `d`, so it should be replaced to last-changed value `d`.")
            XCTAssertEqual(obj3.array, obj1.array)
            XCTAssertEqual(obj3.number, 4, "`obj3.number` should count number of changed elements up to `4` (not `3` in this case).")
            
            expect.fulfill()
            
        }
        
        self.wait()
    }

    func testArrayKVO_detailedSignal()
    {
        // NOTE: this is non-async test
        if self.isAsync { return }
        
        let expect = self.expectationWithDescription(__FUNCTION__)
        
        let obj1 = MyObject()
        
        let detailedSignal = KVO.detailedSignal(obj1, "array")  // NOTE: detailedSignal
        
        var lastValue: NSArray?
        var lastChange: NSKeyValueChange?
        var lastIndexSet: NSIndexSet?
        var reactedCount = 0
        
        // REACT
        detailedSignal ~> { (value: AnyObject?, change: NSKeyValueChange, indexSet: NSIndexSet?) in
            
            // NOTE: change in `mutableArrayValueForKey()` will always send `value` as NSArray
            let array = value as? NSArray
            
            println("[REACT] new value = \(array), change=\(change), indexSet=\(indexSet)")
            
            lastValue = array
            lastChange = change
            lastIndexSet = indexSet
            reactedCount++
        }
        
        // NOTE: call `mutableArrayValueForKey()` after `<~` binding (KVO-addObserver) is ready
        let obj1ArrayProxy = obj1.mutableArrayValueForKey("array")
        
        println("*** Start ***")
        
        XCTAssertEqual(obj1.array.count, 0)
        XCTAssertEqual(reactedCount, 0)
        
        self.perform {
            
            var indexSet: NSMutableIndexSet
            
            // addObject
            obj1ArrayProxy.addObject(1)
            XCTAssertEqual(lastValue!, [1])
            XCTAssertTrue(lastChange! == .Insertion)
            XCTAssertTrue(lastIndexSet!.isEqualToIndexSet(NSIndexSet(index: 0)))
            XCTAssertEqual(lastValue!, [1])
            XCTAssertEqual(reactedCount, 1)
            
            // addObject (once more)
            obj1ArrayProxy.addObject(2)
            XCTAssertEqual(lastValue!, [2])
            XCTAssertTrue(lastChange! == .Insertion)
            XCTAssertTrue(lastIndexSet!.isEqualToIndexSet(NSIndexSet(index: 1)))
            XCTAssertEqual(reactedCount, 2)
            
            // addObjectsFromArray
            obj1ArrayProxy.addObjectsFromArray([3, 4])
            XCTAssertEqual(lastValue!, [4], "Only last added value `4` should be set.")
            XCTAssertTrue(lastChange! == .Insertion)
            XCTAssertTrue(lastIndexSet!.isEqualToIndexSet(NSIndexSet(index: 3)))
            XCTAssertEqual(reactedCount, 4, "`mutableArrayValueForKey().addObjectsFromArray()` will send `3` then `4` **separately** to signal, so `reactedCount` should be incremented as +2.")
            
            // check array
            XCTAssertTrue(obj1.array.isEqualToArray([1, 2, 3, 4]))
            
            // insertObject
            obj1ArrayProxy.insertObject(0, atIndex: 0)
            XCTAssertEqual(lastValue!, [0])
            XCTAssertTrue(lastChange! == .Insertion)
            XCTAssertTrue(lastIndexSet!.isEqualToIndexSet(NSIndexSet(index: 0)))
            XCTAssertEqual(reactedCount, 5)
            
            // prepare indexSet = [1, 3]
            indexSet = NSMutableIndexSet(index: 1)
            indexSet.addIndex(3)
            
            // insertObjects
            obj1ArrayProxy.insertObjects([0.5, 1.5], atIndexes: indexSet)
            XCTAssertEqual(lastValue!, [0.5, 1.5])
            XCTAssertTrue(lastChange! == .Insertion)
            XCTAssertTrue(lastIndexSet!.isEqualToIndexSet(indexSet))
            XCTAssertEqual(reactedCount, 6, "`mutableArrayValueForKey().insertObjects()` will send `0.5` & `1.5` **together** to signal, so `reactedCount` should be incremented as +1.")
            
            // check array
            XCTAssertTrue(obj1.array.isEqualToArray([0, 0.5, 1, 1.5, 2, 3, 4]))
            
            // replaceObjectAtIndex
            obj1ArrayProxy.replaceObjectAtIndex(4, withObject: 2.5)
            XCTAssertEqual(lastValue!, [2.5])
            XCTAssertTrue(lastChange! == .Replacement)
            XCTAssertTrue(lastIndexSet!.isEqualToIndexSet(NSIndexSet(index: 4)))
            XCTAssertEqual(reactedCount, 7)
            
            // prepare indexSet = [5, 6]
            indexSet = NSMutableIndexSet(index: 5)
            indexSet.addIndex(6)
            
            // replaceObjectsAtIndexes
            obj1ArrayProxy.replaceObjectsAtIndexes(indexSet, withObjects: [3.5, 4.5])
            XCTAssertEqual(lastValue!, [3.5, 4.5])
            XCTAssertTrue(lastChange! == .Replacement)
            XCTAssertTrue(lastIndexSet!.isEqualToIndexSet(indexSet))
            XCTAssertEqual(reactedCount, 8)
            
            // check array
            XCTAssertTrue(obj1.array.isEqualToArray([0, 0.5, 1, 1.5, 2.5, 3.5, 4.5]))
            
            // removeObjectAtIndex
            obj1ArrayProxy.removeObjectAtIndex(6)
            XCTAssertNil(lastValue, "lastValue should be nil (deleting element `4.5`).")
            XCTAssertTrue(lastChange! == .Removal)
            XCTAssertTrue(lastIndexSet!.isEqualToIndexSet(NSIndexSet(index: 6)))
            XCTAssertEqual(reactedCount, 9)
            
            // prepare indexSet = [0, 2]
            indexSet = NSMutableIndexSet(index: 0)
            indexSet.addIndex(2)
            
            // removeObjectsAtIndexes
            obj1ArrayProxy.removeObjectsAtIndexes(indexSet)
            XCTAssertNil(lastValue, "lastValue should be nil (deleting element `0` & `1`).")
            XCTAssertTrue(lastChange! == .Removal)
            XCTAssertTrue(lastIndexSet!.isEqualToIndexSet(indexSet))
            XCTAssertEqual(reactedCount, 10)
            
            // check array
            XCTAssertTrue(obj1.array.isEqualToArray([0.5, 1.5, 2.5, 3.5]))
            
            // exchangeObjectAtIndex
            obj1ArrayProxy.exchangeObjectAtIndex(1, withObjectAtIndex: 2)   // replaces `index = 1` then `index = 2`
            XCTAssertEqual(lastValue!, [1.5], "Only last replaced value `1.5` should be set.")
            XCTAssertTrue(lastChange! == .Replacement)
            XCTAssertTrue(lastIndexSet!.isEqualToIndexSet(NSIndexSet(index: 2)))
            XCTAssertEqual(reactedCount, 12, "`mutableArrayValueForKey().exchangeObjectAtIndex()` will send `2.5` (replacing at index=1) then `1.5` (replacing at index=2) **separately** to signal, so `reactedCount` should be incremented as +2.")
            
            // check array
            XCTAssertTrue(obj1.array.isEqualToArray([0.5, 2.5, 1.5, 3.5]))
            
            // sortUsingComparator
            obj1ArrayProxy.sortUsingComparator { (element1, element2) -> NSComparisonResult in
                return (element2 as NSNumber).compare(element1 as NSNumber)
            }
            XCTAssertEqual(lastValue!, [0.5], "Only last replaced value `0.5` should be set.")
            XCTAssertTrue(lastChange! == .Replacement)
            XCTAssertTrue(lastIndexSet!.isEqualToIndexSet(NSIndexSet(index: 3)))
            XCTAssertEqual(reactedCount, 16, "`mutableArrayValueForKey().sortUsingComparator()` will send all sorted values **separately** to signal, so `reactedCount` should be incremented as number of elements i.e. +4.")
            
            // check array
            XCTAssertTrue(obj1.array.isEqualToArray([3.5, 2.5, 1.5, 0.5]))
            
            expect.fulfill()
            
        }
        
        self.wait()
    }
    
}

class AsyncArrayKVOTests: KVOTests
{
    override var isAsync: Bool { return true }
}