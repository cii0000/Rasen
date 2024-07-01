// Copyright 2024 Cii
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

extension O {
    var startIndex: Int {
        switch self {
        case .range(let a):
            switch a.type {
            case .fili(let f, _): f.rounded(.up).asInt ?? 0
            case .filo(let f, _): f.rounded(.up).asInt ?? 0
            case .foli(let f, _): (f.rounded(.up).asInt ?? 0) + 1
            case .folo(let f, _): (f.rounded(.up).asInt ?? 0) + 1
            case .fi(let f): f.rounded(.up).asInt ?? 0
            case .fo(let f): (f.rounded(.up).asInt ?? 0) + 1
            case .li: 0
            case .lo: 0
            case .all: 0
            }
        case .array(let a): a.startIndex
        default: 0
        }
    }
    var endIndex: Int {
        switch self {
        case .range(let a):
            switch a.type {
            case .fili(_, let l): (l.rounded(.up).asInt ?? 0) + 1
            case .filo(_, let l): l.rounded(.up).asInt ?? 0
            case .foli(_, let l): (l.rounded(.up).asInt ?? 0) + 1
            case .folo(_, let l): l.rounded(.up).asInt ?? 0
            case .fi: 0
            case .fo: 0
            case .li(let l): l.rounded(.up).asInt ?? 0
            case .lo(let l): (l.rounded(.up).asInt ?? 0) + 1
            case .all: 0
            }
        case .array(let a): a.endIndex
        default: count
        }
    }
    var endReal: Real1 {
        switch self {
        case .range(let a):
            switch a.type {
            case .fili(_, let l): l.asReal1 ?? 0
            case .filo(_, let l): l.asReal1 ?? 0
            case .foli(_, let l): l.asReal1 ?? 0
            case .folo(_, let l): l.asReal1 ?? 0
            case .fi: 0
            case .fo: 0
            case .li(let l): l.asReal1 ?? 0
            case .lo(let l): l.asReal1 ?? 0
            case .all: 0
            }
        case .array(let a): Real1(a.endIndex)
        default: Real1(count)
        }
    }
    var count: Int {
        switch self {
        case .bool(_): return 1
        case .int(_): return 1
        case .rational(_): return 1
        case .real1(_): return 1
        case .string(let a): return a.count
        case .range(let a):
            let dlo = a.delta
            if dlo == O(1) {
                return endIndex - startIndex
            } else {
                let d = endIndex - startIndex
                switch dlo {
                case .int(let a): return a == 0 ? 0 : d / a
                case .rational(let a): return Int(a == 0 ? 0 : Rational(d) / a)
                case .real1(let a): return Int(a == 0 ? 0 : Real1(d) / a)
                default: return 0
                }
            }
        case .array(let a): return a.count
        case .g(let a):
            switch a {
            case .b: return 2
            default: return 0
            }
        case .dic(let a): return a.count
        default: return 1
        }
    }
    static let countaName = "counta"
    var counta: O {
        switch self {
        case .g(let a):
            switch a {
            case .b: return O(2)
            default: return O(.infinity)
            }
        case .error: return self
        default: return O(count)
        }
    }
    
    struct Elements: Sequence, IteratorProtocol {
        private let o: O
        let underestimatedCount: Int, endIndex: Int, endV: Real1
        
        private var i = 0, realI = 0.0, delta = 1, realDelta: Real1?
        private var containsLast = true
        mutating func next() -> O? {
            if let realDelta = realDelta {
                if containsLast ? realI <= endV : realI < endV {
                    defer { realI += realDelta }
                    return O(realI)
                } else {
                    return nil
                }
            } else {
                if containsLast ? i <= endIndex : i < endIndex {
                    defer { i += delta }
                    return o.at(i)
                } else {
                    return nil
                }
            }
        }
        
        init(_ o: O) {
            self.o = o
            
            switch o {
            case .range(let a):
                let containsLast: Bool
                switch a.type {
                case .fili(let f, let l):
                    i = f.asInt ?? 0
                    realI = f.asReal1 ?? 0
                    endIndex = l.rounded(.down).asInt ?? 0
                    endV = l.asReal1 ?? 0
                    containsLast = true
                case .filo(let f, let l):
                    i = f.asInt ?? 0
                    realI = f.asReal1 ?? 0
                    endIndex = l.rounded(.up).asInt ?? 0
                    endV = l.asReal1 ?? 0
                    containsLast = false
                case .foli(let f, let l):
                    i = f.asInt ?? 0
                    realI = f.asReal1 ?? 0
                    endIndex = l.rounded(.down).asInt ?? 0
                    endV = l.asReal1 ?? 0
                    containsLast = true
                case .folo(let f, let l):
                    i = f.asInt ?? 0
                    realI = f.asReal1 ?? 0
                    endIndex = l.rounded(.up).asInt ?? 0
                    endV = l.asReal1 ?? 0
                    containsLast = false
                default:
                    endIndex = 0
                    endV = 0
                    containsLast = false
                }
                
                switch a.delta {
                case .int(let a):
                    delta = a
                    if delta == 0 {
                        underestimatedCount = 0
                    } else {
                        let s = (endV - realI).truncatingRemainder(dividingBy: Double(delta))
                        underestimatedCount
                            = (s == 0 && !containsLast ? -1 : 0)
                            + (Int(exactly: (endV - realI) / Double(delta)) ?? 0)
                    }
                case .real1(let a):
                    realDelta = a
                    let s = (endV - realI).truncatingRemainder(dividingBy: a)
                    underestimatedCount
                        = (s == 0 && !containsLast ? -1 : 0)
                        + (Int(exactly: (endV - realI) / a) ?? 0)
                default:
                    underestimatedCount = 0
                }
                self.containsLast = containsLast
            case .array(let a):
                i = a.startIndex
                endIndex = a.endIndex
                endV = Double(endIndex)
                underestimatedCount = a.count
                containsLast = false
                delta = 1
            default:
                endIndex = 0
                endV = 0
                underestimatedCount = 0
            }
        }
    }
    var elements: Elements {
        Elements(self)
    }
    
    subscript(i: Int) -> O {
        get {
            at(i)
        }
    }
    
    func at(_ i: Int) -> O {
        switch self {
        case .range: O(i)
        case .string(let a): O(String(a[a.index(fromInt: i)]))
        case .array(let a): a[i]
        case .dic(let a): a[a.index(a.startIndex, offsetBy: i)].value
        default: self
        }
    }
    
