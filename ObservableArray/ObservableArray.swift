//
//  ObservableArray.swift
//  ObservableArray
//
//  Created by Safx Developer on 2015/02/19.
//  Copyright (c) 2016 Safx Developers. All rights reserved.
//  Copyright (c) 2017 HANAI Tohru. All rights reserved.
//

import Foundation
import RxSwift

public struct ArrayChangeEvent<Element> {
    public let inserted: ArraySlice<Element>
    public let removed: [Element]
    public let updated: ArraySlice<Element>

    fileprivate init(inserted: ArraySlice<Element> = [], removed: [Element] = [], updated: ArraySlice<Element> = []) {
        assert(0 < inserted.count + removed.count + updated.count)
        self.inserted = inserted
        self.removed = removed
        self.updated = updated
    }
}

public struct ObservableArray<Element>: ExpressibleByArrayLiteral {
    public typealias EventType = ArrayChangeEvent<Element>

    internal var eventSubject: PublishSubject<EventType>!
    internal var elementsSubject: BehaviorSubject<[Element]>!
    internal var elements: [Element]

    public init() {
        self.elements = []
    }

    public init(count:Int, repeatedValue: Element) {
        self.elements = Array(repeating: repeatedValue, count: count)
    }

    public init<S : Sequence>(_ s: S) where S.Iterator.Element == Element {
        self.elements = Array(s)
    }

    public init(arrayLiteral elements: Element...) {
        self.elements = elements
    }
}

extension ObservableArray {
    public mutating func rx_elements() -> Observable<[Element]> {
        if elementsSubject == nil {
            self.elementsSubject = BehaviorSubject<[Element]>(value: self.elements)
        }
        return elementsSubject
    }

    public mutating func rx_events() -> Observable<EventType> {
        if eventSubject == nil {
            self.eventSubject = PublishSubject<EventType>()
        }
        return eventSubject
    }

    fileprivate func arrayDidChange(_ event: EventType) {
        elementsSubject?.onNext(elements)
        eventSubject?.onNext(event)
    }
}

extension ObservableArray: Collection {
    public var capacity: Int {
        return elements.capacity
    }

    /*public var count: Int {
        return elements.count
    }*/

    public var startIndex: Int {
        return elements.startIndex
    }

    public var endIndex: Int {
        return elements.endIndex
    }

    public func index(after i: Int) -> Int {
        return elements.index(after: i)
    }
}

extension ObservableArray: MutableCollection {
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        elements.reserveCapacity(minimumCapacity)
    }

    public mutating func append(_ newElement: Element) {
        elements.append(newElement)
        arrayDidChange(ArrayChangeEvent(inserted: [newElement]))
    }

    public mutating func append<S : Sequence>(contentsOf newElements: S) where S.Iterator.Element == Element {
        let end = elements.count
        elements.append(contentsOf: newElements)
        let count = elements.count - end
        if 0 < count {
            arrayDidChange(ArrayChangeEvent(inserted: elements.suffix(count)))
        }
    }

    public mutating func appendContentsOf<C : Collection>(_ newElements: C) where C.Iterator.Element == Element {
        guard !newElements.isEmpty else {
            return
        }
        let end = elements.count
        elements.append(contentsOf: newElements)
        let count = elements.count - end
        if 0 < count {
            arrayDidChange(ArrayChangeEvent(inserted: elements.suffix(count)))
        }
    }

    public mutating func removeLast() -> Element {
        let e = elements.removeLast()
        arrayDidChange(ArrayChangeEvent(removed: [e]))
        return e
    }

    public mutating func insert(_ newElement: Element, at i: Int) {
        elements.insert(newElement, at: i)
        arrayDidChange(ArrayChangeEvent(inserted: elements[i..<i + 1]))
    }

    public mutating func remove(at index: Int) -> Element {
        let e = elements.remove(at: index)
        arrayDidChange(ArrayChangeEvent(removed: [e]))
        return e
    }

    public mutating func removeAll(_ keepCapacity: Bool = false) {
        guard !elements.isEmpty else {
            return
        }
        let es = elements
        elements.removeAll(keepingCapacity: keepCapacity)
        arrayDidChange(ArrayChangeEvent(removed: es))
    }

    public mutating func insertContentsOf(_ newElements: [Element], atIndex i: Int) {
        guard !newElements.isEmpty else {
            return
        }
        elements.insert(contentsOf: newElements, at: i)
        arrayDidChange(ArrayChangeEvent(inserted: elements[i..<i + newElements.count]))
    }

    public mutating func popLast() -> Element? {
        let e = elements.popLast()
        if e != nil {
            arrayDidChange(ArrayChangeEvent(removed: [e!]))
        }
        return e
    }
}

extension ObservableArray: RangeReplaceableCollection {
    public mutating func replaceSubrange<C : Collection>(_ subRange: Range<Int>, with newCollection: C) where C.Iterator.Element == Element {
        let removed = Array(elements[subRange.lowerBound..<subRange.upperBound])
        let oldCount = elements.count
        elements.replaceSubrange(subRange, with: newCollection)
        let insertedCount = (elements.count - oldCount) + removed.count
        if 0 < insertedCount {
            arrayDidChange(ArrayChangeEvent(inserted: elements[subRange.lowerBound..<subRange.lowerBound + insertedCount],
                                            removed: removed))
        } else if 0 < removed.count {
            arrayDidChange(ArrayChangeEvent(removed: removed))
        }
    }
}

extension ObservableArray: CustomDebugStringConvertible {
    public var description: String {
        return elements.description
    }
}

extension ObservableArray: CustomStringConvertible {
    public var debugDescription: String {
        return elements.debugDescription
    }
}

extension ObservableArray: Sequence {

    public subscript(index: Int) -> Element {
        get {
            return elements[index]
        }
        set {
            elements[index] = newValue
            if index == elements.count {
                arrayDidChange(ArrayChangeEvent(inserted: elements[index..<index + 1]))
            } else {
                arrayDidChange(ArrayChangeEvent(updated: [newValue]))
            }
        }
    }

    public subscript(bounds: Range<Int>) -> ArraySlice<Element> {
        get {
            return elements[bounds]
        }
        set {
            return replaceSubrange(bounds, with: newValue)
        }
    }
}
