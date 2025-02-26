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

extension Comparable {
    func clipped(min minV: Self, max maxV: Self) -> Self {
        self < minV ?
        minV :
        (self > maxV ? maxV : self)
    }
    func clipped(_ range: ClosedRange<Self>) -> Self {
        self < range.lowerBound ?
        range.lowerBound :
        (self > range.upperBound ? range.upperBound : self)
    }
}
extension Range {
    func intersects(_ other: Self) -> Bool {
        if self == other {
            true
        } else {
            other.upperBound > lowerBound
            && other.lowerBound < upperBound
        }
    }
    func intersection(_ other: Self) -> Self? {
        let minV = Swift.max(lowerBound, other.lowerBound)
        let maxV = Swift.min(upperBound, other.upperBound)
        return minV < maxV ? minV ..< maxV : nil
    }
    func formUnion(_ other: Self) -> Self {
        let minV = Swift.min(lowerBound, other.lowerBound)
        let maxV = Swift.max(upperBound, other.upperBound)
        return minV ..< maxV
    }
}
extension Range where Bound: SignedNumeric {
    init(start: Bound, length: Bound) {
        self = start ..< (start + length)
    }
    var start: Bound {
        get { lowerBound }
        set { self = newValue ..< (newValue + length) }
    }
    var end: Bound {
        get { upperBound }
        set { self = lowerBound ..< newValue }
    }
    var length: Bound {
        get { upperBound - lowerBound }
        set { self = lowerBound ..< (lowerBound + newValue) }
    }
    static func + (lhs: Self, rhs: Bound) -> Self {
        (lhs.lowerBound + rhs) ..< (lhs.upperBound + rhs)
    }
    static func += (lhs: inout Self, rhs: Bound) {
        lhs = lhs + rhs
    }
    static func - (lhs: Self, rhs: Bound) -> Self {
        lhs + (-rhs)
    }
    static func -= (lhs: inout Self, rhs: Bound) {
        lhs = lhs - rhs
    }
    
    static func union(_ bRange: Self, in aRanges: inout [Self]) {
        var removeIs = [Int](), bRange = bRange
        for (i, aRange) in aRanges.enumerated() {
            if aRange.intersects(bRange) || aRange.start == bRange.end || aRange.end == bRange.start {
                if aRange.start < bRange.start {
                    bRange.start = aRange.start
                }
                if aRange.end > bRange.end {
                    bRange.start = aRange.start
                }
                removeIs.append(i)
            }
        }
        aRanges.remove(at: removeIs)
        aRanges.append(bRange)
        aRanges.sort { $0.start < $1.start }
    }
}
extension ClosedRange where Bound: SignedNumeric {
    init(start: Bound, length: Bound) {
        self = start ... (start + length)
    }
    var start: Bound {
        get { lowerBound }
        set { self = newValue ... (newValue + length) }
    }
    var end: Bound {
        get { upperBound }
        set { self = lowerBound ... newValue }
    }
    var length: Bound {
        get { upperBound - lowerBound }
        set { self = lowerBound ... (lowerBound + newValue) }
    }
    static func + (lhs: Self, rhs: Bound) -> Self {
        (lhs.lowerBound + rhs) ... (lhs.upperBound + rhs)
    }
    static func += (lhs: inout Self, rhs: Bound) {
        lhs = lhs + rhs
    }
    static func - (lhs: Self, rhs: Bound) -> Self {
        lhs + (-rhs)
    }
    static func -= (lhs: inout Self, rhs: Bound) {
        lhs = lhs - rhs
    }
}