    static let atName = "."
    static func at(_ ao: O, _ bo: O) -> O {
        switch ao {
        case .dic(let a):
            switch bo {
            case .error: return bo
            default:
                guard let n = a[bo] else { return O(OError(String(format: "'%1$@' is out of bounds dictionary range".localized, bo.name))) }
                return n
            }
        case .sheet(let a):
            switch bo {
            case .string(let b):
                switch b {
                case linesName: return O(a.value.picture.lines)
                case textsName: return O(a.value.texts)
                default: break
                }
            case .error: return bo
            default: break
            }
            return O(OError(String(format: "'%1$@' is out of bounds dictionary range".localized, bo.name)))
        case .error: return ao
        default:
            switch bo {
            case .error: return bo
            default: break
            }
            let oi = bo.asInt
            guard let i = oi else { return O(OError.undefined(with: "\(ao.name)\(atName)\(bo.name)")) }
            let count = ao.count
            guard i >= 0 && i < count else { return O(OError(String(format: "'%1$d' is out of bounds array range 0 ..< %2$d".localized, i, count))) }
            return ao.at(i)
        }
    }
    
    static let selectName = "/."
    static func select(_ ao: O, _ bo: O) -> O {
        switch ao {
        case .selected(var a):
            switch bo {
            case .error: return bo
            default: break
            }
            a.ranges.append(bo)
            return O(a)
        case .error: return ao
        default:
            switch bo {
            case .error: return bo
            default: break
            }
            return O(Selected(ao, ranges: [bo]))
        }
    }
    
    static func set(_ bo: O, in ao: O, at io: O,
                    _ errorHandler: () -> (O)) -> O {
        switch ao {
        case .error: return ao
        default: break
        }
        switch bo {
        case .error: return bo
        default: break
        }
        switch io {
        case .error: return io
        default: break
        }
        
        switch ao {
        case .dic(var a):
            a[io] = bo
            return O(a)
        case .sheet(var a):
            switch io {
            case .string(let i):
                switch i {
                case linesName:
                    switch bo {
                    case .array(let b):
                        let ls = b.compactMap { $0.asLine }
                        if b.count != ls.count {
                            return O([O(linesName): bo,
                                      O(textsName): O(a.value.texts)])
                        } else {
                            guard !ls.isEmpty else { break }
                            a.removeLines(at: Array(0 ..< a.value.picture.lines.count))
                            a.append(ls)
                            return O(a)
                        }
                    case .dic:
                        if let l = bo.asLine {
                            a.removeLines(at: Array(0 ..< a.value.picture.lines.count))
                            a.append([l])
                            return O(a)
                        }
                    default: break
                    }
                case textsName:
                    switch bo {
                    case .array(let b):
                        let ts = b.compactMap { $0.asText }
                        if b.count != ts.count {
                            return O([O(linesName): O(a.value.picture.lines),
                                      O(textsName): bo])
                        } else {
                            guard !ts.isEmpty else { break }
                            a.removeTexts(at: Array(0 ..< a.value.texts.count))
                            a.append(ts)
                            return O(a)
                        }
                    case .dic:
                        if let t = bo.asText {
                            a.removeTexts(at: Array(0 ..< a.value.picture.lines.count))
                            a.append([t])
                            return O(a)
                        }
                    default: break
                    }
                default: break
                }
                let n = O(a.value)
                return set(bo, in: n, at: io, errorHandler)
            default: break
            }
            return O(OError(String(format: "'%1$@' is out of bounds dictionary range".localized, bo.name)))
        default:
            switch ao {
            case .range(let a):
                switch a.type {
                case .fi, .fo, .li, .lo, .all:
                    return errorHandler()
                default: break
                }
            default: break
            }
            if let i = io.asInt {
                switch ao {
                case .array(var a):
                    guard i >= 0 && i < a.count else { return O(OError(String(format: "'%1$d' is out of bounds array range 0 ..< %2$d".localized, i, a.count))) }
                    a[i] = bo
                    return O(a)
                default:
                    let count = ao.count
                    guard i >= 0 && i < count else { return O(OError(String(format: "'%1$d' is out of bounds array range 0 ..< %2$d".localized, i, count))) }
                    
                    switch ao {
                    case .range:
                        return errorHandler()
                    case .string(var a):
                        if case .string(let r) = bo, r.count == 1 {
                            let si = a.index(a.startIndex, offsetBy: i)
                            a.replaceSubrange(si ... si, with: r)
                            return O(a)
                        }
                    default:
                        return bo
                    }
                    var nos = ao.elements.map { $0 }
                    nos[i] = bo
                    return ao.with(nos)
                }
            }
        }
        return errorHandler()
    }
    
