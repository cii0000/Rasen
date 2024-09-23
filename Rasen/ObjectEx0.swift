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
               F(right: 1, .draw))
        append(drawAxesName, OKeyInfo(sheetGroup, "Draw axes on the sheet with $0 as the base scale, $1 as the x axis name, $2 as the y axis name, and the center of the sheet as the origin,\ne.g. drawAxes base: 1 \"X\" \"Y\"".localized),
               F(left: [], right: ["base", "", ""], .drawAxes))
        append(plotName, OKeyInfo(sheetGroup, "Plot points $1 on the sheet with $0 as the base scale, center of the sheet as the origin,\ne.g. plot base: 1 ((0 0) (1 1))".localized),
               F(left: [], right: ["base", ""], .plot))
        append(flipName, OKeyInfo(sheetGroup, "Flip sheet based on $0, e.g. flip horizontal".localized),
               F(right: 1, .flip))
        
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
            case .error: return bo
            default: break
            }
        case .int(let a):
            switch bo {
            case .bool(let b): return O(.apow(Double(a), Double(b)))
            case .int(let b): return O(.apow(Double(a), Double(b)))
            case .rational(let b): return O(.apow(Double(a), Double(b)))
            case .double(let b): return O(.apow(Double(a), b))
            case .error: return bo
            default: break
            }
        case .rational(let a):
            switch bo {
            case .bool(let b): return O(.apow(Double(a), Double(b)))
            case .int(let b): return O(.apow(Double(a), Double(b)))
            case .rational(let b): return O(.apow(Double(a), Double(b)))
            case .double(let b): return O(.apow(Double(a), b))
            case .error: return bo
            default: break
            }
        case .double(let a):
            switch bo {
            case .bool(let b): return O(.apow(a, Double(b)))
            case .int(let b): return O(.apow(a, Double(b)))
            case .rational(let b): return O(.apow(a, Double(b)))
            case .double(let b): return O(.apow(a, b))
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
                if a.isInfinite || b.isInfinite {
                    if (a.isInfinite && b == 0) || (a == 0 && b.isInfinite) {
                        return O(OError.undefined(with: "\(ao.name) \(multiplyName) \(bo.name)"))
                    }
                }
                return O(a * b)
            case .error: return bo
            default: break
            }
        case .array(let a):
            switch bo {
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
            case .error: return bo
            default: break
            }
        case .int(let a):
            switch bo {
            case .bool(let b): return O(Int.overMod(a, Int(b)))
            case .int(let b): return O(Int.overMod(a, b))
            case .rational(let b): return O(Rational.overMod(Rational(a), b))
            case .double(let b):
                return O(Double(a).truncatingRemainder(dividingBy: b))
            case .error: return bo
            default: break
            }
        case .rational(let a):
            switch bo {
            case .bool(let b): return O(Rational.overMod(a, Rational(b)))
            case .int(let b): return O(Rational.overMod(a, Rational(b)))
            case .rational(let b): return O(Rational.overMod(a, b))
            case .double(let b):
                return O(Double(a).truncatingRemainder(dividingBy: b))
            case .error: return bo
            default: break
            }
        case .double(let a):
            switch bo {
            case .bool(let b):
                return O(a.truncatingRemainder(dividingBy: Double(b)))
            case .int(let b):
                return O(a.truncatingRemainder(dividingBy: Double(b)))
            case .rational(let b):
                return O(a.truncatingRemainder(dividingBy: Double(b)))
            case .double(let b):
                if a.isInfinite && b.isInfinite {
                    return O(OError.undefined(with: "\(ao.name) \(moduloName) \(bo.name)"))
                }
                return O(a.truncatingRemainder(dividingBy: b))
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
            case .error: return bo
            default: break
            }
        case .int(let a):
            switch bo {
            case .bool(let b): return O(Int.overAdd(a, Int(b)))
            case .int(let b): return O(Int.overAdd(a, b))
            case .rational(let b): return O(Rational.overAdd(Rational(a), b))
            case .double(let b): return O(Double(a) + b)
            case .error: return bo
            default: break
            }
        case .rational(let a):
            switch bo {
            case .bool(let b): return O(Rational.overAdd(a, Rational(b)))
            case .int(let b): return O(Rational.overAdd(a, Rational(b)))
            case .rational(let b): return O(Rational.overAdd(a, b))
            case .double(let b): return O(Double(a) + b)
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
            case .error: return bo
            default: break
            }
        case .array(let a):
            switch bo {
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
            case .error: return bo
            default: break
            }
        case .int(let a):
            switch bo {
            case .bool(let b): return O(Int.overDiff(a, Int(b)))
            case .int(let b): return O(Int.overDiff(a, b))
            case .rational(let b): return O(Rational.overDiff(Rational(a), b))
            case .double(let b): return O(Double(a) - b)
            case .error: return bo
            default: break
            }
        case .rational(let a):
            switch bo {
            case .bool(let b): return O(Rational.overDiff(a, Rational(b)))
            case .int(let b): return O(Rational.overDiff(a, Rational(b)))
            case .rational(let b): return O(Rational.overDiff(a, b))
            case .double(let b): return O(Double(a) - b)
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
            case .error: return bo
            default: break
            }
        case .array(let a):
            switch bo {
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
    static let filiZName = "..."
    static let filoZName = "..<"
    static let foliZName = "<.."
    static let foloZName = "<.<"
    static let filiRName = "~~~"
    static let filoRName = "~~<"
    static let foliRName = "<~~"
    static let foloRName = "<~<"
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
}
