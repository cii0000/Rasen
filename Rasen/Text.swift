// Copyright 2023 Cii
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

import struct Foundation.Locale
import struct Foundation.Data
import struct Foundation.NSRange
import class Foundation.NSString
import CoreFoundation

extension String {
    var isAlphanumeric: Bool {
        !isEmpty && (range(of: "[^x00-x7f\\s]",
                           options: .regularExpression) == nil)
    }
    func toHiragana() -> String {
        var nstrs = [String]()
        for cstr in components(separatedBy: .whitespaces) {
            let localeID = CFLocaleCreateCanonicalLanguageIdentifierFromString(kCFAllocatorDefault, "ja" as CFString)
            let locale = CFLocaleCreate(kCFAllocatorDefault, localeID)

            let range = CFRangeMake(0, (cstr as NSString).length)
            let tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault,
                                                    cstr as CFString,
                                                    range,
                                                    kCFStringTokenizerUnitWordBoundary,
                                                    locale)
            var token = CFStringTokenizerGoToTokenAtIndex(tokenizer, 0)
            var nstr = ""
            while token != [] {
                if let latin = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String,
                   let hira = latin.applyingTransform(.latinToHiragana, reverse: false) {
                    nstr += hira
                } else {
                    let nRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
                    let nsRange = NSRange(location: nRange.location, length: nRange.length)
                    nstr += (cstr as NSString).substring(with: nsRange)
                }
                token = CFStringTokenizerAdvanceToNextToken(tokenizer)
            }
            nstrs.append(nstr)
        }
        return nstrs.reduce(into: "") { $0 += $0.isEmpty ? $1 : " " + $1 }
    }
}

extension String: Serializable {
    struct SerializableError: Error {}
    init(serializedData data: Data) throws {
        guard let string = String(data: data, encoding: .utf8) else {
            throw SerializableError()
        }
        self = string
    }
    func serializedData() throws -> Data {
        if let data = data(using: .utf8) {
            return data
        } else {
            throw SerializableError()
        }
    }
}
extension String {
    func intIndex(from i: String.Index) -> Int {
        distance(from: startIndex, to: i)
    }
    func intRange(from range: Range<String.Index>) -> Range<Int> {
        intIndex(from: range.lowerBound) ..< intIndex(from: range.upperBound)
    }
    func index(fromInt i: Int) -> String.Index {
        index(startIndex, offsetBy: i)
    }
    func index(fromSafetyInt i: Int) -> String.Index? {
        if i >= 0 && i < count {
            return index(startIndex, offsetBy: i)
        } else {
            return nil
        }
    }
    func range(fromInt range: Range<Int>) -> Range<String.Index> {
        index(fromInt: range.lowerBound) ..< index(fromInt: range.upperBound)
    }
    
    func range(_ range: Range<Index>, offsetBy d: Int) -> Range<Index> {
        let nsi = index(range.lowerBound, offsetBy: d)
        let nei = index(range.upperBound, offsetBy: d)
        return nsi ..< nei
    }
    func count(from range: Range<Index>) -> Int {
        distance(from: range.lowerBound, to: range.upperBound)
    }
    
    var lines: [String] {
        var lines = [String]()
        enumerateLines { line, stop in
            lines.append(line)
        }
        return lines
    }
    
    func difference(to toString: String) -> (intRange: Range<Int>,
                                             subString: String)? {
        let fromV = Array(self), toV = Array(toString)
        let fromCount = count, toCount = toString.count
        var startI = 0, endI = 0
        while startI < fromCount && startI < toCount
                && fromV[startI] == toV[startI] {
            startI += 1
        }
        while startI + endI < fromCount && startI + endI < toCount
                && fromV[fromCount - 1 - endI] == toV[toCount - 1 - endI] {
            endI += 1
        }
        if fromCount != startI + endI {
            let range = startI ..< (fromCount - endI)
            return (range, String(toV[startI ..< (toCount - endI)]))
        } else if toCount != startI + endI {
            let range = startI ..< (toCount - endI)
            return (startI ..< startI, String(toV[range]))
        } else {
            return nil
        }
    }
    init(intBased od: Double, roundScale: Int? = 14) {
        let d: Double
        if let r = roundScale {
            d = od.rounded10(decimalPlaces: r)
        } else {
            d = od
        }
        if let i = Int(exactly: d) {
            self.init(i)
        } else {
            self.init(oBased: d)
        }
    }
    init(oBased d: Double) {
        let str = String(d)
        if let si = str.firstIndex(of: "e") {
            let a = str[..<si]
            var b = str[str.index(after: si)...]
            if b.first == "+" {
                b.removeFirst()
            }
            let nb = b.reduce(into: "") { $0.append($1.toSuperscript ?? $1) }
            self = "\(a)*10\(nb)"
        } else if str == "inf" {
            self = "∞"
        } else if str == "-inf" {
            self = "-∞"
        } else {
            self = str
        }
    }
    func ranges<T: StringProtocol>(of s: T,
                                   options: CompareOptions = [],
                                   locale: Locale? = nil) -> [Range<Index>] {
        var ranges = [Range<Index>]()
        while let range
                = range(of: s, options: options,
                        range: (ranges.last?.upperBound ?? startIndex) ..< endIndex,
                        locale: locale) {
            ranges.append(range)
        }
        return ranges
    }
    func substring(_ str: String,
                   _ range: Range<String.Index>) -> Substring {
        var s = str[range]
        s.replaceSubrange(range, with: str)
        return s
    }
    func substring(_ str: String,
                   _ range: ClosedRange<String.Index>) -> Substring {
        var s = self[range]
        s.replaceSubrange(range, with: str)
        return s
    }
    
