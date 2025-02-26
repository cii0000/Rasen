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

import struct Foundation.Locale
import class Foundation.NSAttributedString
import class Foundation.NSMutableAttributedString
import struct Foundation.NSRange

//#if os(macOS) && os(iOS) && os(watchOS) && os(tvOS) && os(visionOS)
import CoreText
//#elseif os(linux) && os(windows)
//#endif

extension CTFont: @retroactive @unchecked Sendable {}
extension CTLine: @retroactive @unchecked Sendable {}
extension CTRun: @retroactive @unchecked Sendable {}

extension NSRange {
    init(_ cfRange: CFRange) {
        self.init(location: cfRange.location, length: cfRange.length)
    }
}
extension CFRange {
    init(_ nsRange: NSRange) {
        self.init(location: nsRange.location, length: nsRange.length)
    }
}
extension String {
    func nsIndex(from i: String.Index) -> Int {
        NSRange(i ..< i, in: self).location
    }
    func cfIndex(from i: String.Index) -> CFIndex {
        NSRange(i ..< i, in: self).location
    }
    func nsRange(from range: Range<String.Index>) -> NSRange? {
        NSRange(range, in: self)
    }
    func cfRange(from range: Range<String.Index>) -> CFRange? {
        CFRange(NSRange(range, in: self))
    }
    func index(fromNS nsI: Int) -> String.Index? {
        Range(NSRange(location: nsI, length: 0), in: self)?.lowerBound
    }
    func index(fromCF cfI: CFIndex) -> String.Index? {
        Range(NSRange(location: cfI, length: 0), in: self)?.lowerBound
    }
    func range(fromNS nsRange: NSRange) -> Range<String.Index>? {
        Range(nsRange, in: self)
    }
    func range(fromCF cfRange: CFRange) -> Range<String.Index>? {
        Range(NSRange(cfRange), in: self)
    }
    
    var cfBased: CFString { self as CFString }
    var nsBased: String { self }
    var swiftBased: String {
        String(bytes: utf8.map { $0 }, encoding: .utf8) ?? ""
    }
}

struct Font {
    static let jpName = "GensenJP-Medium"
    static let cnName = "GensenCN-Medium"
    static let hkName = "GensenHK-Medium"
    static let krName = "GensenKR-Medium"
    static let twName = "GensenTW-Medium"
    static let defaultName = jpName
    static let defaultCascadeNames = [jpName, cnName, hkName, krName, twName]
    static let cnCascadeNames = [cnName, jpName, hkName, krName, twName]
    static let hkCascadeNames = [hkName, jpName, cnName, krName, twName]
    static let krCascadeNames = [krName, jpName, cnName, hkName, twName]
    static let twCascadeNames = [twName, jpName, cnName, hkName, krName]
    
    static let smallSize = 8.0
    static let defaultSize = 12.0
    static let largeSize = 16.0
    static let maxSize = 1000000.0
    static let proportionalScale = 1.4
    static let small = Font(name: defaultName, size: smallSize)
    static let `default` = Font(name: defaultName, size: defaultSize)
    
    var name: String {
        didSet {
            updateWith(name: name, cascadeNames: cascadeNames, size: size)
        }
    }
    var cascadeNames: [String] {
        didSet {
            updateWith(name: name, cascadeNames: cascadeNames, size: size)
        }
    }
    var size: Double {
        didSet {
            updateWith(name: name, cascadeNames: cascadeNames, size: size)
        }
    }
    var isProportional: Bool {
        didSet {
            updateWith(name: name, cascadeNames: cascadeNames, size: size,
                       isEnableProportional: false)
        }
    }
    private(set) var ascent: Double, descent: Double,
                     defaultRatio: Double,
                     capHeight: Double, xHeight: Double,
                     cascadeNamesSet: Set<String>
    
    fileprivate(set) var ctFont: CTFont
    
    private mutating func updateWith(name: String,
                                     cascadeNames: [String], size: Double,
                                     isEnableProportional: Bool = true) {
        defaultRatio = size / Font.defaultSize
        if isEnableProportional {
            isProportional = defaultRatio > Font.proportionalScale
        }
        ctFont = Font.ctFont(name: name,
                             cascadeNames: cascadeNames, size: size,
                             isProportional: isProportional)
        cascadeNamesSet = Set(cascadeNames)
        ascent = Double(CTFontGetAscent(ctFont))
        descent = Double(CTFontGetDescent(ctFont))
        capHeight = Double(CTFontGetCapHeight(ctFont))
        xHeight = Double(CTFontGetXHeight(ctFont))
    }
    
    private static func ctFont(name: String,
                               cascadeNames: [String],
                               size: Double,
                               isProportional: Bool) -> CTFont {
        if cascadeNames.isEmpty {
            if isProportional {
                let ctFont = CTFontCreateWithName(name as CFString,
                                                  CGFloat(size), nil)
                let fd = CTFontCopyFontDescriptor(ctFont)
                let nfd = CTFontDescriptorCreateCopyWithFeature(fd, kTextSpacingType as CFNumber, kAltProportionalTextSelector as CFNumber)
                return CTFontCreateCopyWithAttributes(ctFont, CTFontGetSize(ctFont), nil, nfd)
            } else {
                return CTFontCreateWithName(name as CFString, CGFloat(size), nil)
            }
        } else {
            let cascades = cascadeNames.map {
                CTFontDescriptorCreateWithNameAndSize($0 as CFString,
                                                      CGFloat(size))
            }
            let dic: [CFString: Any]
                = [kCTFontNameAttribute: name as CFString,
                   kCTFontCascadeListAttribute: cascades as CFArray]
            let des = CTFontDescriptorCreateWithAttributes(dic as CFDictionary)
            
            if isProportional {
                let ctFont = CTFontCreateWithFontDescriptor(des, CGFloat(size), nil)
                let fd = CTFontCopyFontDescriptor(ctFont)
                let nfd = CTFontDescriptorCreateCopyWithFeature(fd, kTextSpacingType as CFNumber, kAltProportionalTextSelector as CFNumber)
                return CTFontCreateCopyWithAttributes(ctFont, CTFontGetSize(ctFont), nil, nfd)
            } else {
                return CTFontCreateWithFontDescriptor(des, CGFloat(size), nil)
            }
        }
    }
    init(locale: Locale,
         isProportional: Bool? = nil,
         size: Double) {
        
        let name: String, cascadeNames: [String]
        switch locale.language.languageCode?.identifier ?? "en" {
        case "cn":
            name = Self.cnName
            cascadeNames = Self.cnCascadeNames
        case "hk":
            name = Self.hkName
            cascadeNames = Self.hkCascadeNames
        case "kr":
            name = Self.krName
            cascadeNames = Self.krCascadeNames
        case "tw":
            name = Self.twName
            cascadeNames = Self.twCascadeNames
        default:
            name = Self.defaultName
            cascadeNames = Self.defaultCascadeNames
        }
        self.init(name: name,
                  cascadeNames: cascadeNames,
                  isProportional: isProportional, size: size)
    }
    init(name: String,
         cascadeNames: [String] = Font.defaultCascadeNames,
         isProportional: Bool? = nil,
         size: Double) {
        let defaultRatio = size / Font.defaultSize
        let isProportional = isProportional
            ?? (defaultRatio > Font.proportionalScale)
        self.defaultRatio = defaultRatio
        self.isProportional = isProportional
        let ctFont = Font.ctFont(name: name,
                                 cascadeNames: Array(cascadeNames), size: size,
                                 isProportional: isProportional)
        self.name = name
        self.cascadeNames = cascadeNames
        self.cascadeNamesSet = Set(cascadeNames)
        self.size = size
        ascent = Double(CTFontGetAscent(ctFont))
        descent = Double(CTFontGetDescent(ctFont))
        capHeight = Double(CTFontGetCapHeight(ctFont))
        xHeight = Double(CTFontGetXHeight(ctFont))
        self.ctFont = ctFont
    }
}

