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

import Dispatch

final class RangeSelector: DragEditor, @unchecked Sendable {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    private var firstP = Point(), multiFrameSlider: MultiFrameSlider?
    let snappedDistance = 4.0
    
    func send(_ event: DragEvent) {
        let p = document.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            if let sheetView = document.sheetView(at: p),
               sheetView.animationView.containsTimeline(sheetView.convertFromWorld(p),
                                                        scale: document.screenToWorldScale) {
                
                multiFrameSlider = MultiFrameSlider(document)
                multiFrameSlider?.send(event)
                return
            }
            
            document.cursor = .arrow
            document.selections.append(Selection(rect: Rect(Edge(p, p)),
                                             rectCorner: .maxXMinY))
            firstP = p
        case .changed:
            if let multiFrameSlider {
                multiFrameSlider.send(event)
                return
            }
//            guard firstP.distance(p) >= snappedDistance * document.screenToWorldScale else {
//                document.selections = []
//                return
//            }
            let orientation: RectCorner
            if firstP.x < p.x {
                if firstP.y < p.y {
                    orientation = .maxXMaxY
                } else {
                    orientation = .maxXMinY
                }
            } else {
                if firstP.y < p.y {
                    orientation = .minXMaxY
                } else {
                    orientation = .minXMinY
                }
            }
            if document.selections.isEmpty {
                document.selections = [Selection(rect: Rect(Edge(p, p)),
                                                 rectCorner: .maxXMinY)]
            } else {
                document.selections[.last] = Selection(rect: Rect(Edge(firstP, p)),
                                                        rectCorner: orientation)
            }
            
        case .ended:
            if let multiFrameSlider {
                multiFrameSlider.send(event)
                return
            }
            document.cursor = document.defaultCursor
        }
    }
}
final class Unselector: InputKeyEditor, @unchecked Sendable {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    func send(_ event: InputKeyEvent) {
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            document.closeLookingUp()
            document.selections = []
        case .changed:
            break
        case .ended:
            document.cursor = document.defaultCursor
        }
    }
}

final class LineDrawer: DragEditor, @unchecked Sendable {
    let editor: LineEditor
    
    init(_ document: Document) {
        editor = LineEditor(document)
    }
    
