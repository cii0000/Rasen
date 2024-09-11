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
    static let horizontalName = "horizontal"
    static let verticalName = "vertical"
    
    static let sheetDicName = "sheetDic"
    static let sheetName = "sheet"
    static let sheetSizeName = "sheetSize"
    static let cursorPName = "cursorP"
    static let printPName = "printP"
}
extension O {
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
        
        if !sheet.value.picture.lines.isEmpty {
            sheet.removeLines(at: Array(0 ..< sheet.value.picture.lines.count))
        }
        if !sheet.value.texts.isEmpty {
            sheet.removeTexts(at: Array(0 ..< sheet.value.texts.count))
        }
        sheet.append(line)
        sheet.append(ts)
        return O(sheet)
    }
    
    static let drawName = "draw"
    static func draw(_ ao: O, _ oDic: inout [OKey: O]) -> O {
        switch ao {
        case .error: return ao
        default:
            let ps = ao.asPoints
            if ps.count == 1 {
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
        guard let base = bo.asReal1, base > 0 else { return O(OError(String(format: "'%1$@' is not positive real".localized, bo.name))) }
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
        guard let base = bo.asReal1, base > 0 else { return O(OError(String(format: "'%1$@' is not positive real".localized, bo.name))) }
        
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
        case .real1(let a): return String(oBased: a)
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