extension NSAttributedString.Key {
    static let ctFont = NSAttributedString
        .Key(rawValue: String(kCTFontAttributeName))
    static let ctBaselineOffset = NSAttributedString
        .Key(rawValue: String(kCTBaselineOffsetAttributeName))
    static let ctTracking = NSAttributedString
        .Key(rawValue: String(kCTTrackingAttributeName))
    static let ctParagraphStyle = NSAttributedString
        .Key(rawValue: String(kCTParagraphStyleAttributeName))
    static let ctOrientation = NSAttributedString
        .Key(rawValue: String(kCTVerticalFormsAttributeName))
    static let ctFrameProgression = NSAttributedString
        .Key(rawValue: String(kCTFrameProgressionAttributeName))
    static let ctForegroundColorFromContext = NSAttributedString
        .Key(rawValue: String(kCTForegroundColorFromContextAttributeName))
}
extension Alignment {
    var ct: CTTextAlignment {
        switch self {
        case .left: .left
        case .center: .center
        case .right: .right
        case .natural: .natural
        case .justified: .justified
        }
    }
}
extension NSAttributedString {
    static func attributesWith(font: Font,
                               alignment: Alignment,
                               orientation: Orientation) -> [Key: Any] {
        let progression: CTFrameProgression = orientation == .vertical ?
            .rightToLeft : .leftToRight
        
        let d = font.size * 2
        let tab0 = [CTTextTabCreate(.left, d, nil)] as CFArray
        let tab1 = CGFloat(d)
        let alignment = alignment.ct
        let stlye: CTParagraphStyle = withUnsafeBytes(of: tab0) { tab0Bytes in
            withUnsafeBytes(of: tab1) { tab1Bytes in
                withUnsafeBytes(of: alignment) { alignmentBytes in
                    let settings = [CTParagraphStyleSetting(spec: .tabStops,
                                             valueSize:
                                                MemoryLayout<CTTextTab>.size,
                                             value: tab0Bytes.baseAddress!),
                     CTParagraphStyleSetting(spec: .defaultTabInterval,
                                             valueSize:
                                                MemoryLayout<CGFloat>.size,
                                             value: tab1Bytes.baseAddress!),
                     CTParagraphStyleSetting(spec: .alignment,
                                             valueSize:
                                                MemoryLayout<CTTextAlignment>.size,
                                             value: alignmentBytes.baseAddress!)]
                    return CTParagraphStyleCreate(settings, settings.count)
                }
            }
        }
        
        return [.ctFont: font.ctFont,
                .ctOrientation: orientation == .vertical,
                .ctFrameProgression: progression,
                .ctForegroundColorFromContext: true,
                .ctParagraphStyle: stlye]
    }
}
extension Typobute {
    func attributes() -> [NSAttributedString.Key: Any] {
        NSAttributedString.attributesWith(font: font,
                                          alignment: alignment,
                                          orientation: orientation)
    }
}
extension Typesetter {
    static func attibutedString(with string: String,
                                typobute: Typobute) -> CFAttributedString {
        let minCount = 5, maxCount = 5000
        let dfCount = Double(maxCount) / typobute.font.defaultRatio
        let count = (Int(exactly: dfCount.rounded()) ?? 1)
            .clipped(min: minCount, max: maxCount)
        
        let str: String
        if string.count > count {
            let li = string.index(string.startIndex, offsetBy: count)
            str = "\(String(string[..<li]))...C\(string.count - count)"
        } else {
            str = string
        }
        
        let attributes = typobute.attributes()
        if str.contains(where: { ":;ー〜〰０１２３４５６７８９".contains($0) }) {
            var sFont = typobute.font
            sFont.size = typobute.font.size * 3 / 4
            
            var superSet = attributes
            superSet[.ctBaselineOffset] = typobute.font.xHeight * 0.9
            superSet[.ctFont] = sFont.ctFont
            
            var subSet = attributes
            subSet[.ctBaselineOffset] = -typobute.font.size * 0.25
            subSet[.ctFont] = sFont.ctFont
            
            let attributedString = NSMutableAttributedString()
            attributedString.beginEditing()
            
            var numberCount = 0
            var tempStr = ""
            func appendFromTemp() {
                endDash()
                endWaveDash()
                endWavyDash()
                guard !tempStr.isEmpty else { return }
                attributedString
                    .append(NSAttributedString(string: tempStr.nsBased,
                                               attributes: attributes))
                tempStr = ""
                numberCount = 0
            }
            
            var dashCount = 0, preC: Character?, numPreC: Character?
            var waveDashCount = 0, wavyDashCount = 0, isLower: Bool?
            func endDash() {
                if dashCount >= 2 {
                    tempStr.removeLast()
                    tempStr.append("\u{E002}")
                }
                dashCount = 0
            }
            func endWaveDash() {
                if waveDashCount >= 2 {
                    tempStr.removeLast()
                    tempStr.append("\u{E005}")
                }
                waveDashCount = 0
            }
            func endWavyDash() {
                if wavyDashCount >= 2 {
                    tempStr.removeLast()
                    tempStr.append("\u{E008}")
                }
                wavyDashCount = 0
            }
            func appendNumber() {
                guard tempStr.count >= 2 else { return }
                let ti0 = tempStr.index(tempStr.endIndex, offsetBy: -2)
                let ti1 = tempStr.index(tempStr.endIndex, offsetBy: -1)
                let s0, s1: Character
                switch tempStr[ti0] {
                case "０": s0 = "\u{E020}"
                case "１": s0 = "\u{E021}"
                case "２": s0 = "\u{E022}"
                case "３": s0 = "\u{E023}"
                case "４": s0 = "\u{E024}"
                case "５": s0 = "\u{E025}"
                case "６": s0 = "\u{E026}"
                case "７": s0 = "\u{E027}"
                case "８": s0 = "\u{E028}"
                case "９": s0 = "\u{E029}"
                default: return
                }
                switch tempStr[ti1] {
                case "０": s1 = "\u{E030}"
                case "１": s1 = "\u{E031}"
                case "２": s1 = "\u{E032}"
                case "３": s1 = "\u{E033}"
                case "４": s1 = "\u{E034}"
                case "５": s1 = "\u{E035}"
                case "６": s1 = "\u{E036}"
                case "７": s1 = "\u{E037}"
                case "８": s1 = "\u{E038}"
                case "９": s1 = "\u{E039}"
                default: return
                }
                tempStr.removeLast()
                tempStr.removeLast()
                tempStr.append(s0)
                tempStr.append(s1)
            }
            func isAppendNumber(_ c: Character?) -> Bool {
                c != "." && c != ","
            }
            for c in str {
                if typobute.orientation == .vertical {
                    if "０１２３４５６７８９".contains(c) {
                        if numberCount == 0 {
                            numPreC = preC
                        }
                        numberCount += 1
                    } else {
                        if numberCount == 2
                            && isAppendNumber(numPreC)
                            && isAppendNumber(c) {
                            appendNumber()
                        }
                        numberCount = 0
                    }
                }
                func appendNormal() {
                    if dashCount >= 2 {
                        tempStr.append("\u{E001}")
                    } else if waveDashCount >= 2 {
                        tempStr.append("\u{E004}")
                    } else if wavyDashCount >= 2 {
                        tempStr.append("\u{E007}")
                    } else {
                        tempStr.append(c)
                    }
                }
                if c == ":" {
                    if isLower ?? (preC?.isLowercase ?? false) {
                        isLower = true
                        tempStr.append("\u{E010}")
                    } else {
                        appendNormal()
                        isLower = false
                    }
                } else if c == ";" {
                    if isLower ?? (preC?.isLowercase ?? false) {
                        isLower = true
                        tempStr.append("\u{E011}")
                    } else {
                        appendNormal()
                        isLower = false
                    }
                } else {
                    if c == "ー" {
                        endWaveDash()
                        endWavyDash()
                        if dashCount == 1 {
                            tempStr.removeLast()
                            tempStr.append("\u{E000}")
                        }
                        dashCount += 1
                    } else if c == "〜" {
                        endDash()
                        endWavyDash()
                        if waveDashCount == 1 {
                            tempStr.removeLast()
                            tempStr.append("\u{E003}")
                        }
                        waveDashCount += 1
                    } else if c == "〰" {
                        endDash()
                        endWaveDash()
                        if wavyDashCount == 1 {
                            tempStr.removeLast()
                            tempStr.append("\u{E006}")
                        }
                        wavyDashCount += 1
                    } else {
                        endDash()
                        endWaveDash()
                        endWavyDash()
                    }
                    appendNormal()
                    
                    isLower = nil
                }
                preC = c
            }
            if numberCount == 2 && isAppendNumber(numPreC) {
                appendNumber()
            }
            appendFromTemp()
            
            attributedString.endEditing()
            return attributedString
        } else {
            return NSAttributedString(string: str.nsBased,
                                      attributes: attributes)
        }
    }
    
