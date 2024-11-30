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

import struct Foundation.UUID

struct OSheet {
    var value: Sheet
    var bounds: Rect
    var undos: [UndoItemValue<SheetUndoItem>]
}
extension OSheet: Hashable {
    static func == (lhs: OSheet, rhs: OSheet) -> Bool {
        lhs.value == rhs.value
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}
extension OSheet {
    init(_ v: Sheet, bounds: Rect) {
        self.value = v
        self.bounds = bounds
        undos = []
    }
    private mutating func append(undo undoItem: SheetUndoItem,
                        redo redoItem: SheetUndoItem) {
        undos.append(UndoItemValue(undoItem: undoItem, redoItem: redoItem))
    }
    mutating func set(_ item: SheetUndoItem) {
        switch item {
        case .appendLine(let line):
            value.picture.lines.append(line)
        case .appendLines(let lines):
            value.picture.lines += lines
        case .insertLines(let livs):
            value.picture.lines.insert(livs)
        case .removeLines(let lineIndexes):
            value.picture.lines.remove(at: lineIndexes)
        case .insertTexts(let tivs):
            value.texts.insert(tivs)
        case .removeTexts(let textIndexes):
            value.texts.remove(at: textIndexes)
        default: fatalError()
        }
    }
    mutating func append(_ line: Line) {
        let undoItem = SheetUndoItem.removeLastLines(count: 1)
        let redoItem = SheetUndoItem.appendLine(line)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    mutating func append(_ lines: [Line]) {
        if lines.count == 1 {
            append(lines[0])
        } else {
            let undoItem = SheetUndoItem.removeLastLines(count: lines.count)
            let redoItem = SheetUndoItem.appendLines(lines)
            append(undo: undoItem, redo: redoItem)
            set(redoItem)
        }
    }
    mutating func insert(_ livs: [IndexValue<Line>]) {
        let undoItem = SheetUndoItem
            .removeLines(lineIndexes: livs.map { $0.index })
        let redoItem = SheetUndoItem.insertLines(livs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    mutating func replace(_ livs: [IndexValue<Line>]) {
        let ivs = livs.map { $0.index }
        let olivs = livs
            .map { IndexValue(value: value.picture.lines[$0.index],
                              index: $0.index) }
        let undoItem0 = SheetUndoItem.insertLines(olivs)
        let redoItem0 = SheetUndoItem.removeLines(lineIndexes: ivs)
        append(undo: undoItem0, redo: redoItem0)
        
        let undoItem1 = SheetUndoItem.removeLines(lineIndexes: ivs)
        let redoItem1 = SheetUndoItem.insertLines(livs)
        append(undo: undoItem1, redo: redoItem1)
        
        livs.forEach { value.picture.lines[$0.index] = $0.value }
    }
    mutating func removeLines(at lineIndexes: [Int]) {
        let livs = lineIndexes.map {
            IndexValue(value: value.picture.lines[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertLines(livs)
        let redoItem = SheetUndoItem.removeLines(lineIndexes: lineIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    mutating func append(_ text: Text) {
        let undoItem = SheetUndoItem.removeTexts(textIndexes: [value.texts.count])
        let redoItem = SheetUndoItem
            .insertTexts([IndexValue(value: text, index: value.texts.count)])
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    mutating func append(_ texts: [Text]) {
        let undoItem = SheetUndoItem.removeTexts(textIndexes: Array(value.texts.count ..< (value.texts.count + texts.count)))
        let redoItem = SheetUndoItem.insertTexts(texts.enumerated().map {
            IndexValue(value: $0.element, index: value.texts.count + $0.offset)
        })
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    mutating func insert(_ tivs: [IndexValue<Text>]) {
        let undoItem = SheetUndoItem.removeTexts(textIndexes: tivs
                                                    .map { $0.index })
        let redoItem = SheetUndoItem.insertTexts(tivs)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    mutating func replace(_ tivs: [IndexValue<Text>]) {
        let ivs = tivs.map { $0.index }
        let otivs = tivs
            .map { IndexValue(value: value.texts[$0.index], index: $0.index) }
        let undoItem0 = SheetUndoItem.insertTexts(otivs)
        let redoItem0 = SheetUndoItem.removeTexts(textIndexes: ivs)
        append(undo: undoItem0, redo: redoItem0)
        
        let undoItem1 = SheetUndoItem.removeTexts(textIndexes: ivs)
        let redoItem1 = SheetUndoItem.insertTexts(tivs)
        append(undo: undoItem1, redo: redoItem1)
        
        tivs.forEach { value.texts[$0.index] = $0.value }
    }
    mutating func removeText(at textIndex: Int) {
        removeTexts(at: [textIndex])
    }
    mutating func removeTexts(at textIndexes: [Int]) {
        let tivs = textIndexes.map {
            IndexValue(value: value.texts[$0], index: $0)
        }
        let undoItem = SheetUndoItem.insertTexts(tivs)
        let redoItem = SheetUndoItem.removeTexts(textIndexes: textIndexes)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    mutating func removeAll() {
        if !value.picture.lines.isEmpty {
            removeLines(at: Array(0 ..< value.picture.lines.count))
        }
        if !value.texts.isEmpty {
            removeTexts(at: Array(0 ..< value.texts.count))
        }
    }
}
extension Sheet {
    func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Sheet {
        let lines = picture.lines.map { $0.rounded(rule) }
        let texts = self.texts.map { Text(string: $0.string,
                                          orientation: $0.orientation,
                                          size: $0.size.rounded(rule),
                                          origin: $0.origin.rounded(rule)) }
        let kf = Keyframe(picture: Picture(lines: lines, planes: []))
        return Sheet(animation: Animation(keyframes: [kf]),
                     texts: texts,
                     borders: borders,
                     backgroundUUColor: backgroundUUColor)
    }
}
extension OSheet {
    func rounded(_ rule: FloatingPointRoundingRule
                    = .toNearestOrAwayFromZero) -> OSheet {
        let ss = value.rounded(rule)
        var v = self
        v.removeTexts(at: Array(0 ..< v.value.texts.count))
        v.removeLines(at: Array(0 ..< v.value.picture.lines.count))
        v.insert(ss.texts.enumerated()
                    .map { IndexValue(value: $0.element, index: $0.offset) })
        v.insert(ss.picture.lines.enumerated()
                    .map { IndexValue(value: $0.element, index: $0.offset) })
        return v
    }
}

struct OArray: Hashable, BidirectionalCollection {
    var value: [O], dimension: Int, nextCount: Int
}
extension OArray {
    init(_ value: [O], dimension: Int = 1, nextCount: Int = 1) {
        self.value = value
        self.dimension = dimension
        self.nextCount = nextCount
    }
    init(union value: [O], currentDimension: Int? = nil) {
        guard let f = value.first else {
            self.init(value)
            return
        }
        switch f {
        case .array(let a):
            let d = a.dimension, nextCount = a.value.count
            if let od = currentDimension, od == 1 || od != d + 1 {
                self.init(value)
                return
            }
            for e in value {
                switch e {
                case .array(let b):
                    if b.count != nextCount || b.dimension != d {
                        self.init(value)
                        return
                    }
                default:
                    self.init(value)
                    return
                }
            }
            self.init(value, dimension: d + 1, nextCount: nextCount)
        default:
            self.init(value)
        }
    }
    
    var startIndex: Int {
        value.startIndex
    }
    var endIndex: Int {
        value.endIndex
    }
    var count: Int {
        value.count
    }
    func index(before i: Int) -> Int {
        value.index(before: i)
    }
    func index(after i: Int) -> Int {
        value.index(after: i)
    }
    subscript(i: Int) -> O {
        get { value[i] }
        set { value[i] = newValue }
    }
    
    func isEqualDimension(_ other: OArray) -> Bool {
        count == other.count
            && dimension == other.dimension
            && nextCount == other.nextCount
    }
    func with(_ value: [O]) -> Self {
        .init(value, dimension: dimension, nextCount: nextCount)
    }
    
    static func ** (lhs: Self, rhs: O) -> Self {
        .init(lhs.map { $0 ** rhs }, dimension: lhs.dimension, nextCount: lhs.nextCount)
    }
    static func ** (lhs: O, rhs: Self) -> Self {
        .init(rhs.map { lhs ** $0 }, dimension: rhs.dimension, nextCount: rhs.nextCount)
    }
    static func apow(_ lhs: Self, _ rhs: O) -> Self {
        .init(lhs.map { O.apow($0, rhs) }, dimension: lhs.dimension, nextCount: lhs.nextCount)
    }
    static func apow(_ lhs: O, _ rhs: Self) -> Self {
        .init(rhs.map { O.apow(lhs, $0) }, dimension: rhs.dimension, nextCount: rhs.nextCount)
    }
    static func * (lhs: Self, rhs: O) -> Self {
        .init(lhs.map { $0 * rhs }, dimension: lhs.dimension, nextCount: lhs.nextCount)
    }
    static func * (lhs: O, rhs: Self) -> Self {
        .init(rhs.map { lhs * $0 }, dimension: rhs.dimension, nextCount: rhs.nextCount)
    }
    static func / (lhs: Self, rhs: O) -> Self {
        .init(lhs.map { $0 / rhs }, dimension: lhs.dimension, nextCount: lhs.nextCount)
    }
    static func / (lhs: O, rhs: Self) -> Self {
        .init(rhs.map { lhs / $0 }, dimension: rhs.dimension, nextCount: rhs.nextCount)
    }
    static func % (lhs: Self, rhs: O) -> Self {
        .init(lhs.map { $0 % rhs }, dimension: lhs.dimension, nextCount: lhs.nextCount)
    }
    static func % (lhs: O, rhs: Self) -> Self {
        .init(rhs.map { lhs % $0 }, dimension: rhs.dimension, nextCount: rhs.nextCount)
    }
    static func + (lhs: Self, rhs: O) -> Self {
        .init(lhs.map { $0 + rhs }, dimension: lhs.dimension, nextCount: lhs.nextCount)
    }
    static func + (lhs: O, rhs: Self) -> Self {
        .init(rhs.map { lhs + $0 }, dimension: rhs.dimension, nextCount: rhs.nextCount)
    }
    static func - (lhs: Self, rhs: O) -> Self {
        .init(lhs.map { $0 - rhs }, dimension: lhs.dimension, nextCount: lhs.nextCount)
    }
    static func - (lhs: O, rhs: Self) -> Self {
        .init(rhs.map { lhs - $0 }, dimension: rhs.dimension, nextCount: rhs.nextCount)
    }
    func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Self {
        .init(value: value.rounded(rule), dimension: dimension, nextCount: nextCount)
    }
}

struct ORange: Hashable {
    enum RangeType: Hashable {
        case fili(O, O)
        case filo(O, O)
        case foli(O, O)
        case folo(O, O)
        case fi(O)
        case fo(O)
        case li(O)
        case lo(O)
        case all
    }
    let type: RangeType, delta: O
    
    init(_ type: RangeType, delta: O) {
        self.type = type
        self.delta = delta
    }
}
extension ORange {
    static func ** (lhs: Self, rhs: O) -> Self {
        Self.cal(lhs: lhs, rhs: rhs, fn: **)
    }
    static func ** (lhs: O, rhs: Self) -> Self {
        Self.cal(lhs: lhs, rhs: rhs, fn: **)
    }
    static func apow(_ lhs: Self, _ rhs: O) -> Self {
        Self.cal(lhs: lhs, rhs: rhs, fn: O.apow)
    }
    static func apow(_ lhs: O, _ rhs: Self) -> Self {
        Self.cal(lhs: lhs, rhs: rhs, fn: O.apow)
    }
    static func * (lhs: Self, rhs: O) -> Self {
        Self.cal(lhs: lhs, rhs: rhs, fn: *)
    }
    static func * (lhs: O, rhs: Self) -> Self {
        Self.cal(lhs: lhs, rhs: rhs, fn: *)
    }
    static func / (lhs: Self, rhs: O) -> Self {
        Self.cal(lhs: lhs, rhs: rhs, fn: /)
    }
    static func / (lhs: O, rhs: Self) -> Self {
        Self.cal(lhs: lhs, rhs: rhs, fn: /)
    }
    static func % (lhs: Self, rhs: O) -> Self {
        Self.cal(lhs: lhs, rhs: rhs, fn: %)
    }
    static func % (lhs: O, rhs: Self) -> Self {
        Self.cal(lhs: lhs, rhs: rhs, fn: %)
    }
    static func + (lhs: Self, rhs: O) -> Self {
        Self.cal(lhs: lhs, rhs: rhs, fn: +)
    }
    static func + (lhs: O, rhs: Self) -> Self {
        Self.cal(lhs: lhs, rhs: rhs, fn: +)
    }
    static func - (lhs: Self, rhs: O) -> Self {
        Self.cal(lhs: lhs, rhs: rhs, fn: -)
    }
    static func - (lhs: O, rhs: Self) -> Self {
        Self.cal(lhs: lhs, rhs: rhs, fn: -)
    }
    static func cal(lhs: O, rhs: Self, fn: (O, O) -> (O)) -> Self {
        switch rhs.type {
        case .fili(let f, let l): .init(.fili(fn(lhs, f), fn(lhs, l)), delta: fn(lhs, rhs.delta))
        case .filo(let f, let l): .init(.filo(fn(lhs, f), fn(lhs, l)), delta: fn(lhs, rhs.delta))
        case .foli(let f, let l): .init(.foli(fn(lhs, f), fn(lhs, l)), delta: fn(lhs, rhs.delta))
        case .folo(let f, let l): .init(.folo(fn(lhs, f), fn(lhs, l)), delta: fn(lhs, rhs.delta))
        case .fi(let f): .init(.fi(fn(lhs, f)), delta: fn(lhs, rhs.delta))
        case .fo(let f): .init(.fo(fn(lhs, f)), delta: fn(lhs, rhs.delta))
        case .li(let l): .init(.li(fn(lhs, l)), delta: fn(lhs, rhs.delta))
        case .lo(let l): .init(.lo(fn(lhs, l)), delta: fn(lhs, rhs.delta))
        case .all: rhs
        }
    }
    static func cal(lhs: Self, rhs: O, fn: (O, O) -> (O)) -> Self {
        switch lhs.type {
        case .fili(let f, let l): .init(.fili(fn(f, rhs), fn(l, rhs)), delta: fn(lhs.delta, rhs))
        case .filo(let f, let l): .init(.filo(fn(f, rhs), fn(l, rhs)), delta: fn(lhs.delta, rhs))
        case .foli(let f, let l): .init(.foli(fn(f, rhs), fn(l, rhs)), delta: fn(lhs.delta, rhs))
        case .folo(let f, let l): .init(.folo(fn(f, rhs), fn(l, rhs)), delta: fn(lhs.delta, rhs))
        case .fi(let f): .init(.fi(fn(f, rhs)), delta: fn(lhs.delta, rhs))
        case .fo(let f): .init(.fo(fn(f, rhs)), delta: fn(lhs.delta, rhs))
        case .li(let l): .init(.li(fn(l, rhs)), delta: fn(lhs.delta, rhs))
        case .lo(let l): .init(.lo(fn(l, rhs)), delta: fn(lhs.delta, rhs))
        case .all: lhs
        }
    }
    func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> ORange {
        switch type {
        case .fili(let f, let l):
            if f.isInt && l.isInt && delta.isInt {
                self
            } else {
                ORange(.fili(f.rounded(rule), l.rounded(rule)), delta: delta.rounded(rule))
            }
        case .filo(let f, let l):
            if f.isInt && l.isInt && delta.isInt {
                self
            } else {
                ORange(.filo(f.rounded(rule), l.rounded(rule)), delta: delta.rounded(rule))
            }
        case .foli(let f, let l):
            if f.isInt && l.isInt && delta.isInt {
                self
            } else {
                ORange(.foli(f.rounded(rule), l.rounded(rule)), delta: delta.rounded(rule))
            }
        case .folo(let f, let l):
            if f.isInt && l.isInt && delta.isInt {
                self
            } else {
                ORange(.folo(f.rounded(rule), l.rounded(rule)), delta: delta.rounded(rule))
            }
        case .fi(let f):
            if f.isInt && delta.isInt {
                self
            } else {
                ORange(.fi(f.rounded(rule)), delta: delta.rounded(rule))
            }
        case .fo(let f):
            if f.isInt && delta.isInt {
                self
            } else {
                ORange(.fo(f.rounded(rule)), delta: delta.rounded(rule))
            }
        case .li(let l):
            if l.isInt && delta.isInt {
                self
            } else {
                ORange(.li(l.rounded(rule)), delta: delta.rounded(rule))
            }
        case .lo(let l):
            if l.isInt && delta.isInt {
                self
            } else {
                ORange(.lo(l.rounded(rule)), delta: delta.rounded(rule))
            }
        case .all:
            if delta.isInt {
                self
            } else {
                ORange(.all, delta: delta.rounded(rule))
            }
        }
    }
}

enum G: String, Hashable, CaseIterable {
    case empty = "Nil"
    case b = "B", n0 = "N0", n1 = "N1", z = "Z", q = "Q", r = "R"
    case string = "String", array = "Array", dic = "Dic"
    case f = "F", all = "All"
}
extension G {
    var displayString: String {
        switch self {
        case .empty: "\("Empty".localized)"
        case .b: "Bool".localized
        case .n0: "Whole number".localized
        case .n1: "Natural number".localized
        case .z: "Integer number".localized
        case .q: "Rational number".localized
        case .r: "Real number".localized
        case .string: "String".localized
        case .array: "Array".localized
        case .dic: "Dictionary".localized
        case .f: "Function".localized
        case .all: "All".localized
        }
    }
}
enum Generics: Hashable {
    case customArray([O])
    case customDic([O: O])
    case array(element: O)
    case dic(key: O, value: O)
    //matrix mxn
}
extension Generics {
    func rounded(_ rule: FloatingPointRoundingRule
                    = .toNearestOrAwayFromZero) -> Generics {
        switch self {
        case .customArray(let a):
             .customArray(a.rounded(rule))
        case .customDic(let a):
             .customDic(a.rounded(rule))
        case .array(let element):
             .array(element: element.rounded(rule))
        case .dic(let key, let value):
             .dic(key: key.rounded(rule), value: value.rounded(rule))
        }
    }
}
extension Generics: CustomStringConvertible {
    var description: String {
        switch self {
        case .customArray(let a):
             a.description
        case .customDic(let a):
             a.description
        case .array(let element):
             "\(element.description)]"
        case .dic(let key, let value):
             "\(key.description):\(value.description)]"
        }
    }
}

struct Selected: Hashable {
    var o: O, ranges: [O]
    init(_ o: O, ranges: [O]) {
        self.o = o
        self.ranges = ranges
    }
}
extension Selected {
    func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Selected {
        Selected(o.rounded(rule), ranges: ranges.rounded(rule))
    }
}

struct OKeyInfo {
    struct Group: Hashable {
        var name: String, index: Int = 0
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(index)
        }
    }
    var group: Group
    var index: Int
    var description: String
    
    init(_ g: Group, _ desc: String) {
        group = g
        index = 0
        description = desc
    }
    init(_ g: Group, _ i: Int, _ desc: String) {
        group = g
        index = i
        description = desc
    }
}
struct OKey {
    var baseString: String, string: String
    private let aHashValue: Int
    var info: OKeyInfo?
    init(_ c: Character) {
        string = String(c)
        baseString = string
        info = nil
        aHashValue = c.hashValue
    }
    init(_ s: Substring) {
        string = String(s)
        baseString = string
        info = nil
        aHashValue = s.hashValue
    }
    init(_ s: String = "", base: String? = nil, _ info: OKeyInfo? = nil) {
        string = s
        baseString = base ?? s
        self.info = info
        aHashValue = s.hashValue
    }
}
extension OKey: Hashable {
    static func == (lhs: OKey, rhs: OKey) -> Bool {
        lhs.string == rhs.string
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(aHashValue)
    }
}
extension OKey: CustomStringConvertible {
    var description: String {
        string
    }
}

struct Argument: Hashable {
    var inKey: OKey?, outKey = OKey("")
}
struct F: Hashable, Sendable {
    enum AssociativityType: String {
        case left, right
    }
    enum FType: String {
        case empty, left, right, binary
    }
    enum RunType {
        case pow, apow, multiply, division, modulo, addition, subtraction,
             equal, notEqual, less, greater, lessEqual, greaterEqual,
             not, floor, round, ceil, abs, sqrt, sin, cos, tan, asin, acos, atan, atan2, plus, minus,
             filiZ, filoZ, foliZ, foloZ, fiZ, foZ, liZ, loZ, filiR, filoR, foliR, foloR, fiR, foR, liR, loR, delta,
             counta, at, select, set, insert, remove, makeMatrix, releaseMatrix, `is`,
             random, asLabel, asString, asError, isError,
             send, showAboutRun, showAllDefinitions,
             draw, drawAxes, plot, flip, map, filter, reduce, custom
    }
    
    let precedence: Int, associativity: AssociativityType
    let rpn: RPN?
    let isBlock: Bool
    let type: FType
    let leftArguments: [Argument], rightArguments: [Argument]
    let outKeys: [OKey]
    let definitions: [OKey: F]
    let os: [O]
    let isShortCircuit: Bool
    let runType: RunType
    let id = UUID()
}
extension F.FType: CustomStringConvertible {
    var description: String {
        rawValue
    }
}
extension F.FType {
    func key(from str: String,
             leftString: String = "$", rightString: String = "$",
             info: OKeyInfo? = nil) -> OKey {
        switch self {
        case .left: OKey("\(str)\(rightString)", base: str, info)
        case .right: OKey("\(leftString)\(str)", base: str, info)
        case .binary: OKey("\(leftString)\(str)\(rightString)",
                                  base: str, info)
        default: OKey(str, base: str, info)
        }
    }
}
extension F {
    init(_ precedence: Int = F.defaultPrecedence,
         _ associativity: AssociativityType = .left,
         left leftKeywords: [String],
         right rightKeywords: [String],
         isShortCircuit: Bool = false,
         _ runType: RunType = .custom)  {
        
        let la = leftKeywords.enumerated().map { (i, str) in
            Argument(inKey: !str.isEmpty ? OKey(str) : nil,
                     outKey: OKey("$\(i)"))
        }
        let ra = rightKeywords.enumerated().map { (i, str) in
            Argument(inKey: !str.isEmpty ? OKey(str) : nil,
                     outKey: OKey("$\(i + leftKeywords.count)"))
        }
        self.init(precedence: precedence, associativity: associativity,
                  left: la, right: ra, [:], os: [],
                  isShortCircuit: isShortCircuit,
                  runType)
    }
    init(_ precedence: Int = F.defaultPrecedence,
         _ associativity: AssociativityType = .left,
         right rightCount: Int,
         definitions: [OKey: F] = [:], os: [O] = [],
         isShortCircuit: Bool = false,
         _ runType: RunType = .custom)  {
        
        let ra = (0 ..< rightCount).map { Argument(inKey: nil, outKey: OKey("$\($0)")) }
        self.init(precedence: precedence, associativity: associativity,
                  left: [], right: ra, definitions, os: os,
                  isShortCircuit: isShortCircuit,
                  runType)
    }
    init(_ precedence: Int = F.defaultPrecedence,
         _ associativity: AssociativityType = .left,
         left leftCount: Int,
         definitions: [OKey: F] = [:], os: [O] = [],
         isShortCircuit: Bool = false,
         _ runType: RunType = .custom)  {
        
        let la = (0 ..< leftCount).map { Argument(inKey: nil, outKey: OKey("$\($0)")) }
        self.init(precedence: precedence, associativity: associativity,
                  left: la, right: [], definitions, os: os,
                  isShortCircuit: isShortCircuit,
                  runType)
    }
    init(_ precedence: Int = F.defaultPrecedence,
         _ associativity: AssociativityType = .left,
         left leftCount: Int,
         right rightCount: Int,
         definitions: [OKey: F] = [:], os: [O] = [],
         isShortCircuit: Bool = false,
         _ runType: RunType = .custom)  {
        
        let la = (0 ..< leftCount).map {
            Argument(inKey: nil, outKey: OKey("$\($0)"))
        }
        let ra = (0 ..< rightCount).map {
            Argument(inKey: nil, outKey: OKey("$\($0 + leftCount)"))
        }
        self.init(precedence: precedence, associativity: associativity,
                  left: la, right: ra, definitions, os: os,
                  isShortCircuit: isShortCircuit,
                  runType)
    }
    init(precedence: Int = F.defaultPrecedence,
         associativity: AssociativityType = .left,
         left leftArguments: [Argument] = [],
         right rightArguments: [Argument] = [],
         _ definitions: [OKey: F] = [:], os: [O] = [],
         isShortCircuit: Bool = false,
         _ runType: RunType = .custom) {
        
        self.precedence = precedence
        if leftArguments.isEmpty {
            type = rightArguments.isEmpty ? .empty : .left
            self.associativity = rightArguments.isEmpty ?
                associativity : .right
        } else {
            type = rightArguments.isEmpty ? .right : .binary
            self.associativity = rightArguments.isEmpty ?
                .left : associativity
        }
        rpn = nil
        isBlock = false
        self.leftArguments = leftArguments
        self.rightArguments = rightArguments
        self.definitions = definitions
        self.os = os
        self.isShortCircuit = isShortCircuit
        self.runType = runType
        outKeys = leftArguments.map { $0.outKey } + rightArguments.map { $0.outKey }
    }
    init(_ os: [O]) {
        precedence = F.defaultPrecedence
        rpn = nil
        isBlock = false
        type = .empty
        associativity = .left
        leftArguments = []
        rightArguments = []
        definitions = [:]
        self.os = os
        self.isShortCircuit = false
        runType = .custom
        outKeys = []
    }
    init(_ rpn: RPN, isBlock: Bool) {
        self.rpn = rpn
        precedence = F.defaultPrecedence
        self.isBlock = isBlock
        type = .empty
        associativity = .left
        leftArguments = []
        rightArguments = []
        definitions = [:]
        os = []
        self.isShortCircuit = false
        runType = .custom
        outKeys = []
    }
    
    func run(_ args: [O]) -> O? {
        switch runType {
        case .pow: args[0] ** args[1]
        case .apow: .apow(args[0], args[1])
        case .multiply: args[0] * args[1]
        case .division: args[0] / args[1]
        case .modulo: args[0] % args[1]
        case .addition: args[0] + args[1]
        case .subtraction: args[0] - args[1]
        case .equal: .equalO(args[0], args[1])
        case .notEqual: .notEqualO(args[0], args[1])
        case .less: .lessO(args[0], args[1])
        case .greater: .greaterO(args[0], args[1])
        case .lessEqual: .lessEqualO(args[0], args[1])
        case .greaterEqual: .greaterEqualO(args[0], args[1])
        case .not: !args[0]
        case .floor: args[0].floor
        case .round: args[0].round
        case .ceil: args[0].ceil
        case .abs: args[0].absV
        case .sqrt: args[0].sqrt
        case .sin: args[0].sin
        case .cos: args[0].cos
        case .tan: args[0].tan
        case .asin: args[0].asin
        case .acos: args[0].acos
        case .atan: args[0].atan
        case .atan2: args[0].atan2
        case .plus: +args[0]
        case .minus: -args[0]
        case .filiZ: .rangeO(.fili(args[0], args[1]), isSmooth: false)
        case .filoZ: .rangeO(.filo(args[0], args[1]), isSmooth: false)
        case .foliZ: .rangeO(.foli(args[0], args[1]), isSmooth: false)
        case .foloZ: .rangeO(.folo(args[0], args[1]), isSmooth: false)
        case .fiZ: .rangeO(.fi(args[0]), isSmooth: false)
        case .foZ: .rangeO(.fo(args[0]), isSmooth: false)
        case .liZ: .rangeO(.li(args[0]), isSmooth: false)
        case .loZ: .rangeO(.lo(args[0]), isSmooth: false)
        case .filiR: .rangeO(.fili(args[0], args[1]), isSmooth: true)
        case .filoR: .rangeO(.filo(args[0], args[1]), isSmooth: true)
        case .foliR: .rangeO(.foli(args[0], args[1]), isSmooth: true)
        case .foloR: .rangeO(.folo(args[0], args[1]), isSmooth: true)
        case .fiR: .rangeO(.fi(args[0]), isSmooth: true)
        case .foR: .rangeO(.fo(args[0]), isSmooth: true)
        case .liR: .rangeO(.li(args[0]), isSmooth: true)
        case .loR: .rangeO(.lo(args[0]), isSmooth: true)
        case .delta: .deltaO(args[0], args[1])
        case .counta: args[0].counta
        case .at: .at(args[0], args[1])
        case .select: .select(args[0], args[1])
        case .set: .set(args[0], args[1])
        case .insert: .insert(args[0], args[1])
        case .remove: .remove(args[0])
        case .makeMatrix: .makeMatrix(args[0])
        case .releaseMatrix: .releaseMatrix(args[0])
        case .is: .isO(args[0], args[1])
        case .random: args[0].random
        case .asLabel: args[0].asLabel
        case .asString: args[0].asStringO
        case .asError: args[0].asError
        case .isError: args[0].isErrorO
        case .showAboutRun: .showAboutRun(args[0])
        case .send, .showAllDefinitions,
                .draw, .drawAxes, .plot, .flip, .map, .filter, .reduce, .custom: nil
        }
    }
    
    func with(isBlock: Bool) -> F {
        F(precedence: precedence, associativity: associativity,
          rpn: rpn, isBlock: isBlock,
          type: type,
          leftArguments: leftArguments, rightArguments: rightArguments,
          outKeys: outKeys,
          definitions: definitions, os: os,
          isShortCircuit: isShortCircuit,
          runType: runType)
    }
    
    func key(from str: String, info: OKeyInfo? = nil) -> OKey {
        func argumentString(from args: [Argument]) -> String {
             return args.reduce(into: "") {
                if let str = $1.inKey?.string {
                    $0 += "$" + str + "$"
                } else {
                    $0 += "$"
                }
            }
        }
        return type.key(from: str,
                        leftString: argumentString(from: leftArguments),
                        rightString: argumentString(from: rightArguments),
                        info: info)
    }
}
extension F: CustomStringConvertible {
    func argsString(from args: [Argument]) -> String {
        args.reduce(into: "") {
            if let str = $1.inKey?.string {
                $0 += ($0.isEmpty ? "" : " ") + str + ": " + $1.outKey.string
            } else {
                $0 += ($0.isEmpty ? "" : " ") + $1.outKey.string
            }
        }
    }
    func argString(name: String = "$") -> String {
        var argStr = ""
        if !leftArguments.isEmpty {
            argStr += "(\(argsString(from: leftArguments)))"
        }
        argStr += name
        if !rightArguments.isEmpty {
            argStr += "(\(argsString(from: rightArguments)))"
        }
        if type == .binary || type == .right {
            if (precedence != F.defaultPrecedence || associativity == .right)
                && type == .right {
                
                argStr += "()"
            }
            if precedence != F.defaultPrecedence {
                argStr += "\(precedence)"
            }
            if associativity == .right {
                argStr += "r"
            }
        }
        return argStr
    }
    var definitionsAndOsDescription: String {
        var isLabel = false
        let ooss = os.reduce(into: "") {
            if case .label = $1 {
                isLabel = true
            }
            $0 += $0.isEmpty ? $1.asString : " "
                + $1.asString
        }
        let oss = isLabel ? "(" + ooss + ")" : ooss

        if definitions.isEmpty {
            return oss
        } else {
            let ds = definitions.reduce(into: "") {
                var fs = $1.value.definitionsAndOsDescription
                if !$1.value.definitions.isEmpty {
                    fs.insert("(", at: fs.startIndex)
                    fs.append(")")
                }
                $0 += ($0.isEmpty ? "" : " ")
                    + $1.value.argString(name: $1.key.baseString) + ": " + fs
            }
            return ds + " | " + oss
        }
    }
    var description: String {
        var s = definitionsAndOsDescription
        if definitions.isEmpty && os.count == 1, case .f = os[0] {
        } else {
            s = O.removeFirstAndLastBrackets(s)
        }
        if type == .empty {
            return isBlock ? "(| \(s))" : "(\(s))"
        } else if precedence == F.defaultPrecedence && associativity == .left
            && !leftArguments.isEmpty
            && !leftArguments.contains(where: { $0.inKey != nil })
            && rightArguments.isEmpty {
            
            return "(\(argsString(from: leftArguments)) | \(s))"
        } else {
            return "(\(argString()) | \(s))"
        }
    }
}
extension F {
    static let defaultPrecedence = 200
}
extension F {
    func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> F {
        F(precedence: precedence, associativity: associativity,
          rpn: rpn, isBlock: isBlock,
          type: type,
          leftArguments: leftArguments, rightArguments: rightArguments,
          outKeys: outKeys,
          definitions: definitions.reduce(into: .init()) { $0[$1.key] = $1.value.rounded(rule) },
          os: os.rounded(rule),
          isShortCircuit: isShortCircuit,
          runType: runType)
    }
}

struct ID {
    var key: OKey {
        didSet { aHashValue = key.hashValue }
    }
    var isInactivity: Bool
    private var aHashValue: Int
    var typobute: Typobute?, typoBounds: Rect?
}
extension ID {
    init(_ str: String, isInactivity: Bool = false,
         _ typobute: Typobute? = nil,
         _ typoBounds: Rect? = nil) {
        key = OKey(str)
        aHashValue = key.hashValue
        self.isInactivity = isInactivity
        self.typobute = typobute
        self.typoBounds = typoBounds
    }
    func with(_ typobute: Typobute?, typoBounds: Rect?) -> ID {
        ID(key: key, isInactivity: isInactivity,
           aHashValue: hashValue,
           typobute: typobute,
           typoBounds: typoBounds)
    }
}
extension ID: Hashable {
    static func == (lhs: ID, rhs: ID) -> Bool {
        lhs.key == rhs.key
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(aHashValue)
    }
}
extension ID: CustomStringConvertible {
    var description: String {
        key.description
    }
}

struct OLabel: Hashable {
    var o: O, isMatrix = false
}
extension OLabel {
    init(_ o: O, isMatrix: Bool = false) {
        self.o = o
        self.isMatrix = isMatrix
    }
}
extension OLabel {
    func rounded(_ rule: FloatingPointRoundingRule
                    = .toNearestOrAwayFromZero) -> OLabel {
        OLabel(o.rounded(rule), isMatrix: isMatrix)
    }
}
extension OLabel: CustomStringConvertible {
    var description: String {
        o.asString + ":"
    }
}

struct IDF: Hashable {
    var key: OKey, f: F, v: ID?
}
extension IDF {
    func rounded(_ rule: FloatingPointRoundingRule
                    = .toNearestOrAwayFromZero) -> IDF {
        IDF(key: key, f: f.rounded(rule), v: v)
    }
}
enum OIDF: Hashable {
    case oOrBlockO(O), calculateON0(F), calculateVN0(ID), calculateVN1(IDF)
}
extension OIDF: CustomStringConvertible {
    var description: String {
        switch self {
        case .oOrBlockO(let o): "ob: " + o.description
        case .calculateON0(let o): "o0: " + o.description
        case .calculateVN0(let v): "v0: " + v.description
        case .calculateVN1(let idf): "idf: " + idf.key.string
        }
    }
}
extension OIDF {
    func rounded(_ rule: FloatingPointRoundingRule
                    = .toNearestOrAwayFromZero) -> OIDF {
        switch self {
        case .oOrBlockO(let o): .oOrBlockO(o.rounded(rule))
        case .calculateON0(let f): .calculateON0(f.rounded(rule))
        case .calculateVN0(let v): .calculateVN0(v)
        case .calculateVN1(let idf): .calculateVN1(idf.rounded(rule))
        }
    }
}
struct RPN: Hashable {
    var oidfs = [OIDF]()
}
extension RPN {
    func rounded(_ rule: FloatingPointRoundingRule
                    = .toNearestOrAwayFromZero) -> RPN {
        RPN(oidfs: oidfs.map { $0.rounded(rule) })
    }
}

struct OError: Hashable {
    let message: String
    static func undefined(with str: String) -> OError {
        OError("\("Undefined".localized): \(str)")
    }
}
extension OError {
    init(_ d: String) {
        message = d
    }
}
extension OError: CustomStringConvertible {
    var description: String {
        "?" + message
    }
}

enum O: Sendable {
    case bool(Bool)
    case int(Int)
    case rational(Rational)
    case double(Double)
    indirect case array(OArray)
    indirect case range(ORange)
    indirect case dic([O: O])
    indirect case string(String)
    indirect case sheet(OSheet)
    indirect case g(G)
    indirect case generics(Generics)
    indirect case selected(Selected)
    indirect case f(F)
    indirect case label(OLabel)
    indirect case id(ID)
    indirect case error(OError)
}
extension O {
    init() { self = .f(F()) }
    init(_ v: Bool) { self = .bool(v) }
    init(_ v: Int) { self = .int(v) }
    init(_ v: Rational) { self = .rational(v) }
    init(_ v: Double) { self = .double(v) }
    init(_ v: OArray) { self = .array(v) }
//    init(_ v: [O]) { self = .array(OArray(v)) }
    init(_ v: ORange) { self = .range(v) }
    init(_ v: [O: O]) { self = .dic(v) }
    init(_ v: String) { self = .string(v) }
    init(_ v: OSheet) { self = .sheet(v) }
    init(_ v: G) { self = .g(v) }
    init(_ v: Generics) { self = .generics(v) }
    init(_ v: Selected) { self = .selected(v) }
    init(_ v: F) { self = .f(v) }
    init(_ v: OLabel) { self = .label(v) }
    init(_ v: ID) { self = .id(v) }
    init(_ v: OError) { self = .error(v) }
    
    static let empty = O(OArray([]))
    init(_ p: Point) {
        self = .array(OArray([O(p.x), O(p.y)]))
    }
    init(_ shp: IntPoint) {
        self = .array(OArray([O(shp.x), O(shp.y)]))
    }
    static let pointName = "point"
    static let weightName = "weight"
    static let pressureName = "pressure"
    init(_ lc: Line.Control) {
        self = O([O(O.pointName): O(lc.point),
                  O(O.weightName): O(lc.weight),
                  O(O.pressureName): O(lc.pressure)])
    }
    init(_ line: Line) {
        self = .array(OArray(line.controls.map { O($0) }))
    }
    init(_ lines: [Line]) {
        self = .array(OArray(lines.map { O($0) }))
    }
    init(_ o: Orientation) {
        self = .string(o.rawValue)
    }
    init(textBased str: String) {
        let s = str
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        self = .string(s)
    }
    static let stringName = "string"
    static let orientationName = "orientation"
    static let sizeName = "size"
    static let originName = "originName"
    init(_ text: Text) {
        self = O([O(O.stringName): O(textBased: text.string),
                  O(O.orientationName): O(text.orientation),
                  O(O.sizeName): O(text.size),
                  O(O.originName): O(text.origin)])
    }
    init(_ texts: [Text]) {
        self = .array(OArray(texts.map { O($0) }))
    }
    static let linesName = "lines"
    static let textsName = "texts"
    init(_ sheet: Sheet) {
        self = O([O(O.linesName): O(sheet.picture.lines),
                  O(O.textsName): O(sheet.texts)])
    }
    init(_ v: Int.OverResult) {
        switch v {
        case .int(let i): self = .int(i)
        case .double(let d): self = .double(d)
        }
    }
    init(_ v: Rational.OverResult) {
        switch v {
        case .rational(let r): self = .rational(r)
        case .double(let d): self = .double(d)
        }
    }
    
    static let sendName = "send"
}
extension O {
    static func defaultDictionary(with sheet: Sheet, bounds: Rect,
                                  ssDic: [O: O],
                                  cursorP: Point, printP: Point) -> [OKey: O] {
        var oDic = [OKey : O]()
        var i = 0, gi = 0, oldName = ""
        func append(_ str: String, _ info: OKeyInfo, _ f: F) {
            if oldName != info.group.name {
                oldName = info.group.name
                gi += 1
            }
            var info = info
            info.index = i
            info.group.index = gi
            i += 1
            oDic[f.key(from: str, info: info)] = O(f)
        }
        func append(_ key: OKey, _ o: O) {
            if let name = key.info?.group.name, oldName != name {
                oldName = name
                gi += 1
            }
            var key = key
            key.info?.index = i
            key.info?.group.index = gi
            i += 1
            oDic[key] = o
        }
        
        let constantGroup = OKeyInfo.Group(name: "Constant".localized)
        append(OKey(piName, OKeyInfo(constantGroup, "Archimedes' constant. Key input: ⌥ p".localized)), pi)
        
        let bboGroup = OKeyInfo.Group(name: "Basic binary operation".localized)
        append(powName, OKeyInfo(bboGroup, "Exponentiation (Principal value). a ** b = aᵇ".localized),
               F(170, .right, left: 1, right: 1, .pow))
        append(apowName, OKeyInfo(bboGroup, "Logarithm (Principal value). b */ a = logₐb".localized),
               F(170, .right, left: 1, right: 1, .apow))
        append(multiplyName, OKeyInfo(bboGroup, "Multiply.".localized),
               F(160, left: 1, right: 1, .multiply))
        append(divisionName, OKeyInfo(bboGroup, "Division.".localized),
               F(160, left: 1, right: 1, .division))
        append(moduloName, OKeyInfo(bboGroup, "Modulo.".localized),
               F(160, left: 1, right: 1, .modulo))
        append(additionName, OKeyInfo(bboGroup, "Add.".localized),
               F(150, left: 1, right: 1, .addition))
        append(subtractionName, OKeyInfo(bboGroup, "Subtract.".localized),
               F(150, left: 1, right: 1,  .subtraction))
        append(equalName, OKeyInfo(bboGroup, "Equal.".localized),
               F(130, left: 1, right: 1, .equal))
        append(notEqualName, OKeyInfo(bboGroup, "Not equal.".localized),
               F(130, left: 1, right: 1, .notEqual))
        append(lessName, OKeyInfo(bboGroup, "$0 < $1"),
               F(130, left: 1, right: 1, .less))
        append(greaterName, OKeyInfo(bboGroup, "$0 > $1"),
               F(130, left: 1, right: 1, .greater))
        append(lessEqualName, OKeyInfo(bboGroup, "$0 ≤ $1"),
               F(130, left: 1, right: 1, .lessEqual))
        append(greaterEqualName, OKeyInfo(bboGroup, "$0 ≥ $1"),
               F(130, left: 1, right: 1, .greaterEqual))
        append(andName, OKeyInfo(bboGroup, "Logical multiply. Short circuit evaluation.".localized),
               F(precedence: 120,
                 left: [Argument(inKey: nil, outKey: OKey("a"))],
                 right: [Argument(inKey: nil, outKey: OKey("b"))],
                 os: [O(F([O(F([O(false), O(ID("b"))])), O(ID(atName)), O(ID("a"))])), O(ID(sendName)), O()],
                 isShortCircuit: true))
        append(orName, OKeyInfo(bboGroup, "Logical add. Short circuit evaluation.".localized),
               F(precedence: 110,
                 left: [Argument(inKey: nil, outKey: OKey("a"))],
                 right: [Argument(inKey: nil, outKey: OKey("b"))],
                 os: [O(F([O(F([O(ID("b")), O(true)])), O(ID(atName)), O(ID("a"))])), O(ID(sendName)), O()],
                 isShortCircuit: true))
        
        let buoGroup = OKeyInfo.Group(name: "Basic unary operation".localized)
        append(notName, OKeyInfo(buoGroup, "Negation.".localized),
               F(right: 1, .not))
        append(floorName, OKeyInfo(buoGroup, "Floor function.".localized),
               F(right: 1, .floor))
        append(roundName, OKeyInfo(buoGroup, "Rounding function.".localized),
               F(right: 1, .round))
        append(ceilName, OKeyInfo(buoGroup, "Ceiling function.".localized),
               F(right: 1, .ceil))
        append(absName, OKeyInfo(buoGroup, "Absolute value function.".localized),
               F(right: 1, .abs))
        append(sqrtName, OKeyInfo(buoGroup, "Square root (Principal value).".localized),
               F(right: 1, .sqrt))
        append(sinName, OKeyInfo(buoGroup, "Sine.".localized),
               F(right: 1, .sin))
        append(cosName, OKeyInfo(buoGroup, "Cosine.".localized),
               F(right: 1, .cos))
        append(tanName, OKeyInfo(buoGroup, "Tangent.".localized),
               F(right: 1, .tan))
        append(asinName, OKeyInfo(buoGroup, "Arcsine (Principal value).".localized),
               F(right: 1, .asin))
        append(acosName, OKeyInfo(buoGroup, "Arccosine (Principal value).".localized),
               F(right: 1, .acos))
        append(atanName, OKeyInfo(buoGroup, "Arctangent (Principal value).".localized),
               F(right: 1, .atan))
        append(atan2Name, OKeyInfo(buoGroup, "Arctangent2 (Principal value).".localized),
               F(right: 1, .atan2))
        append(plusName, OKeyInfo(buoGroup, "Plus.".localized),
               F(150, right: 1, .plus))
        append(minusName, OKeyInfo(buoGroup, "Minus.".localized),
               F(150, right: 1, .minus))
        
        let rangeGroup = OKeyInfo.Group(name: "Range".localized)
        append(filiZName, OKeyInfo(rangeGroup, "{x | $0 ≤ x ≤ $1, x ∈ Z}"),
               F(140, left: 1, right: 1, .filiZ))
        append(filoZName, OKeyInfo(rangeGroup, "{x | $0 ≤ x < $1, x ∈ Z}"),
               F(140, left: 1, right: 1, .filoZ))
        append(foliZName, OKeyInfo(rangeGroup, "{x | $0 < x ≤ $1, x ∈ Z}"),
               F(140, left: 1, right: 1, .foliZ))
        append(foloZName, OKeyInfo(rangeGroup, "{x | $0 < x < $1, x ∈ Z}"),
               F(140, left: 1, right: 1, .foloZ))
        append(fiZName, OKeyInfo(rangeGroup, "{x | $0 ≤ x, x ∈ Z}"),
               F(140, left: 1, .fiZ))
        append(foZName, OKeyInfo(rangeGroup, "{x | $0 < x, x ∈ Z}"),
               F(140, left: 1, .foZ))
        append(liZName, OKeyInfo(rangeGroup, "{x | x ≤ $0, x ∈ Z}"),
               F(140, right: 1, .liZ))
        append(loZName, OKeyInfo(rangeGroup, "{x | x < $0, x ∈ Z}"),
               F(140, right: 1, .loZ))
        append(filiRName, OKeyInfo(rangeGroup, "{x | $0 ≤ x ≤ $1, x ∈ R}"),
               F(140, left: 1, right: 1, .filiR))
        append(filoRName, OKeyInfo(rangeGroup, "{x | $0 ≤ x < $1, x ∈ R}"),
               F(140, left: 1, right: 1, .filoR))
        append(foliRName, OKeyInfo(rangeGroup, "{x | $0 < x ≤ $1, x ∈ R}"),
               F(140, left: 1, right: 1, .foliR))
        append(foloRName, OKeyInfo(rangeGroup, "{x | $0 < x < $1, x ∈ R}"),
               F(140, left: 1, right: 1, .foloR))
        append(fiRName, OKeyInfo(rangeGroup, "{x | $0 ≤ x, x ∈ R}"),
               F(140, left: 1, .fiR))
        append(foRName, OKeyInfo(rangeGroup, "{x | $0 < x, x ∈ R}"),
               F(140, left: 1, .foR))
        append(liRName, OKeyInfo(rangeGroup, "{x | x ≤ $0, x ∈ R}"),
               F(140, right: 1, .liR))
        append(loRName, OKeyInfo(rangeGroup, "{x | x < $0, x ∈ R}"),
               F(140, right: 1, .loR))
        
        append(deltaName, OKeyInfo(rangeGroup, "Change spacing between elements, e.g. 0 ..< 10 __ 2 = (0 2 4 6 8)".localized),
               F(140, left: 1, right: 1, .delta))
        
        let arrayGroup = OKeyInfo.Group(name: "Array or set".localized)
        append(countaName, OKeyInfo(arrayGroup, "Get count.".localized),
               F(200, left: 1, .counta))
        append(atName, OKeyInfo(arrayGroup, "Get, e.g. (3 4 5).2 = 5".localized),
               F(140, left: 1, right: 1, .at))
        append(selectName, OKeyInfo(arrayGroup, "Select.".localized),
               F(140, left: 1, right: 1, .select))
        append(setName, OKeyInfo(arrayGroup, "Replace, e.g. (3 4 5)/.1 <- 2 = (3 2 5)".localized),
               F(140, left: 1, right: 1, .set))
        append(insertName, OKeyInfo(arrayGroup, "Append, e.g. (3 4)/.1 ++ 5 = (3 5 4), (3 4) ++ 5 = (3 4 5)".localized),
               F(140, left: 1, right: 1, .insert))
        append(removeName, OKeyInfo(arrayGroup, "Remove, e.g. (3 4 5)/.1 -- = (3 5)".localized),
               F(140, left: 1, .remove))
        append(makeMatrixName, OKeyInfo(arrayGroup, "Make matrix".localized),
               F(140, left: 1, .makeMatrix))
        append(releaseMatrixName, OKeyInfo(arrayGroup, "Release matrix".localized),
               F(140, left: 1, .releaseMatrix))
        append(isName, OKeyInfo(arrayGroup, "$0 is $1 = $0 ∈ $1"),
               F(200, left: 1, right: 1, .is))
        append(mapName, OKeyInfo(arrayGroup, "Map function, e.g. (3 4 5) map (x | x + 2) = (5 6 7)".localized),
               F(200, left: 1, right: 1, .map))
        append(filterName, OKeyInfo(arrayGroup, "Filter function, e.g. (3 4 5 6) filter (x | x % 2 != 0) = (3 5)".localized),
               F(200, left: 1, right: 1, .filter))
        append(reduceName, OKeyInfo(arrayGroup, "Reduce function, e.g. (3 4 5) reduce 0 (y x | y + x) = 12".localized),
               F(200, left: 1, right: 2, .reduce))
        append(randomName, OKeyInfo(arrayGroup, "Random, e.g. (3 4 5) random = 4".localized),
               F(200, left: 1, .random))
        
        let orientationGroup = OKeyInfo.Group(name: "Orientation".localized)
        append(OKey(horizontalName, OKeyInfo(orientationGroup, "Horizontal.".localized)),
               O(horizontalName))
        append(OKey(verticalName, OKeyInfo(orientationGroup, "Vertical.".localized)),
               O(verticalName))
        
        let sheetGroup = OKeyInfo.Group(name: "Sheet".localized)
        append(OKey(sheetDicName, OKeyInfo(sheetGroup, "Sheets dictionary where key is coordinates. Key of the sheet at the cursor position is the origin (0 0). The keys on the other sheets are relative to the origin.".localized)),
               O(ssDic))
        append(OKey(sheetName, OKeyInfo(sheetGroup, "Sheet at the cursor position.".localized)),
               O(OSheet(sheet, bounds: bounds)))
        append(OKey(sheetSizeName, OKeyInfo(sheetGroup, "Sheet size.".localized)),
               O([O("width"): O(bounds.width), O("height"): O(bounds.height)]))
        append(OKey(cursorPName, OKeyInfo(sheetGroup, "Cursor position.".localized)),
               O(cursorP))
        append(OKey(printPName, OKeyInfo(sheetGroup, "Display position of the execution result.".localized)),
               O(printP))
        append(showAboutRunName, OKeyInfo(sheetGroup, "Show about Run.".localized),
               F(left: 1, .showAboutRun))
        append(showAllDefinitionsName, OKeyInfo(sheetGroup, "Show all definitions.".localized),
               F(left: 1, .showAllDefinitions))
        append(drawName, OKeyInfo(sheetGroup, "Draw points $0 on sheet, e.g. draw ((100 100) (200 200))".localized),
               F(left: 1, .draw))
        append(drawAxesName, OKeyInfo(sheetGroup, "Draw axes on the sheet with $0 as the base scale, $1 as the x axis name, $2 as the y axis name, and the center of the sheet as the origin,\ne.g. drawAxes base: 1 \"X\" \"Y\"".localized),
               F(left: [], right: ["base", "", ""], .drawAxes))
        append(plotName, OKeyInfo(sheetGroup, "Plot points $1 on the sheet with $0 as the base scale, center of the sheet as the origin,\ne.g. plot base: 1 ((0 0) (1 1))".localized),
               F(left: [], right: ["base", ""], .plot))
        append(flipName, OKeyInfo(sheetGroup, "Flip sheet based on $0, e.g. horizontal flip".localized),
               F(left: 1, .flip))
        
        let otherGroup = OKeyInfo.Group(name: "Other".localized)
        append(asLabelName, OKeyInfo(otherGroup, "Make label.".localized),
               F(left: 1, .asLabel))
        append(asStringName, OKeyInfo(otherGroup, "Make string.".localized),
               F(right: 1, .asString))
        append(asErrorName, OKeyInfo(otherGroup, "Make error.".localized),
               F(right: 1, .asError))
        append(isErrorName, OKeyInfo(otherGroup, "Error check.".localized),
               F(130, left: 1, .isError))
        append(nilCoalescingName, OKeyInfo(otherGroup, "Nil coalescing. Short circuit evaluation, e.g. (0 1).2 ?? 3 = 3".localized),
               F(precedence: 140,
                 left: [Argument(inKey: nil, outKey: OKey("a"))],
                 right: [Argument(inKey: nil, outKey: OKey("b"))],
                 os: [O(F([O(F([O(F([O(ID("a"))]).with(isBlock: true)),
                                O(ID("b"))])), O(ID(atName)), O(F([O(ID("a")), O(ID(equalName)), O.nilV]))])), O(ID(sendName)), O()],
                 isShortCircuit: true))
        append(sendName, OKeyInfo(otherGroup, "Send $1 to $0. $+$ send (a b) = a + b".localized),
               F(left: 1, right: 1, .send))
        
        return oDic
    }
}

extension O: CustomStringConvertible {
    var description: String {
        return displayString()
    }
    var name: String {
        return displayString(fromLength: 12, isFirstAndLastBrackets: false)
    }
    static func removeFirstAndLastBrackets(_ s: String) -> String {
        if s.count > 2 && s.first == "(" && s.last == ")" {
            var i = s.startIndex, d = 0, count = 0
            while i < s.endIndex {
                if s[i] == "(" {
                    d += 1
                } else if s[i] == ")" {
                    d -= 1
                    if d == 0 {
                        count += 1
                    }
                }
                i = s.index(after: i)
            }
            if count == 1 {
                var s = s
                s.removeFirst()
                s.removeLast()
                return s
            }
        }
        return s
    }
    func displayString(fromLength l: Int = 1000,
                       isFirstAndLastBrackets: Bool = true) -> String {
        var s = asString
        if isFirstAndLastBrackets {
            s = O.removeFirstAndLastBrackets(s)
        }
        let cs = "...C\(s.count - l)"
        if s.count - cs.count > l {
            let si = s.startIndex
            let ei = s.index(s.startIndex, offsetBy: l)
            return "\(s[si ..< ei])\(cs)"
        } else {
            return s
        }
    }
}

extension O {
    var asInt: Int? {
        switch self {
        case .bool(let a): return Int(a)
        case .int(let a): return a
        case .rational(let a): return a.isInteger ? Int(a) : nil
        case .double(let a): return a.isInteger ? Int(exactly: a) : nil
        case .string(let a):
            switch a {//
            case "x": return 0
            case "y": return 1
            case "z": return 2
            case "w": return 3
            default: return Int(a)
            }
        default: return nil
        }
    }
    
    var asDouble: Double? {
        switch self {
        case .bool(let a): return Double(a)
        case .int(let a): return Double(a)
        case .rational(let a): return Double(a)
        case .double(let a): return a
        default: return nil
        }
    }
    
    var asPoint: Point? {
        switch self {
        case .array(let a):
            if a.count == 2, let x = a[0].asDouble, let y = a[1].asDouble {
                return Point(x, y)
            } else {
                return nil
            }
        default: return nil
        }
    }
    
    var asArray: [O] {
        switch self {
        case .array(let a): return a.value
        default: return [self]
        }
    }
    
    var asPoints: [Point] {
        switch self {
        case .array(let a): return a.compactMap { $0.asPoint }
        default: return []
        }
    }
    
    var asOrientation: Orientation? {
        guard case .string(let str) = self else { return nil }
        return Orientation(rawValue: str)
    }
    
    var asTextBasedString: String {
        if case .string(let s) = self {
            return s
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\n", with: "\n")
        } else {
            return asString
        }
    }
    
    var asText: Text? {
        switch self {
        case .dic(let a):
            if a.count == 4,
               let string = a[O(O.stringName)]?.asTextBasedString,
               let orientation = a[O(O.orientationName)]?.asOrientation,
               let size = a[O(O.sizeName)]?.asDouble,
               let origin = a[O(O.originName)]?.asPoint {
                
                return Text(string: string, orientation: orientation,
                            size: size, origin: origin)
            } else {
                return nil
            }
        default: return nil
        }
    }
    
    var asLineControl: Line.Control? {
        switch self {
        case .dic(let a):
            if a.count == 3,
               let point = a[O(O.pointName)]?.asPoint,
               let weight = a[O(O.weightName)]?.asDouble,
               let pressure = a[O(O.pressureName)]?.asDouble {
                
                return Line.Control(point: point,
                                    weight: weight,
                                    pressure: pressure)
            } else {
                return nil
            }
        default: return nil
        }
    }
    
    var asLine: Line? {
        switch self {
        case .array(let a):
            var cs = [Line.Control]()
            cs.reserveCapacity(a.count)
            for i in 0 ..< a.count {
                guard let lc = a[i].asLineControl else {
                    return nil
                }
                cs.append(lc)
            }
            return Line(controls: cs)
        default: return nil
        }
    }
    
    var asSheet: Sheet? {
        switch self {
        case .sheet(let a): return a.value
        case .dic(let a):
            if let oLines = a[O(O.linesName)]?.asArray,
               let oTexts = a[O(O.textsName)]?.asArray {
                
                var lines = [Line]()
                lines.reserveCapacity(oLines.count)
                for i in 0 ..< oLines.count {
                    guard let l = oLines[i].asLine else {
                        return nil
                    }
                    lines.append(l)
                }
                
                var texts = [Text]()
                texts.reserveCapacity(oTexts.count)
                for i in 0 ..< oTexts.count {
                    guard let t = oTexts[i].asText else {
                        return nil
                    }
                    texts.append(t)
                }
                
                let keyframe = Keyframe(picture: Picture(lines: lines,
                                                         planes: []))
                return Sheet(animation: Animation(keyframes: [keyframe]),
                             texts: texts)
            } else {
                return nil
            }
        default: return nil
        }
    }
}

extension O {
    static let piName = "π"
    static let pi = O(Double.pi)
    
    static let nilName = "nil"
    static let nilV = O(OArray([]))
}
extension O {
    static let powName = "**"
    static func ** (ao: O, bo: O) -> O {
        if ao == O(1) || bo == O(0) {
            return O(1)
        }
        switch ao {
        case .bool(let a):
            switch bo {
            case .bool(let b):
                if a {
                    if b {
                        return O(true)
                    } else {
                        return O(true)
                    }
                } else {
                    if b {
                        return O(false)
                    } else {
                        return O(true)
                    }
                }
            case .int(let b): return O(Int.overPow(Int(a), b))
            case .rational(let b): return O(Double(a) ** Double(b))
            case .double(let b): return O(Double(a) ** b)
            case .array(let b): return .init(ao ** b)
            case .range(let b): return .init(ao ** b)
            case .error: return bo
            default: break
            }
        case .int(let a):
            if a < 0 {
                return O(OError.undefined(with: "\(ao.name) \(powName) \(bo.name)"))//
            }
            switch bo {
            case .bool(let b): return O(Int.overPow(a, Int(b)))
            case .int(let b): return O(Int.overPow(a, b))
            case .rational(let b): return O(Double(a) ** Double(b))
            case .double(let b): return O(Double(a) ** b)
            case .array(let b): return .init(ao ** b)
            case .range(let b): return .init(ao ** b)
            case .error: return bo
            default: break
            }
        case .rational(let a):
            if a < 0 {
                return O(OError.undefined(with: "\(ao.name) \(powName) \(bo.name)"))//
            }
            switch bo {
            case .bool(let b): return O(Rational.overPow(a, Int(b)))
            case .int(let b): return O(Rational.overPow(a, b))
            case .rational(let b): return O(Double(a) ** Double(b))
            case .double(let b): return O(Double(a) ** b)
            case .array(let b): return .init(ao ** b)
            case .range(let b): return .init(ao ** b)
            case .error: return bo
            default: break
            }
        case .double(let a):
            if a < 0 {
                return O(OError.undefined(with: "\(ao.name) \(powName) \(bo.name)"))//
            }
            switch bo {
            case .bool(let b): return O(a ** Double(b))
            case .int(let b): return O(a ** Double(b))
            case .rational(let b): return O(a ** Double(b))
            case .double(let b): return O(a ** b)
            case .array(let b): return .init(ao ** b)
            case .range(let b): return .init(ao ** b)
            case .error: return bo
            default: break
            }
        case .error: return ao
        default:
            switch bo {
            case .error: return bo
            default: break
            }
        }
        return O(OError.undefined(with: "\(ao.name) \(powName) \(bo.name)"))
    }
    
    static let apowName = "*/"
    static func apow(_ ao: O, _ bo: O) -> O {
        if bo < O(0) || bo == O(1) {
            return O(OError.undefined(with: "\(ao.name) \(apowName) \(bo.name)"))//
        }
        switch ao {
        case .bool(let a):
            switch bo {
            case .bool(let b): return O(.apow(Double(a), Double(b)))
            case .int(let b): return O(.apow(Double(a), Double(b)))
            case .rational(let b): return O(.apow(Double(a), Double(b)))
            case .double(let b): return O(.apow(Double(a), b))
            case .array(let b): return .init(.apow(ao, b))
            case .range(let b): return .init(.apow(ao, b))
            case .error: return bo
            default: break
            }
        case .int(let a):
            switch bo {
            case .bool(let b): return O(.apow(Double(a), Double(b)))
            case .int(let b): return O(.apow(Double(a), Double(b)))
            case .rational(let b): return O(.apow(Double(a), Double(b)))
            case .double(let b): return O(.apow(Double(a), b))
            case .array(let b): return .init(.apow(ao, b))
            case .range(let b): return .init(.apow(ao, b))
            case .error: return bo
            default: break
            }
        case .rational(let a):
            switch bo {
            case .bool(let b): return O(.apow(Double(a), Double(b)))
            case .int(let b): return O(.apow(Double(a), Double(b)))
            case .rational(let b): return O(.apow(Double(a), Double(b)))
            case .double(let b): return O(.apow(Double(a), b))
            case .array(let b): return .init(.apow(ao, b))
            case .range(let b): return .init(.apow(ao, b))
            case .error: return bo
            default: break
            }
        case .double(let a):
            switch bo {
            case .bool(let b): return O(.apow(a, Double(b)))
            case .int(let b): return O(.apow(a, Double(b)))
            case .rational(let b): return O(.apow(a, Double(b)))
            case .double(let b): return O(.apow(a, b))
            case .array(let b): return .init(.apow(ao, b))
            case .range(let b): return .init(.apow(ao, b))
            case .error: return bo
            default: break
            }
        case .error: return ao
        default:
            switch bo {
            case .error: return bo
            default: break
            }
        }
        return O(OError.undefined(with: "\(ao.name) \(apowName) \(bo.name)"))
    }
    
    static let multiplyName = "*"
    static func * (ao: O, bo: O) -> O {
        switch ao {
        case .bool(let a):
            switch bo {
            case .bool(let b): return O(a && b)
            case .int(let b): return O(Int.overMulti(Int(a), b))
            case .rational(let b): return O(Rational.overMulti(Rational(a), b))
            case .double(let b):
                if b.isInfinite && !a {
                    return O(OError.undefined(with: "\(ao.name) \(multiplyName) \(bo.name)"))
                }
                return O(Double(a) * b)
            case .array(let b): return .init(ao * b)
            case .range(let b): return .init(ao * b)
            case .error: return bo
            default: break
            }
        case .int(let a):
            switch bo {
            case .bool(let b): return O(Int.overMulti(a, Int(b)))
            case .int(let b): return O(Int.overMulti(a, b))
            case .rational(let b): return O(Rational.overMulti(Rational(a), b))
            case .double(let b):
                if b.isInfinite && a == 0 {
                    return O(OError.undefined(with: "\(ao.name) \(multiplyName) \(bo.name)"))
                }
                return O(Double(a) * b)
            case .array(let b): return .init(ao * b)
            case .range(let b): return .init(ao * b)
            case .error: return bo
            default: break
            }
        case .rational(let a):
            switch bo {
            case .bool(let b): return O(Rational.overMulti(a, Rational(b)))
            case .int(let b): return O(Rational.overMulti(a, Rational(b)))
            case .rational(let b): return O(Rational.overMulti(a, b))
            case .double(let b):
                if b.isInfinite && a == 0 {
                    return O(OError.undefined(with: "\(ao.name) \(multiplyName) \(bo.name)"))
                }
                return O(Double(a) * b)
            case .array(let b): return .init(ao * b)
            case .range(let b): return .init(ao * b)
            case .error: return bo
            default: break
            }
        case .double(let a):
            switch bo {
            case .bool(let b):
                if a.isInfinite && !b {
                    return O(OError.undefined(with: "\(ao.name) \(multiplyName) \(bo.name)"))
                }
                return O(a * Double(b))
            case .int(let b):
                if a.isInfinite && b == 0 {
                    return O(OError.undefined(with: "\(ao.name) \(multiplyName) \(bo.name)"))
                }
                return O(a * Double(b))
            case .rational(let b):
                if a.isInfinite && b == 0 {
                    return O(OError.undefined(with: "\(ao.name) \(multiplyName) \(bo.name)"))
                }
                return O(a * Double(b))
            case .double(let b):
                if (a.isInfinite || b.isInfinite) && ((a.isInfinite && b == 0) || (a == 0 && b.isInfinite)) {
                    return O(OError.undefined(with: "\(ao.name) \(multiplyName) \(bo.name)"))
                }
                return O(a * b)
            case .array(let b): return .init(ao * b)
            case .range(let b): return .init(ao * b)
            case .error: return bo
            default: break
            }
        case .array(let a):
            switch bo {
            case .bool, .int, .rational, .double: return .init(a * bo)
            case .array(let b):
                guard a.dimension == b.dimension else {
                    return O(OError.undefined(with: "\(ao.name) \(multiplyName) \(bo.name)"))
                }
                let aColumnCount = a.nextCount
                let aRowCount = a.count

                let bColumnCount = b.nextCount
                let bRowCount = b.count

                guard aColumnCount == bRowCount else {
                    return O(OError.undefined(with: "\(ao.name) \(multiplyName) \(bo.name)"))
                }
                let m = aColumnCount, n = aRowCount, p = bColumnCount

                var ns = [O]()
                ns.reserveCapacity(n)
                for i in 0 ..< n {
                    var nj = [O]()
                    nj.reserveCapacity(p)
                    let ai = a[i]
                    for j in 0 ..< p {
                        var ne = O(0)
                        for k in 0 ..< m {
                            let ne0 = ne + ai[k] * b[k][j]
                            switch ne0 {
                            case .error: return ne0
                            default: ne = ne0
                            }
                        }
                        nj.append(ne)
                    }
                    ns.append(O(OArray(union: nj)))
                }
                return O(OArray(ns, dimension: a.dimension, nextCount: p))
            case .error: return bo
            default: break
            }
        case .error: return ao
        default:
            switch bo {
            case .error: return bo
            default: break
            }
        }
        return O(OError.undefined(with: "\(ao.name) \(multiplyName) \(bo.name)"))
    }
    static func *= (lhs: inout O, rhs: O) {
        lhs = lhs * rhs
    }
    
    static let divisionName = "/"
    static func / (ao: O, bo: O) -> O {
        if ao == O(0) && bo == O(0) {
            return O(OError("0/0"))
        }
        switch ao {
        case .bool(let a):
            switch bo {
            case .bool(let b):
                if a {
                    if b {
                        return O(true)
                    } else {
                        return O(Double.infinity)
                    }
                } else {
                    if b {
                        return O(false)
                    } else {
                        return O(OError.undefined(with: "\(ao.name) \(divisionName) \(bo.name)"))
                    }
                }
            case .int(let b):
                return b == 0 ?
                    O(Double(a) / Double(b)) :
                    O(Rational(Int(a), b))
            case .rational(let b):
                return b == 0 ?
                    O(Double(a) / Double(b)) :
                    O(Rational.overDiv(Rational(a), b))
            case .double(let b): return O(Double(a) / b)
            case .array(let b): return .init(ao / b)
            case .range(let b): return .init(ao / b)
            case .error: return bo
            default: break
            }
        case .int(let a):
            switch bo {
            case .bool(let b):
                return !b ?
                    O(Double(a) / Double(b)) :
                    O(Rational(a, Int(b)))
            case .int(let b):
                return b == 0 ?
                    O(Double(a) / Double(b)) :
                    O(Rational(a, b))
            case .rational(let b):
                return b == 0 ?
                    O(Double(a) / Double(b)) :
                    O(Rational.overDiv(Rational(a), b))
            case .double(let b): return O(Double(a) / b)
            case .array(let b): return .init(ao / b)
            case .range(let b): return .init(ao / b)
            case .error: return bo
            default: break
            }
        case .rational(let a):
            switch bo {
            case .bool(let b):
                return !b ?
                    O(Double(a) / Double(b)) :
                    O(Rational.overDiv(a, Rational(b)))
            case .int(let b):
                return b == 0 ?
                    O(Double(a) / Double(b)) :
                    O(Rational.overDiv(a, Rational(b)))
            case .rational(let b):
                return b == 0 ?
                    O(Double(a) / Double(b)) :
                    O(Rational.overDiv(a, b))
            case .double(let b): return O(Double(a) / b)
            case .array(let b): return .init(ao / b)
            case .range(let b): return .init(ao / b)
            case .error: return bo
            default: break
            }
        case .double(let a):
            switch bo {
            case .bool(let b): return O(a / Double(b))
            case .int(let b): return O(a / Double(b))
            case .rational(let b): return O(a / Double(b))
            case .double(let b):
                if a.isInfinite && b.isInfinite {
                    return O(OError.undefined(with: "\(ao.name) \(divisionName) \(bo.name)"))
                }
                return O(a / b)
            case .array(let b): return .init(ao / b)
            case .range(let b): return .init(ao / b)
            case .error: return bo
            default: break
            }
        case .error: return ao
        default:
            switch bo {
            case .error: return bo
            default: break
            }
        }
        return O(OError.undefined(with: "\(ao.name) \(divisionName) \(bo.name)"))
    }
    static func /= (lhs: inout O, rhs: O) {
        lhs = lhs / rhs
    }
    
    static let moduloName = "%"
    static func % (ao: O, bo: O) -> O {
        if bo == O(0) {
            return O(OError("%0"))
        }
        switch ao {
        case .bool(let a):
            switch bo {
            case .bool(let b):
                if a {
                    if b {
                        return O(false)
                    } else {
                        return O(OError.undefined(with: "\(ao.name) \(moduloName) \(bo.name)"))
                    }
                } else {
                    if b {
                        return O(false)
                    } else {
                        return O(OError.undefined(with: "\(ao.name) \(moduloName) \(bo.name)"))
                    }
                }
            case .int(let b): return O(Int.overMod(Int(a), b))
            case .rational(let b): return O(Rational.overMod(Rational(a), b))
            case .double(let b): return O(Double(a).truncatingRemainder(dividingBy: b))
            case .array(let b): return .init(ao % b)
            case .range(let b): return .init(ao % b)
            case .error: return bo
            default: break
            }
        case .int(let a):
            switch bo {
            case .bool(let b): return O(Int.overMod(a, Int(b)))
            case .int(let b): return O(Int.overMod(a, b))
            case .rational(let b): return O(Rational.overMod(Rational(a), b))
            case .double(let b): return O(Double(a).truncatingRemainder(dividingBy: b))
            case .array(let b): return .init(ao % b)
            case .range(let b): return .init(ao % b)
            case .error: return bo
            default: break
            }
        case .rational(let a):
            switch bo {
            case .bool(let b): return O(Rational.overMod(a, Rational(b)))
            case .int(let b): return O(Rational.overMod(a, Rational(b)))
            case .rational(let b): return O(Rational.overMod(a, b))
            case .double(let b): return O(Double(a).truncatingRemainder(dividingBy: b))
            case .array(let b): return .init(ao % b)
            case .range(let b): return .init(ao % b)
            case .error: return bo
            default: break
            }
        case .double(let a):
            switch bo {
            case .bool(let b): return O(a.truncatingRemainder(dividingBy: Double(b)))
            case .int(let b): return O(a.truncatingRemainder(dividingBy: Double(b)))
            case .rational(let b): return O(a.truncatingRemainder(dividingBy: Double(b)))
            case .double(let b):
                if a.isInfinite && b.isInfinite {
                    return O(OError.undefined(with: "\(ao.name) \(moduloName) \(bo.name)"))
                }
                return O(a.truncatingRemainder(dividingBy: b))
            case .array(let b): return .init(ao % b)
            case .range(let b): return .init(ao % b)
            case .error: return bo
            default: break
            }
        case .array(let a):
            switch bo {
            case .bool, .int, .rational, .double: return .init(a % bo)
            case .array(let b):
                if a.isEqualDimension(b) {
                    var n = [O]()
                    n.reserveCapacity(a.count)
                    for (i, ae) in a.enumerated() {
                        let ne = ae % b[i]
                        switch ne {
                        case .error: return ne
                        default: n.append(ne)
                        }
                    }
                    return O(a.with(n))
                } else {
                    return O(OError.undefined(with: "\(ao.name) \(additionName) \(bo.name)"))
                }
            case .error: return bo
            default: break
            }
        case .error: return ao
        default:
            switch bo {
            case .error: return bo
            default: break
            }
        }
        return O(OError.undefined(with: "\(ao.name) \(moduloName) \(bo.name)"))
    }
    
    static let additionName = "+"
    static func + (ao: O, bo: O) -> O {
        switch ao {
        case .bool(let a):
            switch bo {
            case .bool(let b): return O(a != b)
            case .int(let b): return O(Int.overAdd(Int(a), b))
            case .rational(let b): return O(Rational.overAdd(Rational(a), b))
            case .double(let b): return O(Double(a) + b)
            case .array(let b): return .init(ao + b)
            case .range(let b): return .init(ao + b)
            case .error: return bo
            default: break
            }
        case .int(let a):
            switch bo {
            case .bool(let b): return O(Int.overAdd(a, Int(b)))
            case .int(let b): return O(Int.overAdd(a, b))
            case .rational(let b): return O(Rational.overAdd(Rational(a), b))
            case .double(let b): return O(Double(a) + b)
            case .array(let b): return .init(ao + b)
            case .range(let b): return .init(ao + b)
            case .error: return bo
            default: break
            }
        case .rational(let a):
            switch bo {
            case .bool(let b): return O(Rational.overAdd(a, Rational(b)))
            case .int(let b): return O(Rational.overAdd(a, Rational(b)))
            case .rational(let b): return O(Rational.overAdd(a, b))
            case .double(let b): return O(Double(a) + b)
            case .array(let b): return .init(ao + b)
            case .range(let b): return .init(ao + b)
            case .error: return bo
            default: break
            }
        case .double(let a):
            switch bo {
            case .bool(let b): return O(a + Double(b))
            case .int(let b): return O(a + Double(b))
            case .rational(let b): return O(a + Double(b))
            case .double(let b):
                if a.isInfinite && b.isInfinite {
                    if (a < 0 && b > 0) || (a > 0 && b < 0) {
                        return O(OError.undefined(with: "\(ao.name) \(additionName) \(bo.name)"))
                    }
                }
                return O(a + b)
            case .array(let b): return .init(ao + b)
            case .range(let b): return .init(ao + b)
            case .error: return bo
            default: break
            }
        case .array(let a):
            switch bo {
            case .bool, .int, .rational, .double: return .init(a + bo)
            case .array(let b):
                if a.isEqualDimension(b) {
                    var n = [O]()
                    n.reserveCapacity(a.count)
                    for (i, ae) in a.enumerated() {
                        let ne = ae + b[i]
                        switch ne {
                        case .error: return ne
                        default: n.append(ne)
                        }
                    }
                    return O(a.with(n))
                } else {
                    return O(OError.undefined(with: "\(ao.name) \(additionName) \(bo.name)"))
                }
            case .error: return bo
            default: break
            }
        case .dic(let a):
            switch bo {
            case .dic(let b):
                if a.count == b.count {
                    var n = [O: O]()
                    n.reserveCapacity(a.count)
                    for (aKey, ae) in a {
                        guard let be = b[aKey] else {
                            return O(OError.undefined(with: "\(ao.name) \(additionName) \(bo.name)"))
                        }
                        let ne = ae + be
                        switch ne {
                        case .error: return ne
                        default: n[aKey] = ne
                        }
                    }
                    return O(n)
                } else {
                    return O(OError.undefined(with: "\(ao.name) \(additionName) \(bo.name)"))
                }
            case .error: return bo
            default: break
            }
        case .error: return ao
        default:
            switch bo {
            case .error: return bo
            default: break
            }
        }
        return O(OError.undefined(with: "\(ao.name) \(additionName) \(bo.name)"))
    }
    static func += (lhs: inout O, rhs: O) {
        lhs = lhs + rhs
    }
    
    static let subtractionName = "-"
    static func - (ao: O, bo: O) -> O {
        switch ao {
        case .bool(let a):
            switch bo {
            case .bool(let b):
                if a {
                    if b {
                        return O(false)
                    } else {
                        return O(true)
                    }
                } else {
                    if b {
                        return O(true)
                    } else {
                        return O(false)
                    }
                }
            case .int(let b): return O(Int.overDiff(Int(a), b))
            case .rational(let b): return O(Rational.overDiff(Rational(a), b))
            case .double(let b): return O(Double(a) - b)
            case .array(let b): return .init(ao - b)
            case .range(let b): return .init(ao - b)
            case .error: return bo
            default: break
            }
        case .int(let a):
            switch bo {
            case .bool(let b): return O(Int.overDiff(a, Int(b)))
            case .int(let b): return O(Int.overDiff(a, b))
            case .rational(let b): return O(Rational.overDiff(Rational(a), b))
            case .double(let b): return O(Double(a) - b)
            case .array(let b): return .init(ao - b)
            case .range(let b): return .init(ao - b)
            case .error: return bo
            default: break
            }
        case .rational(let a):
            switch bo {
            case .bool(let b): return O(Rational.overDiff(a, Rational(b)))
            case .int(let b): return O(Rational.overDiff(a, Rational(b)))
            case .rational(let b): return O(Rational.overDiff(a, b))
            case .double(let b): return O(Double(a) - b)
            case .array(let b): return .init(ao - b)
            case .range(let b): return .init(ao - b)
            case .error: return bo
            default: break
            }
        case .double(let a):
            switch bo {
            case .bool(let b): return O(a - Double(b))
            case .int(let b): return O(a - Double(b))
            case .rational(let b): return O(a - Double(b))
            case .double(let b):
                if a.isInfinite && b.isInfinite {
                    if (a > 0 && b > 0) || (a < 0 && b < 0) {
                        return O(OError.undefined(with: "\(ao.name) \(subtractionName) \(bo.name)"))
                    }
                }
                return O(a - b)
            case .array(let b): return .init(ao - b)
            case .range(let b): return .init(ao - b)
            case .error: return bo
            default: break
            }
        case .array(let a):
            switch bo {
            case .bool, .int, .rational, .double: return .init(a - bo)
            case .array(let b):
                if a.isEqualDimension(b) {
                    var n = [O]()
                    n.reserveCapacity(a.count)
                    for (i, ae) in a.enumerated() {
                        let ne = ae - b[i]
                        switch ne {
                        case .error: return ne
                        default: n.append(ne)
                        }
                    }
                    return O(a.with(n))
                } else {
                    return O(OError.undefined(with: "\(ao.name) \(subtractionName) \(bo.name)"))
                }
            case .error: return bo
            default: break
            }
        case .dic(let a):
            switch bo {
            case .dic(let b):
                if a.count == b.count {
                    var n = [O: O]()
                    n.reserveCapacity(a.count)
                    for (aKey, ae) in a {
                        guard let be = b[aKey] else {
                            return O(OError.undefined(with: "\(ao.name) \(subtractionName) \(bo.name)"))
                        }
                        let ne = ae - be
                        switch ne {
                        case .error: return ne
                        default: n[aKey] = ne
                        }
                    }
                    return O(n)
                } else {
                    return O(OError.undefined(with: "\(ao.name) \(subtractionName) \(bo.name)"))
                }
            case .error: return bo
            default: break
            }
        case .error: return ao
        default:
            switch bo {
            case .error: return bo
            default: break
            }
        }
        return O(OError.undefined(with: "\(ao.name) \(subtractionName) \(bo.name)"))
    }
    static func -= (lhs: inout O, rhs: O) {
        lhs = lhs - rhs
    }
    
    static let andName = "&&"
    static func and(_ ao: O, _ bo: O) -> O {
        switch ao {
        case .bool(let a):
            switch bo {
            case .bool(let b): return O(a && b)
            case .error: return bo
            default: break
            }
        case .error: return ao
        default:
            switch bo {
            case .error: return bo
            default: break
            }
        }
        return O(OError.undefined(with: "\(ao.name) \(andName) \(bo.name)"))
    }
    static let orName = "||"
    static func or(_ ao: O, _ bo: O) -> O {
        switch ao {
        case .bool(let a):
            switch bo {
            case .bool(let b): return O(a || b)
            case .error: return bo
            default: break
            }
        case .error: return ao
        default:
            switch bo {
            case .error: return bo
            default: break
            }
        }
        return O(OError.undefined(with: "\(ao.name) \(orName) \(bo.name)"))
    }
}

extension O: Equatable {
    static func == (lhs: O, rhs: O) -> Bool {
        return equal(lhs, rhs)
    }
    static func equal(_ lhs: O, _ rhs: O) -> Bool {//
        switch lhs {
        case .bool(let a):
            switch rhs {
            case .bool(let b): return a == b
            case .int(let b): return Int(a) == b
            case .rational(let b): return Rational(a) == b
            case .double(let b): return Double(a) == b
            default: return false
            }
        case .int(let a):
            switch rhs {
            case .bool(let b): return a == Int(b)
            case .int(let b): return a == b
            case .rational(let b): return Rational(a) == b
            case .double(let b): return Double(a) == b
            default: return false
            }
        case .rational(let a):
            switch rhs {
            case .bool(let b): return a == Rational(b)
            case .int(let b): return a == Rational(b)
            case .rational(let b): return a == b
            case .double(let b): return Double(a) == b
            default: return false
            }
        case .double(let a):
            switch rhs {
            case .bool(let b): return a == Double(b)
            case .int(let b): return a == Double(b)
            case .rational(let b): return a == Double(b)
            case .double(let b): return a == b
            default: return false
            }
        case .array(let a):
            switch rhs {
            case .array(let b): return a == b
            default: return false
            }
        case .range(let a):
            switch rhs {
            case .range(let b): return a == b
            default: return false
            }
        case .dic(let a):
            switch rhs {
            case .dic(let b): return a == b
            default: return false
            }
        case .string:
            return lhs.asString == rhs.asString
        case .sheet(let a):
            switch rhs {
            case .sheet(let b): return a == b
            default: return false
            }
        case .selected(let a):
            switch rhs {
            case .selected(let b): return a == b
            default: return false
            }
        case .g(let a):
            switch rhs {
            case .g(let b): return a == b
            default: return false
            }
        case .generics(let a):
            switch rhs {
            case .generics(let b): return a == b
            default: return false
            }
        case .f(let a):
            switch rhs {
            case .f(let b): return a == b
            default: return false
            }
        case .label(let a):
            switch rhs {
            case .label(let b): return a == b
            default: return false
            }
        case .id(let a):
            switch rhs {
            case .id(let b): return a == b
            default: return false
            }
        case .error(let a):
            switch rhs {
            case .error(let b): return a == b
            default: return false
            }
        }
    }
    static func notEqual(_ lhs: O, _ rhs: O) -> Bool {
        return !equal(lhs, rhs)
    }
    static let equalName = "=="
    static func equalO(_ ao: O, _ bo: O) -> O {
        switch ao {
        case .error: return ao
        default: break
        }
        switch bo {
        case .error: return bo
        default: break
        }
        return O(equal(ao, bo))
    }
    static let notEqualName = "!="
    static func notEqualO(_ ao: O, _ bo: O) -> O {
        switch ao {
        case .error: return ao
        default: break
        }
        switch bo {
        case .error: return bo
        default: break
        }
        return O(notEqual(ao, bo))
    }
}
extension O: Comparable {
    static func < (lhs: O, rhs: O) -> Bool {
        return less(lhs, rhs) ?? false
    }
    static func less(_ lhs: O, _ rhs: O) -> Bool? {
        switch lhs {
        case .bool(let a):
            switch rhs {
            case .int(let b): return Int(a) < b
            case .rational(let b): return Rational(a) < b
            case .double(let b): return Double(a) < b
            default: return nil
            }
        case .int(let a):
            switch rhs {
            case .bool(let b): return a < Int(b)
            case .int(let b): return a < b
            case .rational(let b): return Rational(a) < b
            case .double(let b): return Double(a) < b
            default: return nil
            }
        case .rational(let a):
            switch rhs {
            case .bool(let b): return a < Rational(b)
            case .int(let b): return a < Rational(b)
            case .rational(let b): return a < b
            case .double(let b): return Double(a) < b
            default: return nil
            }
        case .double(let a):
            switch rhs {
            case .bool(let b): return a < Double(b)
            case .int(let b): return a < Double(b)
            case .rational(let b): return a < Double(b)
            case .double(let b): return a < b
            default: return nil
            }
        case .string:
            return lhs.asString < rhs.asString
        default: return nil
        }
    }
    static func greater(_ lhs: O, _ rhs: O) -> Bool? {
        if equal(lhs, rhs) {
            return false
        } else if let bool0 = less(lhs, rhs) {
            return !bool0
        } else {
            return nil
        }
    }
    static func lessEqual(_ lhs: O, _ rhs: O) -> Bool? {
        if let bool = less(lhs, rhs), bool {
            return true
        }
        return equal(lhs, rhs)
    }
    static func greaterEqual(_ lhs: O, _ rhs: O) -> Bool? {
        if let bool = less(lhs, rhs), !bool {
            return true
        }
        return equal(lhs, rhs)
    }
    
    static let lessName = "<"
    static func lessO(_ ao: O, _ bo: O) -> O {
        switch ao {
        case .error: return ao
        default: break
        }
        switch bo {
        case .error: return bo
        default: break
        }
        if let bool = less(ao, bo) {
            return O(bool)
        } else {
            return O(OError.undefined(with: "\(ao.name) \(lessName) \(bo.name)"))
        }
    }
    static let greaterName = ">"
    static func greaterO(_ ao: O, _ bo: O) -> O {
        switch ao {
        case .error: return ao
        default: break
        }
        switch bo {
        case .error: return bo
        default: break
        }
        if let bool = greater(ao, bo) {
            return O(bool)
        } else {
            return O(OError.undefined(with: "\(ao.name) \(greaterName) \(bo.name)"))
        }
    }
    static let lessEqualName = "<="
    static func lessEqualO(_ ao: O, _ bo: O) -> O {
        switch ao {
        case .error: return ao
        default: break
        }
        switch bo {
        case .error: return bo
        default: break
        }
        if let bool = lessEqual(ao, bo) {
            return O(bool)
        } else {
            return O(OError.undefined(with: "\(ao.name) \(lessEqualName) \(bo.name)"))
        }
    }
    static let greaterEqualName = ">="
    static func greaterEqualO(_ ao: O, _ bo: O) -> O {
        switch ao {
        case .error: return ao
        default: break
        }
        switch bo {
        case .error: return bo
        default: break
        }
        if let bool = greaterEqual(ao, bo) {
            return O(bool)
        } else {
            return O(OError.undefined(with: "\(ao.name) \(greaterEqualName) \(bo.name)"))
        }
    }
}
extension O: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .bool(let a): hasher.combine(Double(a))
        case .int(let a): hasher.combine(Double(a))
        case .rational(let a): hasher.combine(Double(a))
        case .double(let a): hasher.combine(a)
        case .array(let a): hasher.combine(a)
        case .range(let a): hasher.combine(a)
        case .dic(let a): hasher.combine(a)
        case .string(let a): hasher.combine(a)
        case .sheet(let a): hasher.combine(a)
        case .selected(let a): hasher.combine(a)
        case .g(let a): hasher.combine(a)
        case .generics(let a): hasher.combine(a)
        case .f(let a): hasher.combine(a)
        case .label(let a): hasher.combine(a)
        case .id(let a): hasher.combine(a)
        case .error(let a): hasher.combine(a)
        }
    }
}

extension O {
    static let notName = "!"
    prefix static func !(ao: O) -> O {
        switch ao {
        case .bool(let a): return O(!a)
        case .int(let a):
            return O(Int.overDiff(1, a))
        case .rational(let a):
            return O(Rational.overDiff(1, a))
        case .double(let a):
            return O(1 - a)
        case .array(let a):
            var n = [O]()
            n.reserveCapacity(a.count)
            for e in a {
                let ne = !e
                switch ne {
                case .error: return ne
                default: n.append(ne)
                }
            }
            return O(a.with(n))
        case .dic(let a):
            var n = [O: O]()
            n.reserveCapacity(a.count)
            for (key, e) in a {
                let ne = !e
                switch ne {
                case .error: return ne
                default: n[key] = ne
                }
            }
            return O(n)
        case .error: return ao
        default: return O(OError.undefined(with: "\(notName)\(ao.name)"))
        }
    }
}

extension Array where Element == O {
    func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> [O] {
        return map { $0.rounded(rule) }
    }
}
extension Dictionary where Key == O, Value == O {
    func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> [O: O] {
        return mapValues { $0.rounded(rule) }
    }
}
extension O {
    func rounded(_ rule: FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> O {
        switch self {
        case .bool: return self
        case .int: return self
        case .rational(let a): return O(a.rounded(rule))
        case .double(let a): return O(a.rounded(rule))
        case .array(let a): return O(a.rounded(rule))
        case .range(let a): return O(a.rounded(rule))
        case .dic(let a): return O(a.rounded(rule))
        case .string: return self
        case .sheet(let a): return O(a.rounded(rule))
        case .g: return self
        case .generics(let a): return O(a.rounded(rule))
        case .selected(let a): return O(a.rounded(rule))
        case .f(let a): return O(a.rounded(rule))
        case .label(let a): return O(a.rounded(rule))
        case .id: return self
        case .error: return self
        }
    }
    static let floorName = "floor"
    var floor: O {
        return rounded(.down)
    }
    static let roundName = "round"
    var round: O {
        return rounded()
    }
    static let ceilName = "ceil"
    var ceil: O {
        return rounded(.up)
    }
}

extension O {
    static let absName = "abs"
    var absV: O {
        switch self {
        case .bool(let a): return O(a)
        case .int(let a): return O(abs(a))
        case .rational(let a): return O(abs(a))
        case .double(let a): return O(abs(a))
        case .array(let a):
            var n = O(0)
            for e in a {
                let ne = n + e * e
                switch ne {
                case .error: return ne
                default: n = ne
                }
            }
            return n.sqrt
        case .dic(let a):
            var n = O(0)
            for e in a.values {
                let ne = n + e * e
                switch ne {
                case .error: return ne
                default: n = ne
                }
            }
            return n.sqrt
        case .sheet(let a): return O(a.value).absV
        case .error: return self
        default: return O(OError.undefined(with: "\(O.absName) \(name)"))
        }
    }
    
    static let sqrtName = "sqrt"
    var sqrt: O {
        switch self {
        case .bool(let a): return O(a)
        case .int(let a):
            if a < 0 {
                return O(OError.undefined(with: "\(O.sqrtName) \(name)"))
            }
            return O(Double(a).squareRoot())
        case .rational(let a):
            if a < 0 {
                return O(OError.undefined(with: "\(O.sqrtName) \(name)"))
            }
            return O(Double(a).squareRoot())
        case .double(let a):
            if a < 0 {
                return O(OError.undefined(with: "\(O.sqrtName) \(name)"))
            }
            return O(a.squareRoot())
        case .error: return self
        default: return O(OError.undefined(with: "\(O.sqrtName) \(name)"))
        }
    }
    
    static let sinName = "sin"
    var sin: O {
        switch self {
        case .bool(let a): return O(.sin(Double(a)))
        case .int(let a): return O(.sin(Double(a)))
        case .rational(let a): return O(.sin(Double(a)))
        case .double(let a):
            if a.isInfinite {
                return O(OError.undefined(with: "\(O.sinName) \(name)"))
            }
            return O(.sin(a))
        case .error: return self
        default: return O(OError.undefined(with: "\(O.sinName) \(name)"))
        }
    }
    static let cosName = "cos"
    var cos: O {
        switch self {
        case .bool(let a): return O(.cos(Double(a)))
        case .int(let a): return O(.cos(Double(a)))
        case .rational(let a): return O(.cos(Double(a)))
        case .double(let a):
            if a.isInfinite {
                return O(OError.undefined(with: "\(O.cosName) \(name)"))
            }
            return O(.cos(a))
        case .error: return self
        default: return O(OError.undefined(with: "\(O.cosName) \(name)"))
        }
    }
    static let tanName = "tan"
    var tan: O {
        switch self {
        case .bool(let a): return O(.tan(Double(a)))
        case .int(let a): return O(.tan(Double(a)))
        case .rational(let a): return O(.tan(Double(a)))
        case .double(let a):
            if a.isInfinite {
                return O(OError.undefined(with: "\(O.tanName) \(name)"))
            }
            return O(.tan(a))
        case .error: return self
        default: return O(OError.undefined(with: "\(O.tanName) \(name)"))
        }
    }
    static let asinName = "asin"
    var asin: O {
        switch self {
        case .bool(let a): return O(.asin(Double(a)))
        case .int(let a):
            if a < -1 || a > 1 {
                return O(OError.undefined(with: "\(O.asinName) \(name)"))
            }
            return O(.asin(Double(a)))
        case .rational(let a):
            if a < -1 || a > 1 {
                return O(OError.undefined(with: "\(O.asinName) \(name)"))
            }
            return O(.asin(Double(a)))
        case .double(let a):
            if a < -1 || a > 1 {
                return O(OError.undefined(with: "\(O.asinName) \(name)"))
            }
            return O(.asin(a))
        case .error: return self
        default: return O(OError.undefined(with: "\(O.asinName) \(name)"))
        }
    }
    static let acosName = "acos"
    var acos: O {
        switch self {
        case .bool(let a): return O(.acos(Double(a)))
        case .int(let a):
            if a < -1 || a > 1 {
                return O(OError.undefined(with: "\(O.acosName) \(name)"))
            }
            return O(.acos(Double(a)))
        case .rational(let a):
            if a < -1 || a > 1 {
                return O(OError.undefined(with: "\(O.acosName) \(name)"))
            }
            return O(.acos(Double(a)))
        case .double(let a):
            if a < -1 || a > 1 {
                return O(OError.undefined(with: "\(O.acosName) \(name)"))
            }
            return O(.acos(a))
        case .error: return self
        default: return O(OError.undefined(with: "\(O.acosName) \(name)"))
        }
    }
    static let atanName = "atan"
    var atan: O {
        switch self {
        case .bool(let a): return O(.atan(Double(a)))
        case .int(let a): return O(.atan(Double(a)))
        case .rational(let a): return O(.atan(Double(a)))
        case .double(let a): return O(.atan(a))
        case .error: return self
        default: return O(OError.undefined(with: "\(O.atanName) \(name)"))
        }
    }
    static let atan2Name = "atan2"
    var atan2: O {
        if let p = asPoint {
            return O(.atan2(y: p.y, x: p.x))
        } else {
            return O(OError.undefined(with: "\(O.atan2Name) \(name)"))
        }
    }
}
extension O {
    static let plusName = "+"
    prefix static func + (ao: O) -> O {
        return ao
    }
    static let minusName = "-"
    prefix static func - (ao: O) -> O {
        switch ao {
        case .bool(let a): return O(a)
        case .int(let a): return O(-a)
        case .rational(let a): return O(-a)
        case .double(let a): return O(-a)
        case .array(let a):
            var n = [O]()
            n.reserveCapacity(a.count)
            for e in a {
                let ne = -e
                switch ne {
                case .error: return ne
                default: n.append(ne)
                }
            }
            return O(a.with(n))
        case .dic(let a):
            var n = [O: O]()
            n.reserveCapacity(a.count)
            for (key, e) in a {
                let ne = -e
                switch ne {
                case .error: return ne
                default: n[key] = ne
                }
            }
            return O(n)
        case .sheet(let a): return -O(a.value)
        case .error: return ao
        default: return O(OError.undefined(with: "\(minusName)\(ao.name)"))
        }
    }
}

extension O {
    static func rangeError(_ ao: O, _ str: String, _ bo: O) -> O {
        return O(OError(String(format: "'%1$@' %2$@ '%3$@' is false".localized,
                               ao.name, str, bo.name)))
    }
    static let fiZName = "..."
    static let foZName = "..."
    static let liZName = "..."
    static let loZName = "..."
    static let filiZName = "..."
    static let filoZName = "..<"
    static let foliZName = "<.."
    static let foloZName = "<.<"
    static let filiRName = "~~~"
    static let filoRName = "~~<"
    static let foliRName = "<~~"
    static let foloRName = "<~<"
    static let fiRName = "~~~"
    static let foRName = "~~~"
    static let liRName = "~~~"
    static let loRName = "~~~"
    static func rangeO(_ type: ORange.RangeType, isSmooth: Bool) -> O {
        switch type {
        case .fili(let ao, let bo):
            ao <= bo ?
                O(ORange(type, delta: O(isSmooth ? 0 : 1))) :
                rangeError(ao, isSmooth ? filiRName : filiZName, bo)
        case .filo(let ao, let bo):
            ao <= bo ?
                O(ORange(type, delta: O(isSmooth ? 0 : 1))) :
                rangeError(ao, isSmooth ? filoRName : filoZName, bo)
        case .foli(let ao, let bo):
            ao < bo ?
                O(ORange(type, delta: O(isSmooth ? 0 : 1))) :
                rangeError(ao, isSmooth ? foliRName : foliZName, bo)
        case .folo(let ao, let bo):
            ao < bo ?
                O(ORange(type, delta: O(isSmooth ? 0 : 1))) :
                rangeError(ao, isSmooth ? foloRName : foloZName, bo)
        default:
            O(ORange(type, delta: O(isSmooth ? 0 : 1)))
        }
    }
    
    static let deltaName = "__"
    static func deltaO(_ ao: O, _ bo: O) -> O {
        switch ao {
        case .range(let a):
            return .range(ORange(a.type, delta: bo))
        default:
            return O(OError.undefined(with: "\(ao.name) \(O.deltaName) \(bo.name)"))
        }
    }
}

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
    var endReal: Double {
        switch self {
        case .range(let a):
            switch a.type {
            case .fili(_, let l): l.asDouble ?? 0
            case .filo(_, let l): l.asDouble ?? 0
            case .foli(_, let l): l.asDouble ?? 0
            case .folo(_, let l): l.asDouble ?? 0
            case .fi: 0
            case .fo: 0
            case .li(let l): l.asDouble ?? 0
            case .lo(let l): l.asDouble ?? 0
            case .all: 0
            }
        case .array(let a): Double(a.endIndex)
        default: Double(count)
        }
    }
    var count: Int {
        switch self {
        case .bool(_): return 1
        case .int(_): return 1
        case .rational(_): return 1
        case .double(_): return 1
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
                case .double(let a): return Int(a == 0 ? 0 : Double(d) / a)
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
        let underestimatedCount: Int, endIndex: Int, endV: Double
        
        private var i = 0, realI = 0.0, delta = 1, realDelta: Double?
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
                    realI = f.asDouble ?? 0
                    endIndex = l.rounded(.down).asInt ?? 0
                    endV = l.asDouble ?? 0
                    containsLast = true
                case .filo(let f, let l):
                    i = f.asInt ?? 0
                    realI = f.asDouble ?? 0
                    endIndex = l.rounded(.up).asInt ?? 0
                    endV = l.asDouble ?? 0
                    containsLast = false
                case .foli(let f, let l):
                    i = f.asInt ?? 0
                    realI = f.asDouble ?? 0
                    endIndex = l.rounded(.down).asInt ?? 0
                    endV = l.asDouble ?? 0
                    containsLast = true
                case .folo(let f, let l):
                    i = f.asInt ?? 0
                    realI = f.asDouble ?? 0
                    endIndex = l.rounded(.up).asInt ?? 0
                    endV = l.asDouble ?? 0
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
                case .double(let a):
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
                                if let weight = bo.asDouble {
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
                                if let pressure = bo.asDouble {
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
                                if let v = bo.asDouble {
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
                                if let v = bo.asDouble {
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
                                if let size = bo.asDouble {
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
                                if let v = bo.asDouble {
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
                                if let v = bo.asDouble {
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
        case .double(let a): return O(a == 0 || a == 1)
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
        case .double(let a): return a.isInteger
        default: return false
        }
    }
    var isIntO: O {
        switch self {
        case .bool: return O(true)
        case .int: return O(true)
        case .rational(let a): return O(a.isInteger)
        case .double(let a): return O(a.isInteger)
        case .error: return self
        default: return O(false)
        }
    }
    var isRational: O {
        switch self {
        case .bool: return O(true)
        case .int: return O(true)
        case .rational: return O(true)
        case .double: return O(true)
        case .error: return self
        default: return O(false)
        }
    }
    var isDouble: O {
        switch self {
        case .bool: return O(true)
        case .int: return O(true)
        case .rational: return O(true)
        case .double: return O(true)
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
            case .r: return ao.isDouble
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
        
        guard case .f(let f) = bo else { return arrayArgsError(withCount: 1, notCount: 0)  }
        let nf = f.with(isBlock: false)
        guard nf.outKeys.count == 1 else { return arrayArgsError(withCount: 1, notCount: nf.outKeys.count) }
        
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
        
        guard case .f(let f) = bo else { return arrayArgsError(withCount: 1, notCount: 0)  }
        let nf = f.with(isBlock: false)
        guard nf.outKeys.count == 1 else { return arrayArgsError(withCount: 1, notCount: nf.outKeys.count) }
        
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
        
        guard case .f(let f) = bo else { return arrayArgsError(withCount: 2, notCount: 0)  }
        let nf = f.with(isBlock: false)
        guard nf.outKeys.count == 2 else { return arrayArgsError(withCount: 2, notCount: nf.outKeys.count) }
        
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
                               delta: Double, _ o: O) -> O {
        if delta == 1 {
            let f = inOut == .out ?
                range.lowerBound + 1 : range.lowerBound
            let l = range.upperBound
            guard f <= l else { return rangeError(O(f), "<=", O(l)) }
            return O(Int.random(in: f ... l))
        } else {
            let f = inOut == .out ?
                (Double(range.lowerBound) + (delta > 0 ? delta : .ulpOfOne)) :
                Double(range.lowerBound)
            let l = Double(range.upperBound)
            guard f <= l else { return rangeError(O(f), "<=", O(l)) }
            guard !f.isInfinite && !l.isInfinite else { return O(OError.undefined(with: "\(o.name) \(randomName)")) }
            if delta == 0 {
                return O(Double.random(in: f ... l))
            } else if delta > 0 {
                let v = Double.random(in: f ... l)
                return O((v - f).interval(scale: delta) + f)
            } else {
                fatalError()
            }
        }
    }
    private static func random(in range: ClosedRange<Rational>, _ inOut: InOut,
                               delta: Double, _ o: O) -> O {
        let f = inOut == .out ?
            (Double(range.lowerBound) + (delta > 0 ? delta : .ulpOfOne)) :
            Double(range.lowerBound)
        let l = Double(range.upperBound)
        guard f <= l else { return rangeError(O(f), "<=", O(l)) }
        guard !f.isInfinite && !l.isInfinite else { return O(OError.undefined(with: "\(o.name) \(randomName)")) }
        if delta == 0 {
            return O(Double.random(in: f ... l))
        } else if delta > 0 {
            let v = Double.random(in: f ... l)
            return O((v - f).interval(scale: delta) + f)
        } else {
            fatalError()
        }
    }
    private static func random(in range: ClosedRange<Double>, _ inOut: InOut,
                               delta: Double, _ o: O) -> O {
        let f = inOut == .out ?
            (range.lowerBound + (delta > 0 ? delta : .ulpOfOne)) :
            range.lowerBound
        let l = range.upperBound
        guard f <= l else { return rangeError(O(f), "<=", O(l)) }
        guard !f.isInfinite && !l.isInfinite else { return O(OError.undefined(with: "\(o.name) \(randomName)")) }
        let v = Double.random(in: f ... l)
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
                               delta: Double, _ o: O) -> O {
        if delta == 1 {
            let f = inOut == .out ?
                range.lowerBound + 1 : range.lowerBound
            let l = range.upperBound
            guard f < l else { return rangeError(O(f), "<", O(l)) }
            return O(Int.random(in: f ..< l))
        } else {
            let f = inOut == .out ?
                (Double(range.lowerBound) + (delta > 0 ? delta : .ulpOfOne)) :
                Double(range.lowerBound)
            let l = Double(range.upperBound)
            guard f < l else { return rangeError(O(f), "<", O(l)) }
            guard !f.isInfinite && !l.isInfinite else { return O(OError.undefined(with: "\(o.name) \(randomName)")) }
            if delta == 0 {
                return O(Double.random(in: f ..< l))
            } else if delta > 0 {
                let v = Double.random(in: f ..< l)
                return O((v - f).interval(scale: delta) + f)
            } else {
                fatalError()
            }
        }
    }
    private static func random(in range: Range<Rational>, _ inOut: InOut,
                               delta: Double, _ o: O) -> O {
        let f = inOut == .out ?
            (Double(range.lowerBound) + (delta > 0 ? delta : .ulpOfOne)) :
            Double(range.lowerBound)
        let l = Double(range.upperBound)
        guard f < l else { return rangeError(O(f), "<", O(l)) }
        guard !f.isInfinite && !l.isInfinite else { return O(OError.undefined(with: "\(o.name) \(randomName)")) }
        if delta == 0 {
            return O(Double.random(in: f ..< l))
        } else if delta > 0 {
            let v = Double.random(in: f ..< l)
            return O((v - f).interval(scale: delta) + f)
        } else {
            fatalError()
        }
    }
    private static func random(in range: Range<Double>, _ inOut: InOut,
                               delta: Double, _ o: O) -> O {
        let f = inOut == .out ?
            (range.lowerBound + (delta > 0 ? delta : .ulpOfOne)) :
            range.lowerBound
        let l = range.upperBound
        guard f < l else { return rangeError(O(f), "<", O(l)) }
        guard !f.isInfinite && !l.isInfinite else { return O(OError.undefined(with: "\(o.name) \(randomName)")) }
        let v = Double.random(in: f ..< l)
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
            let d = range.delta.asDouble ?? 0
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
                    case .double(let b):
                        return .random(in: Double(a) ... b, .in, delta: d, self)
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
                    case .double(let b):
                        return .random(in: Double(a) ... b, .in, delta: d, self)
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
                    case .double(let b):
                        return .random(in: Double(a) ... b, .in, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .double(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ... Double(b), .in, delta: d, self)
                    case .int(let b):
                        return .random(in: a ... Double(b), .in, delta: d, self)
                    case .rational(let b):
                        return .random(in: a ... Double(b), .in, delta: d, self)
                    case .double(let b):
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
                    case .double(let b):
                        return .random(in: Double(a) ..< b, .in, delta: d, self)
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
                    case .double(let b):
                        return .random(in: Double(a) ..< b, .in, delta: d, self)
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
                    case .double(let b):
                        return .random(in: Double(a) ..< b, .in, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .double(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ..< Double(b), .in, delta: d, self)
                    case .int(let b):
                        return .random(in: a ..< Double(b), .in, delta: d, self)
                    case .rational(let b):
                        return .random(in: a ..< Double(b), .in, delta: d, self)
                    case .double(let b):
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
                    case .double(let b):
                        return .random(in: Double(a) ... b, .out, delta: d, self)
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
                    case .double(let b):
                        return .random(in: Double(a) ... b, .out, delta: d, self)
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
                    case .double(let b):
                        return .random(in: Double(a) ... b, .out, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .double(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ... Double(b), .out, delta: d, self)
                    case .int(let b):
                        return .random(in: a ... Double(b), .out, delta: d, self)
                    case .rational(let b):
                        return .random(in: a ... Double(b), .out, delta: d, self)
                    case .double(let b):
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
                    case .double(let b):
                        return .random(in: Double(a) ..< b, .out, delta: d, self)
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
                    case .double(let b):
                        return .random(in: Double(a) ..< b, .out, delta: d, self)
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
                    case .double(let b):
                        return .random(in: Double(a) ..< b, .out, delta: d, self)
                    default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                    }
                case .double(let a):
                    switch bo {
                    case .bool(let b):
                        return .random(in: a ..< Double(b), .out, delta: d, self)
                    case .int(let b):
                        return .random(in: a ..< Double(b), .out, delta: d, self)
                    case .rational(let b):
                        return .random(in: a ..< Double(b), .out, delta: d, self)
                    case .double(let b):
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
                    return O.random(in: Double(a) ... .infinity, .in, delta: d, self).rounded()
                case .rational(let a):
                    let n = O.random(in: Double(a) ... .infinity, .in, delta: d, self)
                    if case .double(let r) = n, let nn = Rational(exactly: r) {
                        return O(nn)
                    } else {
                        return n
                    }
                case .double(let a):
                    return .random(in: a ... .infinity, .in, delta: d, self)
                default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                }
            case .fo(let ao):
                switch ao {
                case .bool(let a):
                    return a ? .empty : O(true)
                case .int(let a):
                    return O.random(in: Double(a) ... .infinity, .out, delta: d, self).rounded()
                case .rational(let a):
                    let n = O.random(in: Double(a) ... .infinity, .out, delta: d, self)
                    if case .double(let r) = n, let nn = Rational(exactly: r) {
                        return O(nn)
                    } else {
                        return n
                    }
                case .double(let a):
                    return .random(in: a ... .infinity, .out, delta: d, self)
                default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                }
            case .li(let ao):
                switch ao {
                case .bool(let a):
                    return O(a ? Bool.random() : false)
                case .int(let a):
                    return O.random(in: -.infinity ... Double(a), .in, delta: d, self).rounded()
                case .rational(let a):
                    let n = O.random(in: -.infinity ... Double(a), .in, delta: d, self)
                    if case .double(let r) = n, let nn = Rational(exactly: r) {
                        return O(nn)
                    } else {
                        return n
                    }
                case .double(let a):
                    return .random(in: -.infinity ... a, .in, delta: d, self)
                default: return O(OError.undefined(with: "\(self) \(O.randomName)"))
                }
            case .lo(let ao):
                switch ao {
                case .bool(let a):
                    return a ? O(false) : .empty
                case .int(let a):
                    return O.random(in: -.infinity ..< Double(a), .in, delta: d, self).rounded()
                case .rational(let a):
                    let n = O.random(in: -.infinity ..< Double(a), .in, delta: d, self)
                    if case .double(let r) = n, let nn = Rational(exactly: r) {
                        return O(nn)
                    } else {
                        return n
                    }
                case .double(let a):
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

extension O {
    static let horizontalName = "horizontal"
    static let verticalName = "vertical"
    
    static let sheetDicName = "sheetDic"
    static let sheetName = "sheet"
    static let sheetSizeName = "sheetSize"
    static let cursorPName = "cursorP"
    static let printPName = "printP"
}
extension O {
    static let showAboutRunName = "showAboutRun"
    static func showAboutRun(_ ao: O) -> O {
        guard case .sheet(var sheet) = ao else { return O(OError(String(format: "Argument $0 must be sheet, not '%1$@'".localized, ao.name))) }
        
        let b = sheet.bounds
        let lPadding = 20.0
        
        var p = Point(0, -lPadding), allSize = Size()
        
        var t0 = Text(string: "About Run".localized, size: 20, origin: p)
        let size0 = t0.typesetter.typoBounds?.size ?? Size()
        p.y -= size0.height + lPadding / 4
        allSize.width = max(allSize.width, size0.width)
        
        var t1 = Text(string: "To show all definitions, run the following statement".localized, origin: p)
        let size2 = t1.typesetter.typoBounds?.size ?? Size()
        p.y -= size2.height * 2
        
        var t2 = Text(string: "sheet showAllDefinitions =", origin: p)
        let size3 = t2.typesetter.typoBounds?.size ?? Size()
        p.y -= size3.height + lPadding * 2
        
        let s0 = """
\("Bool".localized)
    false
    true

\("Rational number".localized)
    0
    1
    +3
    -20
    1/2

\("Real number".localized)
    0.0
    1.3
    +1.02
    -20.0

\("Infinity".localized)
    ∞ -∞ +∞ (\("Key input".localized): ⌥ 5)

\("String".localized)
    "A AA" -> A AA
    "AA\"A" -> AA"A
    "AAAAA\\nAA" ->
        AAAAA
        AA

\("Array".localized)
    a b c
    (a b c)
    (a b (c d))

\("Dictionary".localized)
    (a: d  b: e  c: f)
    = ((\"a\"): d  (\"b\"): e  (\"c\"): f)

\("Function".localized)
    (1 + 2) = 3
    (a: 1  b: 2  c: 3 | a + b + c) = 6
    (a(b c): b + c | a 1 2 + 3) = 6
    ((b)a(c): b + c | 1 a 2 + 3) = 6
    ((b)a(c: d): b + d | 1 a c: 2 + 3) = 6
    ((b)a(c)100: b + c | 2 a 2 * 3 + 1) = 9
        \("Precedence".localized): 100  \("Associaticity".localized): \("Left".localized)
    ((b)a(c)150r: b / c | 1 a 2 a 3 + 1) = 5 / 2
        \("Precedence".localized): 150  \("Associaticity".localized): \("Right".localized)

\("Block function".localized)
    (| 1 + 2) send () = 3
    (| a: 1  b: 2  c: 3 | a + b + c) send () = 6
    (a b c | a + b + c) send (1 2 3) = 6
    (a b c | d: a + b | d + c) send (1 2 3) = 6

\("Conditional function".localized)
        1 == 2
        -> 3
        -! 4
    = 4,
        1 == 2
        -> 3
        -!
        4 * 5
        case 10      -> 100
        case 10 + 10 -> 200
        -! 300
    = 200,
        "a"
        case "a" -> 1
        case "b" -> 2
        case "c" -> 3
    = 1
"""
        // Issue?: if 1 == 2
        // switch "a"
        
        let t3 = Text(string: s0, origin: p)
        let size4 = t3.typesetter.typoBounds?.size ?? Size()
        
        let setS = G.allCases.reduce(into: "") {
            $0 += ($0.isEmpty ? "" : "\n\t") + $1.rawValue + ": " + $1.displayString
        }
        let s1 = """
\("Set".localized)
    \(setS)

\("Lines bracket".localized)
    a + b +
        c +
            d + e
    = a + b + (c + (d + e))

\("Split".localized)
    (a + b, b + c, c) = ((a + b) (b + c) (c))

\("Separator".localized) (\("Separator character".localized) \(O.defaultLiteralSeparator)):
    abc12+3 = abc12 + 3
    abc12++3 = abc12 ++ 3

\("Union".localized)
    a + b+c = a + (b + c)
    a+b*c + d/e = (a + b * c) + (d / e)

\("Omit multiplication sign".localized)
    3a + b = 3 * a + b
    3a\("12".toSubscript)c\("3".toSubscript) + b = 3 * a\("12".toSubscript) * c\("3".toSubscript) + b
    a\("2".toSubscript)''b\("2".toSubscript)c'd = a\("2".toSubscript)'' * b\("2".toSubscript) * c' * d
    (x + 1)(x - 1) = (x + 1) * (x - 1)

\("Pow".localized)
    x\("1+2".toSuperscript) = x ** (1 + 2)

\("Get".localized)
    a.b.c = a . "b" . "c"

\("Select".localized)
    a/.b.c = a /. "b" /. "c"

\("xyzw".localized)
    a is Array -> a.x = a . 0
    a is Array -> a.y = a . 1
    a is Array -> a.z = a . 2
    a is Array -> a.w = a . 3

\("Sheet bond".localized)
    \("Put '+' string beside the frame of the sheet you want to connect.".localized)
""" // + xxxx -> border bond
        
        let t4 = Text(string: s1, origin: p + Point(size4.width + lPadding * 2, 0))
        let size5 = t4.typesetter.typoBounds?.size ?? Size()
        
        p.y -= max(size4.height, size5.height) + lPadding
        allSize.width = size4.width + size5.width + lPadding * 2
        
        t0.origin.x = (allSize.width - size0.width) / 2
        t1.origin.x = (allSize.width - size2.width) / 2
        t2.origin.x = (allSize.width - size3.width) / 2
        
        let w = allSize.width, h = -p.y
        let ts = [t0, t1, t2, t3, t4]
        
        let size = Size(width: w + lPadding * 2,
                        height: h + lPadding * 2)
        let scale = min(1, b.width / size.width, b.height / size.height)
        let dx = (b.width - size.width * scale) / 2
        let t = Transform(scale: scale)
            * Transform(translation: b.minXMaxYPoint + Point(lPadding * scale + dx, -lPadding * scale))
        let nts = ts.map { $0 * t }
        
        sheet.removeAll()
        sheet.append(nts)
        return O(sheet)
    }
    
    static let showAllDefinitionsName = "showAllDefinitions"
    static func showAllDefinitions(_ ao: O, _ oDic: inout [OKey: O],
                                   enableCustom: Bool = true) -> O {
        guard case .sheet(var sheet) = ao else { return O(OError(String(format: "Argument $0 must be sheet, not '%1$@'".localized, ao.name))) }
        let b = sheet.bounds
        
        let customGroup = OKeyInfo.Group(name: "Custom".localized, index: -1)
        
        var os = [OKeyInfo.Group: [OKey: O]]()
        for (key, value) in oDic {
            if let info = key.info {
                if os[info.group] != nil {
                    os[info.group]?[key] = value
                } else {
                    os[info.group] = [key: value]
                }
            } else if enableCustom {
                if os[customGroup] != nil {
                    os[customGroup]?[key] = value
                } else {
                    os[customGroup] = [key: value]
                }
            }
        }
        
        let nnos = os.reduce(into: [OKeyInfo.Group: [(key: OKey, value: O)]]()) {
            $0[$1.key] = $1.value
                .sorted { $0.key.info?.index ?? 0 < $1.key.info?.index ?? 0 }
        }
        let nos = nnos.sorted { $0.key.index < $1.key.index }
        
        struct Cell {
            var string: String
            var size: Size
            init(_ s: String) {
                string = s
                size = Text(string: s)
                    .typesetter.typoBounds?.size ?? Size()
            }
        }
        struct Table {
            var y = 0.0
            var groupCell: Cell
            var nameCell: Cell, precedenceCell: Cell
            var associaticityCell: Cell, descriptionCell: Cell
            var height: Double {
                max(groupCell.size.height,
                    nameCell.size.height,
                    precedenceCell.size.height,
                    associaticityCell.size.height,
                    descriptionCell.size.height)
            }
        }
        
        let lPadding = 24.0
        let padding = 10.0
        
        var y = 0.0, tables = [Table]()
        let nameS = "Definition name".localized
        let preceS = "Precedence".localized
        let assoS = "Associaticity".localized
        let descS = "Description ($0: zeroth argument, $1: First argument, ...)".localized
        var table = Table(y: y, groupCell: Cell(""),
                          nameCell: Cell(nameS),
                          precedenceCell: Cell(preceS),
                          associaticityCell: Cell(assoS),
                          descriptionCell: Cell(descS))
        let typeH = table.height
        table.y = typeH + lPadding
        tables.append(table)
        for (group, oDic) in nos {
            for (i, v) in oDic.enumerated() {
                let (key, value) = v
                let groupName = i == 0 ? (group.name + ":") : ""
                let name = key.description
                let precedence: String
                switch value {
                case .f(let f): precedence = "\(f.precedence)"
                default: precedence = "0"
                }
                let associativity: String
                switch value {
                case .f(let f):
                    switch f.associativity {
                    case .left: associativity = "Left".localized
                    case .right: associativity = "Right".localized
                    }
                default: associativity = "None".localized
                }
                let s = key.info?.description ?? "None".localized
                let description = s.isEmpty ? "None".localized : s
                let table = Table(y: y, groupCell: Cell(groupName),
                                  nameCell: Cell(name),
                                  precedenceCell: Cell(precedence),
                                  associaticityCell: Cell(associativity),
                                  descriptionCell: Cell(description))
                tables.append(table)
                y -= table.height + padding
            }
            y += padding
            y -= lPadding
        }
        y += lPadding
        
        var ts = [Text]()
        var x = 0.0
        var groupW = 0.0
        for table in tables {
            if !table.groupCell.string.isEmpty {
                groupW = max(groupW, table.groupCell.size.width)
                let t = Text(string: table.groupCell.string,
                             origin: Point(-table.groupCell.size.width - lPadding, table.y))
                ts.append(t)
            }
        }
        var dw = 0.0
        for table in tables {
            dw = max(dw, table.nameCell.size.width)
            let t = Text(string: table.nameCell.string,
                         origin: Point(x, table.y))
            ts.append(t)
        }
        x += dw + lPadding
        dw = 0
        for table in tables {
            dw = max(dw, table.precedenceCell.size.width)
        }
        for table in tables {
            let t = Text(string: table.precedenceCell.string,
                         origin: Point(x + dw - table.precedenceCell.size.width, table.y))
            ts.append(t)
        }
        x += dw + lPadding
        dw = 0
        for table in tables {
            dw = max(dw, table.associaticityCell.size.width)
            let t = Text(string: table.associaticityCell.string,
                         origin: Point(x, table.y))
            ts.append(t)
        }
        x += dw + lPadding
        dw = 0
        for table in tables {
            dw = max(dw, table.descriptionCell.size.width)
            let t = Text(string: table.descriptionCell.string,
                         origin: Point(x, table.y))
            ts.append(t)
        }
        x += dw
        
        let h = -y + typeH + lPadding
        let w = x + groupW + lPadding
        
        let size = Size(width: w + lPadding * 2, height: h + lPadding * 2)
        let scale = min(1, b.width / size.width, b.height / size.height)
        let dx = (b.width - size.width * scale) / 2
        let t = Transform(scale: scale)
            * Transform(translation: b.minXMaxYPoint + Point((groupW + lPadding * 2) * scale + dx, -(typeH + lPadding * 2) * scale))
        ts = ts.map { $0 * t }
        
        var line = Line(edge: Edge(Point(-groupW - lPadding, (typeH + lPadding) / 2), Point(w - groupW, (typeH + lPadding) / 2))) * t
        line.size *= scale
        
        sheet.removeAll()
        sheet.append(line)
        sheet.append(ts)
        return O(sheet)
    }
    
    static let drawName = "draw"
    static func draw(_ ao: O, _ oDic: inout [OKey: O]) -> O {
        func no(from a: [O: O], lineWidth: Double? = nil) -> O {
            if let rectO = a[O("rect")], case .dic(let rectDic) = rectO, let r = a[O("r")]?.asDouble,
               let originO = rectDic[O("origin")], let sizeO = rectDic[O("size")],
                 case .array(let originOs) = originO, case .dic(let sizeDic) = sizeO,
                  originOs.count == 2, let x = originOs[0].asDouble, let y = originOs[1].asDouble,
               let width = sizeDic[O("width")]?.asDouble, let height = sizeDic[O("height")]?.asDouble {
                
                let rect = Rect(x: x, y: y, width: width, height: height)
                let path = Path([Pathline(rect, cornerRadius: r)])
                let (dps, _) = path.pathDistancePoints(lineWidth: 1)
                let line = Line(controls: dps.map { .init(point: $0.point, pressure: 1) },
                                size: lineWidth ?? Line.defaultLineWidth)
                return drawLine(line, &oDic)
            } else if let originO = a[O("origin")], let sizeO = a[O("size")],
               case .array(let originOs) = originO, case .dic(let sizeDic) = sizeO,
                originOs.count == 2, let x = originOs[0].asDouble, let y = originOs[1].asDouble,
               let width = sizeDic[O("width")]?.asDouble, let height = sizeDic[O("height")]?.asDouble {
                
                let rect = Rect(x: x, y: y, width: width, height: height)
                let ps = [rect.minXMaxYPoint, rect.minXMinYPoint, rect.minXMinYPoint,
                          rect.maxXMinYPoint, rect.maxXMinYPoint, rect.maxXMaxYPoint, rect.maxXMaxYPoint,
                          rect.minXMaxYPoint]
                let line = Line(controls: ps.map { Line.Control(point: $0) },
                                size: lineWidth ?? Line.defaultLineWidth)
                return drawLine(line, &oDic)
            }
            return O(OError.undefined(with: "\(self) \(O.drawName)"))
        }
        switch ao {
        case .array(let a):
            if a.count == 2,
               case .dic(let rectDic) = a[0],
               case .dic(let lineWidthDic) = a[1],
               let lineWidth = lineWidthDic[O("lineWidth")]?.asDouble {
                
                return no(from: rectDic, lineWidth: lineWidth)
            } else {
                return O(OError.undefined(with: "\(self) \(O.drawName)"))
            }
        case .dic(let a):
            return no(from: a)
        case .error: return ao
        default:
            let ps = ao.asPoints
            if ps.isEmpty {
                return O(OError.undefined(with: "\(self) \(O.drawName)"))
            } else if ps.count == 1 {
                return drawPoint(ps[0], &oDic)
            } else {
                let line = Line(controls: ps.map { Line.Control(point: $0) })
                return drawLine(line, &oDic)
            }
        }
    }
    
    static let drawAxesName = "drawAxes"
    static func drawAxes(base bo: O, _ xo: O, _ yo: O,
                         _ oDic: inout [OKey: O]) -> O {
        guard let base = bo.asDouble, base > 0 else { return O(OError(String(format: "'%1$@' is not positive real".localized, bo.name))) }
        guard case .sheet(var sheet)? = oDic[OKey(sheetName)] else { return O(OError(String(format: "'%1$@' does not exist".localized, sheetName))) }
        let xName = xo.asTextBasedString, yName = yo.asTextBasedString
        
        let b = sheet.bounds
        let cp = b.centerPoint, r = 200.0, d = 5.0
        let ex = Edge(cp + Point(-r, 0), cp + Point(r, 0))
        let ey = Edge(cp + Point(0, -r), cp + Point(0, r))
        
        let ax = ex.reversed().angle(), ay = ey.reversed().angle()
        let xArrow0 = Line(edge: Edge(ex.p1.movedWith(distance: d,
                                                      angle: ax - .pi / 6),
                                      ex.p1))
        let xArrow1 = Line(edge: Edge(ex.p1,
                                      ex.p1.movedWith(distance: d,
                                                      angle: ax + .pi / 6)))
        let yArrow0 = Line(edge: Edge(ey.p1.movedWith(distance: d,
                                                      angle: ay - .pi / 6),
                                      ey.p1))
        let yArrow1 = Line(edge: Edge(ey.p1,
                                      ey.p1.movedWith(distance: d,
                                                      angle: ay + .pi / 6)))
        let xAxis = Line(edge: ex), yAxis = Line(edge: ey)
        let ys = Text(string: yName)
            .typesetter.typoBounds?.size ?? Size()
        let x = Text(string: xName, origin: ex.p1 + Point(5, 0))
        let y = Text(string: yName, origin: ey.p1 + Point(-ys.width / 2,
                                                          ys.height / 2 + 5))
        
        let baseP = Point(180, 0) + Point(256, 362)
        let baseLine = Line(edge: Edge(Point(baseP.x, baseP.y - 5),
                                       Point(baseP.x, baseP.y + 5)))
        let baseName = String(intBased: base)
        let bs = Text(string: baseName)
            .typesetter.typoBounds?.size ?? Size()
        let baseS = Text(string: baseName,
                         origin: baseP + Point(-bs.width / 2, -bs.height - 5))
        
        let texts = [x, y, baseS].filter { !$0.isEmpty }
        sheet.append([xAxis, xArrow0, xArrow1,
                      yAxis, yArrow0, yArrow1, baseLine])
        sheet.append(texts)
        return O(sheet)
    }
    
    static let plotName = "plot"
    static func plot(base bo: O, _ ao: O, _ oDic: inout [OKey: O]) -> O {
        guard let base = bo.asDouble, base > 0 else { return O(OError(String(format: "'%1$@' is not positive real".localized, bo.name))) }
        
        switch ao {
        case .error: return ao
        default:
            let ps = ao.asPoints
            let s = 180 / base
            if ps.count == 1 {
                let np = ps[0] * s + Point(256, 362)
                return drawPoint(np, name: ao.name, &oDic)
            } else {
                let line = Line(controls: ps.map {
                    let np = $0 * s + Point(256, 362)
                    return Line.Control(point: np)
                })
                return drawLine(line, &oDic)
            }
        }
    }
    static func drawPoint(_ np: Point, name: String? = nil,
                          _ oDic: inout [OKey: O]) -> O {
        guard case .sheet(var sheet)? = oDic[OKey(sheetName)] else { return O(OError(String(format: "'%1$@' does not exist".localized, sheetName))) }
        
        let b = sheet.bounds
        let xs = String(intBased: np.x), ys = String(intBased: np.y)
        if b.inset(by: Line.defaultLineWidth).contains(np) {
            let line = Line.circle(centerPosition: np, radius: 1)
            let t = Text(string: name ?? "(\(xs) \(ys))",
                         origin: np + Point(7, 0))
            sheet.append(line)
            sheet.append(t)
            return O(sheet)
        }
        return drawEqual(String(format: "'%1$@' is out of bounds".localized,
                                "(\(xs) \(ys))"), &oDic)
    }
    static func drawLine(_ l: Line, _ oDic: inout [OKey: O]) -> O {
        guard case .sheet(var sheet)? = oDic[OKey(sheetName)] else { return O(OError(String(format: "'%1$@' does not exist".localized, sheetName))) }
        
        if l.controls.count >= 2 {
            let l = l.controls.count > 10000 ? Line(controls: Array(l.controls[0 ..< 10000])) : l
            let b = sheet.bounds
            let newLines = Sheet.clipped([l],
                                         in: b.inset(by: Line.defaultLineWidth))
            if !newLines.isEmpty {
                sheet.append(newLines)
                return O(sheet)
            }
        }
        return drawEqual("Line is out of bounds".localized,  &oDic)
    }
    static func drawText(_ t: Text, _ oDic: inout [OKey: O]) -> O {
        guard case .sheet(var sheet)? = oDic[OKey(sheetName)] else { return O(OError(String(format: "'%1$@' does not exist".localized, sheetName))) }
        
        let b = sheet.bounds
        if let frame = t.frame, b.intersects(frame) {
            sheet.append(t)
            return O(sheet)
        }
        return drawEqual("Text is out of bounds".localized, &oDic)
    }
    static func drawEqual(_ s: String, _ oDic: inout [OKey: O]) -> O {
        guard case .sheet(var sheet)? = oDic[OKey(sheetName)] else { return O(OError(String(format: "'%1$@' does not exist".localized, sheetName))) }
        guard let p = oDic[OKey(printPName)]?.asPoint else { return O(OError(String(format: "'%1$@' does not exist".localized, printPName))) }
        
        let nt = Text(string: "= " + s, origin: p)
        sheet.append(nt)
        return O(sheet)
    }
    
    static let flipName = "flip"
    static func flip(_ orientationO: O, _ oDic: inout [OKey: O]) -> O {
        guard case .string(let oString) = orientationO else { return O(OError(String(format: "'%1$@' is not string".localized, orientationO.name))) }
        let orientation: Orientation
        if oString == horizontalName {
            orientation = .horizontal
        } else if oString == verticalName {
            orientation = .vertical
        } else {
            return O(OError(String(format: "'%1$@' is not horizontal or vertical".localized, orientationO.name)))
        }
        
        guard case .sheet(var sheet)? = oDic[OKey(sheetName)] else { return O(OError(String(format: "'%1$@' does not exist".localized, sheetName))) }
        let lines = sheet.value.picture.lines
        sheet.removeLines(at: Array(0 ..< lines.count))
        switch orientation {
        case .horizontal:
            var t = Transform.identity
            t.translate(by: -sheet.bounds.centerPoint)
            t.scaleBy(x: -1, y: 1)
            t.translate(by: sheet.bounds.centerPoint)
            sheet.append(lines.map { $0 * t })
        case .vertical:
            var t = Transform.identity
            t.translate(by: -sheet.bounds.centerPoint)
            t.scaleBy(x: 1, y: -1)
            t.translate(by: sheet.bounds.centerPoint)
            sheet.append(lines.map { $0 * t })
        }
        return O(sheet)
    }
}

extension O {
    static let asLabelName = ":"
    var asLabel: O {
        switch self {
        case .error: self
        default: O(OLabel(self))
        }
    }
}

extension O {
    static let asStringName = "\\"
    var asString: String {
        func lineStr(_ a: Line) -> String {
            let s = a.controls.reduce(into: "") {
                var ns = ""
                ns += ns.isEmpty ? "" : " "
                ns += "("
                ns += "point: ((\(String(intBased: $1.point.x)) \(String(intBased: $1.point.y)))\n"
                ns += "weight: \(String(intBased: $1.weight))\n"
                ns += "pressure: \(String(intBased: $1.pressure))\n"
                ns += ")"
                $0 += ns
            }
            return "(\(s))"
        }
        func textStr(_ a: Text) -> String {
            let s = a.string
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            var ns = ""
            ns += ns.isEmpty ? "" : " "
            ns += "("
            ns += "string: \"\(s)\"\n"
            ns += "orientation: \(a.orientation.rawValue)\n"
            ns += "size: \(String(intBased: a.size))\n"
            ns += "origin: (\(String(intBased: a.origin.x)) \(String(intBased: a.origin.y)))"
            ns += ")"
            return ns
        }
        
        switch self {
        case .bool(let a): return String(a)
        case .int(let a): return String(a)
        case .rational(let a): return String(a)
        case .double(let a): return String(oBased: a)
        case .array(let a):
            let bs = a.reduce(into: "") {
                let s = $1.asString
                $0 += $0.isEmpty ? s : (s.count > 10 ? "\n" : " ") + s
            }
            return a.dimension > 1 ?
                "((" + bs + ") ;)" :
                "(" + bs + ")"
        case .range(let a):
            let d = a.delta
            switch a.type {
            case .fili(let f, let l):
                return d == O(0) ? "\(f)~~~\(l)" :
                    (d == O(1) ? "\(f) ... \(l)" : "\(f) ... \(l) __ \(d)")
            case .filo(let f, let l):
                return d == O(0) ? "\(f)~~<\(l)" :
                    (d == O(1) ? "\(f) ..< \(l)" : "\(f) ..< \(l) __ \(d)")
            case .foli(let f, let l):
                return d == O(0) ? "\(f)<~~\(l)" :
                    (d == O(1) ? "\(f) <.. \(l)" : "\(f) <..\(l) __ \(d)")
            case .folo(let f, let l):
                return d == O(0) ? "\(f)<~<\(l)" :
                    (d == O(1) ? "\(f)<.<\(l)" : "\(f)<.<\(l)_\(d)")
            case .fi(let f):
                return d == O(0) ? "\(f)~~~" :
                    (d == O(1) ? "\(f)..." : "\(f)..._\(d)")
            case .fo(let f):
                return d == O(0) ? "\(f)<~~" :
                    (d == O(1) ? "\(f)<.." : "\(f)<.._\(d)")
            case .li(let l):
                return d == O(0) ? "~~~\(l)" :
                    (d == O(1) ? "...\(l)" : "...\(l)_\(d)")
            case .lo(let l):
                return d == O(0) ? "~~<\(l)" :
                    (d == O(1) ? "..<\(l)" : "..<\(l) __ \(d)")
            case .all:
                return d == O(0) ? "R" :
                    (d == O(1) ? "Z" : "Z_\(d)")
            }
        case .dic(let a):
            func dicString(key: O, value: O) -> String {
                switch key {
                case .string(let s):
                    return s + ": " + value.asString
                default:
                    return key.asString + ": " + value.asString
                }
            }
            let bs = a.reduce(into: "") {
                $0 += $0.isEmpty ?
                    dicString(key: $1.key, value: $1.value) :
                    "  " + dicString(key: $1.key, value: $1.value)
            }
            return "(" + bs + ")"
        case .string(let a):
            let s = a
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            return "\"\(s)\""
        case .sheet(let ss):
            var s = ""
            if !ss.value.picture.lines.isEmpty {
                var ns = ""
                for line in ss.value.picture.lines {
                    ns += ns.isEmpty ? "" : "\n"
                    ns += lineStr(line)
                }
                s += "lines: " + "(" + ns + ")"
            }
            if !ss.value.texts.isEmpty {
                s += s.isEmpty ? "" : "\n"
                var ns = ""
                for text in ss.value.texts {
                    ns += ns.isEmpty ? "" : "\n"
                    ns += textStr(text)
                }
                s += "texts: " + "(" + ns + ")"
            }
            return "(" + s + ")"
        case .g(let a): return a.rawValue
        case .generics(let a): return a.description
        case .selected(let a):
            if a.ranges.count == 1 {
                return a.o.asString + "/." + a.ranges[0].asString
            } else {
                let bs = a.ranges.reduce(into: "") {
                    let s = $1.asString
                    $0 += $0.isEmpty ? s : (s.count > 10 ? "\n" : " ") + s
                }
                let rangeStr = "(" + bs + ")"
                return a.o.asString + "/." + rangeStr
            }
        case .f(let a): return a.description
        case .label(let a): return a.description
        case .id(let a): return a.description
        case .error(let a): return a.description
        }
    }
    var asStringO: O {
        O(asString)
    }
}

extension O {
    static let asErrorName = "?"
    var asError: O {
        switch self {
        case .string(let a): O(OError(a))
        case .error: self
        default: O(OError(description))
        }
    }
    
    var isError: Bool {
        switch self {
        case .error: true
        default: false
        }
    }
    static let isErrorName = "?"
    var isErrorO: O {
        switch self {
        case .error: O(true)
        default: O(false)
        }
    }
    
    static let errorCoalescingName = "???"
    static func errorCoalescing(_ ao: O, _ bo: O) -> O {
        ao.isError ? bo : ao
    }
    
    static let nilCoalescingName = "??"
    static func nilCoalescing(_ ao: O, _ bo: O) -> O {
        ao == O.nilV ? bo : ao
    }
}