    static let setName = "<-"
    static func set(_ ao: O, _ bo: O) -> O {
        switch ao {
        case .error: return ao
        default: break
        }
        switch bo {
        case .error: return bo
        default: break
        }
        
        guard case .selected(let aao) = ao else { return bo }
        let nao = aao.o
        let ios = aao.ranges
        guard ios.count > 0 else {
            return O(OError.undefined(with: "\(ao.name) \(O.setName) \(bo.name)"))
        }
        
        var no = nao
        var oss = [(o: O, i: O)]()
        oss.reserveCapacity(ios.count)
        iosLoop: for (i, io) in ios.enumerated() {
            if case .sheet(var ss) = no,
               case .string(let str) = io, i < ios.count - 1 {
                
                if str == linesName {
                    if let li = ios[i + 1].asInt, li < ss.value.picture.lines.count {
                        if i + 1 == ios.count - 1 {
                            if let line = bo.asLine {
                                ss.replace([IndexValue(value: line, index: li)])
                                if oss.isEmpty {
                                    return O(ss)
                                } else {
                                    oss[.last].i = O(ss)
                                }
                                break iosLoop
                            }
                        } else if i + 2 == ios.count - 1,
                                  let lci = ios[i + 2].asInt, lci < ss.value.picture.lines[li].controls.count {
                            
                            if let lc = bo.asLineControl {
                                var line = ss.value.picture.lines[li]
                                line.controls[lci] = lc
                                ss.replace([IndexValue(value: line, index: li)])
                                if oss.isEmpty {
                                    return O(ss)
                                } else {
                                    oss[.last].i = O(ss)
                                }
                                break iosLoop
                            }
                        } else if i + 3 == ios.count - 1,
                                  let lci = ios[i + 2].asInt, lci < ss.value.picture.lines[li].controls.count,
                                  case .string(let lcci) = ios[i + 3] {
                            
                            switch lcci {
                            case "point":
                                if let origin = bo.asPoint {
                                    var line = ss.value.picture.lines[li]
                                    line.controls[lci].point = origin
                                    ss.replace([IndexValue(value: line, index: li)])
                                    if oss.isEmpty {
                                        return O(ss)
                                    } else {
                                        oss[.last].i = O(ss)
                                    }
                                    break iosLoop
                                }
                            case "weight":
                                if let weight = bo.asReal1 {
                                    var line = ss.value.picture.lines[li]
                                    line.controls[lci].weight = weight
                                    ss.replace([IndexValue(value: line, index: li)])
                                    if oss.isEmpty {
                                        return O(ss)
                                    } else {
                                        oss[.last].i = O(ss)
                                    }
                                    break iosLoop
                                }
                            case "pressure":
                                if let pressure = bo.asReal1 {
                                    var line = ss.value.picture.lines[li]
                                    line.controls[lci].pressure = pressure
                                    ss.replace([IndexValue(value: line, index: li)])
                                    if oss.isEmpty {
                                        return O(ss)
                                    } else {
                                        oss[.last].i = O(ss)
                                    }
                                    break iosLoop
                                }
                            default: break
                            }
                        } else if i + 4 == ios.count - 1,
                                  let lci = ios[i + 2].asInt,
                                  case .string(let lcci) = ios[i + 3], lcci == "point",
                                  let lccpi = ios[i + 4].asInt {
                            
                            switch lccpi {
                            case 0:
                                if let v = bo.asReal1 {
                                    var line = ss.value.picture.lines[li]
                                    line.controls[lci].point.x = v
                                    ss.replace([IndexValue(value: line, index: li)])
                                    if oss.isEmpty {
                                        return O(ss)
                                    } else {
                                        oss[.last].i = O(ss)
                                    }
                                    break iosLoop
                                }
                            case 1:
                                if let v = bo.asReal1 {
                                    var line = ss.value.picture.lines[li]
                                    line.controls[lci].point.y = v
                                    ss.replace([IndexValue(value: line, index: li)])
                                    if oss.isEmpty {
                                        return O(ss)
                                    } else {
                                        oss[.last].i = O(ss)
                                    }
                                    break iosLoop
                                }
                            default: break
                            }
                        }
                    }
                } else if str == "texts" {
                    if let ti = ios[i + 1].asInt, ti < ss.value.texts.count {
                        if i + 1 == ios.count - 1 {
                            if let text = bo.asText {
                                ss.replace([IndexValue(value: text, index: ti)])
                                if oss.isEmpty {
                                    return O(ss)
                                } else {
                                    oss[.last].i = O(ss)
                                }
                                break iosLoop
                            }
                        } else if i + 2 == ios.count - 1 {
                            switch ios[i + 2] {
                            case O("string"):
                                if case .string(let str) = bo {
                                    var text = ss.value.texts[ti]
                                    text.string = str
                                    ss.replace([IndexValue(value: text, index: ti)])
                                    if oss.isEmpty {
                                        return O(ss)
                                    } else {
                                        oss[.last].i = O(ss)
                                    }
                                    break iosLoop
                                } else {
                                    return O(OError(String(format: "'%1$@' is not '%2$@'".localized, bo.name, G.string.rawValue)))
                                }
                            case O("orientation"):
                                if let orientation = bo.asOrientation {
                                    var text = ss.value.texts[ti]
                                    text.orientation = orientation
                                    ss.replace([IndexValue(value: text, index: ti)])
                                    if oss.isEmpty {
                                        return O(ss)
                                    } else {
                                        oss[.last].i = O(ss)
                                    }
                                    break iosLoop
                                } else {
                                    return O(OError(String(format: "'%1$d' is not '%2$d'".localized, bo.name, "Orientation".localized)))
                                }
                            case O("size"):
                                if let size = bo.asReal1 {
                                    var text = ss.value.texts[ti]
                                    text.size = size
                                    ss.replace([IndexValue(value: text, index: ti)])
                                    if oss.isEmpty {
                                        return O(ss)
                                    } else {
                                        oss[.last].i = O(ss)
                                    }
                                    break iosLoop
                                } else {
                                    return O(OError("'' is not ''"))
                                }
                            case O("origin"):
                                if let origin = bo.asPoint {
                                    var text = ss.value.texts[ti]
                                    text.origin = origin
                                    ss.replace([IndexValue(value: text, index: ti)])
                                    if oss.isEmpty {
                                        return O(ss)
                                    } else {
                                        oss[.last].i = O(ss)
                                    }
                                    break iosLoop
                                }
                            default: break
                            }
                        } else if i + 3 == ios.count - 1,
                                  ios[i + 2] == O("string"),
                                  let ttsi = ios[i + 3].asInt, ttsi < ss.value.texts[ti].string.count {
                            
                            if case .string(let str) = bo, str.count == 1 {
                                var text = ss.value.texts[ti]
                                let si = text.string.index(text.string.startIndex, offsetBy: ttsi)
                                text.string.replaceSubrange(si ... si, with: str)
                                ss.replace([IndexValue(value: text, index: ti)])
                                if oss.isEmpty {
                                    return O(ss)
                                } else {
                                    oss[.last].i = O(ss)
                                }
                                break iosLoop
                            }
                        } else if i + 3 == ios.count - 1,
                                  ios[i + 2] == O("origin"),
                                  let ttoi = ios[i + 3].asInt {
                            
                            switch ttoi {
                            case 0:
                                if let v = bo.asReal1 {
                                    var text = ss.value.texts[ti]
                                    text.origin.x = v
                                    ss.replace([IndexValue(value: text, index: ti)])
                                    if oss.isEmpty {
                                        return O(ss)
                                    } else {
                                        oss[.last].i = O(ss)
                                    }
                                    break iosLoop
                                }
                            case 1:
                                if let v = bo.asReal1 {
                                    var text = ss.value.texts[ti]
                                    text.origin.y = v
                                    ss.replace([IndexValue(value: text, index: ti)])
                                    if oss.isEmpty {
                                        return O(ss)
                                    } else {
                                        oss[.last].i = O(ss)
                                    }
                                    break iosLoop
                                }
                            default: break
                            }
                        }
                    }
                }
            }
            
            oss.append((no, io))
            no = O.at(no, io)
        }
        no = bo
        for os in oss.reversed() {
            no = set(no, in: os.o, at: os.i) { O(OError.undefined(with: "\(ao.name) \(O.setName) \(bo.name)")) }
        }
        return no
    }
    