    static func spacing(from typobute: Typobute) -> Double {
        let mtlw = min(typobute.clippedMaxTypelineWidth,
                       typobute.maxTypelineWidth)
        let sd = Font.defaultSize
        let size = typobute.font.size <= sd ?
            typobute.font.size :
            (typobute.font.size >= sd * 2 ?
                typobute.font.size * (1.3 / 2) :
                typobute.font.size.clipped(min: sd,
                                           max: sd * 2,
                                           newMin: sd,
                                           newMax: sd * 1.3))
        
        return typobute.spacing
        ?? mtlw.clipped(min: typobute.font.size * 25,
                        max: typobute.font.size * 35,
                        newMin: size * 0.5,
                        newMax: size * 10 / 12)
    }
    
    static func typelineAndSpacingWith(string: String, typobute: Typobute)
    -> (typelines: [Typeline], spacing: Double) {
        let attributedString = attibutedString(with: string, typobute: typobute)
        let isLastHasSuffix = string.hasSuffix("\n")
        let ctTypesetter
            = CTTypesetterCreateWithAttributedString(attributedString)
        let length = CFAttributedStringGetLength(attributedString)
        
        let mtlw = min(typobute.clippedMaxTypelineWidth,
                       typobute.maxTypelineWidth)
        
        var cfRange = CFRange(), maxWidth = 0.0, tMaxWidth = 0.0
        var ls = [(ctLine: CTLine, width: Double)]()
        while cfRange.maxLocation < length {
            if mtlw < typobute.clippedMaxTypelineWidth {
                cfRange.length
                    = CTTypesetterSuggestLineBreak(ctTypesetter, cfRange.location,
                                                   typobute.clippedMaxTypelineWidth)
                if let range = string.range(fromCF: cfRange) {
                    var i = range.upperBound, isTab = false
                    if i > range.lowerBound {
                        i = string.index(before: i)
                        while true {
                            if string[i] == "\t" {
                                let ni = string.nsIndex(from: i)
                                let ctLine = CTTypesetterCreateLine(ctTypesetter, cfRange)
                                let tw = CTLineGetOffsetForStringIndex(ctLine, ni, nil)
                                let nt = min(typobute.clippedMaxTypelineWidth,
                                             mtlw + Double(tw))
                                cfRange.length
                                    = CTTypesetterSuggestLineBreak(ctTypesetter,
                                                                   cfRange.location,
                                                                   nt)
                                isTab = true
                                break
                            }
                            guard i > range.lowerBound else { break }
                            i = string.index(before: i)
                        }
                    }
                    if !isTab {
                        cfRange.length
                            = CTTypesetterSuggestLineBreak(ctTypesetter,
                                                           cfRange.location,
                                                           mtlw)
                    }
                }
            } else {
                cfRange.length
                    = CTTypesetterSuggestLineBreak(ctTypesetter, cfRange.location,
                                                   typobute.clippedMaxTypelineWidth)
            }
            
            let maxI = cfRange.maxLocation
            let ctLine = CTTypesetterCreateLine(ctTypesetter, cfRange)
            var aLineWidth: CGFloat = 0.0
            CTLineGetOffsetForStringIndex(ctLine,
                                          maxI,
                                          &aLineWidth)
            let lineWidth = min(Double(aLineWidth), typobute.clippedMaxTypelineWidth)
            maxWidth = max(lineWidth, maxWidth)
            
            let nCFRange = CTLineGetStringRange(ctLine)
            var tWidth = lineWidth
            if let range = string.range(fromCF: nCFRange) {
                var i = range.lowerBound
                while i < string.endIndex {
                    if string[i] != "\t" {
                        let ni = string.nsIndex(from: i)
                        let tw = CTLineGetOffsetForStringIndex(ctLine, ni, nil)
                        tWidth -= Double(tw)
                        break
                    }
                    i = string.index(after: i)
                }
            }
            tMaxWidth = max(tWidth, tMaxWidth)
            
            ls.append((ctLine, lineWidth))
            
            cfRange = CFRange(location: maxI, length: 0)
        }
        maxWidth = maxWidth.rounded(.up)
        let width = typobute.maxTypelineWidth.isInfinite ?
            maxWidth : mtlw

        let typelineSpacing = spacing(from: typobute)
        let typelineHeight = typobute.font.size + typelineSpacing
        
        var origin = Point()
        let nlines: [Typeline] = ls.enumerated().compactMap { (i, v) in
            let runs = v.ctLine.runs.map { Typerun(ctRun: $0,
                                                   mainFont: typobute.font) }
            
            var typelineOrigin = origin
            if typobute.alignment == .right {
                switch typobute.orientation {
                case .horizontal: typelineOrigin.x += width - v.width
                case .vertical: typelineOrigin.y += width - v.width
                }
            } else if typobute.alignment == .center {
                switch typobute.orientation {
                case .horizontal: typelineOrigin.x += (width - v.width) / 2
                case .vertical: typelineOrigin.y += (width - v.width) / 2
                }
            }
            
            let baseDeltaOrigin: Point
            switch typobute.orientation {
            case .horizontal:
                baseDeltaOrigin = Point(0, -typobute.font.capHeight / 2)
            case .vertical:
                baseDeltaOrigin = Point()
            }
            
            let nCFRange = CTLineGetStringRange(v.ctLine)
            guard let range = string.range(fromCF: nCFRange) else { return nil }
            let isReturnEnd = i == ls.count - 1 ?
                isLastHasSuffix :
                string[string.index(before: range.upperBound)] == "\u{000a}"
            let isLastReturnEnd = i == ls.count - 1 && isLastHasSuffix
            let w = (typobute.orientation == .vertical ? (isReturnEnd ? -6 : 0) : 0)
                + v.width
            let result = Typeline(string: string,
                                  range: range,
                                  origin: typelineOrigin,
                                  baseDeltaOrigin: baseDeltaOrigin,
                                  width: w, height: typobute.font.size,
                                  spacing: typelineSpacing,
                                  orientation: typobute.orientation,
                                  isReturnEnd: isReturnEnd,
                                  isLastReturnEnd: isLastReturnEnd,
                                  runs: runs,
                                  cfRange: nCFRange,
                                  ctLine: v.ctLine)
            
            switch typobute.orientation {
            case .horizontal: origin.y -= typelineHeight
            case .vertical: origin.x -= typelineHeight
            }
            
            return result
        }
        return (nlines, typelineSpacing)
    }
}
extension Typesetter {
    func texture(with aBounds: Rect, scale: Double = 2,
                 fillColor: Color,
                 backgroundColor: Color) -> Texture? {
        let bounds = aBounds.integral
        guard !isEmpty, let firstLine = typelines.first else { return nil }
        let size = bounds.size * scale
        let bitmapInfo = backgroundColor.opacity == 1 ?
            CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue
                            | CGBitmapInfo.byteOrder32Little.rawValue) :
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                            | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let ctx = CGContext(data: nil,
                                  width: Int(size.width),
                                  height: Int(size.height),
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: .default,
                                  bitmapInfo: bitmapInfo.rawValue) else { return nil }
        ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        ctx.scaleBy(x: 1, y: -1)
        ctx.translateBy(x: 0, y: -CGFloat(bounds.height))
        ctx.setFillColor(backgroundColor.cg)
        ctx.fill(Rect(size: bounds.size).cg)
        let dp = bounds.origin - aBounds.origin
        ctx.translateBy(x: CGFloat(dp.x),
                        y: CGFloat(bounds.height - firstLine.height / 2 + dp.y))
        draw(in: bounds, fillColor: fillColor, in: ctx)
        return ctx.renderedTexture(isOpaque: backgroundColor.opacity == 1)
    }
    func draw(in bounds: Rect, fillColor: Color, in ctx: CGContext) {
        ctx.setFillColor(fillColor.cg)
        ctx.setShouldSmoothFonts(false)
        ctx.setShouldSubpixelQuantizeFonts(false)
        
        ctx.saveGState()
        typelines.forEach { $0.draw(in: ctx) }
        ctx.restoreGState()
        
        let pathlines = indentPathlines()
        for pathline in pathlines {
            ctx.move(to: pathline.firstPoint.cg)
            for element in pathline.elements {
                switch element {
                case .linear(let p1):
                    ctx.addLine(to: p1.cg)
                case .bezier(let p1, let cp):
                    ctx.addQuadCurve(to: p1.cg, control: cp.cg)
                case .line(let line):
                    ctx.addLine(to: line.firstPoint.cg)
                    if line.controls.count >= 2 {
                        for b in line.bezierSequence {
                            ctx.addQuadCurve(to: b.p1.cg, control: b.cp.cg)
                        }
                    }
                case .arc(let arc):
                    ctx.addArc(center: arc.centerPosition.cg,
                               radius: CGFloat(arc.radius),
                               startAngle: CGFloat(arc.startAngle),
                               endAngle: CGFloat(arc.endAngle),
                               clockwise: arc.orientation == .clockwise)
                }
            }
            ctx.fillPath()
        }
    }
    func append(in ctx: CGContext) {
        ctx.saveGState()
        typelines.forEach { $0.append(in: ctx) }
        ctx.restoreGState()
        
        let pathlines = indentPathlines()
        for pathline in pathlines {
            ctx.move(to: pathline.firstPoint.cg)
            for element in pathline.elements {
                switch element {
                case .linear(let p1):
                    ctx.addLine(to: p1.cg)
                case .bezier(let p1, let cp):
                    ctx.addQuadCurve(to: p1.cg, control: cp.cg)
                case .line(let line):
                    ctx.addLine(to: line.firstPoint.cg)
                    if line.controls.count >= 2 {
                        for b in line.bezierSequence {
                            ctx.addQuadCurve(to: b.p1.cg, control: b.cp.cg)
                        }
                    }
                case .arc(let arc):
                    ctx.addArc(center: arc.centerPosition.cg,
                               radius: CGFloat(arc.radius),
                               startAngle: CGFloat(arc.startAngle),
                               endAngle: CGFloat(arc.endAngle),
                               clockwise: arc.orientation == .clockwise)
                }
            }
        }
    }
}

