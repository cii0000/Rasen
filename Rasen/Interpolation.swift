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

struct Interpolation<Value: MonoInterpolatable & Equatable> {
    enum KeyType: Int8, Hashable, Codable {
        case step, linear, spline
    }
    struct Key {
        var value: Value
        var time = 0.0
        var type = KeyType.spline
    }
    
    var keys = [Key]()
    var duration = 1.0
}
extension Interpolation.Key: Sendable where Value: Sendable {}
extension Interpolation.Key: Equatable where Value: Equatable {}
extension Interpolation.Key: Hashable where Value: Hashable {}
extension Interpolation.Key: Codable where Value: Codable {}
extension Interpolation: Sendable where Value: Sendable {}
extension Interpolation: Equatable where Value: Equatable {}
extension Interpolation: Hashable where Value: Hashable {}
extension Interpolation: Codable where Value: Codable {}
extension Interpolation {
    var isEmpty: Bool {
        keys.isEmpty
    }
    var enabled: Bool {
        keys.count >= 2
    }
    mutating func insert(_ key: Key) {
        for (i, aKeyframe) in keys.enumerated() {
            if key.time < aKeyframe.time {
                keys.insert(key, at: i)
                return
            }
        }
        keys.append(key)
    }
    
    func valueEnabledFirstLast(withT t: Double, isLoop: Bool = true) -> Value? {
        if t <= 0 {
            return keys.first?.value
        } else if t >= duration {
            return keys.last?.value
        } else {
            if let result = timeResult(withTime: t) {
                return value(with: result, isLoop: isLoop)
            } else {
                return nil
            }
        }
    }
    func value(withTime t: Double, isLoop: Bool = true) -> Value? {
        if let result = timeResult(withTime: t) {
            return value(with: result, isLoop: isLoop)
        } else {
            return nil
        }
    }
    func value(with timeResult: TimeResult, isLoop: Bool = true) -> Value? {
        guard !keys.isEmpty else { return nil }
        let i1 = timeResult.index
        let k1 = keys[i1]
        guard k1.type != .step && keys.count > 1,
           timeResult.sectionTime > 0 else { return k1.value }
        if !isLoop && i1 + 1 >= keys.count {
            return k1.value
        }
        let k2 = keys[i1 + 1 >= keys.count ? 0 : i1 + 1]
        if k1.type == .linear {
            let t = timeResult.internalTime / timeResult.sectionTime
            return Value.linear(k1.value, k2.value, t: t)
        }
        if !isLoop && i1 - 1 < 0 {
            let t = timeResult.internalTime / timeResult.sectionTime
            if i1 + 2 >= keys.count {
                return Value.linear(k1.value, k2.value, t: t)
            } else {
                let k3 = keys[i1 + 2]
                return Value.firstSpline(k1.value, k2.value, k3.value, t: t)
            }
        }
        let k0 = keys[i1 - 1 < 0 ? keys.count - 1 : i1 - 1]
        if !isLoop && i1 + 2 >= keys.count {
            let t = timeResult.internalTime / timeResult.sectionTime
            return Value.lastSpline(k0.value, k1.value, k2.value, t: t)
        }
        let k3 = keys[i1 + 2 >= keys.count ? i1 + 2 - keys.count : i1 + 2]
        let t = timeResult.internalTime / timeResult.sectionTime
        if k2.type == .spline {
            if k0.type == .spline {
                return Value.spline(k0.value, k1.value,
                                    k2.value, k3.value, t: t)
            } else {
                return Value.firstSpline(k1.value, k2.value, k3.value, t: t)
            }
        } else {
            if k0.type == .spline {
                return Value.lastSpline(k0.value, k1.value, k2.value, t: t)
            } else {
                return Value.linear(k1.value, k2.value, t: t)
            }
        }
    }
    