    static let insertName = "++"
    static func insert(_ ao: O, _ bo: O) -> O {
        switch ao {
        case .error: return ao
        default: break
        }
        switch bo {
        case .error: return bo
        default: break
        }
        
        let nao: O, ios: [O]
        if case .selected(let aao) = ao {
            nao = aao.o
            ios = aao.ranges
        } else {
            nao = ao
            ios = [ao.counta]
        }
        guard ios.count > 0 else {
            return O(OError.undefined(with: "\(ao.name) \(O.insertName) \(bo.name)"))
        }
        
        func insert(_ sbo: O, in sao: O, at io: O) -> O {
            switch sao {
            case .error(_): return sao
            default: break
            }
            
            switch sao {
            case .range(let a):
                switch a.type {
                case .fi, .fo, .li, .lo, .all:
                    return O(OError.undefined(with: "\(ao.name) \(O.insertName) \(bo.name)"))
                default: break
                }
            default: break
            }
            
            if let i = io.asInt {
                switch sao {
                case .array(var a):
                    guard i >= 0 && i <= a.count else { return O(OError(String(format: "'%1$d' is out of bounds array range 0 ... %2$d".localized, i, a.count))) }
                    a.value.insert(bo, at: i)
                    return O(a)
                default:
                    let count = sao.count
                    guard i >= 0 && i <= count else { return O(OError(String(format: "'%1$d' is out of bounds array range 0 ..< %2$d".localized, i, count))) }
                    
                    switch sao {
                    case .range:
                        return O(OError.undefined(with: "\(ao.name) \(O.insertName) \(bo.name)"))
                    case .string(var a):
                        if case .string(let r) = sbo, r.count == 1 {
                            let si = a.index(a.startIndex, offsetBy: i)
                            a.insert(contentsOf: r, at: si)
                            return O(a)
                        }
                    case .dic:
                        return O(OError.undefined(with: "\(ao.name) \(O.insertName) \(bo.name)"))
                    default: break
                    }
                    var nos = sao.elements.map { $0 }
                    guard i >= 0 && i <= nos.count else { return O(OError(String(format: "'%1$d' is out of bounds array range 0 ..< %2$d".localized, i, nos.count))) }
                    nos.insert(bo, at: i)
                    return sao.with(nos)
                }
            }
            return O(OError.undefined(with: "\(ao.name) \(O.insertName) \(bo.name)"))
        }
        
        var no = nao
        var oss = [(o: O, i: O)]()
        oss.reserveCapacity(ios.count)
        iosLoop: for (i, io) in ios.enumerated() {
            
            if case .sheet(var ss) = no,
               case .string(let str) = io, i < ios.count - 1 {
                
                if str == linesName {
                    if let li = ios[i + 1].asInt {
                        if i + 1 == ios.count - 1 {
                            if let line = bo.asLine, li <= ss.value.picture.lines.count {
                                ss.insert([IndexValue(value: line, index: li)])
                                if oss.isEmpty {
                                    return O(ss)
                                } else {
                                    oss[.last].i = O(ss)
                                }
                                break iosLoop
                            }
                        } else if i + 2 == ios.count - 1,
                                  let lci = ios[i + 2].asInt, li < ss.value.picture.lines.count, lci <= ss.value.picture.lines[li].controls.count {
                            
                            if let lc = bo.asLineControl {
                                var line = ss.value.picture.lines[li]
                                line.controls.insert(lc, at: lci)
                                ss.replace([IndexValue(value: line, index: li)])
                                if oss.isEmpty {
                                    return O(ss)
                                } else {
                                    oss[.last].i = O(ss)
                                }
                                break iosLoop
                            }
                        }
                    }
                } else if str == textsName {
                    if let ti = ios[i + 1].asInt {
                        if i + 1 == ios.count - 1 {
                            if let text = bo.asText, ti <= ss.value.texts.count {
                                ss.insert([IndexValue(value: text, index: ti)])
                                if oss.isEmpty {
                                    return O(ss)
                                } else {
                                    oss[.last].i = O(ss)
                                }
                                break iosLoop
                            }
                        } else if i + 3 == ios.count - 1, ti < ss.value.texts.count,
                                  case .string(let tti) = ios[i + 2], tti == stringName,
                                  let ttsi = ios[i + 3].asInt, ttsi <= ss.value.texts[ti].string.count {
                            
                            if case .string(let str) = bo, str.count == 1 {
                                var text = ss.value.texts[ti]
                                let si = text.string.index(text.string.startIndex, offsetBy: ttsi)
                                text.string.insert(contentsOf: str, at: si)
                                ss.replace([IndexValue(value: text, index: ti)])
                                if oss.isEmpty {
                                    return O(ss)
                                } else {
                                    oss[.last].i = O(ss)
                                }
                                break iosLoop
                            }
                        }
                    }
                }
            }
            
            oss.append((no, io))
            no = O.at(no, io)
        }
        no = bo
        guard let lo = oss.last else { return no }
        no = insert(no, in: lo.o, at: lo.i)
        oss.removeLast()
        for os in oss.reversed() {
            no = set(no, in: os.o, at: os.i) { O(OError.undefined(with: "\(ao.name) \(O.insertName) \(bo.name)")) }
        }
        return no
    }
    