    var toSuperscript: String {
        String(compactMap { $0.toSuperscript })
    }
    var toSubscript: String {
        String(compactMap { $0.toSubscript })
    }
    
    func omit(count: Int, omitString: String = "...") -> String {
        if count < self.count {
            return self[..<index(fromInt: count)] + omitString
        } else {
            return self
        }
    }
}
extension Substring {
    func substring(_ str: String,
                   _ range: ClosedRange<String.Index>) -> Substring {
        var s = self[range]
        s.replaceSubrange(range, with: str)
        return s
    }
    func substring(_ str: String,
                   _ range: Range<String.Index>) -> Substring {
        var s = self[range]
        s.replaceSubrange(range, with: str)
        return s
    }
}

extension Character {
    static let superscriptScalar: Unicode.Scalar = "\u{F87E}"
    static let subscriptScalar: Unicode.Scalar = "\u{F87F}"
    
    var isSuperscript: Bool {
        fromSuperscript != nil
    }
    var isSubscript: Bool {
        fromSubscript != nil
    }
    var toSuperscript: Character? {
        let s = "\(self)\(Character.superscriptScalar)"
        return s.count == 1 ? s.first : nil
    }
    var toSubscript: Character? {
        let s = "\(self)\(Character.subscriptScalar)"
        return s.count == 1 ? s.first : nil
    }
    var fromSuperscript: Character? {
        if unicodeScalars.count == 2,
           unicodeScalars.last == Character.superscriptScalar,
           let us = unicodeScalars.first {
            
            return Character(us)
        }
        return nil
    }
    var fromSubscript: Character? {
        if unicodeScalars.count == 2,
           unicodeScalars.last == Character.subscriptScalar,
           let us = unicodeScalars.first {
            
            return Character(us)
        }
        return nil
    }
}

extension StringProtocol {
    func unionSplit<T>(separator: String,
                       handler: (SubSequence) -> (T)) -> [T] {
        var oi = startIndex, ns = [T]()
        for i in indices {
            let n = self[i ... i]
            if separator.contains(n) {
                if oi < i {
                    ns.append(handler(self[oi ..< i]))
                }
                ns.append(handler(n))
                oi = index(after: i)
            }
        }
        if oi < endIndex {
            if oi == startIndex {
                ns.append(handler(self[startIndex ..< endIndex]))
            } else {
                ns.append(handler(self[oi...]))
            }
        }
        return ns
    }
    func unionSplit(separator: String) -> [SubSequence] {
        var oi = startIndex, ns = [SubSequence]()
        for i in indices {
            let n = self[i ... i]
            if separator.contains(n) {
                if oi < i {
                    ns.append(self[oi ..< i])
                }
                ns.append(n)
                oi = index(after: i)
            }
        }
        if oi < endIndex {
            if oi == startIndex {
                ns.append(self[startIndex ..< endIndex])
            } else {
                ns.append(self[oi...])
            }
        }
        return ns
    }
}

extension Locale: Protobuf {
    init(_ pb: PBLocale) throws {
        self = .init(identifier: pb.identifier)
    }
    var pb: PBLocale {
        .with {
            $0.identifier = identifier
        }
    }
}