    func send(_ event: DragEvent) {
        editor.drawLine(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class StraightLineDrawer: DragEditor, @unchecked Sendable {
    let editor: LineEditor
    
    init(_ document: Document) {
        editor = LineEditor(document)
    }
    
    func send(_ event: DragEvent) {
        editor.drawStraightLine(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class LassoCutter: DragEditor, @unchecked Sendable {
    let editor: LineEditor
    
    init(_ document: Document) {
        editor = LineEditor(document)
    }
    
    func send(_ event: DragEvent) {
        editor.lassoCut(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class LassoCopier: DragEditor, @unchecked Sendable {
    let editor: LineEditor
    
    init(_ document: Document) {
        editor = LineEditor(document)
    }
    
    func send(_ event: DragEvent) {
        editor.lassoCopy(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
enum LassoType {
    case cut, copy, makeFaces, cutFaces, changeDraft, cutDraft
}
final class LineEditor: Editor, @unchecked Sendable {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private(set) var tempLineNode: Node?
    var tempLineWidth = Line.defaultLineWidth
    var lassoDistance = 3.0
    
    struct Temp {
        var control: Line.Control, distance: Double, speed: Double
        var time: Double, position: Point, length: Double
        var pressurePoint: Point {
            return Point(distance, control.pressure)
        }
    }
    var temps = [Temp](), times = [Double]()
    var firstPoint = Point(), oldPoint = Point(), tempDistance = 0.0
    var oldFirstChangedTime: Double?, oldTime = 0.0, lastSpeed = 0.0, oldTempTime = 0.0
    var oldPressure = 1.0, firstTime = 0.0
    var prs = [Double](), snapDC: Line.Control?, snapSize = 0.0, isStopFirstPressure = false
    
    var isSnapStraight = false {
        didSet {
            guard isSnapStraight != oldValue else { return }
            if isSnapStraight {
                Feedback.performAlignment()
            }
            tempLineNode?.lineType = isSnapStraight ? .color(.selected) : .color(.content)
        }
    }
    var lastSnapStraightTime = 0.0
    
    var centerOrigin = Point(), centerBounds = Rect(), clipBounds = Rect()
    var centerSHP = Sheetpos(), nearestShps = [Sheetpos]()
    var tempLine = Line()
    
    func updateNode() {
        lassoPathNodeLineWidth = 1 * document.screenToWorldScale
        selectingNode.children.forEach { $0.lineWidth = lassoPathNodeLineWidth }
        rectNode?.children.forEach { $0.lineWidth = lassoPathNodeLineWidth }
        updateStraightNode()
    }
    func updateStraightNode() {
        if let isStraightNode = isStraightNode {
            let fp = firstPoint + centerOrigin
            let lw = lassoPathNodeLineWidth
            let wb = document.worldBounds
            let b0 = Rect(x: fp.x - lw / 2, y: wb.minY, width: lw, height: wb.height)
            let b1 = Rect(x: wb.minX, y: fp.y - lw / 2, width: wb.width, height: lw)
            let paths = [Path(b0), Path(b1)]
            isStraightNode.children = paths.map {
                Node(path: $0, fillType: isStraightNode.fillType)
            }
        }
    }
    func updateClipBoundsAndIndexRange(at p: Point) {
        let ip = document.intPosition(at: p)
        let shp = document.sheetPosition(at: ip)
        let aroundShps = document.aroundSheetpos(atCenter: ip).map { $0.shp }
        nearestShps = [shp] + aroundShps
        
        let nearestB = nearestShps.reduce(into: document.sheetFrame(with: shp)) {
            $0.formUnion(document.sheetFrame(with: $1))
        }
        
        let cb = document.sheetFrame(with: shp)
        centerOrigin = cb.origin
        centerBounds = Rect(origin: Point(), size: cb.size)
        
        clipBounds = nearestB.inset(by: document.sheetLineWidth) - cb.origin
        centerSHP = shp
    }
    
    private(set) var outlineLassoNode: Node?
    private(set) var lassoNode: Node?
    private(set) var selectingNode = Node(lineWidth: 1.5,
                                          lineType: .color(.selected),
                                          fillType: .color(.subSelected))
    private(set) var isStraightNode: Node?
    var lassoPathNodeLineWidth = 1.0 {
        didSet {
            outlineLassoNode?.lineWidth = lassoPathNodeLineWidth
        }
    }
    
    private static func joinControlWith(_ line: Line,
                                        lastControl lc: Line.Control,
                                        lowAngle: Double = 0.8 * (.pi / 2),
                                        angle: Double = 1.0 * (.pi / 2)) -> Line.Control? {
        guard line.controls.count >= 4 else { return nil }
        let c0 = line.controls[line.controls.count - 4]
        let c1 = line.controls[line.controls.count - 3], c2 = lc
        guard c0.point != c1.point && c1.point != c2.point else { return nil }
        guard c1.point.distance(c2.point) > 3 else { return nil }
        let dr = abs(Point.differenceAngle(c0.point, c1.point, c2.point))
        if dr > angle {
            return c1
        } else if dr > lowAngle {
            let t = 1 - (dr - lowAngle) / (angle - lowAngle)
            return Line.Control(point: Point.linear(c1.point, c2.point, t: t),
                                weight: 0.5,
                                pressure: Double.linear(c1.pressure, c2.pressure, t: t))
        } else {
            return nil
        }
    }
    
    private static func speed(from temps: [Temp], at i: Int, delta: Int = 2) -> Double {
        var allSpeed = 0.0, count = 0
        for temp in temps[max(0, i - delta) ..< i] {
            allSpeed += temp.speed
            count += 1
        }
        if i + 1 < temps.count {
            for temp in temps[(i + 1) ... min(temps.count - 1, i + delta)] {
                allSpeed += temp.speed
                count += 1
            }
        }
        guard count > 0 else { return temps[i].speed }
        let averageSpeed = allSpeed / Double(count)
        if temps[i].speed < averageSpeed * 2 {
            return temps[i].speed
        } else {
            return averageSpeed
        }
    }
    
    private static func isAppendPointWith(distance: Double, deltaTime: Double,
                                          _ temps: [Temp], lastBezier lb: Bezier,
                                          scale: Double,
                                          minSpeed: Double = 300.0,
                                          maxSpeed: Double = 1000.0,
                                          exp: Double = 2.0,
                                          minTime: Double = 0.06,
                                          maxTime: Double = 0.017,
                                          minDistance: Double = 0.5,
                                          maxDistance: Double = 0.5,
                                          maxPressureDistance maxPrD: Double = 0.05) -> Bool {
        guard deltaTime > 0 else {
            return false
        }
        let speed = ((distance * scale) / deltaTime)
            .clipped(min: minSpeed, max: maxSpeed)
        let t = ((speed - minSpeed) / (maxSpeed - minSpeed)) ** (1 / exp)
        let time = minTime + (maxTime - minTime) * t
        if temps.count <= 2 {
            return false
        } else if deltaTime > time {
            return true
        } else {
            guard let lTemp = temps.last else {
                return false
            }
            let linearLine = LinearLine(temps.first!.control.point,
                                        temps.last!.control.point)
            let ss = scale * scale
            var angle = 0.0
            for (i, tc) in temps.enumerated() {
                if i > 1 {
                    angle += Point.differenceAngle(temps[i].control.point,
                                                  temps[i - 1].control.point,
                                                  temps[i - 2].control.point)
                    if abs(angle) > .pi / 4 {
                        return true
                    }
                }
                
                let speed = (LineEditor.speed(from: temps, at: i) * scale).clipped(min: minSpeed, max: maxSpeed)
                let t = ((speed - minSpeed) / (maxSpeed - minSpeed)) ** (1 / exp)
                let maxD = minDistance + (maxDistance - minDistance) * t
                
                let nMaxD = maxD * (lTemp.time - tc.time)
                    .clipped(min: 0, max: time, newMin: 1, newMax: 0)
                guard let p = lb.position(withLength: tc.length) else {
                    if linearLine.distanceSquared(from: tc.control.point) * ss > maxD * maxD {
                        return true
                    }
                    continue
                }
                if tc.position.distanceSquared(p) * ss > nMaxD * nMaxD {
                    return true
                }
            }
            return false
        }
    }
    
    private static func revision(pressure: Double,
                                 minPressure: Double = 0.3,
                                 revisonMinPressure: Double = 0.125) -> Double {
        if pressure < minPressure {
            return revisonMinPressure
        } else {
            return pressure.clipped(min: minPressure,
                                    max: 1,
                                    newMin: revisonMinPressure,
                                    newMax: 1)
        }
    }
    
    private static func clipPoint(_ op: Point, old oldP: Point?, from node: Node) -> Point {
        let cp = node.convertFromWorld(op)
        let sBounds = node.bounds ?? Rect()
        if let oldP = oldP, let np = sBounds.intersection(Edge(oldP, cp)).first {
            return np
        } else {
            return sBounds.clipped(cp)
        }
    }
    
    private static func snap(_ fol: FirstOrLast, _ line: Line,
                             isSnapSelf: Bool = true,
                             worldToScreenScale: Double,
                             screenToWorldScale: Double,
                             from lines: [Line]) -> Line.Control? {
        snap(line.controls[fol],
             isSnapSelf ? line.controls[fol.reversed] : nil,
             size: line.size * line.controls[fol].pressure,
             worldToScreenScale: worldToScreenScale,
             screenToWorldScale: screenToWorldScale, from: lines)?.control
    }
    private static func snap(_ c: Line.Control, _ nc: Line.Control?,
                             size: Double,
                             worldToScreenScale: Double,
                             screenToWorldScale: Double,
                             from lines: [Line]) -> (size: Double, control: Line.Control)? {
        let dq = screenToWorldScale.clipped(min: 0.06, max: 2,
                                            newMin: 0.5, newMax: 2)
        let dd = size / 2
        var minDSQ = Double.infinity, minP: Line.Control?,
            preMinDSQ = Double.infinity
        var minSize = size
        func update(_ oc: Line.Control, _ oSize: Double) {
            let ond = dq * (dd + oSize / 2)
            let dSQ = c.distanceSquared(oc)
            if dSQ < ond * ond && dSQ < minDSQ && size.absRatio(oSize) < 2 {
                preMinDSQ = minDSQ
                minDSQ = dSQ
                minP = oc
                minSize = oSize
            }
        }
        for oLine in lines {
            guard let fc = oLine.controls.first,
                  let lc = oLine.controls.last else { continue }
            update(fc, oLine.size * fc.pressure)
            update(lc, oLine.size * lc.pressure)
        }
        if let nc = nc {
            update(nc, size)
        }
        if minDSQ.distance(to: preMinDSQ) * worldToScreenScale <= 5 {
            return nil
        }
        return if let minP {
            (minSize, minP)
        } else {
            nil
        }
    }
    
    static func line(from events: [DrawLineEvent],
                     isClip: Bool = true,
                     isSnap: Bool = true,
                     firstSnapLines: [Line], lastSnapLines: [Line],
                     clipBounds: Rect, isStraight: Bool) -> (line: Line, isSnapStraight: Bool) {
        isStraight ?
        straightLine(from: events, isClip: isClip, isSnap: isSnap,
                     firstSnapLines: firstSnapLines,
                     lastSnapLines: lastSnapLines,
                     clipBounds: clipBounds) :
        (line(from: events, isClip: isClip, isSnap: isSnap,
             firstSnapLines: firstSnapLines,
             lastSnapLines: lastSnapLines,
             clipBounds: clipBounds), false)
    }
    static func line(from events: [DrawLineEvent],
                     isClip: Bool = true,
                     isSnap: Bool = true,
                     firstSnapLines: [Line], lastSnapLines: [Line],
                     clipBounds: Rect) -> Line {
        var nLine = Line()
        
        var temps = [Temp](), times = [Double]()
        var oldPoint = Point(), tempDistance = 0.0
        var oldFirstChangedTime: Double?, oldTime = 0.0, oldTempTime = 0.0
        var prs = [Double](), snapDC: Line.Control?, snapSize = 0.0, isStopFirstPressure = false
        var tempLineWidth = Line.defaultLineWidth
        
        func drawLine(for p: Point, sp: Point, pressure: Double,
                      time: Double, isClip: Bool = true,
                      isSnap: Bool = true,
                      worldToScreenScale: Double,
                      screenToWorldScale: Double,
                      sheetLineWidth: Double,
                      _ phase: Phase) {
            let wtsScale = worldToScreenScale
            var p = Document.roundedPoint(from: p, scale: wtsScale)
            let pressure = revision(pressure: pressure).rounded(decimalPlaces: 2)
            
            switch phase {
            case .began:
                if isClip {
                    p = clipBounds.clipped(p)
                }
                tempLineWidth = sheetLineWidth
                var fc = Line.Control(point: p, weight: 0.5, pressure: pressure)
                if isSnap,
                   let (nSnapSize, snapC) = snap(fc, nil, size: tempLineWidth,
                                                 worldToScreenScale: worldToScreenScale,
                                                 screenToWorldScale: screenToWorldScale,
                                                 from: firstSnapLines) {
                    snapDC = Line.Control(point: snapC.point - fc.point,
                                          weight: 0,
                                          pressure: snapC.pressure)
                    snapSize = nSnapSize
                    fc.point = snapC.point
                }
                nLine = Line(controls: [fc, fc, fc, fc],
                                size: tempLineWidth)
                times = [time, time, time, time]
                oldPoint = p
                oldTime = time
                oldTempTime = time
                tempDistance = 0
                temps = [Temp(control: fc, distance: 0, speed: 0,
                              time: time, position: fc.point, length: 0)]
            case .changed:
                //
    //            document.rootNode.append(child: Node(attitude: Attitude(position: centerOrigin + p),
    //                                                 path: Path(circleRadius: 0.25),
    //                                                 fillType: .color(.border)))
                let tempLine = nLine
                
                let firstChangedTime: Double
                if let aTime = oldFirstChangedTime {
                    firstChangedTime = aTime
                } else {
                    oldFirstChangedTime = time
                    firstChangedTime = time
                }
                
                if isClip, let nSnapDC = snapDC {
                    if !nSnapDC.isEmpty && time - firstChangedTime < 0.08 {
                        snapDC?.point *= 0.75
                        p += nSnapDC.point * 0.75
                        
                        p = Document.roundedPoint(from: p, scale: wtsScale)
                    }
                    p = clipBounds.clipped(p)
                }
                
                guard p != oldPoint && time > oldTime
                        && tempLine.controls.count >= 4 else { return }
                let d = p.distance(oldPoint)
                tempDistance += d
                
                prs.append(pressure)
                
                let speed = d / (time - oldTime)
                let lc = Line.Control(point: p, weight: 0.5, pressure: pressure)
                var lb = nLine.bezier(at: nLine.maxBezierIndex - 1)
                lb.p1 = lb.cp.mid(lc.point)
                temps.append(Temp(control: lc, distance: tempDistance, speed: speed,
                                  time: time, position: lb.p1, length: lb.length()))
                
                if !isStopFirstPressure {
                    let pre: Double
                    if isClip, let snapDC = snapDC {
                        if (nLine.size * pressure).absRatio(snapSize) < 1.5 {
                            pre = snapDC.pressure
                        } else {
                            pre = pressure
                        }
                    } else {
                        pre = pressure
                    }
                    if nLine.controls[.first].pressure < pre {
                        for i in 0 ..< nLine.controls.count {
                            nLine.controls[i].pressure = pre
                        }
                        temps = temps.map {
                            var temp = $0
                            temp.control.pressure = pre
                            return temp
                        }
                    }
                }
                if time - firstChangedTime > 0.075 {
                     isStopFirstPressure = true
                }
                
                if nLine.controls.count == 4, temps.count >= 2 {
                    var maxL = 0.0
                    for i in 0 ..< (temps.count - 1) {
                        let edge = Edge(temps[i].control.point,
                                        temps[i + 1].control.point)
                        maxL += edge.length
                    }
                    let d = maxL / 4
                    var l = 0.0, maxP = nLine.firstPoint
                    for i in 0 ..< (temps.count - 1) {
                        let edge = Edge(temps[i].control.point,
                                        temps[i + 1].control.point)
                        let el = edge.length
                        if el > 0 && d >= l && d < l + el {
                            maxP = edge.position(atT: (d - l) / el)
                        }
                        l += el
                    }
                    nLine.controls[nLine.controls.count - 3].point = maxP
                }
                
                let mp = lc.point.mid(temps[temps.count - 1].control.point)
                let mpr = lc.pressure.mid(temps[temps.count - 1].control.pressure)
                let mlc = Line.Control(point: mp, weight: 0.5, pressure: mpr)
                if var jc = joinControlWith(nLine, lastControl: mlc) {
                    if time - firstChangedTime < 0.02 {
                        jc.weight = 0.5
                        nLine.controls = [jc, jc, jc, jc]
                        times = [time, time, time, time]
                    } else {
                        //
    //                    document.rootNode.append(child: Node(attitude: Attitude(position: centerOrigin + jc.point),
    //                                                         path: Path(circleRadius: 1),
    //                                                         fillType: .color(.selected)))
                        
                        nLine.controls[nLine.controls.count - 3].weight = 0.5
                        jc.weight = 1
                        
                        nLine.controls.insert(jc, at: nLine.controls.count - 2)
                        times.insert(time, at: times.count - 2)
                    }
                    let lb = tempLine.bezier(at: tempLine.maxBezierIndex - 1)
                    temps = [Temp(control: lc, distance: 0, speed: speed,
                                  time: time, position: lb.p1, length: lb.length())]
                    oldTempTime = time
                    tempDistance = 0
                } else if isAppendPointWith(distance: tempDistance,
                                            deltaTime: time - oldTempTime,
                                            temps, lastBezier: lb,
                                            scale: wtsScale) {
                    nLine.controls[nLine.controls.count - 3].weight = 0.5
                    let prp = nLine.controls[nLine.controls.count - 1]
                    nLine.controls[nLine.controls.count - 2] = prp
                    nLine.controls[nLine.controls.count - 2].weight = 1
                    
                    nLine.controls.insert(prp, at: nLine.controls.count - 1)
                    times.insert(times[times.count - 1], at: times.count - 1)
                    
                    //
    //                document.rootNode.append(child: Node(attitude: Attitude(position: centerOrigin + prp.point),
    //                                                     path: Path(circleRadius: 0.5),
    //                                                     fillType: .color(.selected)))
                    
                    let lb = nLine.bezier(at: nLine.maxBezierIndex - 1)
                    temps = [Temp(control: lc, distance: 0, speed: speed,
                                  time: time, position: lb.p1, length: lb.length())]
                    oldTempTime = time
                    tempDistance = 0
                }
                
                nLine.controls[nLine.controls.count - 3].weight = 1
                nLine.controls[nLine.controls.count - 2]
                    = nLine.controls[nLine.controls.count - 3].mid(lc)
                nLine.controls[nLine.controls.count - 2].weight = 0.5
                nLine.controls[.last] = lc
                times[times.count - 2] = time
                times[.last] = time
                
                oldTime = time
                oldPoint = p
            case .ended:
                guard nLine.controls.count >= 4 else { return }
                
                nLine.controls[nLine.controls.count - 3].weight = 0.5
                nLine.controls[nLine.controls.count - 2] = nLine.controls.last!
                nLine.controls.removeLast()
                times.removeLast()
                
                if nLine.controls.count == times.count && nLine.controls.count >= 3 {
                    var fi = times.count
                    for (i, oldTime) in times.enumerated().reversed() {
                        fi = i
                        if time - oldTime > 0.04 { break }
                    }
                    fi = min(max(1, nLine.controls.count - 3), fi)
                    let fpre = nLine.controls[fi].pressure
                    for i in (fi + 1) ..< nLine.controls.count {
                        nLine.controls[i].pressure = fpre
                    }
                    
                    if nLine.controls.count > 2 {
                        var oldC = nLine.controls.first!
                        let ll = nLine.controls.reduce(0.0) {
                            let n = $0 + $1.point.distance(oldC.point)
                            oldC = $1
                            return n
                        }
                        oldC = nLine.controls.last!
                        var l = 0.0
                        for i in (2 ..< nLine.controls.count).reversed() {
                            let p0 = nLine.controls[i].point,
                                p1 = nLine.controls[i - 1].point,
                                p2 = nLine.controls[i - 2].point
                            l += p0.distance(oldC.point)
                            oldC = nLine.controls[i]
                            if time - times[i] > 0.1
                                || l * wtsScale > 6
                                || l / ll > 0.05 {
                                break
                            }
                            let dr = abs(Point.differenceAngle(p0, p1, p2))
                            if dr > .pi * 0.3 {
                                let nCount = nLine.controls.count - i
                                nLine.controls.removeLast(nCount)
                                times.removeLast(nCount)
                                break
                            }
                        }
                    }
                }
                
                if isSnap, let nc = snap(.last, nLine,
                                         worldToScreenScale: worldToScreenScale,
                                         screenToWorldScale: screenToWorldScale,
                                         from: lastSnapLines) {
                    nLine.controls[.last] = nc
                }
                
                let edge = Edge(nLine.firstPoint, nLine.lastPoint)
                let length = edge.length
                if length > 0 {
                    let lScale = length.clipped(min: 20 * screenToWorldScale,
                                                max: 200 * screenToWorldScale,
                                                newMin: 0, newMax: 0.5)
                    if nLine.straightDistance() * wtsScale < lScale {
                        nLine.controls = [nLine.controls.first!, nLine.controls.last!]
                        let pd = nLine.controls.first!.pressure
                            .distance(nLine.controls.last!.pressure)
                        if pd < 0.1 {
                            let pres = max(nLine.controls.first!.pressure,
                                           nLine.controls.last!.pressure)
                            nLine.controls[.first].pressure = pres
                            nLine.controls[.last].pressure = pres
                        }
                    }
                }
            }
        }
        
        for event in events {
            drawLine(for: event.p, sp: event.sp, pressure: event.pressure,
                     time: event.time, isClip: isClip, isSnap: isSnap,
                     worldToScreenScale: event.worldToScreenScale,
                     screenToWorldScale: event.screenToWorldScale, sheetLineWidth: tempLineWidth,
                     event.phase)
        }
        
        return nLine
    }
    
    static func straightLine(from events: [DrawLineEvent],
                             isClip: Bool = true,
                             isSnap: Bool = true,
                             firstSnapLines: [Line], lastSnapLines: [Line],
                             clipBounds: Rect) -> (line: Line, snapStraight: Bool) {
        var nLine = Line()
        
        var temps = [Temp]()
        var oldPoint = Point(), tempDistance = 0.0
        var oldFirstChangedTime: Double?, oldTime = 0.0
        var prs = [Double](), snapDC: Line.Control?, snapSize = 0.0
        var tempLineWidth = Line.defaultLineWidth
        var isSnapStraight = false
        var lastSnapStraightTime = 0.0
        
        func drawLine(for p: Point, sp: Point, pressure: Double,
                      time: Double, isClip: Bool = true,
                      isSnap: Bool = true,
                      worldToScreenScale: Double,
                      screenToWorldScale: Double,
                      sheetLineWidth: Double,
                      _ phase: Phase) {
            let wtsScale = worldToScreenScale
            var p = Document.roundedPoint(from: p, scale: wtsScale)
            let pressure = Self.revision(pressure: pressure).rounded(decimalPlaces: 2)
            
            switch phase {
            case .began:
                if isClip {
                    p = clipBounds.clipped(p)
                }
                tempLineWidth = sheetLineWidth
                var fc = Line.Control(point: p, weight: 0.5, pressure: pressure)
                if isSnap,
                   let (nSnapSize, snapC) = Self.snap(fc, nil, size: tempLineWidth,
                                                     worldToScreenScale: worldToScreenScale,
                                                     screenToWorldScale: screenToWorldScale,
                                                     from: firstSnapLines) {
                    snapDC = Line.Control(point: snapC.point - fc.point,
                                          weight: 0,
                                          pressure: snapC.pressure)
                    fc.point = snapC.point
                    snapSize = nSnapSize
                }
                nLine = Line(controls: [fc, fc],
                             size: tempLineWidth)
                oldPoint = p
                oldTime = time
                tempDistance = 0
                temps = [Temp(control: fc, distance: 0, speed: 0,
                              time: time, position: fc.point, length: 0)]
                prs = [pressure]
                isSnapStraight = false
            case .changed:
                let firstChangedTime: Double
                if let aTime = oldFirstChangedTime {
                    firstChangedTime = aTime
                } else {
                    oldFirstChangedTime = time
                    firstChangedTime = time
                }
                
                if isClip, let nSnapDC = snapDC {
                    if !nSnapDC.isEmpty && time - firstChangedTime < 0.08 {
                        snapDC?.point *= 0.75
                        p += nSnapDC.point * 0.75
                        
                        p = Document.roundedPoint(from: p, scale: wtsScale)
                    }
                    p = clipBounds.clipped(p)
                }
                
                guard p != oldPoint && time > oldTime else { return }
                let d = p.distance(oldPoint)
                tempDistance += d
                
                prs.append(pressure)
                
                let speed = d / (time - oldTime)
                let lc = Line.Control(point: p, weight: 0.5, pressure: pressure)
                var lb = nLine.bezier(at: nLine.maxBezierIndex - 1)
                lb.p1 = lb.cp.mid(lc.point)
                temps.append(Temp(control: lc, distance: tempDistance, speed: speed,
                                  time: time, position: lb.p1, length: lb.length()))
                
                if time - firstChangedTime < 0.1 {
                    let pre: Double
                    if isClip, let snapDC = snapDC {
                        if (nLine.size * pressure).absRatio(snapSize) < 1.5 {
                            pre = snapDC.pressure
                        } else {
                            pre = pressure
                        }
                    } else {
                        pre = pressure
                    }
                    if nLine.controls[.first].pressure < pre {
                        for i in 0 ..< nLine.controls.count {
                            nLine.controls[i].pressure = pre
                        }
                    }
                }
                
                nLine.controls[.last] = lc
                
                let fp = nLine.firstPoint, lp = lc.point
                let llp: Point
                let ls = nLine.size / 2 * wtsScale
                let maxAxisD = max(ls, 2.5), maxD = 50.0, snapSpeed = 100.0
                let dp = lp - fp
                if abs(dp.x) > abs(dp.y) {
                    let dx = abs(dp.x * wtsScale).clipped(min: 0, max: maxD,
                                                                newMin: 0, newMax: maxAxisD)
                    if abs(dp.y) * wtsScale < dx && LineEditor.speed(from: temps, at: temps.count - 1) * wtsScale < snapSpeed, time - firstChangedTime > 0.1 {
                        llp = Point(lp.x, fp.y)
                        isSnapStraight = true
                        lastSnapStraightTime = time
                    } else if time - lastSnapStraightTime < 0.1 {
                        llp = Point(lp.x, fp.y)
                    } else {
                        llp = lp
                        isSnapStraight = false
                    }
                } else {
                    let dy = abs(dp.y * wtsScale).clipped(min: 0, max: maxD,
                                                                newMin: 0, newMax: maxAxisD)
                    if abs(dp.x) * wtsScale < dy && LineEditor.speed(from: temps, at: temps.count - 1) * wtsScale < snapSpeed, time - firstChangedTime > 0.1 {
                        llp = Point(fp.x, lp.y)
                        isSnapStraight = true
                        lastSnapStraightTime = time
                    }  else if time - lastSnapStraightTime < 0.1 {
                        llp = Point(fp.x, lp.y)
                    } else {
                        llp = lp
                        isSnapStraight = false
                    }
                }
                
                if prs.count == temps.count {
                    var fpre = prs.last!
                    for (i, oldTemp) in temps.enumerated().reversed() {
                        if time - oldTemp.time < 0.3 {
                            fpre = max(fpre, prs[i])
                        } else {
                            break
                        }
                    }
                    nLine.controls[.last].pressure = fpre
                }
                
                if let aLine = snapStraightLine(with: nLine, fp: fp, lp: llp) {
                    nLine = aLine
                }
                
                oldTime = time
                oldPoint = p
            case .ended:
                guard nLine.controls.count == 2 else { return }
                
                if prs.count == temps.count {
                    var fpre = prs.last!
                    for (i, oldTemp) in temps.enumerated().reversed() {
                        if time - oldTemp.time < 0.3 {
                            fpre = max(fpre, prs[i])
                        } else {
                            break
                        }
                    }
                    if abs(nLine.controls.first!.pressure - fpre) < 0.2 {
                        fpre = nLine.controls.first!.pressure
                    }
                    nLine.controls[.last].pressure = fpre
                }
                
                if isSnap, let nc = Self.snap(.last, nLine,
                                              worldToScreenScale: worldToScreenScale,
                                              screenToWorldScale: screenToWorldScale,
                                              from: lastSnapLines) {
                    nLine.controls[.last] = nc
                    if let nnLine = snapStraightLine(with: nLine,
                                                    fp: nLine.firstPoint,
                                                    lp: nc.point) {
                        nLine = nnLine
                    }
                }
                
                if time - lastSnapStraightTime < 0.2 {
                    let fp = nLine.firstPoint, lp = nLine.lastPoint
                    let llp: Point
                    let dp = lp - fp
                    if abs(dp.x) > abs(dp.y) {
                        llp = Point(lp.x, fp.y)
                    } else {
                        llp = Point(fp.x, lp.y)
                    }
                    if let aLine = snapStraightLine(with: nLine, fp: fp, lp: llp) {
                        nLine = aLine
                    }
                }
            }
        }
        
        for event in events {
            drawLine(for: event.p, sp: event.sp, pressure: event.pressure,
                     time: event.time, isClip: isClip, isSnap: isSnap,
                     worldToScreenScale: event.worldToScreenScale,
                     screenToWorldScale: event.screenToWorldScale, sheetLineWidth: tempLineWidth,
                     event.phase)
        }
        
        return (nLine, isSnapStraight)
    }
    
    static func snapStraightLine(with line: Line,
                                 fp: Point, lp: Point) -> Line? {
        let ol = line.pointsLength
        guard ol > 0 else {
            return nil
        }
        let nl = fp.distance(lp)
        let ratio = nl / ol
        let angle = fp.angle(lp)
        var d = 0.0, oldP = fp
        var line = line
        line.controls = line.controls.enumerated().map {
            if $0.offset == 0 {
                return $0.element
            } else {
                d += $0.element.point.distance(oldP)
                oldP = $0.element.point
                var c = $0.element
                c.point = fp.movedWith(distance: d * ratio, angle: angle)
                return c
            }
        }
        return line
    }
    
    private var isDrawNote = false
    private var noteSheetView: SheetView?, oldPitch = Rational(0), firstTone = Tone(),
                beganScore: Score?, beganPitch = Rational(), octaveNode: Node?, oldBeat = Rational(0),
                noteI: Int?, noteStartBeat: Rational?, notePlayer: NotePlayer?
    func drawNote(with event: DragEvent, isStraight: Bool = false) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        switch event.phase {
        case .began:
            if document.isPlaying(with: event) {
                document.stopPlaying(with: event)
            }
            
            let p = document.convertScreenToWorld(event.screenPoint)
            if let sheetView = noteSheetView, sheetView.model.score.enabled {
                let scoreView = sheetView.scoreView
                let inP = sheetView.convertFromWorld(p)
                let scoreP = scoreView.convertFromWorld(p)
                let pitchInterval = document.currentPitchInterval
                let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                    .clipped(min: Score.pitchRange.start, max: Score.pitchRange.end)
                let score = scoreView.model
                let count = score.notes.count
                let beatInterval = document.currentBeatInterval
                let beat = scoreView.beat(atX: inP.x, interval: beatInterval)
                let beatRange = beat ..< beat
                firstTone = isStraight ? Tone.empty() : Tone()
                let note = Note(beatRange: beatRange, pitch: pitch,
                                pits: .init([.init(beat: 0, pitch: 0, tone: firstTone)]),
                                envelope: !isStraight && firstTone.spectlope.isFullNoise ? .init(releaseSec: 0.5) : .init())
                
                noteI = count
                oldPitch = pitch
                oldBeat = beat
                beganPitch = pitch
                noteStartBeat = beat
                beganScore = score
                
                if let notePlayer = sheetView.notePlayer {
                    self.notePlayer = notePlayer
                    notePlayer.notes = [note.firstPitResult]
                } else {
                    let note = isStraight ? Note(beatRange: beatRange, pitch: pitch) : note
                    notePlayer = try? NotePlayer(notes: [note.firstPitResult])
                    sheetView.notePlayer = notePlayer
                }
                notePlayer?.play()
                
                scoreView.append(note)
//                    let noteNode = scoreView.noteNode(from: note)
//                    noteNode.attitude.position
//                        = scoreView.node.attitude.position
//                        + sheetView.node.attitude.position
//                    self.tempLineNode = noteNode
//                    document.rootNode.insert(child: noteNode,
//                                             at: document.accessoryNodeIndex)
                
//                stoppedSeqSec = sheetView.sequencer?.currentPositionInSec
                
                let octaveNode = scoreView.octaveNode(fromPitch: pitch, scoreView.notesNode.children.last!.children[0].clone,
                                                  .subInterpolated)
                octaveNode.attitude.position = sheetView.node.attitude.position
                self.octaveNode = octaveNode
                document.rootNode.append(child: octaveNode)
                
                document.cursor = .circle(string: Pitch(value: pitch).octaveString())
            }
        case .changed:
            let p = document.convertScreenToWorld(event.screenPoint)
            if let sheetView = noteSheetView,
                let nsBeat = noteStartBeat, let noteI {
                
                let pitchInterval = document.currentPitchInterval
                let beatInterval = document.currentBeatInterval
                let scoreView = sheetView.scoreView
                let sheetP = sheetView.convertFromWorld(p)
                let scoreP = scoreView.convertFromWorld(p)
                let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                    .clipped(min: Score.pitchRange.start, max: Score.pitchRange.end)
                let beat = scoreView.beat(atX: sheetP.x, interval: beatInterval)
                let beatRange = beat > nsBeat ? nsBeat ..< beat : beat ..< nsBeat
                let note = Note(beatRange: beatRange, pitch: pitch,
                                pits: [.init(beat: 0, pitch: 0, tone: firstTone)],
                                envelope: !isStraight && firstTone.spectlope.isFullNoise ? .init(releaseSec: 0.5) : .init())
                let isNote = oldPitch != pitch
                
                if isNote {
                    notePlayer?.notes = [note.firstPitResult]
                    self.oldPitch = pitch
                }
                
                scoreView[noteI] = note
//                    tempLineNode?.children
//                        = scoreView.noteNode(from: note).children
                
                if isNote || beat != oldBeat {
                    octaveNode?.children = scoreView.octaveNode(fromPitch: pitch,
                                                                scoreView.notesNode.children.last!.children[0].clone,
                                                                .octave).children
                    oldBeat = beat
                }
                
                document.cursor = .circle(string: Pitch(value: pitch)
                    .octaveString(deltaPitch: pitch - beganPitch))
            }
        case .ended:
            tempLineNode?.removeFromParent()
            tempLineNode = nil
            octaveNode?.removeFromParent()
            octaveNode = nil
            
            let p = document.convertScreenToWorld(event.screenPoint)
            if let sheetView = noteSheetView, let nsBeat = noteStartBeat, let noteI,
               !sheetView.model.score.notes.isEmpty {
                
                let scoreView = sheetView.scoreView
                let sheetP = sheetView.convertFromWorld(p)
                let interval = document.currentBeatInterval
                let beat = scoreView.beat(atX: sheetP.x, interval: interval)
                let beatRange = beat > nsBeat ? nsBeat ..< beat : beat ..< nsBeat
                if beatRange.length == 0 {
                    scoreView.remove(at: noteI)
                } else {
                    sheetView.newUndoGroup()
                    sheetView.captureAppend(sheetView.model.score.notes.last!)
                }
                
                sheetView.updatePlaying()
            }
            
            notePlayer?.stop()
            
            document.cursor = document.defaultCursor
        }
    }
    
    func removeNote(with event: DragEvent) {
        let p = document.convertScreenToWorld(event.screenPoint)
        if let sheetView = document.sheetView(at: p) {
            let scoreView = sheetView.scoreView
            let scoreP = scoreView.convertFromWorld(p)
            let nLine = tempLine * Transform(translation: -centerBounds.origin)
            let lasso = Lasso(line: nLine)
            let nis = (0 ..< scoreView.model.notes.count).compactMap { i in
                lasso.intersects(scoreView.pointline(from: scoreView.model.notes[i])) ? i : nil
            }
            if !nis.isEmpty {
                if document.isPlaying(with: event) {
                    document.stopPlaying(with: event)
                }
                
                let pitch = scoreView.pitch(atY: scoreP.y, interval: document.currentPitchInterval)
                let score = scoreView.model
                let interval = document.currentBeatInterval
                let beat = scoreView.beat(atX: scoreP.x, interval: interval)
                let notes: [Note] = nis.map {
                    var note = score.notes[$0]
                    note.pitch -= pitch
                    note.beatRange.start -= beat
                    return note
                }
                
                Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: notes))]
                sheetView.newUndoGroup()
                sheetView.removeNote(at: nis)
            }
        }
    }
    
    var isStopPlaying = false
    
    func drawLine(with event: DragEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        
        if isDrawNote {
            drawNote(with: event)
            return
        } else if event.phase == .began {
            let p = document.convertScreenToWorld(event.screenPoint)
            if let sheetView = document.sheetView(at: p), sheetView.model.score.enabled {
                isDrawNote = true
                noteSheetView = sheetView
                drawNote(with: event)
                return
            }
        }
        
        if isStopPlaying || document.isPlaying(with: event) {
            document.stopPlaying(with: event)
            isStopPlaying = true
            return
        }
        drawLine(with: event, isStraight: false)
    }
    func drawStraightLine(with event: DragEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        
        if isDrawNote {
            drawNote(with: event, isStraight: true)
            return
        } else if event.phase == .began {
            let p = document.convertScreenToWorld(event.screenPoint)
            if let sheetView = document.sheetView(at: p), sheetView.model.score.enabled {
                isDrawNote = true
                noteSheetView = sheetView
                drawNote(with: event, isStraight: true)
                return
            }
        }
        
        if isStopPlaying || document.isPlaying(with: event) {
            document.stopPlaying(with: event)
            isStopPlaying = true
            return
        }
        drawLine(with: event, isStraight: true)
    }
    
    struct DrawLineEvent {
        var p: Point,
            sp: Point, pressure: Double,
            time: Double, isClip: Bool = true,
            isSnap: Bool = true,
            worldToScreenScale: Double, screenToWorldScale: Double,
            phase: Phase
    }
    private var drawLineTimer: (any DispatchSourceTimer)?
    private var  oldDrawLineEventsCount = 0
    private var drawLineEvents = [DrawLineEvent](), drawLineEventsCount = 0, snapLines = [Line]()
    var textView: SheetTextView?
    
    func drawLine(with event: DragEvent, isStraight: Bool) {
        let p = document.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            document.cursor = document.defaultCursor
            
            updateClipBoundsAndIndexRange(at: p)
            let tempLineNode = Node(attitude: Attitude(position: centerOrigin),
                                    path: Path(),
                                    lineWidth: document.sheetLineWidth,
                                    lineType: .color(Line.defaultUUColor.value))
            self.tempLineNode = tempLineNode
            document.rootNode.insert(child: tempLineNode,
                                     at: document.accessoryNodeIndex)
            
            snapLines = document.sheetView(at: centerSHP)?
                .model.picture.lines ?? []
            
            drawLineEvents.append(.init(p: p - centerOrigin,
                                        sp: event.screenPoint, pressure: event.pressure,
                                        time: event.time,
                                        worldToScreenScale: document.worldToScreenScale,
                                        screenToWorldScale: document.screenToWorldScale,
                                        phase: .began))
            
            if isStraight {
                let isStraightNode = Node(fillType: .color(.subSelected))
                self.isStraightNode = isStraightNode
                document.rootNode.insert(child: isStraightNode,
                                         at: document.accessoryNodeIndex + 1)
                firstPoint = document.roundedPoint(from: p - centerOrigin)
                updateStraightNode()
            }
            
            drawLineTimer = DispatchSource.scheduledTimer(withTimeInterval: 1 / 60) { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard let self, !(self.drawLineTimer?.isCancelled ?? true) else { return }
                    guard self.drawLineEvents.count != self.oldDrawLineEventsCount else { return }
                    let events = self.drawLineEvents
                    self.oldDrawLineEventsCount = events.count
                    let snapLines = self.snapLines, clipBounds = self.clipBounds
                    DispatchQueue.global().async { [weak self] in
                        guard let self, !(self.drawLineTimer?.isCancelled ?? true) else { return }
                        let (tempLine, isSnapStraight) = Self.line(from: events,
                                                                   firstSnapLines: snapLines,
                                                                   lastSnapLines: snapLines,
                                                                   clipBounds: clipBounds,
                                                                   isStraight: isStraight)
                        let path = Path(tempLine)
                        let (linePathData, linePathBufferVertexCounts) = path.linePointsDataWith(lineWidth: tempLine.size)
                        DispatchQueue.main.async { [weak self] in
                            guard let self, !(self.drawLineTimer?.isCancelled ?? true) else { return }
                            guard events.count > self.drawLineEventsCount else { return }
                            self.tempLineNode?.update(path: path,
                                                      withLinePathData: linePathData,
                                                      bufferVertexCounts: linePathBufferVertexCounts)
                            self.isSnapStraight = isSnapStraight
                            self.drawLineEventsCount = events.count
                        }
                    }
                }
            }
            break
        case .changed:
            drawLineEvents.append(.init(p: p - centerOrigin,
                                        sp: event.screenPoint, pressure: event.pressure,
                                        time: event.time,
                                        worldToScreenScale: document.worldToScreenScale,
                                        screenToWorldScale: document.screenToWorldScale,
                                        phase: .changed))
        case .ended:
            document.cursor = document.defaultCursor
            
            drawLineTimer?.cancel()
            
            drawLineEvents.append(.init(p: p - centerOrigin,
                                        sp: event.screenPoint, pressure: event.pressure,
                                        time: event.time,
                                        worldToScreenScale: document.worldToScreenScale,
                                        screenToWorldScale: document.screenToWorldScale,
                                        phase: .ended))
            let tempLine = Self.line(from: drawLineEvents,
                                     firstSnapLines: snapLines,
                                     lastSnapLines: snapLines,
                                     clipBounds: clipBounds,
                                     isStraight: isStraight).line
            
            guard let lb = tempLine.bounds else {
                tempLineNode?.removeFromParent()
                tempLineNode = nil
                if isStraight {
                    isStraightNode?.removeFromParent()
                    isStraightNode = nil
                }
                return
            }
            
            if centerBounds.contains(lb),
               let sheetView = document.madeSheetView(at: centerSHP) {
                
                sheetView.newUndoGroup()
                sheetView.append(tempLine)
//                if sheetView.isSound {
//                    document.updateAudio()
//                }
            } else {
                var isWorldNewUndoGroup = true
                for shp in nearestShps {
                    let b = document.sheetFrame(with: shp) - centerOrigin
                    if lb.intersects(b),
                       let sheetView = document.madeSheetView(at: shp, isNewUndoGroup: isWorldNewUndoGroup) {
                        isWorldNewUndoGroup = false
                        let nLine = tempLine * Transform(translation: -b.origin)
                        if let b = sheetView.node.bounds {
                            let nLines = Sheet.clipped([nLine], in: b).filter {
                                if let b = $0.bounds {
                                    return max(b.width, b.height)
                                    > document.worldLineWidth * 4
                                } else {
                                    return true
                                }
                            }
                            if !nLines.isEmpty {
                                sheetView.newUndoGroup()
                                sheetView.append(nLines)
                            }
                        }
                    }
                }
            }
            
            tempLineNode?.removeFromParent()
            tempLineNode = nil
            if isStraight {
                isStraightNode?.removeFromParent()
                isStraightNode = nil
            }
            
            document.updateSelects()
        }
    }
    
    func lassoCut(with event: DragEvent) {
        lasso(with: event, .cut)
    }
    func lassoCopy(with event: DragEvent, distance: Double = 4) {
        lasso(with: event, .copy)
    }
    func lasso(with event: DragEvent, _ type: LassoType) {
        let p = document.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            document.cursor = document.defaultCursor
            
            let isScore = document.sheetView(at: p)?.model.score.enabled ?? false
            
            if !isScore && document.isPlaying(with: event) {
                document.stopPlaying(with: event)
                return
            }
            if isEditingSheet {
                updateClipBoundsAndIndexRange(at: p)
            }
            
            let path = tempLine.path(isClosed: true, isPolygon: false)
            lassoPathNodeLineWidth = 1 * document.screenToWorldScale
            let lineType = Node.LineType.color(type == .copy ? .selected : .removing)
            let fillType = Node.FillType.color(type == .copy ? .subSelected : .subRemoving)
            
            let outlineLassoNode = Node(attitude: Attitude(position: centerOrigin),
                                        path: path,
                                        lineWidth: lassoPathNodeLineWidth,
                                        lineType: lineType)
            let lassoNode = Node(attitude: Attitude(position: centerOrigin),
                                 path: path, fillType: fillType)
            selectingNode.lineType = lineType
            selectingNode.fillType = fillType
            let i = document.accessoryNodeIndex
            document.rootNode.insert(child: lassoNode, at: i)
            document.rootNode.insert(child: outlineLassoNode, at: i + 1)
            document.rootNode.insert(child: selectingNode, at: i + 2)
            self.outlineLassoNode = outlineLassoNode
            self.lassoNode = lassoNode
            
            if !isEditingSheet {
                let rectNode = Node(lineWidth: lassoPathNodeLineWidth,
                                    lineType: lineType, fillType: fillType)
                self.rectNode = rectNode
                document.rootNode.append(child: rectNode)
            }
            
            drawLineEvents.append(.init(p: p - centerOrigin,
                                        sp: event.screenPoint,
                                        pressure: event.pressure,
                                        time: event.time,
                                        isClip: isEditingSheet,
                                        isSnap: false,
                                        worldToScreenScale: document.worldToScreenScale,
                                        screenToWorldScale: document.screenToWorldScale,
                                        phase: .began))
            
            snapLines = document.sheetView(at: centerSHP)?
                .model.picture.lines ?? []
            
            drawLineTimer = DispatchSource.scheduledTimer(withTimeInterval: 1 / 60) { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard let self, !(self.drawLineTimer?.isCancelled ?? true) else { return }
                    guard self.drawLineEvents.count != self.oldDrawLineEventsCount else { return }
                    let events = self.drawLineEvents
                    self.oldDrawLineEventsCount = events.count
                    let snapLines = self.snapLines, clipBounds = self.clipBounds
                    DispatchQueue.global().async { [weak self] in
                        guard let self, !(self.drawLineTimer?.isCancelled ?? true) else { return }
                        let (tempLine, _) = Self.line(from: events,
                                                      firstSnapLines: snapLines,
                                                      lastSnapLines: snapLines,
                                                      clipBounds: clipBounds,
                                                      isStraight: false)
                        let path = tempLine.path(isClosed: true, isPolygon: false)
                        DispatchQueue.main.async { [weak self] in
                            guard let self, !(self.drawLineTimer?.isCancelled ?? true) else { return }
                            guard events.count > self.drawLineEventsCount else { return }
                            
                            self.outlineLassoNode?.path = path
                            self.lassoNode?.path = path
                            
                            if self.isEditingSheet {
                                self.updateSelectingText()
                            } else {
                                self.updateSelectingSheetNodes(with: tempLine)
                            }
                            
                            self.drawLineEventsCount = events.count
                        }
                    }
                }
            }
        case .changed:
            drawLineEvents.append(.init(p: p - centerOrigin,
                                        sp: event.screenPoint,
                                        pressure: event.pressure,
                                        time: event.time,
                                        isClip: isEditingSheet,
                                        isSnap: false,
                                        worldToScreenScale: document.worldToScreenScale,
                                        screenToWorldScale: document.screenToWorldScale,
                                        phase: .changed))
        case .ended:
            document.cursor = document.defaultCursor
            
            drawLineTimer?.cancel()
            
            drawLineEvents.append(.init(p: p - centerOrigin,
                                        sp: event.screenPoint,
                                        pressure: event.pressure,
                                        time: event.time,
                                        isClip: isEditingSheet,
                                        isSnap: false,
                                        worldToScreenScale: document.worldToScreenScale,
                                        screenToWorldScale: document.screenToWorldScale,
                                        phase: .ended))
            
            tempLine = Self.line(from: drawLineEvents,
                                 firstSnapLines: snapLines,
                                 lastSnapLines: snapLines,
                                 clipBounds: clipBounds,
                                 isStraight: false).line
            
            switch type {
            case .cut:
                if isEditingSheet {
                    if let sheetView = document.sheetView(at: p), sheetView.model.score.enabled {
                        removeNote(with: event)
                    } else {
                        lassoCopy(isRemove: true, distance: lassoDistance,
                                  at: document.roundedPoint(from: p))
                    }
                } else {
                    cutSheets(at: p)
                }
            case .copy:
                if isEditingSheet {
                    lassoCopy(isRemove: false, distance: lassoDistance,
                              at: document.roundedPoint(from: p))
                } else {
                    copySheets(at: p)
                }
            case .changeDraft:
                changeDraft()
            case .cutDraft:
                cutDraft(at: p)
            case .makeFaces:
                makeFaces()
            case .cutFaces:
                cutFaces()
            }
            
            lassoNode?.removeFromParent()
            outlineLassoNode?.removeFromParent()
            selectingNode.removeFromParent()
            outlineLassoNode = nil
            rectNode?.removeFromParent()
            
            document.updateSelects()
            document.updateFinding(at: p)
        }
    }
    
    func updateSelectingText() {
        func selectingTextPaths(with nLine: Line,
                                with sheetView: SheetView) -> [Path] {
            guard let nlb = nLine.bounds else { return [] }
            let nPath = nLine.path(isClosed: true, isPolygon: false)
            var paths = [Path]()
            for textView in sheetView.textsView.elementViews {
                if textView.transformedBounds.intersects(nlb) {
                    let ranges = textView.lassoRanges(at: nPath)
                    for range in ranges {
                        for rect in textView.typesetter.rects(for: range) {
                            let r = textView.convertToWorld(rect)
                            paths.append(Path(r))
                        }
                    }
                }
            }
            return paths
        }
        guard let lb = tempLine.bounds else {
            selectingNode.children = []
            return
        }
        if centerBounds.contains(lb),
           let sheetView = document.sheetView(at: centerSHP) {
            
            let nLine = tempLine * Transform(translation: -centerBounds.origin)
            let paths = selectingTextPaths(with: nLine, with: sheetView)
            selectingNode.children = paths.map {
                Node(path: $0,
                     lineWidth: lassoPathNodeLineWidth,
                     lineType: selectingNode.lineType, fillType: selectingNode.fillType)
            }
        } else {
            var paths = [Path]()
            for shp in nearestShps {
                let b = document.sheetFrame(with: shp)
                if lb.intersects(b),
                   let sheetView = document.sheetView(at: shp) {
                    
                    let nLine = tempLine * Transform(translation: -b.origin)
                    paths += selectingTextPaths(with: nLine, with: sheetView)
                }
            }
            
            selectingNode.children = paths.map {
                Node(path: $0,
                     lineWidth: lassoPathNodeLineWidth,
                     lineType: selectingNode.lineType, fillType: selectingNode.fillType)
            }
        }
    }
    
    func lassoCopy(isRemove: Bool,
                   isEnableLine: Bool = true,
                   isEnablePlane: Bool = true,
                   isEnableText: Bool = true,
                   isSplitLine: Bool = true,
                   distance: Double = 0,
                   selections: [Selection] = [], at p: Point) {
        guard let lb = tempLine.bounds else { return }
        if centerBounds.contains(lb),
           let sheetView = document.sheetView(at: centerSHP) {
            
            let nLine = tempLine * Transform(translation: -centerBounds.origin)
            let d = distance  * document.screenToWorldScale
            if let value = sheetView.lassoErase(with: Lasso(line: nLine),
                                                distance: d,
                                                isSplitLine: isSplitLine,
                                                  isRemove: isRemove,
                                                  isEnableLine: isEnableLine,
                                                  isEnablePlane: isEnablePlane,
                                                  isEnableText: isEnableText,
                                                  selections: selections) {
                let np = sheetView.convertFromWorld(p)
                let t = Transform(translation: -np)
                var nValue = value * t
                nValue.origin = np
                if let s = nValue.string {
                    Pasteboard.shared.copiedObjects
                        = [.sheetValue(nValue), .string(s)]
                } else {
                    Pasteboard.shared.copiedObjects
                        = [.sheetValue(nValue)]
                }
            }
        } else {
            var value = SheetValue()
            for shp in nearestShps {
                let b = document.sheetFrame(with: shp) - centerOrigin
                if lb.intersects(b),
                   let sheetView = document.sheetView(at: shp) {
                    
                    let nLine = tempLine
                        * Transform(translation: -b.origin)
                    if let aValue
                        = sheetView.lassoErase(with: Lasso(line: nLine),
                                               isSplitLine: isSplitLine,
                                               isRemove: isRemove,
                                               isEnableLine: isEnableLine,
                                               isEnablePlane: isEnablePlane,
                                               isEnableText: isEnableText,
                                               selections: selections) {
                        let t = Transform(translation: -sheetView.convertFromWorld(p))
                        value += aValue * t
                    }
                }
            }
            
            if !value.isEmpty {
                if let s = value.string {
                    Pasteboard.shared.copiedObjects
                        = [.sheetValue(value), .string(s)]
                } else {
                    Pasteboard.shared.copiedObjects
                        = [.sheetValue(value)]
                }
            }
        }
    }
    func sheetValue(isRemove: Bool,
                    isEnableLine: Bool = true,
                    isEnablePlane: Bool = true,
                    isEnableText: Bool = true,
                    isSplitLine: Bool = true,
                    distance: Double = 2,
                    selections: [Selection] = [], at p: Point) -> SheetValue {
        guard let lb = tempLine.bounds else { return SheetValue() }
        if centerBounds.contains(lb),
           let sheetView = document.sheetView(at: centerSHP) {
            
            let nLine = tempLine * Transform(translation: -centerBounds.origin)
            let d = distance * document.screenToWorldScale
            if let value = sheetView.lassoErase(with: Lasso(line: nLine),
                                                distance: d,
                                                  isSplitLine: isSplitLine,
                                                  isRemove: isRemove,
                                                  isEnableLine: isEnableLine,
                                                  isEnablePlane: isEnablePlane,
                                                  isEnableText: isEnableText,
                                                  selections: selections) {
                let t = Transform(translation: -sheetView.convertFromWorld(p))
                let nValue = value * t
                return nValue
            }
        } else {
            var value = SheetValue()
            for shp in nearestShps {
                let b = document.sheetFrame(with: shp) - centerOrigin
                if lb.intersects(b),
                   let sheetView = document.sheetView(at: shp) {
                    
                    let nLine = tempLine
                        * Transform(translation: -b.origin)
                    if let aValue
                        = sheetView.lassoErase(with: Lasso(line: nLine),
                                               isSplitLine: isSplitLine,
                                               isRemove: isRemove,
                                               isEnableLine: isEnableLine,
                                               isEnablePlane: isEnablePlane,
                                               isEnableText: isEnableText,
                                               selections: selections) {
                        let t = Transform(translation: -sheetView.convertFromWorld(p))
                        value += aValue * t
                    }
                }
            }
            return value
        }
        return SheetValue()
    }
    
    var rectNode: Node?
    
    struct Value {
        var shp: Sheetpos, frame: Rect
    }
    func values(with line: Line) -> [Value] {
        guard let rect = line.bounds else { return [] }
        let minXMinYSHP = document.sheetPosition(at: rect.minXMinYPoint)
        let maxXMinYSHP = document.sheetPosition(at: rect.maxXMinYPoint)
        let minXMaxYSHP = document.sheetPosition(at: rect.minXMaxYPoint)
        let lx = minXMinYSHP.x, rx = maxXMinYSHP.x
        let by = minXMinYSHP.y, ty = minXMaxYSHP.y
        
        var vs = [Value]()
        for shp in document.world.sheetIDs.keys {
            if shp.x >= lx && shp.x <= rx {
                if shp.y >= by && shp.y <= ty {
                    let frame = document.sheetFrame(with: shp)
                    if line.lassoIntersects(frame) {
                        vs.append(Value(shp: shp, frame: frame))
                    }
                }
            }
        }
        return vs
    }
    func updateSelectingSheetNodes(with line: Line) {
        guard let rectNode = rectNode else { return }
        rectNode.children = values(with: line).map {
            Node(path: Path($0.frame),
                 lineWidth: rectNode.lineWidth, lineType: rectNode.lineType,
                 fillType: rectNode.fillType)
        }
    }
    
    func updateWithCopySheet(at dp: Point, from values: [Value]) {
        var csv = CopiedSheetsValue()
        for value in values {
            if let sid = document.sheetID(at: value.shp) {
                csv.sheetIDs[value.shp] = sid
            }
        }
        csv.deltaPoint = dp
        Pasteboard.shared.copiedObjects = [.copiedSheetsValue(csv)]
    }
    func cutSheets(at p: Point) {
        let values = self.values(with: tempLine)
        updateWithCopySheet(at: p, from: values)
        if !values.isEmpty {
            document.newUndoGroup()
            document.removeSheets(at: values.map { $0.shp })
        }
    }
    func copySheets(at p: Point) {
        updateWithCopySheet(at: p, from: values(with: tempLine))
    }
    
    func changeDraft() {
        guard let lb = tempLine.bounds else { return }
        if centerBounds.contains(lb),
           let sheetView = document.madeSheetView(at: centerSHP) {
            
            let nLine = tempLine * Transform(translation: -centerBounds.origin)
            if let value = sheetView.lassoErase(with: Lasso(line: nLine),
                                                  isRemove: true,
                                                  isEnableText: false) {
                let li = sheetView.model.draftPicture.lines.count
                sheetView.insertDraft(value.lines.enumerated().map {
                    IndexValue(value: $0.element, index: li + $0.offset)
                })
                let pi = sheetView.model.draftPicture.planes.count
                sheetView.insertDraft(value.planes.enumerated().map {
                    IndexValue(value: $0.element, index: pi + $0.offset)
                })
            }
        } else {
            for shp in nearestShps {
                let b = document.sheetFrame(with: shp)
                if b.contains(lb),
                   let sheetView = document.sheetView(at: shp),
                   !sheetView.model.picture.isEmpty {
                    
                    sheetView.newUndoGroup()
                    sheetView.changeToDraft()
                } else if lb.intersects(b),
                          let sheetView = document.sheetView(at: shp) {
                    let nLine = tempLine * Transform(translation: -b.origin)
                    
                    if let value = sheetView.lassoErase(with: Lasso(line: nLine),
                                                   isRemove: true,
                                                   isEnableText: false) {
                        let li = sheetView.model.draftPicture.lines.count
                        sheetView.insertDraft(value.lines.enumerated().map {
                            IndexValue(value: $0.element, index: li + $0.offset)
                        })
                        let pi = sheetView.model.draftPicture.planes.count
                        sheetView.insertDraft(value.planes.enumerated().map {
                            IndexValue(value: $0.element, index: pi + $0.offset)
                        })
                    }
                }
            }
        }
    }
    func cutDraft(at p: Point) {
        guard let lb = tempLine.bounds else { return }
        if centerBounds.contains(lb),
           let sheetView = document.madeSheetView(at: centerSHP) {
            
            let nLine = tempLine * Transform(translation: -centerBounds.origin)
            if let value = sheetView.lassoErase(with: Lasso(line: nLine),
                                                  isRemove: true,
                                                  isEnableText: false,
                                                  isDraft: true) {
                let t = Transform(translation: -sheetView.convertFromWorld(p))
                Pasteboard.shared.copiedObjects = [.sheetValue(value * t)]
            }
        } else {
            var value = SheetValue()
            for shp in nearestShps {
                let b = document.sheetFrame(with: shp)
                if lb.intersects(b),
                   let sheetView = document.sheetView(at: shp) {
                    let nLine = tempLine * Transform(translation: -b.origin)
                    if let aValue = sheetView.lassoErase(with: Lasso(line: nLine),
                                                    isRemove: true,
                                                    isEnableText: false,
                                                    isDraft: true) {
                        let t = Transform(translation: -sheetView.convertFromWorld(p))
                        value += aValue * t
                    }
                }
            }
            if !value.isEmpty {
                Pasteboard.shared.copiedObjects = [.sheetValue(value)]
            }
        }
    }
    
    func makeFaces() {
        guard let lb = tempLine.bounds else { return }
        if centerBounds.contains(lb),
           let sheetView = document.madeSheetView(at: centerSHP) {
            
            let nLine = tempLine * Transform(translation: -centerBounds.origin)
            let path = Path(nLine)
            sheetView.makeFaces(with: path, isSelection: true)
        } else {
            for shp in nearestShps {
                let b = document.sheetFrame(with: shp)
                if lb.intersects(b),
                   let sheetView = document.sheetView(at: shp) {
                    
                    let nLine = tempLine * Transform(translation: -b.origin)
                    
                    let path = Path(nLine)
                    sheetView.makeFaces(with: path, isSelection: true)
                }
            }
        }
    }
    func cutFaces() {
        guard let lb = tempLine.bounds else { return }
        if centerBounds.contains(lb),
           let sheetView = document.madeSheetView(at: centerSHP) {
            
            let nLine = tempLine * Transform(translation: -centerBounds.origin)
            let path = Path(nLine)
            sheetView.cutFaces(with: path)
        }
    }
}