    func monoValueEnabledFirstLast(withT t: Double, isLoop: Bool = true) -> Value? {
        if t <= 0 {
            return keys.first?.value
        } else if t >= duration {
            return keys.last?.value
        } else {
            if let result = timeResult(withTime: t) {
                return monoValue(with: result, isLoop: isLoop)
            } else {
                return nil
            }
        }
    }
    func monoValue(withTime t: Double, isLoop: Bool = true) -> Value? {
        if let result = timeResult(withTime: t) {
            return monoValue(with: result, isLoop: isLoop)
        } else {
            return nil
        }
    }
    func monoValue(with timeResult: TimeResult, isLoop: Bool = true) -> Value? {
        guard !keys.isEmpty else { return nil }
        let i1 = timeResult.index
        let k1 = keys[i1]
        guard k1.type != .step && keys.count > 1,
           timeResult.sectionTime > 0 else { return k1.value }
        if !isLoop && i1 + 1 >= keys.count {
            return k1.value
        }
        let k2 = keys[i1 + 1 >= keys.count ? 0 : i1 + 1]
        guard k1.value != k2.value else { return k1.value }
        if k1.type == .linear {
            let t = timeResult.internalTime / timeResult.sectionTime
            return Value.linear(k1.value, k2.value, t: t)
        }
        if !isLoop && i1 - 1 < 0 {
            let t = timeResult.internalTime / timeResult.sectionTime
            if i1 + 2 >= keys.count {
                return Value.linear(k1.value, k2.value, t: t)
            } else {
                let k3 = keys[i1 + 2]
                let ms = Monospline(x1: k1.time, x2: k2.time,
                                    x3: k3.time, t: t)
                return Value.firstMonospline(k1.value, k2.value, k3.value,
                                             with: ms)
            }
        }
        let k0 = keys[i1 - 1 < 0 ? keys.count - 1 : i1 - 1]
        if !isLoop && i1 + 2 >= keys.count {
            let t = timeResult.internalTime / timeResult.sectionTime
            let ms = Monospline(x0: k0.time, x1: k1.time,
                                x2: k2.time, t: t)
            return Value.lastMonospline(k0.value, k1.value, k2.value,
                                        with: ms)
        }
        let k3 = keys[i1 + 2 >= keys.count ? i1 + 2 - keys.count : i1 + 2]
        let t = timeResult.internalTime / timeResult.sectionTime
        if k2.type == .spline {
            if k0.type == .spline {
                let ms = Monospline(x0: k0.time, x1: k1.time,
                                    x2: k2.time, x3: k3.time,
                                    t: t)
                return Value.monospline(k0.value, k1.value,
                                        k2.value, k3.value, with: ms)
            } else {
                let ms = Monospline(x1: k1.time, x2: k2.time,
                                    x3: k3.time, t: t)
                return Value.firstMonospline(k1.value, k2.value, k3.value,
                                             with: ms)
            }
        } else {
            if k0.type == .spline {
                let ms = Monospline(x0: k0.time, x1: k1.time,
                                    x2: k2.time, t: t)
                return Value.lastMonospline(k0.value, k1.value, k2.value,
                                            with: ms)
            } else {
                return Value.linear(k1.value, k2.value, t: t)
            }
        }
    }
    
    struct TimeResult {
        var index: Int, internalTime: Double, sectionTime: Double
    }
    func timeResult(withTime t: Double) -> TimeResult? {
        guard !keys.isEmpty && t <= duration else { return nil }
        var oldT = duration
        for i in (0 ..< keys.count).reversed() {
            let ki = keys[i]
            let kt = ki.time
            if t >= kt {
                return TimeResult(index: i,
                                  internalTime: t - kt,
                                  sectionTime: oldT - kt)
            }
            oldT = kt
        }
        return TimeResult(index: 0,
                          internalTime: t - keys.first!.time,
                          sectionTime: oldT - keys.first!.time)
    }
}

protocol Interpolatable {
    func mid(_ other: Self) -> Self
    static func linear(_ f0: Self, _ f1: Self, t: Double) -> Self
    static func firstSpline(_ f1: Self,
                            _ f2: Self, _ f3: Self, t: Double) -> Self
    static func spline(_ f0: Self, _ f1: Self,
                       _ f2: Self, _ f3: Self, t: Double) -> Self
    static func lastSpline(_ f0: Self, _ f1: Self,
                           _ f2: Self, t: Double) -> Self
}
extension Interpolatable {
    func mid(_ other: Self) -> Self {
        .linear(self, other, t: 0.5)
    }
}