extension Path {
    func append(in ctx: CGContext) {
        for pathline in pathlines {
            ctx.move(to: pathline.firstPoint.cg)
            for element in pathline.elements {
                switch element {
                case .linear(let p1):
                    ctx.addLine(to: p1.cg)
                case .bezier(let p1, let cp):
                    ctx.addQuadCurve(to: p1.cg, control: cp.cg)
                case .line(let line):
                    ctx.addLine(to: line.firstPoint.cg)
                    if line.controls.count >= 2 {
                        for b in line.bezierSequence {
                            ctx.addQuadCurve(to: b.p1.cg, control: b.cp.cg)
                        }
                    }
                case .arc(let arc):
                    ctx.addArc(center: arc.centerPosition.cg,
                               radius: CGFloat(arc.radius),
                               startAngle: CGFloat(arc.startAngle),
                               endAngle: CGFloat(arc.endAngle),
                               clockwise: arc.orientation == .clockwise)
                }
            }
        }
    }
}

struct Typeline {
    let string: String
    let range: Range<String.Index>
    let origin: Point, baseDeltaOrigin: Point
    let width: Double, height: Double
    let spacing: Double
    let orientation: Orientation
    let isReturnEnd, isLastReturnEnd: Bool
    let runs: [Typerun]
    
    fileprivate let cfRange: CFRange, ctLine: CTLine
}
extension Typeline {
    var frame: Rect {
        let b = typoBounds
        return Rect(origin: b.origin + origin, size: b.size)
    }
    var typoBounds: Rect {
        switch orientation {
        case .horizontal:
            .init(x: 0, y: -height / 2, width: width, height: height)
        case .vertical:
            .init(x: -height / 2, y: -width, width: height, height: width)
        }
    }
    func typoBounds(for range: Range<String.Index>) -> Rect? {
        guard let cfRange = string.cfRange(from: range) else { return nil }
        return typoBounds(forCF: cfRange)
    }
    private func typoBounds(forCF aCFRange: CFRange) -> Rect? {
        guard cfRange.intersects(aCFRange) else { return nil }
        if aCFRange.contains(cfRange) {
            return typoBounds
        }
        return switch orientation {
        case .horizontal:
            runs.reduce(into: Rect?.none) {
                if let iRange = $1.cfRange.intersection(aCFRange) {
                    let maxI = isReturnEnd
                        && iRange.maxLocation == self.cfRange.maxLocation ?
                        iRange.maxLocation - 1 : iRange.maxLocation
                    let sx = characterOffset(atCF: iRange.location)
                    let ex = characterOffset(atCF: maxI)
                    $0 += Rect(x: sx, y: -height / 2,
                               width: ex - sx, height: height)
                }
            }
        case .vertical:
            runs.reduce(into: Rect?.none) {
                if let iRange = $1.cfRange.intersection(aCFRange) {
                    let maxI = isReturnEnd
                        && iRange.maxLocation == self.cfRange.maxLocation ?
                        iRange.maxLocation - 1 : iRange.maxLocation
                    let sx = characterOffset(atCF: iRange.location)
                    let ex = characterOffset(atCF: maxI)
                    $0 += Rect(x: -height / 2, y: -ex,
                               width: height, height: ex - sx)
                }
            }
        }
    }
    func firstTypoBounds() -> Rect {
        let sx = characterOffset(atCF: cfRange.location)
        return switch orientation {
        case .horizontal:
            .init(x: sx, y: -height / 2, width: 0, height: height)
        case .vertical:
            .init(x: -height / 2, y: -sx, width: height, height: 0)
        }
    }
    func lastTypoBounds() -> Rect {
        let sx = characterOffset(atCF: cfRange.maxLocation)
        return switch orientation {
        case .horizontal:
            .init(x: sx, y: -height / 2, width: 0, height: height)
        case .vertical:
            .init(x: -height / 2, y: -sx, width: height, height: 0)
        }
    }
    