struct Text {
    var string = ""
    var orientation = Orientation.horizontal
    var size = Font.defaultSize
    var widthCount = Typobute.defaultWidthCount
    var origin = Point()
    var timeframe: Timeframe?
    var locale = Locale.autoupdatingCurrent
}
extension Text {
    init(autoWidthCountWith string: String,
         size: Double = Font.defaultSize,
         locale: Locale) {
        var maxCount = 0
        string.enumerateLines { (str, stop) in
            maxCount = max(str.count, maxCount)
        }
        let widthCount = Double(maxCount)
            .clipped(min: Typobute.defaultWidthCount,
                     max: Typobute.maxWidthCount)
        self.init(string: string,
                  size: size,
                  widthCount: widthCount,
                  locale: locale)
    }
}
extension Text: Protobuf {
    init(_ pb: PBText) throws {
        string = pb.string
        orientation = (try? Orientation(pb.orientation)) ?? .horizontal
        let size = (try? pb.size.notNaN()) ?? Font.defaultSize
        self.size = size.clipped(min: 0, max: Font.maxSize)
        let wc = (try? pb.widthCount.notZeroAndNaN()) ?? Typobute.defaultWidthCount
        self.widthCount = wc.clipped(min: Typobute.minWidthCount,
                                     max: Typobute.maxWidthCount)
        origin = (try? Point(pb.origin).notInfiniteAndNAN()) ?? Point()
        if case .timeframe(let timeframe)? = pb.timeframeOptional {
            self.timeframe = try? Timeframe(timeframe)
        } else {
            timeframe = nil
        }
        
        if timeframe?.score?.tone.envelope.attack == 1 {
            timeframe?.score?.tone.envelope.attack = Waver.clappingTime
            if !(timeframe?.score?.notes.isEmpty ?? true) {
                timeframe?.score?.notes[.first].lyric = "p"
            }
            string = "p"
        }
        
        self.locale = (try? Locale(pb.locale)) ?? .current
    }
    var pb: PBText {
        .with {
            $0.string = string
            $0.orientation = orientation.pb
            $0.size = size
            $0.widthCount = widthCount
            $0.origin = origin.pb
            if let timeframe = timeframe {
                $0.timeframeOptional = .timeframe(timeframe.pb)
            } else {
                $0.timeframeOptional = nil
            }
            $0.locale = locale.pb
        }
    }
}
extension Text: Hashable, Codable {}
extension Text: AppliableTransform {
    static func * (lhs: Text, rhs: Transform) -> Text {
        var lhs = lhs
        lhs.size *= rhs.absXScale
        lhs.origin *= rhs
        return lhs
    }
}
extension Text {
    var isEmpty: Bool {
        string.isEmpty
    }
}
extension Text {
    var typelineSpacing: Double {
        let typobute = self.typobute
        let sd = Font.defaultSize
        let size = typobute.font.size <= sd ?
            typobute.font.size :
            (typobute.font.size >= sd * 2 ?
                typobute.font.size * (1.3 / 2) :
                typobute.font.size.clipped(min: sd,
                                           max: sd * 2,
                                           newMin: sd,
                                           newMax: sd * 1.3))
        let mtlw = min(typobute.clippedMaxTypelineWidth,
                       typobute.maxTypelineWidth)
        let typelineSpacing = mtlw.clipped(min: typobute.font.size * 20,
                                           max: typobute.font.size * 30,
                                           newMin: size * 0.5,
                                           newMax: size * 10 / 12)
        return typelineSpacing
    }
    var typelineHeight: Double {
        typobute.font.size + typelineSpacing
    }
    var font: Font {
        Font(locale: locale, size: size)
    }
    var typobute: Typobute {
        Typobute(font: font,
                 maxTypelineWidth: size * widthCount,
                 orientation: orientation)
    }
    var typesetter: Typesetter {
        Typesetter(string: string, typobute: typobute)
    }
    var bounds: Rect? {
        typesetter.typoBounds
    }
    var frame: Rect? {
        if let b = self.typesetter.typoBounds {
            return b + origin
        } else {
            return nil
        }
    }
    func distanceSquared(at p: Point) -> Double? {
        let typesetter = self.typesetter
        guard !typesetter.typelines.isEmpty else { return nil }
        var minDSquared = Double.infinity
        for typeline in typesetter.typelines {
            let dSquared = typeline.frame.distanceSquared(p)
            if dSquared < minDSquared {
                minDSquared = dSquared
            }
        }
        return minDSquared
    }
    
    mutating func replaceSubrange(_ nString: String,
                                  from range: Range<Int>, clipFrame sb: Rect) {
        let oldRange = string.range(fromInt: range)
        string.replaceSubrange(oldRange, with: nString)
        if let textFrame = frame, !sb.contains(textFrame) {
            let nFrame = sb.clipped(textFrame)
            origin += nFrame.origin - textFrame.origin
            
            if let textFrame = frame, !sb.outset(by: 1).contains(textFrame) {
                let scale = min(sb.width / textFrame.width,
                                sb.height / textFrame.height)
                let dp = sb.clipped(textFrame).origin - textFrame.origin
                size *= scale
                origin += dp
            }
        }
    }
}
extension Text {
    func rounded(_ rule: FloatingPointRoundingRule
                    = .toNearestOrAwayFromZero) -> Text {
        Text(string: string,
             orientation: orientation,
             size: size.rounded(rule),
             widthCount: widthCount.rounded(rule),
             origin: origin.rounded(rule))
    }
}