extension Array: Interpolatable where Element: Interpolatable {
    static func linear(_ f0: [Element], _ f1: [Element],
                       t: Double) -> [Element] {
        if f0.isEmpty {
            return f0
        }
        return f0.enumerated().map { i, e0 in
            if i >= f1.count {
                return e0
            }
            let e1 = f1[i]
            return Element.linear(e0, e1, t: t)
        }
    }
    static func firstSpline(_ f1: [Element],
                            _ f2: [Element], _ f3: [Element],
                            t: Double) -> [Element] {
        if f1.isEmpty {
            return f1
        }
        return f1.enumerated().map { i, e1 in
            if i >= f2.count {
                return e1
            }
            let e2 = f2[i]
            let e3 = i >= f3.count ? e2 : f3[i]
            return Element.firstSpline(e1, e2, e3, t: t)
        }
    }
    static func spline(_ f0: [Element], _ f1: [Element],
                       _ f2: [Element], _ f3: [Element],
                       t: Double) -> [Element] {
        if f1.isEmpty {
            return f1
        }
        return f1.enumerated().map { i, e1 in
            if i >= f2.count {
                return e1
            }
            let e0 = i >= f0.count ? e1 : f0[i]
            let e2 = f2[i]
            let e3 = i >= f3.count ? e2 : f3[i]
            return Element.spline(e0, e1, e2, e3, t: t)
        }
    }
    static func lastSpline(_ f0: [Element], _ f1: [Element],
                           _ f2: [Element],
                           t: Double) -> [Element] {
        if f1.isEmpty {
            return f1
        }
        return f1.enumerated().map { i, e1 in
            if i >= f2.count {
                return e1
            }
            let e0 = i >= f0.count ? e1 : f0[i]
            let e2 = f2[i]
            return Element.lastSpline(e0, e1, e2, t: t)
        }
    }
}