    func characterMainIndex(forOffset d: Double,
                            padding: Double,
                            from typesetter: Typesetter) -> String.Index? {
        guard let cfI = characterCFIndex(forOffset: d,
                                         padding: padding),
              let cr = characterRatio(forOffset: d, padding: padding),
              let i = string.index(fromCF: cfI) else { return nil }
        return cr > 0.5 ? typesetter.index(after: i) : i
    }
    func characterMainIndex(for p: Point,
                            padding: Double,
                            from typesetter: Typesetter) -> String.Index? {
        guard let cfI = characterCFIndex(for: p,
                                         padding: padding),
              let cr = characterRatio(for: p, padding: padding),
              let i = string.index(fromCF: cfI) else { return nil }
        return cr > 0.5 ? typesetter.index(after: i) : i
    }
    
    func characterIndex(forOffset d: Double,
                        padding: Double) -> String.Index? {
        guard let cfI = characterCFIndex(forOffset: d,
                                         padding: padding) else { return nil }
        return string.index(fromCF: cfI)
    }
    private func characterCFIndex(forOffset d: Double,
                                  padding: Double) -> CFIndex? {
        guard cfRange.length > 0 else { return nil }
        switch orientation {
        case .horizontal:
            guard d >= -padding else { return nil }
            let x = CGFloat(d)
            var preOffset = -CGFloat.infinity
            for i in cfRange.location ..< cfRange.maxLocation {
                var offset: CGFloat = 0.0
                CTLineGetOffsetForStringIndex(ctLine, i + 1, &offset)
                if preOffset > offset && i + 2 <= cfRange.maxLocation {
                    for i in (i + 2) ... cfRange.maxLocation {
                        CTLineGetOffsetForStringIndex(ctLine, i, &offset)
                        if preOffset < offset { break }
                    }
                }
                if preOffset != 0, x < offset {
                    return i
                }
                preOffset = offset
            }
            if d > width + padding {
                return nil
            } else if isReturnEnd {
                return cfRange.maxLocation - 1
            } else {
                return cfRange.maxLocation
            }
        case .vertical:
            guard d >= -padding else { return nil }
            let y = CGFloat(d)
            var preOffset = -CGFloat.infinity
            for i in cfRange.location ..< cfRange.maxLocation {
                var offset: CGFloat = 0.0
                CTLineGetOffsetForStringIndex(ctLine, i + 1, &offset)
                if preOffset > offset && i + 2 <= cfRange.maxLocation {
                    for i in (i + 2) ... cfRange.maxLocation {
                        CTLineGetOffsetForStringIndex(ctLine, i, &offset)
                        if preOffset < offset { break }
                    }
                }
                if preOffset != 0, y < offset {
                    return i
                }
                preOffset = offset
            }
            if d > width + padding {
                return nil
            } else if isReturnEnd {
                return cfRange.maxLocation - 1
            } else {
                return cfRange.maxLocation
            }
        }
    }
    