    static let removeName = "--"
    static func remove(_ ao: O) -> O {
        switch ao {
        case .error: return ao
        default: break
        }
        
        guard case .selected(let aao) = ao else { return .empty }
        let nao = aao.o
        let ios = aao.ranges
        guard ios.count > 0 else {
            return O(OError.undefined(with: "\(ao.name) \(O.removeName)"))
        }
        
        func remove(in sao: O, at io: O) -> O {
            switch sao {
            case .error(_): return sao
            default: break
            }
            
            switch sao {
            case .range(let a):
                switch a.type {
                case .fi, .fo, .li, .lo, .all:
                    return O(OError.undefined(with: "\(ao.name) \(O.removeName)"))
                default: break
                }
            default: break
            }
            
            if let i = io.asInt {
                switch sao {
                case .array(var a):
                    guard i >= 0 && i <= a.count else { return O(OError(String(format: "'%1$d' is out of bounds array range 0 ... %2$d".localized, i, a.count))) }
                    a.value.remove(at: i)
                    return O(a)
                default:
                    let count = sao.count
                    guard i >= 0 && i <= count else { return O(OError(String(format: "'%1$d' is out of bounds array range 0 ..< %2$d".localized, i, count))) }
                    
                    switch sao {
                    case .range:
                        return O(OError.undefined(with: "\(ao.name) \(O.removeName)"))
                    case .string(var a):
                        let si = a.index(a.startIndex, offsetBy: i)
                        a.remove(at: si)
                        return O(a)
                    case .dic:
                        return O(OError.undefined(with: "\(ao.name) \(O.removeName)"))
                    default: break
                    }
                    var nos = sao.elements.map { $0 }
                    nos.remove(at: i)
                    return sao.with(nos)
                }
            } else {
                switch sao {
                case .dic(var a):
                    guard a[io] != nil else { return O(OError(String(format: "'%1$@' is out of bounds dictionary range".localized, io.name))) }
                    a[io] = nil
                    return O(a)
                case .sheet(let a):
                    switch io {
                    case .string(let i):
                        switch i {
                        case linesName:
                            return O([O(textsName): O(a.value.texts)])
                        case textsName:
                            return O([O(linesName): O(a.value.picture.lines)])
                        default:
                            return O(OError(String(format: "'%1$@' is out of bounds dictionary range".localized, io.name)))
                        }
                    default: break
                    }
                default: break
                }
            }
            return O(OError.undefined(with: "\(ao.name) \(O.removeName)"))
        }
        
        var no = nao
        var oss = [(o: O, i: O)]()
        oss.reserveCapacity(ios.count)
        iosLoop: for (i, io) in ios.enumerated() {
            
            if case .sheet(var ss) = no,
               case .string(let str) = io, i < ios.count - 1 {
                
                if str == linesName {
                    if let li = ios[i + 1].asInt, li < ss.value.picture.lines.count {
                        if i + 1 == ios.count - 1 {
                            ss.removeLines(at: [li])
                            if oss.isEmpty {
                                return O(ss)
                            } else {
                                oss[.last].i = O(ss)
                            }
                            break iosLoop
                        } else if i + 2 == ios.count - 1,
                                  let lci = ios[i + 2].asInt, lci < ss.value.picture.lines[li].controls.count {
                            
                            var line = ss.value.picture.lines[li]
                            line.controls.remove(at: lci)
                            ss.replace([IndexValue(value: line, index: li)])
                            if oss.isEmpty {
                                return O(ss)
                            } else {
                                oss[.last].i = O(ss)
                            }
                            break iosLoop
                        }
                    }
                } else if str == textsName {
                    if let ti = ios[i + 1].asInt, ti < ss.value.texts.count {
                        if i + 1 == ios.count - 1 {
                            ss.removeText(at: ti)
                            if oss.isEmpty {
                                return O(ss)
                            } else {
                                oss[.last].i = O(ss)
                            }
                            break iosLoop
                        } else if i + 3 == ios.count - 1,
                                  case .string(let tti) = ios[i + 2], tti == stringName,
                                  let ttsi = ios[i + 3].asInt, ttsi < ss.value.texts[ti].string.count {
                            
                            var text = ss.value.texts[ti]
                            let si = text.string.index(text.string.startIndex, offsetBy: ttsi)
                            text.string.remove(at: si)
                            ss.replace([IndexValue(value: text, index: ti)])
                            if oss.isEmpty {
                                return O(ss)
                            } else {
                                oss[.last].i = O(ss)
                            }
                            break iosLoop
                        }
                    }
                }
            }
            
            oss.append((no, io))
            no = O.at(no, io)
        }
        guard let lo = oss.last else { return no }
        no = remove(in: lo.o, at: lo.i)
        oss.removeLast()
        for os in oss.reversed() {
            no = set(no, in: os.o, at: os.i) { O(OError.undefined(with: "\(ao.name) \(O.removeName)")) }
        }
        return no
    }
}

extension O {
    var isEmpty: Bool {
        switch self {
        case .array(let a): return a.isEmpty
        case .range: return count == 0
        case .dic(let a): return a.isEmpty
        case .g(let a): return a == .empty
        default: return false
        }
    }
    var isEmptyO: O {
        return O(isEmpty)
    }
    var isBool: O {
        switch self {
        case .bool: return O(true)
        case .int(let a): return O(a == 0 || a == 1)
        case .rational(let a): return O(a == 0 || a == 1)
        case .real1(let a): return O(a == 0 || a == 1)
        default: return O(false)
        }
    }
    var isNatural0: O {
        if let i = asInt {
            return O(i >= 0)
        } else {
            switch self {
            case .error: return self
            default: return O(false)
            }
        }
    }
    var isNatural1: O {
        if let i = asInt {
            return O(i >= 1)
        } else {
            switch self {
            case .error: return self
            default: return O(false)
            }
        }
    }
    var isInt: Bool {
        switch self {
        case .bool: return true
        case .int: return true
        case .rational(let a): return a.isInteger
        case .real1(let a): return a.isInteger
        default: return false
        }
    }
    var isIntO: O {
        switch self {
        case .bool: return O(true)
        case .int: return O(true)
        case .rational(let a): return O(a.isInteger)
        case .real1(let a): return O(a.isInteger)
        case .error: return self
        default: return O(false)
        }
    }
    var isRational: O {
        switch self {
        case .bool: return O(true)
        case .int: return O(true)
        case .rational: return O(true)
        case .real1: return O(true)
        case .error: return self
        default: return O(false)
        }
    }
    var isReal1: O {
        switch self {
        case .bool: return O(true)
        case .int: return O(true)
        case .rational: return O(true)
        case .real1: return O(true)
        case .error: return self
        default: return O(false)
        }
    }
    var isString: O {
        switch self {
        case .string: return O(true)
        default: return O(false)
        }
    }
    var isF: O {
        switch self {
        case .f: return O(true)
        default: return O(false)
        }
    }
    var isArray: O {
        return O(count > 1)
    }
    var isDic: O {
        switch self {
        case .dic: return O(true)
        default: return O(false)
        }
    }
    static let isName = "is"
    static func isO(_ ao: O, _ bo: O) -> O {
        switch bo {
        case .range(let b):
            let dlo = b.delta
            switch b.type {
            case .fili(let fio, let lio):
                if dlo == O(0) {
                    return O(ao >= fio && ao <= lio)
                } else {
                    return O((ao + fio) % dlo == O(0) && ao >= fio && ao <= lio)
                }
            case .filo(let fio, let lio):
                if dlo == O(0) {
                    return O(ao >= fio && ao < lio)
                } else {
                    return O((ao + fio) % dlo == O(0) && ao >= fio && ao < lio)
                }
            case .foli(let fio, let lio):
                if dlo == O(0) {
                    return O(ao > fio && ao <= lio)
                } else {
                    return O((ao + fio) % dlo == O(0) && ao > fio && ao <= lio)
                }
            case .folo(let fio, let lio):
                if dlo == O(0) {
                    return O(ao > fio && ao < lio)
                } else {
                    return O((ao + fio) % dlo == O(0) && ao > fio && ao < lio)
                }
            case .fi(let fio):
                if dlo == O(0) {
                    return O(ao >= fio)
                } else {
                    return O((ao + fio) % dlo == O(0) && ao >= fio)
                }
            case .fo(let fio):
                if dlo == O(0) {
                    return O(ao > fio)
                } else {
                    return O((ao + fio) % dlo == O(0) && ao > fio)
                }
            case .li(let lio):
                if dlo == O(0) {
                    return O(ao <= lio)
                } else {
                    return O(ao % dlo == O(0) && ao <= lio)
                }
            case .lo(let lio):
                if dlo == O(0) {
                    return O(ao < lio)
                } else {
                    return O(ao % dlo == O(0) && ao < lio)
                }
            case .all:
                if dlo == O(0) {
                    return O(true)
                } else {
                    return O(ao % dlo == O(0))
                }
            }
        case .g(let b):
            switch b {
            case .empty: return ao.isEmptyO
            case .b: return ao.isBool
            case .n0: return ao.isNatural0
            case .n1: return ao.isNatural1
            case .z: return ao.isIntO
            case .q: return ao.isRational
            case .r: return ao.isReal1
            case .f: return ao.isF
            case .string: return ao.isString
            case .array: return ao.isArray
            case .dic: return ao.isDic
            case .all: return O(true)
            }
        case .generics(let b):
            switch b {
            case .customArray(let bb):
                for (i, ao) in ao.elements.enumerated() {
                    guard i < bo.count else {
                        return O(false)
                    }
                    if O.isO(ao, bb[i]) == O(false) {
                        return O(false)
                    }
                }
                return O(true)
            case .customDic(let bb):
                switch ao {
                case .dic(let aa):
                    if aa.count != bb.count {
                        return O(false)
                    }
                    for (aaKey, aaValue) in aa {
                        if let bbo = bb[aaKey] {
                            if O.isO(aaValue, bbo) == O(false) {
                                return O(false)
                            }
                        } else {
                            return O(false)
                        }
                    }
                    return O(true)
                default:
                    return O(false)
                }
            case .array(let bb):
                return O(!ao.elements.contains(where: { O.isO($0, bb) == O(false) }))
            case .dic(let bbKey, let bbValue):
                switch ao {
                case .dic(let aa):
                    if aa.keys.contains(where: { O.isO($0, bbKey) == O(false) }) {
                        return O(false)
                    }
                    if aa.values.contains(where: { O.isO($0, bbValue) == O(false) }) {
                        return O(false)
                    }
                    return O(true)
                default:
                    return O(false)
                }
            }
        case .array(let b):
            return O(b.contains(ao))
        case .dic(let b):
            switch ao {
            case .dic(let a):
                for (aKey, bvo) in b {
                    if let avo = a[aKey] {
                        if O.isO(avo, bvo) == O(false) {
                            return O(false)
                        }
                    }
                }
                return O(true)
            default: return O(b.contains(where: { $1 == ao }))
            }
        default:
            return O.equalO(ao, bo)
        }
    }
}