extension Optional: Interpolatable where Wrapped: Interpolatable {
    static func linear(_ f0: Optional, _ f1: Optional,
                       t: Double) -> Optional {
        if let f0 = f0 {
            if let f1 = f1 {
                return Wrapped.linear(f0, f1, t: t)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    static func firstSpline(_ f1: Optional,
                            _ f2: Optional, _ f3: Optional,
                            t: Double) -> Optional {
        if let f1 = f1 {
            if let f2 = f2 {
                if let f3 = f3 {
                    return Wrapped.firstSpline(f1, f2, f3, t: t)
                } else {
                    return Wrapped.linear(f1, f2, t: t)
                }
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    static func spline(_ f0: Optional, _ f1: Optional,
                       _ f2: Optional, _ f3: Optional,
                       t: Double) -> Optional {
        if let f1 = f1 {
            if let f2 = f2 {
                if let f0 = f0 {
                    if let f3 = f3 {
                        return Wrapped.spline(f0, f1, f2, f3, t: t)
                    } else {
                        return Wrapped.lastSpline(f0, f1, f2, t: t)
                    }
                } else {
                    if let f3 = f3 {
                        return Wrapped.firstSpline(f1, f2, f3, t: t)
                    } else {
                        return Wrapped.linear(f1, f2, t: t)
                    }
                }
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    static func lastSpline(_ f0: Optional, _ f1: Optional,
                           _ f2: Optional,
                           t: Double) -> Optional {
        if let f1 = f1 {
            if let f2 = f2 {
                if let f0 = f0 {
                    return Wrapped.lastSpline(f0, f1, f2, t: t)
                } else {
                    return Wrapped.linear(f1, f2, t: t)
                }
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
}

// Monotone Spline
protocol MonoInterpolatable: Interpolatable {
    static func firstMonospline(_ f1: Self, _ f2: Self, _ f3: Self,
                                with ms: Monospline) -> Self
    static func monospline(_ f0: Self, _ f1: Self, _ f2: Self, _ f3: Self,
                           with ms: Monospline) -> Self
    static func lastMonospline(_ f0: Self, _ f1: Self, _ f2: Self,
                               with ms: Monospline) -> Self
}

extension Array: MonoInterpolatable where Element: MonoInterpolatable {
    static func firstMonospline(_ f1: [Element],
                                _ f2: [Element], _ f3: [Element],
                                with ms: Monospline) -> [Element] {
        if f1.isEmpty {
            return f1
        }
        return f1.enumerated().map { i, e1 in
            if i >= f2.count {
                return e1
            }
            let e2 = f2[i]
            let e3 = i >= f3.count ? e2 : f3[i]
            return Element.firstMonospline(e1, e2, e3, with: ms)
        }
    }
    static func monospline(_ f0: [Element], _ f1: [Element],
                           _ f2: [Element], _ f3: [Element],
                           with ms: Monospline) -> [Element] {
        if f1.isEmpty {
            return f1
        }
        return f1.enumerated().map { i, e1 in
            if i >= f2.count {
                return e1
            }
            let e0 = i >= f0.count ? e1 : f0[i]
            let e2 = f2[i]
            let e3 = i >= f3.count ? e2 : f3[i]
            return Element.monospline(e0, e1, e2, e3, with: ms)
        }
    }
    static func lastMonospline(_ f0: [Element],
                               _ f1: [Element], _ f2: [Element],
                               with ms: Monospline) -> [Element] {
        if f1.isEmpty {
            return f1
        }
        return f1.enumerated().map { i, e1 in
            if i >= f2.count {
                return e1
            }
            let e0 = i >= f0.count ? e1 : f0[i]
            let e2 = f2[i]
            return Element.lastMonospline(e0, e1, e2, with: ms)
        }
    }
}

extension Optional: MonoInterpolatable where Wrapped: MonoInterpolatable {
    static func firstMonospline(_ f1: Optional,
                                _ f2: Optional, _ f3: Optional,
                                with ms: Monospline) -> Optional {
        if let f1 = f1 {
            if let f2 = f2 {
                if let f3 = f3 {
                    return Wrapped.firstMonospline(f1, f2, f3, with: ms)
                } else {
                    return Wrapped.linear(f1, f2, t: ms.t)
                }
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    static func monospline(_ f0: Optional, _ f1: Optional,
                           _ f2: Optional, _ f3: Optional,
                           with ms: Monospline) -> Optional {
        if let f1 = f1 {
            if let f2 = f2 {
                if let f0 = f0 {
                    if let f3 = f3 {
                        return Wrapped.monospline(f0, f1, f2, f3, with: ms)
                    } else {
                        return Wrapped.lastMonospline(f0, f1, f2, with: ms)
                    }
                } else {
                    if let f3 = f3 {
                        return Wrapped.firstMonospline(f1, f2, f3, with: ms)
                    } else {
                        return Wrapped.linear(f1, f2, t: ms.t)
                    }
                }
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    static func lastMonospline(_ f0: Optional, _ f1: Optional,
                               _ f2: Optional,
                               with ms: Monospline) -> Optional {
        if let f1 = f1 {
            if let f2 = f2 {
                if let f0 = f0 {
                    return Wrapped.lastMonospline(f0, f1, f2, with: ms)
                } else {
                    return Wrapped.linear(f1, f2, t: ms.t)
                }
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
}

struct Monospline {
    let h0: Double, h1: Double, h2: Double
    let reciprocalH0: Double, reciprocalH1: Double, reciprocalH2: Double
    let reciprocalH0H1: Double, reciprocalH1H2: Double, reciprocalH1H1: Double
    private(set) var xx3: Double, xx2: Double, xx1: Double
    enum XType {
        case empty, linear, first, last, firstAndLast
    }
    let xType: XType
    
    var t: Double {
        didSet {
            xx1 = h1 * t
            xx2 = xx1 * xx1
            xx3 = xx1 * xx1 * xx1
        }
    }
    init(x1: Double, x2: Double, x3: Double, t: Double) {
        if x1 == x2 {
            xType = .empty
        } else if x2 == x3 {
            xType = .linear
        } else {
            xType = .last
        }
        h0 = 0
        h1 = x2 - x1
        h2 = x3 - x2
        reciprocalH0 = 0
        reciprocalH1 = 1 / h1
        reciprocalH2 = 1 / h2
        reciprocalH0H1 = 0
        reciprocalH1H2 = 1 / (h1 + h2)
        reciprocalH1H1 = 1 / (h1 * h1)
        xx1 = h1 * t
        xx2 = xx1 * xx1
        xx3 = xx1 * xx1 * xx1
        self.t = t
    }
    init(x0: Double, x1: Double, x2: Double, x3: Double, t: Double) {
        if x1 == x2 {
            xType = .empty
        } else if x0 == x1 || x2 == x3 {
            if x0 == x1 && x2 == x3 {
                xType = .linear
            } else if x0 == x1 {
                xType = .last
            } else {
                xType = .first
            }
        } else {
            xType = .firstAndLast
        }
        h0 = x1 - x0
        h1 = x2 - x1
        h2 = x3 - x2
        reciprocalH0 = xType == .last ? 0 : 1 / h0
        reciprocalH1 = 1 / h1
        reciprocalH2 = xType == .first ? 0 : 1 / h2
        reciprocalH0H1 = xType == .last ? 0 : 1 / (h0 + h1)
        reciprocalH1H2 = xType == .first ? 0 : 1 / (h1 + h2)
        reciprocalH1H1 = 1 / (h1 * h1)
        xx1 = h1 * t
        xx2 = xx1 * xx1
        xx3 = xx1 * xx1 * xx1
        self.t = t
    }
    init(x0: Double, x1: Double, x2: Double, t: Double) {
        if x1 == x2 {
            xType = .empty
        } else if x0 == x1 {
            xType = .linear
        } else {
            xType = .first
        }
        h0 = x1 - x0
        h1 = x2 - x1
        h2 = 0
        reciprocalH0 = 1 / h0
        reciprocalH1 = 1 / h1
        reciprocalH2 = 0
        reciprocalH0H1 = 1 / (h0 + h1)
        reciprocalH1H2 = 0
        reciprocalH1H1 = 1 / (h1 * h1)
        xx1 = h1 * t
        xx2 = xx1 * xx1
        xx3 = xx1 * xx1 * xx1
        self.t = t
    }
    
    func firstInterpolatedValue(_ f1: Double, _ f2: Double, _ f3: Double) -> Double {
        switch xType {
        case .empty: return f1
        case .linear: return .linear(f1, f2, t: t)
        default: break
        }
        guard f1 != f2 else { return f1 }
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let s3 = 0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2)
        let signS1 = s1.signValue, signS2 = s2.signValue
        let yPrime1 = s1
        let yPrime2 = (signS1 + signS2) * min(abs(s1), abs(s2), s3)
        return interpolatedValue(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2)
    }
    func interpolatedValue(_ f0: Double, _ f1: Double, _ f2: Double, _ f3: Double) -> Double {
        switch xType {
        case .empty: return f1
        case .linear: return .linear(f1, f2, t: t)
        case .first: return firstInterpolatedValue(f1, f2, f3)
        case .last: return lastInterpolatedValue(f0, f1, f2)
        default: break
        }
        guard f1 != f2 else { return f1 }
        let s0 = (f1 - f0) * reciprocalH0
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let s3 = 0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1)
        let s4 = 0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2)
        let signS0 = s0.signValue, signS1 = s1.signValue, signS2 = s2.signValue
        let yPrime1 = (signS0 + signS1) * min(abs(s0), abs(s1), s3)
        let yPrime2 = (signS1 + signS2) * min(abs(s1), abs(s2), s4)
        return interpolatedValue(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2)
    }
    func lastInterpolatedValue(_ f0: Double, _ f1: Double, _ f2: Double) -> Double {
        switch xType {
        case .empty: return f1
        case .linear: return .linear(f1, f2, t: t)
        default: break
        }
        guard f1 != f2 else { return f1 }
        let s0 = (f1 - f0) * reciprocalH0, s1 = (f2 - f1) * reciprocalH1
        let s2 = 0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1)
        let signS0 = s0.signValue, signS1 = s1.signValue
        let yPrime1 = (signS0 + signS1) * min(abs(s0), abs(s1), s2)
        let yPrime2 = s1
        return interpolatedValue(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2)
    }
    private func interpolatedValue(f1: Double, s1: Double,
                                   yPrime1: Double, yPrime2: Double) -> Double {
        let a = (yPrime1 + yPrime2 - 2 * s1) * reciprocalH1H1
        let b = (3 * s1 - 2 * yPrime1 - yPrime2) * reciprocalH1, c = yPrime1, d = f1
        return a * xx3 + b * xx2 + c * xx1 + d
    }
    
    func integralFirstInterpolatedValue(_ f1: Double, _ f2: Double, _ f3: Double,
                                        a: Double, b: Double) -> Double {
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let s3 = 0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2)
        let signS1 = s1.signValue, signS2 = s2.signValue
        let yPrime1 = s1
        let yPrime2 = (signS1 + signS2) * min(abs(s1), abs(s2), s3)
        return integral(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2, a: a, b: b)
    }
    func integralInterpolatedValue(_ f0: Double, _ f1: Double, _ f2: Double, _ f3: Double,
                                   a: Double, b: Double) -> Double {
        let s0 = (f1 - f0) * reciprocalH0
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let s3 = 0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1)
        let s4 = 0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2)
        let signS0 = s0.signValue, signS1 = s1.signValue, signS2 = s2.signValue
        let yPrime1 = (signS0 + signS1) * min(abs(s0), abs(s1), s3)
        let yPrime2 = (signS1 + signS2) * min(abs(s1), abs(s2), s4)
        return integral(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2, a: a, b: b)
    }
    func integralLastInterpolatedValue(_ f0: Double, _ f1: Double, _ f2: Double,
                                       a: Double, b: Double) -> Double {
        let s0 = (f1 - f0) * reciprocalH0, s1 = (f2 - f1) * reciprocalH1
        let s2 = 0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1)
        let signS0 = s0.signValue, signS1 = s1.signValue
        let yPrime1 = (signS0 + signS1) * min(abs(s0), abs(s1), s2)
        let yPrime2 = s1
        return integral(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2, a: a, b: b)
    }
    private func integral(f1: Double, s1: Double, yPrime1: Double, yPrime2: Double,
                          a xa: Double, b xb: Double) -> Double {
        let a = (yPrime1 + yPrime2 - 2 * s1) * reciprocalH1H1
        let b = (3 * s1 - 2 * yPrime1 - yPrime2) * reciprocalH1, c = yPrime1, nd = f1
        
        let xa2 = xa * xa, xb2 = xb * xb, h1_2 = h1 * h1
        let xa3 = xa2 * xa, xb3 = xb2 * xb, h1_3 = h2 * h1
        let xa4 = xa3 * xa, xb4 = xb3 * xb
        let na = a * h1_3 / 4, nb = b * h1_2 / 3, nc = c * h1 / 2
        let fa = na * xa4 + nb * xa3 + nc * xa2 + nd * xa
        let fb = nb * xb4 + nb * xb3 + nc * xb2 + nd * xb
        return fb - fa
    }
}

struct MonotoneSpline {
    var xs, ys, cls, c2s, c3s : [Double]
    init(xs oxs: [Double], ys oys: [Double]) {
        guard !oxs.isEmpty, oxs.count == oys.count else { fatalError() }
        xs = oxs.sorted()
        ys = oys.sorted()
        
        var dxs = [Double](), dys = [Double](), ms = [Double]()
        for i in 0 ..< (xs.count - 1) {
            let dx = xs[i + 1] - xs[i]
            let dy = ys[i + 1] - ys[i]
            dxs.append(dx)
            dys.append(dy)
            ms.append(dy / dx)
        }
        
        cls = [ms[0]]
        for i in 0 ..< (dxs.count - 1) {
            let m = ms[i], mNext = ms[i + 1]
            if m * mNext <= 0 {
                cls.append(0)
            } else {
                let dx = dxs[i], dxNext = dxs[i + 1], common = dx + dxNext
                cls.append(3 * common / ((common + dxNext) / m + (common + dx) / mNext))
            }
        }
        cls.append(ms[ms.count - 1])
        
        c2s = [Double]()
        c3s = [Double]()
        for i in 0 ..< (cls.count - 1) {
            let c1 = cls[i], m = ms[i]
            let invDx = 1 / dxs[i], common = c1 + cls[i + 1] - m * 2
            c2s.append((m - c1 - common) * invDx)
            c3s.append(common * invDx * invDx)
        }
    }
    func y(atX x: Double) -> Double {
        var i = xs.count - 1
        if x == xs[i] {
            return ys[i]
        }
        var low = 0, mid = 0, high = c3s.count - 1
        while low <= high {
            mid = Int(0.5 * Double(low + high))
            let xHere = xs[mid]
            if xHere < x {
                low = mid + 1
            } else if xHere > x {
                high = mid - 1
            } else {
                return ys[mid]
            }
        }
        i = max(0, high)
        
        let diff = x - xs[i]
        let diffSq = diff * diff
        return ys[i] + cls[i] * diff + c2s[i] * diffSq + c3s[i] * diff * diffSq
    }
}