    func characterIndex(for point: Point,
                        padding: Double) -> String.Index? {
        guard let cfI = characterCFIndex(for: point,
                                         padding: padding) else { return nil }
        return string.index(fromNS: cfI)
    }
    private func characterCFIndex(for point: Point,
                                  padding: Double) -> CFIndex? {
        guard cfRange.length > 0 else { return nil }
        switch orientation {
        case .horizontal:
            guard point.x >= -padding else { return nil }
            let x = CGFloat(point.x)
            var preOffset = -CGFloat.infinity
            for i in cfRange.location ..< cfRange.maxLocation {
                var offset: CGFloat = 0.0
                CTLineGetOffsetForStringIndex(ctLine, i + 1, &offset)
                if preOffset > offset && i + 2 <= cfRange.maxLocation {
                    for i in (i + 2) ... cfRange.maxLocation {
                        CTLineGetOffsetForStringIndex(ctLine, i, &offset)
                        if preOffset < offset { break }
                    }
                }
                if preOffset != 0, x < offset {
                    return i
                }
                preOffset = offset
            }
            if point.x > width + padding {
                return nil
            } else if isReturnEnd {
                return cfRange.maxLocation - 1
            } else {
                return cfRange.maxLocation
            }
        case .vertical:
            guard -point.y >= -padding else { return nil }
            let y = CGFloat(-point.y)
            var preOffset = -CGFloat.infinity
            for i in cfRange.location ..< cfRange.maxLocation {
                var offset: CGFloat = 0.0
                CTLineGetOffsetForStringIndex(ctLine, i + 1, &offset)
                if preOffset > offset && i + 2 <= cfRange.maxLocation {
                    for i in (i + 2) ... cfRange.maxLocation {
                        CTLineGetOffsetForStringIndex(ctLine, i, &offset)
                        if preOffset < offset { break }
                    }
                }
                if preOffset != 0, y < offset {
                    return i
                }
                preOffset = offset
            }
            if -point.y > width + padding {
                return nil
            } else if isReturnEnd {
                return cfRange.maxLocation - 1
            } else {
                return cfRange.maxLocation
            }
        }
    }
    
    func characterRatio(for point: Point,
                        padding: Double) -> Double? {
        guard let i = characterCFIndex(for: point,
                                       padding: padding) else { return nil }
        if i < (isReturnEnd ? cfRange.maxLocation - 1 : cfRange.maxLocation) {
            let x = characterOffset(atCF: i)
            let d = characterAdvance(at: i)
            if d != 0 {
                return switch orientation {
                case .horizontal: (point.x - x) / d
                case .vertical: (-point.y - x) / d
                }
            } else {
                return 0
            }
        }
        return 0
    }
    
    func characterRatio(forOffset dd: Double,
                        padding: Double) -> Double? {
        guard let i = characterCFIndex(forOffset: dd,
                                       padding: padding) else { return nil }
        if i < (isReturnEnd ? cfRange.maxLocation - 1 : cfRange.maxLocation) {
            let x = characterOffset(atCF: i)
            let d = characterAdvance(at: i)
            if d != 0 {
                return switch orientation {
                case .horizontal: (dd - x) / d
                case .vertical: (-dd - x) / d
                }
            } else {
                return 0
            }
        }
        return 0
    }
    
    func characterAdvance(at i: String.Index) -> Double {
        let cfI = string.cfIndex(from: i)
        return characterAdvance(at: cfI)
    }
    func characterAdvance(at cfI: CFIndex) -> Double {
        var offset0: CGFloat = 0.0, offset1: CGFloat = 0.0
        CTLineGetOffsetForStringIndex(ctLine, cfI, &offset0)
        if cfI == cfRange.maxLocation - 1 && isReturnEnd {
            return 6.0
        }
        if cfI > cfRange.location && offset0 == 0 {
            return 0
        }
        CTLineGetOffsetForStringIndex(ctLine, cfI + 1, &offset1)
        if offset0 > offset1 && cfI + 2 <= cfRange.maxLocation {
            for i in (cfI + 2) ... cfRange.maxLocation {
                CTLineGetOffsetForStringIndex(ctLine, i, &offset1)
                if offset0 < offset1 { break }
            }
        }
        return Double(offset1 - offset0)
    }
    
