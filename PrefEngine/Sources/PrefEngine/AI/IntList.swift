import Foundation

/// Reference-type Int list mirroring Kotlin's MutableList<Int> in the AI.
/// The rasklad enumerators intentionally SHARE these lists between the
/// enumerator and the first enumerated rasklad; remove/restore cycles then
/// mutate them in place (and restore appends at the end, changing order).
/// A value-type array would silently break that behavior.
public final class IntList {
    public var items: [Int]

    public init(_ items: [Int] = []) {
        self.items = items
    }

    public var count: Int { items.count }
    public var isEmpty: Bool { items.isEmpty }

    public subscript(index: Int) -> Int {
        get { items[index] }
        set { items[index] = newValue }
    }

    public var first: Int? { items.first }
    public var last: Int? { items.last }

    public func contains(_ value: Int) -> Bool {
        items.contains(value)
    }

    public func append(_ value: Int) {
        items.append(value)
    }

    public func insert(_ value: Int, at index: Int) {
        items.insert(value, at: index)
    }

    /// Kotlin MutableList.remove(element): removes the first occurrence, returns success.
    @discardableResult
    public func removeValue(_ value: Int) -> Bool {
        if let idx = items.firstIndex(of: value) {
            items.remove(at: idx)
            return true
        }
        return false
    }

    public func removeAt(_ index: Int) {
        items.remove(at: index)
    }

    /// Snapshot copy for iteration (Kotlin `.toList()` / `.toMutableList()`).
    public func toArray() -> [Int] {
        items
    }

    public func copy() -> IntList {
        IntList(items)
    }
}

extension IntList: Sequence {
    public func makeIterator() -> IndexingIterator<[Int]> {
        items.makeIterator()
    }
}
