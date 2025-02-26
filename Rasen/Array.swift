// Copyright 2025 Cii
//
// This file is part of Rasen.
//
// Rasen is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Rasen is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Rasen.  If not, see <http://www.gnu.org/licenses/>.

enum FirstOrLast: String, Codable {
    case first, last
}
extension FirstOrLast {
    var reversed: Self {
        switch self {
        case .first: .last
        case .last: .first
        }
    }
}
extension Array {
    var removedFirst: [Element] {
        var array = self
        _ = array.removeFirst()
        return array
    }
    var removedLast: [Element] {
        var array = self
        _ = array.removeLast()
        return array
    }
    
    mutating func remove(at indexes: [Int]) {
        for i in indexes.reversed() {
            remove(at: i)
        }
    }
    mutating func insert(_ ivs: [IndexValue<Element>]) {
        for iv in ivs {
            insert(iv.value, at: iv.index)
        }
    }
    mutating func replace(_ ivs: [IndexValue<Element>]) {
        for iv in ivs {
            self[iv.index] = iv.value
        }
    }
    subscript(firstOrLast: FirstOrLast) -> Element {
        get {
            switch firstOrLast {
            case .first: self[0]
            case .last: self[count - 1]
            }
        }
        set {
            switch firstOrLast {
            case .first: self[0] = newValue
            case .last: self[count - 1] = newValue
            }
        }
    }
    subscript(indexes: [Int]) -> [Element] {
        var ns = [Element]()
        ns.reserveCapacity(indexes.count)
        for i in indexes {
            ns.append(self[i])
        }
        return ns
    }
}
extension RangeReplaceableCollection where Element: Equatable {
    static func - (lhs: Self, rhs: Self) -> Self {
        var lhs = lhs
        for element in rhs {
            if let i = lhs.firstIndex(of: element) {
                lhs.remove(at: i)
            }
        }
        return lhs
    }
}

extension Sequence {
    func sum<Result>(_ nextPartialResult: (Element) throws -> Result)
    rethrows -> Result where Result: AdditiveArithmetic {
        try reduce(Result.zero) { $0 + (try nextPartialResult($1)) }
    }
}
extension Sequence where Element: AdditiveArithmetic {
    func sum() -> Element {
        reduce(.zero, +)
    }
}
extension RandomAccessCollection {
    func mean<Result>(_ nextPartialResult: (Element) throws -> Result)
    rethrows -> Result? where Result: FloatingPoint {
        isEmpty ? nil :
        (try reduce(Result.zero) { $0 + (try nextPartialResult($1)) })
        / Result(self.count)
    }
}
extension RandomAccessCollection where Element: FloatingPoint {
    func mean() -> Element? {
        isEmpty ? nil :
        reduce(.zero, +) / Element(self.count)
    }
    func median() -> Element {
        let v = self.sorted()
        return if v.count % 2 == 1 {
            v[(v.count - 1) / 2]
        } else {
            (v[(v.count / 2 - 1)] + v[v.count / 2]) / 2
        }
    }
}

struct Stack<Element> {
    private(set) var elements = [Element]()
}
extension Stack {
    init(minimumCapacity: Int) {
        elements.reserveCapacity(minimumCapacity)
    }
    mutating func push(_ e: Element) {
        elements.append(e)
    }
    mutating func pop() -> Element? {
        elements.popLast()
    }
    var isEmpty: Bool {
        elements.isEmpty
    }
    mutating func removeAll() {
        elements.removeAll()
    }
}

extension Array {
    init(capacity: Int) {
        self.init()
        reserveCapacity(capacity)
    }
    func maxValue<V: Comparable>(_ handler: (Element) -> (V)) -> V? {
        if let firstE = first {
            var maxV = handler(firstE)
            for i in 1 ..< count {
                let v = handler(self[i])
                if v > maxV {
                    maxV = v
                }
            }
            return maxV
        } else {
            return nil
        }
    }
    func minValue<V: Comparable>(_ handler: (Element) -> (V)) -> V? {
        if let firstE = first {
            var minV = handler(firstE)
            for i in 1 ..< count {
                let v = handler(self[i])
                if v < minV {
                    minV = v
                }
            }
            return minV
        } else {
            return nil
        }
    }
}

extension Array {
    init(capacityUninitialized capacity: Int) {
        let ptr = UnsafeMutablePointer<Element>.allocate(capacity: capacity)
        self = Array(UnsafeBufferPointer(start: ptr, count: capacity))
        ptr.deallocate()
    }
    
    func loop(fromLoop li: Int) -> ArraySlice<Element> {
        loop(from: li.loop(start: 0, end: count))
    }
    func loop(from i: Int) -> ArraySlice<Element> {
        self[i...] + self[..<i]
    }
    func loop(where predicate: (Self.Element) throws -> Bool) rethrows -> ArraySlice<Element> {
        if let i = try firstIndex(where: predicate) {
            self[i...] + self[..<i]
        } else {
            self[0...]
        }
    }
    func loopExtended(count nCount: Int) -> Self {
        if count == nCount {
            return self
        } else if count > nCount {
            return Array(self[..<nCount])
        } else {
            var ns = Self(capacity: nCount), i = 0
            for _ in 0 ..< nCount {
                ns.append(self[i])
                i = i + 1 < count ? i + 1 : 0
            }
            return ns
        }
    }
}

extension Dictionary where Value: Hashable {
    func swap() -> [Value: Key] {
        reduce(into: .init()) { $0[$1.value] = $1.key }
    }
}