    func characterOffset(at i: String.Index) -> Double {
        let cfI = string.cfIndex(from: i)
        var offset: CGFloat = 0.0
        CTLineGetOffsetForStringIndex(ctLine, cfI, &offset)
        return Double(offset)
    }
    private func characterOffset(atCF cfI: Int) -> Double {
        var offset: CGFloat = 0.0
        CTLineGetOffsetForStringIndex(ctLine, cfI, &offset)
        return Double(offset)
    }
    
    func characterPosition(at i: String.Index) -> Point? {
        switch orientation {
        case .horizontal:
            if range.contains(i) {
                let x = characterOffset(at: i)
                return Point(x + origin.x, origin.y)
            }
        case .vertical:
            if range.contains(i) {
                let y = characterOffset(at: i)
                return Point(origin.x, origin.y - y)
            }
        }
        return nil
    }
    func characterOffsetUsingLast(at i: String.Index) -> Double? {
        if range.contains(i) {
            return characterOffset(at: i)
        } else if i == range.upperBound {
            return width
        } else {
            return nil
        }
    }
    func characterPositionUsingLast(at i: String.Index) -> Point? {
        if let p = characterPosition(at: i) {
            p
        } else if i == range.upperBound {
            switch orientation {
            case .horizontal: .init(width + origin.x, origin.y)
            case .vertical: .init(origin.x, origin.y - width)
            }
        } else {
            nil
        }
    }
    private func characterPosition(atCF cfI: Int) -> Point? {
        switch orientation {
        case .horizontal:
            if cfRange.contains(cfI) {
                let x = characterOffset(atCF: cfI)
                return Point(x + origin.x, origin.y)
            }
        case .vertical:
            if cfRange.contains(cfI) {
                let y = characterOffset(atCF: cfI)
                return Point(origin.x, origin.y - y)
            }
        }
        return nil
    }
    
    func firstOrLast(at p: Point, padding: Double) -> FirstOrLast? {
        switch orientation {
        case .horizontal:
            if p.x < padding / 2 {
                return .first
            } else if p.x > width + padding / 2 {
                return .last
            }
        case .vertical:
            if p.y > padding / 2 {
                return .first
            } else if p.y < -width - padding / 2 {
                return .last
            }
        }
        return nil
    }
    
    var baselineDelta: Double { -height / 2 }
    
    func underlineEdges(for range: Range<String.Index>,
                        delta: Double = Line.defaultLineWidth) -> Edge? {
        switch orientation {
        case .horizontal:
            if let bounds = typoBounds(for: range), bounds.width > 0 {
                return Edge(origin + bounds.origin + Point(0, -delta),
                            origin + bounds.origin + Point(bounds.width, -delta))
            } else {
                return nil
            }
        case .vertical:
            if let bounds = typoBounds(for: range), bounds.height > 0 {
                return Edge(origin + bounds.maxXMinYPoint + Point(delta, 0),
                            origin + bounds.maxXMinYPoint + Point(delta, bounds.height))
            } else {
                return nil
            }
        }
    }
    
    func pathlines() -> [Pathline] {
        var pathlines = [Pathline]()
        for run in runs {
            pathlines += run.pathlines(for: origin + baseDeltaOrigin)
        }
        return pathlines
    }
}
extension Typeline {
    func append(in ctx: CGContext) {
        runs.forEach { $0.append(for: origin + baseDeltaOrigin, in: ctx) }
    }
    func draw(in ctx: CGContext) {
        ctx.textPosition = (origin + baseDeltaOrigin).cg
        runs.forEach { $0.draw(in: ctx) }
    }
}

struct Typerun {
    fileprivate let ctRun: CTRun, ctFont: CTFont?, isEnableFont: Bool
    init(ctRun: CTRun, mainFont: Font) {
        let attributes = CTRunGetAttributes(ctRun)
            as? [NSAttributedString.Key: Any] ?? [:]
        if let fontAttribute = attributes[.ctFont] {
            let ctFont = (fontAttribute as! CTFont)
            let name = CTFontCopyPostScriptName(ctFont) as String
            self.ctFont = ctFont
            isEnableFont = name == mainFont.name
                || mainFont.cascadeNamesSet.contains(name)
        } else {
            ctFont = nil
            isEnableFont = false
        }
        self.ctRun = ctRun
    }
}
extension Typerun {
    var cfRange: CFRange { CTRunGetStringRange(ctRun) }
    
    func append(for origin: Point, in ctx: CGContext) {
        guard let font = self.ctFont, isEnableFont else {
            for i in 0 ..< CTRunGetGlyphCount(ctRun) {
                let cfRange = CFRangeMake(i, 1)
                var position = CGPoint()
                CTRunGetPositions(ctRun, cfRange, &position)
                var ascent: CGFloat = 0.0, descent: CGFloat = 0.0
                let w = CTRunGetTypographicBounds(ctRun, cfRange,
                                                  &ascent, &descent, nil)
                let h = Double(ascent + descent)
                let rect = Rect(origin: position.my + origin
                                    - Point(0, Double(descent)),
                                size: Size(width: w, height: h))
                let dRect = rect.inset(by: 1)
                ctx.addLines(between: [rect.minXMaxYPoint,
                                        rect.minXMinYPoint,
                                        rect.maxXMinYPoint,
                                        rect.maxXMaxYPoint,
                                        rect.minXMaxYPoint,
                                        dRect.minXMaxYPoint,
                                        dRect.maxXMaxYPoint,
                                        dRect.maxXMinYPoint,
                                        dRect.minXMinYPoint,
                                        dRect.minXMaxYPoint].map { $0.cg })
                ctx.closePath()
            }
            return
        }
        let path = CGMutablePath()
        for i in 0 ..< CTRunGetGlyphCount(ctRun) {
            let cfRange = CFRangeMake(i, 1)
            var glyph: CGGlyph = 0, position = CGPoint()
            CTRunGetGlyphs(ctRun, cfRange, &glyph)
            CTRunGetPositions(ctRun, cfRange, &position)
            if let glyphPath = CTFontCreatePathForGlyph(font, glyph, nil) {
                let t = CGAffineTransform(translationX: position.x + CGFloat(origin.x),
                                          y: position.y + CGFloat(origin.y))
                path.addPath(glyphPath, transform: t)
            }
        }
        ctx.addPath(path)
    }
    