extension O {
    static let mapName = "map"
    static func map(_ ao: O, _ bo: O, _ fun: ((F, O) -> (O))) -> O {
        switch ao {
        case .error: return ao
        default: break
        }
        switch bo {
        case .error: return bo
        default: break
        }
        
        guard case .f(let f) = bo else { return arrayArgsErrorO(withCount: 1, notCount: 0)  }
        let nf = f.with(isBlock: false)
        guard nf.outKeys.count == 1 else { return arrayArgsErrorO(withCount: 1, notCount: nf.outKeys.count) }
        
        switch ao {
        case .range(let a):
            switch a.type {
            case .fi, .fo, .li, .lo, .all:
                return O(OError.undefined(with: "\(ao.name) \(mapName) \(bo.name)"))
            default: break
            }
        default: break
        }
        switch ao {
        case .error(_): return ao
        default:
            var os = [O]()
            os.reserveCapacity(ao.count)
            for eo in ao.elements {
                let o = fun(nf, eo)
                if case .error = o {
                    return o
                } else {
                    os.append(o)
                }
            }
            return ao.with(os)
        }
    }
    static let filterName = "filter"
    static func filter(_ ao: O, _ bo: O, _ fun: ((F, O) -> (O))) -> O {
        switch ao {
        case .error: return ao
        default: break
        }
        switch bo {
        case .error: return bo
        default: break
        }
        
        guard case .f(let f) = bo else { return arrayArgsErrorO(withCount: 1, notCount: 0)  }
        let nf = f.with(isBlock: false)
        guard nf.outKeys.count == 1 else { return arrayArgsErrorO(withCount: 1, notCount: nf.outKeys.count) }
        
        switch ao {
        case .range(let a):
            switch a.type {
            case .fi, .fo, .li, .lo, .all:
                return O(OError.undefined(with: "\(ao.name) \(filterName) \(bo.name)"))
            default: break
            }
        default: break
        }
        switch ao {
        case .error(_): return ao
        default:
            var os = [O]()
            os.reserveCapacity(ao.count)
            for eo in ao.elements {
                let no = fun(nf, eo)
                switch no {
                case .bool(let b):
                    if b {
                        os.append(eo)
                    }
                case .error(_): return no
                default:
                    return O(OError("Return value is not bool".localized))
                }
            }
            return ao.with(os)
        }
    }
    static let reduceName = "reduce"
    static func reduce(_ ao: O, _ firstO: O, _ bo: O,
                       _ fun: ((F, O, O) -> (O))) -> O {
        switch ao {
        case .error: return ao
        default: break
        }
        switch bo {
        case .error: return bo
        default: break
        }
        
        guard case .f(let f) = bo else { return arrayArgsErrorO(withCount: 2, notCount: 0)  }
        let nf = f.with(isBlock: false)
        guard nf.outKeys.count == 2 else { return arrayArgsErrorO(withCount: 2, notCount: nf.outKeys.count) }
        
        switch ao {
        case .range(let a):
            switch a.type {
            case .fi, .fo, .li, .lo, .all:
                return O(OError.undefined(with: "\(ao.name) \(reduceName) \(firstO.name) \(bo.name)"))
            default: break
            }
        default: break
        }
        switch ao {
        case .error(_): return ao
        default:
            var no = firstO
            for eo in ao.elements {
                let nno = fun(nf, no, eo)
                if case .error = nno {
                    return nno
                } else {
                    no = nno
                }
            }
            return no
        }
    }
    
    static let makeMatrixName = ";"
    static func makeMatrix(_ ao: O) -> O {
        switch ao {
        case .array(let a):
            O(OArray(union: a.value))
        default:
            O(OArray([ao]))
        }
    }
    static let releaseMatrixName = ";-"
    static func releaseMatrix(_ ao: O) -> O {
        switch ao {
        case .array(let a):
            O(OArray(a.value, dimension: 1, nextCount: 1))
        default:
            ao
        }
    }
    func with(_ value: [O]) -> O {
        switch self {
        case .array(let a):
            O(OArray(union: value, currentDimension: a.dimension))
        default:
            O(OArray(value))
        }
    }
}