    func pathlines(for origin: Point) -> [Pathline] {
        guard let font = self.ctFont, isEnableFont else {
            var pathlines = [Pathline]()
            for i in 0 ..< CTRunGetGlyphCount(ctRun) {
                let cfRange = CFRangeMake(i, 1)
                var position = CGPoint()
                CTRunGetPositions(ctRun, cfRange, &position)
                var ascent: CGFloat = 0.0, descent: CGFloat = 0.0
                let w = CTRunGetTypographicBounds(ctRun, cfRange,
                                                  &ascent, &descent, nil)
                let h = Double(ascent + descent)
                let rect = Rect(origin: position.my + origin
                                    - Point(0, Double(descent)),
                                size: Size(width: w, height: h))
                let dRect = rect.inset(by: 1)
                pathlines.append(Pathline([rect.minXMaxYPoint,
                                           rect.minXMinYPoint,
                                           rect.maxXMinYPoint,
                                           rect.maxXMaxYPoint,
                                           rect.minXMaxYPoint,
                                           dRect.minXMaxYPoint,
                                           dRect.maxXMaxYPoint,
                                           dRect.maxXMinYPoint,
                                           dRect.minXMinYPoint,
                                           dRect.minXMaxYPoint], isClosed: true))
            }
            return pathlines
        }
        
        let path = CGMutablePath()
        for i in 0 ..< CTRunGetGlyphCount(ctRun) {
            let cfRange = CFRangeMake(i, 1)
            var glyph: CGGlyph = 0, position = CGPoint()
            CTRunGetGlyphs(ctRun, cfRange, &glyph)
            CTRunGetPositions(ctRun, cfRange, &position)
            if let glyphPath = CTFontCreatePathForGlyph(font, glyph, nil) {
                let t = CGAffineTransform(translationX: position.x + CGFloat(origin.x),
                                          y: position.y + CGFloat(origin.y))
                path.addPath(glyphPath, transform: t)
            }
        }
        var pathlines = [Pathline]()
        var fp = Point(), oldP = Point(), elements = [Pathline.Element]()
        path.applyWithBlock { (elementPtr) in
            let element = elementPtr.pointee
            switch element.type {
            case .moveToPoint:
                fp = element.points[0].my
                oldP = fp
            case .addLineToPoint:
                let p = element.points[0].my
                elements.append(.linear(p))
                oldP = p
            case .addQuadCurveToPoint:
                let p = element.points[1].my
                elements.append(.bezier(point: p,
                                        control: element.points[0].my))
                oldP = p
            case .addCurveToPoint:
                let p = element.points[2].my
                let bs = Bezier.beziersWith(p0: oldP,
                                            cp0: element.points[0].my,
                                            cp1: element.points[1].my,
                                            p1: p)
                elements.append(.bezier(point: bs.b0.p1,
                                        control: bs.b0.cp))
                elements.append(.bezier(point: bs.b1.p1,
                                        control: bs.b1.cp))
                oldP = p
            case .closeSubpath:
                pathlines.append(Pathline(firstPoint: fp, elements: elements,
                                          isClosed: true))
                elements = []
            @unknown default:
                fatalError()
            }
        }
        if !elements.isEmpty {
            pathlines.append(Pathline(firstPoint: fp, elements: elements,
                                      isClosed: false))
        }
        return pathlines
    }
}
extension Typerun {
    func draw(in ctx: CGContext) {
        guard isEnableFont else {
            for i in 0 ..< CTRunGetGlyphCount(ctRun) {
                let cfRange = CFRangeMake(i, 1)
                var position = CGPoint()
                CTRunGetPositions(ctRun, cfRange, &position)
                var ascent: CGFloat = 0.0, descent: CGFloat = 0.0
                let w = CTRunGetTypographicBounds(ctRun, cfRange,
                                                  &ascent, &descent, nil)
                let h = Double(ascent + descent)
                let rect = Rect(origin: position.my + ctx.textPosition.my
                                    - Point(0, Double(descent)),
                                size: Size(width: w, height: h))
                let dRect = rect.inset(by: 0.5)
                ctx.saveGState()
                ctx.setLineCap(.square)
                ctx.setStrokeColor(.black)
                ctx.stroke(dRect.cg, width: 1)
                ctx.restoreGState()
            }
            return
        }
        CTRunDraw(ctRun, ctx, CFRangeMake(0, 0))
    }
}

extension CFRange: @retroactive Equatable {
    static func == (lhs: CFRange, rhs: CFRange) -> Bool {
        return lhs.location == rhs.location && lhs.length == rhs.length
    }
}
extension CFRange {
    func contains(_ cfI: CFIndex) -> Bool {
        cfI >= location && cfI < maxLocation
    }
    func contains(_ other: CFRange) -> Bool {
        other.location >= location && other.maxLocation <= maxLocation
    }
    func intersects(_ other: CFRange) -> Bool {
        if self == other {
            return true
        } else if length == 0 {
            return other.contains(location)
        } else if other.length == 0 {
            return contains(other.location)
        } else {
            return other.maxLocation > location && other.location < maxLocation
        }
    }
    func intersection(_ other: CFRange) -> CFRange? {
        if self == other {
            return self
        } else if length == 0 {
            return other.contains(location) ? self : nil
        } else if other.length == 0 {
            return contains(other.location) ? other : nil
        } else {
            let selfMin = location, selfMax = maxLocation
            let otherMin = other.location, otherMax = other.maxLocation
            if otherMax > selfMin && otherMin < selfMax {
                let nMin = max(otherMin, selfMin), nMax = min(otherMax, selfMax)
                return CFRange(location: nMin, length: nMax - nMin)
            } else {
                return nil
            }
        }
    }
    var maxLocation: CFIndex {
        location + length
    }
}
extension CTLine {
    var runs: [CTRun] {
        CTLineGetGlyphRuns(self) as? [CTRun] ?? []
    }
}