extension O {
    private enum InOut {
        case `in`, out
    }
    private static func random(in range: ClosedRange<Int>, _ inOut: InOut,
                               delta: Real1, _ o: O) -> O {
        if delta == 1 {
            let f = inOut == .out ?
                range.lowerBound + 1 : range.lowerBound
            let l = range.upperBound
            guard f <= l else { return rangeError(O(f), "<=", O(l)) }
            return O(Int.random(in: f ... l))
        } else {
            let f = inOut == .out ?
                (Real1(range.lowerBound) + (delta > 0 ? delta : .ulpOfOne)) :
                Real1(range.lowerBound)
            let l = Real1(range.upperBound)
            guard f <= l else { return rangeError(O(f), "<=", O(l)) }
            guard !f.isInfinite && !l.isInfinite else { return O(OError.undefined(with: "\(o.name) \(randomName)")) }
            if delta == 0 {
                return O(Real1.random(in: f ... l))
            } else if delta > 0 {
                let v = Real1.random(in: f ... l)
                return O((v - f).interval(scale: delta) + f)
            } else {
                fatalError()
            }
        }
    }
    private static func random(in range: ClosedRange<Rational>, _ inOut: InOut,
                               delta: Real1, _ o: O) -> O {
        let f = inOut == .out ?
            (Real1(range.lowerBound) + (delta > 0 ? delta : .ulpOfOne)) :
            Real1(range.lowerBound)
        let l = Real1(range.upperBound)
        guard f <= l else { return rangeError(O(f), "<=", O(l)) }
        guard !f.isInfinite && !l.isInfinite else { return O(OError.undefined(with: "\(o.name) \(randomName)")) }
        if delta == 0 {
            return O(Real1.random(in: f ... l))
        } else if delta > 0 {
            let v = Real1.random(in: f ... l)
            return O((v - f).interval(scale: delta) + f)
        } else {
            fatalError()
        }
    }
    private static func random(in range: ClosedRange<Real1>, _ inOut: InOut,
                               delta: Real1, _ o: O) -> O {
        let f = inOut == .out ?
            (range.lowerBound + (delta > 0 ? delta : .ulpOfOne)) :
            range.lowerBound
        let l = range.upperBound
        guard f <= l else { return rangeError(O(f), "<=", O(l)) }
        guard !f.isInfinite && !l.isInfinite else { return O(OError.undefined(with: "\(o.name) \(randomName)")) }
        let v = Real1.random(in: f ... l)
        if delta == 0 {
            return O(v)
        } else if delta > 0 {
            return O((v - range.lowerBound).interval(scale: delta)
                        + range.lowerBound)
        } else {
            fatalError()
        }
    }
    private static func random(in range: Range<Int>, _ inOut: InOut,
                               delta: Real1, _ o: O) -> O {
        if delta == 1 {
            let f = inOut == .out ?
                range.lowerBound + 1 : range.lowerBound
            let l = range.upperBound
            guard f < l else { return rangeError(O(f), "<", O(l)) }
            return O(Int.random(in: f ..< l))
        } else {
            let f = inOut == .out ?
                (Real1(range.lowerBound) + (delta > 0 ? delta : .ulpOfOne)) :
                Real1(range.lowerBound)
            let l = Real1(range.upperBound)
            guard f < l else { return rangeError(O(f), "<", O(l)) }
            guard !f.isInfinite && !l.isInfinite else { return O(OError.undefined(with: "\(o.name) \(randomName)")) }
            if delta == 0 {
                return O(Real1.random(in: f ..< l))
            } else if delta > 0 {
                let v = Real1.random(in: f ..< l)
                return O((v - f).interval(scale: delta) + f)
            } else {
                fatalError()
            }
        }
    }
    private static func random(in range: Range<Rational>, _ inOut: InOut,
                               delta: Real1, _ o: O) -> O {
        let f = inOut == .out ?
            (Real1(range.lowerBound) + (delta > 0 ? delta : .ulpOfOne)) :
            Real1(range.lowerBound)
        let l = Real1(range.upperBound)
        guard f < l else { return rangeError(O(f), "<", O(l)) }
        guard !f.isInfinite && !l.isInfinite else { return O(OError.undefined(with: "\(o.name) \(randomName)")) }
        if delta == 0 {
            return O(Real1.random(in: f ..< l))
        } else if delta > 0 {
            let v = Real1.random(in: f ..< l)
            return O((v - f).interval(scale: delta) + f)
        } else {
            fatalError()
        }
    }
    private static func random(in range: Range<Real1>, _ inOut: InOut,
                               delta: Real1, _ o: O) -> O {
        let f = inOut == .out ?
            (range.lowerBound + (delta > 0 ? delta : .ulpOfOne)) :
            range.lowerBound
        let l = range.upperBound
        guard f < l else { return rangeError(O(f), "<", O(l)) }
        guard !f.isInfinite && !l.isInfinite else { return O(OError.undefined(with: "\(o.name) \(randomName)")) }
        let v = Real1.random(in: f ..< l)
        if delta == 0 {
            return O(v)
        } else if delta > 0 {
            return O((v - range.lowerBound).interval(scale: delta)
                        + range.lowerBound)
        } else {
            fatalError()
        }
    }
    static let randomName = "random"
    var random: O {
        switch self {
        case .range(let range):
            let d = range.delta.asReal1 ?? 0
            switch range.type {
            case .fili(let ao, let bo):
                switch ao {
                case .bool(let a):
                    switch bo {
                    case .bool:
                        return O(Bool.random())
                    case .int(let b):
                        return .random(in: Int(a) ... b, .in, delta: d, self)
                    case .rational(let b):
                        return .random(in: Rational(a) ... b, .in, delta: d, self)
                    case .real1(let b):
                        return .random(in: Real1(a) ... b, .in, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .int(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ... Int(b), .in, delta: d, self)
                    case .int(let b):
                        return .random(in: a ... b, .in, delta: d, self)
                    case .rational(let b):
                        return .random(in: Rational(a) ... b, .in, delta: d, self)
                    case .real1(let b):
                        return .random(in: Real1(a) ... b, .in, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .rational(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ... Rational(b), .in, delta: d, self)
                    case .int(let b):
                        return .random(in: a ... Rational(b), .in, delta: d, self)
                    case .rational(let b):
                        return .random(in: a ... b, .in, delta: d, self)
                    case .real1(let b):
                        return .random(in: Real1(a) ... b, .in, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .real1(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ... Real1(b), .in, delta: d, self)
                    case .int(let b):
                        return .random(in: a ... Real1(b), .in, delta: d, self)
                    case .rational(let b):
                        return .random(in: a ... Real1(b), .in, delta: d, self)
                    case .real1(let b):
                        return .random(in: a ... b, .in, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                }
            case .filo(let ao, let bo):
                switch ao {
                case .bool(let a):
                    switch bo {
                    case .bool: return O(false)
                    case .int(let b):
                        return .random(in: Int(a) ..< b, .in, delta: d, self)
                    case .rational(let b):
                        return .random(in: Rational(a) ..< b, .in, delta: d, self)
                    case .real1(let b):
                        return .random(in: Real1(a) ..< b, .in, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .int(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ..< Int(b), .in, delta: d, self)
                    case .int(let b):
                        return .random(in: a ..< b, .in, delta: d, self)
                    case .rational(let b):
                        return .random(in: Rational(a) ..< b, .in, delta: d, self)
                    case .real1(let b):
                        return .random(in: Real1(a) ..< b, .in, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .rational(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ..< Rational(b), .in, delta: d, self)
                    case .int(let b):
                        return .random(in: a ..< Rational(b), .in, delta: d, self)
                    case .rational(let b):
                        return .random(in: a ..< b, .in, delta: d, self)
                    case .real1(let b):
                        return .random(in: Real1(a) ..< b, .in, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .real1(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ..< Real1(b), .in, delta: d, self)
                    case .int(let b):
                        return .random(in: a ..< Real1(b), .in, delta: d, self)
                    case .rational(let b):
                        return .random(in: a ..< Real1(b), .in, delta: d, self)
                    case .real1(let b):
                        return .random(in: a ..< b, .in, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                }
            case .foli(let ao, let bo):
                switch ao {
                case .bool(let a):
                    switch bo {
                    case .bool: return O(true)
                    case .int(let b):
                        return .random(in: Int(a) ... b, .out, delta: d, self)
                    case .rational(let b):
                        return .random(in: Rational(a) ... b, .out, delta: d, self)
                    case .real1(let b):
                        return .random(in: Real1(a) ... b, .out, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .int(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ... Int(b), .out, delta: d, self)
                    case .int(let b):
                        return .random(in: a ... b, .out, delta: d, self)
                    case .rational(let b):
                        return .random(in: Rational(a) ... b, .out, delta: d, self)
                    case .real1(let b):
                        return .random(in: Real1(a) ... b, .out, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .rational(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ... Rational(b), .out, delta: d, self)
                    case .int(let b):
                        return .random(in: a ... Rational(b), .out, delta: d, self)
                    case .rational(let b):
                        return .random(in: a ... b, .out, delta: d, self)
                    case .real1(let b):
                        return .random(in: Real1(a) ... b, .out, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .real1(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ... Real1(b), .out, delta: d, self)
                    case .int(let b):
                        return .random(in: a ... Real1(b), .out, delta: d, self)
                    case .rational(let b):
                        return .random(in: a ... Real1(b), .out, delta: d, self)
                    case .real1(let b):
                        return .random(in: a ... b, .out, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                }
            case .folo(let ao, let bo):
                switch ao {
                case .bool(let a):
                    switch bo {
                    case .bool: return O(true)
                    case .int(let b):
                        return .random(in: Int(a) ..< b, .out, delta: d, self)
                    case .rational(let b):
                        return .random(in: Rational(a) ..< b, .out, delta: d, self)
                    case .real1(let b):
                        return .random(in: Real1(a) ..< b, .out, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .int(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ..< Int(b), .out, delta: d, self)
                    case .int(let b):
                        return .random(in: a ..< b, .out, delta: d, self)
                    case .rational(let b):
                        return .random(in: Rational(a) ..< b, .out, delta: d, self)
                    case .real1(let b):
                        return .random(in: Real1(a) ..< b, .out, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .rational(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ..< Rational(b), .out, delta: d, self)
                    case .int(let b):
                        return .random(in: a ..< Rational(b), .out, delta: d, self)
                    case .rational(let b):
                        return .random(in: a ..< b, .out, delta: d, self)
                    case .real1(let b):
                        return .random(in: Real1(a) ..< b, .out, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .real1(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ..< Real1(b), .out, delta: d, self)
                    case .int(let b):
                        return .random(in: a ..< Real1(b), .out, delta: d, self)
                    case .rational(let b):
                        return .random(in: a ..< Real1(b), .out, delta: d, self)
                    case .real1(let b):
                        return .random(in: a ..< b, .out, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                }
            case .fi(let ao):
                switch ao {
                case .bool(let a):
                    return O(a ? true : Bool.random())
                case .int(let a):
                    return O.random(in: Real1(a) ... .infinity, .in, delta: d, self).rounded()
                case .rational(let a):
                    let n = O.random(in: Real1(a) ... .infinity, .in, delta: d, self)
                    if case .real1(let r) = n, let nn = Rational(exactly: r) {
                        return O(nn)
                    } else {
                        return n
                    }
                case .real1(let a):
                    return .random(in: a ... .infinity, .in, delta: d, self)
                default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                }
            case .fo(let ao):
                switch ao {
                case .bool(let a):
                    return a ? .empty : O(true)
                case .int(let a):
                    return O.random(in: Real1(a) ... .infinity, .out, delta: d, self).rounded()
                case .rational(let a):
                    let n = O.random(in: Real1(a) ... .infinity, .out, delta: d, self)
                    if case .real1(let r) = n, let nn = Rational(exactly: r) {
                        return O(nn)
                    } else {
                        return n
                    }
                case .real1(let a):
                    return .random(in: a ... .infinity, .out, delta: d, self)
                default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                }
            case .li(let ao):
                switch ao {
                case .bool(let a):
                    return O(a ? Bool.random() : false)
                case .int(let a):
                    return O.random(in: -.infinity ... Real1(a), .in, delta: d, self).rounded()
                case .rational(let a):
                    let n = O.random(in: -.infinity ... Real1(a), .in, delta: d, self)
                    if case .real1(let r) = n, let nn = Rational(exactly: r) {
                        return O(nn)
                    } else {
                        return n
                    }
                case .real1(let a):
                    return .random(in: -.infinity ... a, .in, delta: d, self)
                default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                }
            case .lo(let ao):
                switch ao {
                case .bool(let a):
                    return a ? O(false) : .empty
                case .int(let a):
                    return O.random(in: -.infinity ..< Real1(a), .in, delta: d, self).rounded()
                case .rational(let a):
                    let n = O.random(in: -.infinity ..< Real1(a), .in, delta: d, self)
                    if case .real1(let r) = n, let nn = Rational(exactly: r) {
                        return O(nn)
                    } else {
                        return n
                    }
                case .real1(let a):
                    return .random(in: -.infinity ..< a, .in, delta: d, self)
                default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                }
            case .all:
                return .random(in: -.infinity ..< .infinity, .in, delta: d, self)
            }
        case .array(let os):
            return os.randomElement() ?? .empty
        case .error: return self
        default: return self
        }
    }
}
