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

struct Picture {
    var lines = [Line](), planes = [Plane]()
}
extension Picture: Protobuf {
    init(_ pb: PBPicture) throws {
        lines = pb.lines.compactMap { try? .init($0) }
        planes = pb.planes.compactMap { try? .init($0) }
    }
    var pb: PBPicture {
        .with {
            $0.lines = lines.map { $0.pb }
            $0.planes = planes.map { $0.pb }
        }
    }
}
extension Picture: Hashable, Codable {}
extension Picture: AppliableTransform {
    static func * (lhs: Self, rhs: Transform) -> Self {
        .init(lines: lhs.lines.map { $0 * rhs },
              planes: lhs.planes.map { $0 * rhs })
    }
}
extension Picture {
    var isEmpty: Bool {
        lines.isEmpty && planes.isEmpty
    }
    static func + (lhs: Self, rhs: Self) -> Self {
        Self(lines: lhs.lines + rhs.lines,
             planes: lhs.planes + rhs.planes)
    }
    static func += (lhs: inout Self, rhs: Self) {
        lhs.lines += rhs.lines
        lhs.planes += rhs.planes
    }
}
extension Picture {
    static let defaultRenderingScale = 16.0
    
    enum AutoFillResult {
        case planes(_ planes: [Plane])
        case planeValue(_ planeValue: PlaneValue)
        case none
    }
    
    func autoFill(fromOther otherPlanes: [Plane]? = nil,
                  inFrame bounds: Rect,
                  clipingPath: Path?,
                  renderingScale: Double = Self.defaultRenderingScale,
                  borders: [Border] = [],
                  isSelection: Bool) -> AutoFillResult {
        let nPolys = makePolygons(inFrame: bounds, clipingPath: clipingPath,
                                  renderingScale: renderingScale,
                                  isSelection: isSelection)
        return Self.autoFill(fromOther: otherPlanes, from: nPolys,
                             from: planes,
                             inFrame: bounds,
                             clipingPath: clipingPath, isSelection: isSelection)
    }
    func makePolygons(inFrame bounds: Rect,
                      clipingPath: Path?,
                      renderingScale: Double = Self.defaultRenderingScale,
                      borders: [Border] = [],
                      isSelection: Bool) -> [Topolygon] {
        let bounds = (isSelection ? bounds : (clipingPath?.bounds ?? bounds)).integral
        return Self.topolygons(with: bounds, from: lines,
                               renderingScale: renderingScale, borders: borders)
    }
    static func autoFill(fromOther otherPlanes: [Plane]? = nil,
                         from nPolys: [Topolygon],
                         from planes: [Plane],
                         inFrame bounds: Rect,
                         clipingPath: Path?,
                         renderingScale: Double = Self.defaultRenderingScale,
                         borders: [Border] = [],
                         isSelection: Bool) -> AutoFillResult {
        if nPolys.isEmpty {
            return .none
        }
        var nPlanes: [(plane: Plane, area: Double)] = nPolys.map {
            let area = $0.area
            let color = (area < 1 ?
                            Color.randomLightness(45 ... 55) :
                            Color.randomLightness(60 ... 85))
            return (Plane(topolygon: $0, uuColor: UU(color)), area)
        }
        nPlanes.sort { $0.area > $1.area }
        if !nPlanes.isEmpty && nPlanes[0].plane.topolygon == bounds {
            nPlanes.removeFirst()
        }
        
        if otherPlanes?.isEmpty ?? planes.isEmpty {
            if let path = clipingPath?.inset(by: 0.01) ?? clipingPath {
                nPlanes = nPlanes.filter { path.intersects($0.plane.path) }
                return nPlanes.isEmpty ? .none : .planes(nPlanes.map { $0.plane })
            } else {
                return nPlanes.isEmpty ? .none : .planes(nPlanes.map { $0.plane })
            }
        }
        
        var planeIndexesDic = [Topolygon: Int]()
        planes.enumerated().forEach {
            planeIndexesDic[$0.element.topolygon] = $0.offset
        }
        
        var indexValues = [IndexValue<Int>]()
        var isIndexesArray = Array(repeating: false, count: planes.count)
        
        if let path = clipingPath?.inset(by: 0.01) ?? clipingPath {
            nPlanes = planes.lazy
                .filter { !path.intersects($0.path) }
                .map { ($0, $0.topolygon.area) }
                + nPlanes.filter { path.intersects($0.plane.path) }
            nPlanes.sort { $0.area > $1.area }
        }
        
        var newPlanes: [(plane: Plane, area: Double)]
        newPlanes = nPlanes.enumerated().compactMap {
            if let i = planeIndexesDic[$0.element.plane.topolygon] {
                indexValues.append(IndexValue(value: i, index: $0.offset))
                isIndexesArray[i] = true
                return nil
            } else {
                return $0.element
            }
        }
        if indexValues.count == nPlanes.count {
            return .none
        }
        let removePlaneIndexes = isIndexesArray.enumerated().compactMap {
            $0.element ? nil : $0.offset
        }
        
        struct V {
            var plane: Plane,
                oxs: SIMD16<Double>, oys: SIMD16<Double>,
                pSet: Set<Point>,
                centroid: Point, area: Double
        }
        if !newPlanes.isEmpty {
            let oldPlanes = (otherPlanes ?? []) + (removePlaneIndexes.map { planes[$0] })
            let oldVs: [V] = oldPlanes.compactMap { oldPlane in
                let tripolygon = oldPlane.topolygon.tripolygon
                let area = tripolygon.area
                if let centroid = tripolygon.centroid, area > 0 {
                    let p16s = oldPlane.topolygon.polygon
                        .sortedTopCounterClockwise().edgePoints(count: 16)
                    return V(plane: oldPlane,
                             oxs: SIMD16(p16s.map { $0.x }),
                             oys: SIMD16(p16s.map { $0.y }),
                             pSet: Set(oldPlane.topolygon.allPoints),
                             centroid: centroid,
                             area: area)
                } else {
                    return nil
                }
            }
            if !oldVs.isEmpty {
                var vs = [(oi: Int, ni: Int, s: Double)]()
                newPlanes.enumerated().forEach { (ni, newPlaneValue) in
                    guard let newCentroid
                            = newPlaneValue.plane.topolygon.tripolygon.centroid else { return }
                    let p16s = newPlaneValue.plane.topolygon.polygon
                        .sortedTopCounterClockwise().edgePoints(count: 16)
                    let nxs = SIMD16(p16s.map { $0.x })
                    let nys = SIMD16(p16s.map { $0.y })
                    let newArea = newPlaneValue.area
                    guard newArea > 0 else { return }

                    let nps = newPlaneValue.plane.topolygon.allPoints

                    oldVs.enumerated().forEach { (oi, oldV) in
                        let ds = oldV.centroid.distanceSquared(newCentroid)
                        if ds < 2500 {
                            let x1 = (oldV.area.absRatio(newArea) - 1) * 100
                            if x1 < 10000 {
                                let oxs = oldV.oxs, oys = oldV.oys
                                let dxs = nxs - oxs
                                let dys = nys - oys

                                let d = (dxs * dxs + dys * dys).squareRoot().sum()
                                let x0 = ds
                                let x2 = d
                                let x3 = nps.contains(where: { oldV.pSet.contains($0) }) ? 0.0 : 100.0
                                let s = x0 + x1 + x2 + x3
                                vs.append((oi, ni, s))
                            }
                        }
                    }
                }
                vs.sort(by: { $0.s < $1.s })
                
                var isOFilleds = Array(repeating: false, count: oldVs.count)
                var isNFilleds = Array(repeating: false, count: newPlanes.count)
                for v in vs {
                    if !isOFilleds[v.oi] && !isNFilleds[v.ni] {
                        newPlanes[v.ni].plane.uuColor = oldVs[v.oi].plane.uuColor
                        isOFilleds[v.oi] = true
                        isNFilleds[v.ni] = true
                    }
                }
            }
        }
        
        return .planeValue(PlaneValue(planes: newPlanes.map { $0.plane },
                                      moveIndexValues: indexValues))
    }
    
    private static func topolygons(with bounds: Rect,
                                   from lines: [Line],
                                   connectableScale cd: Double = 3.0,
                                   straightConnectableScale scd: Double = 6.0,
                                   renderingScale: Double,
                                   borders: [Border]) -> [Topolygon] {
        guard !lines.isEmpty else { return [] }
        
        let size = bounds.size * renderingScale
        
        guard let bitmap = Bitmap<UInt16>(width: Int(size.width), height: Int(size.height),
                                          colorSpace: .grayscale) else { return [] }
        bitmap.set(isAntialias: false)
        let transform = Transform(translation: -bounds.origin)
            * Transform(scaleX: size.width / bounds.width, y: size.height / bounds.height)
        bitmap.set(transform)
        bitmap.set(fillColor: .init(red: 1.0, green: 1, blue: 1))
        bitmap.set(lineCap: .round)
        bitmap.set(lineWidth: 2 / renderingScale)
        bitmap.set(lineColor: .init(red: 1.0, green: 1, blue: 1))
        
        struct EdgeLine: Rectable {
            var edges: [Edge]
            var edgeSearchTree: RectSearchTree<Edge>
            var bounds: Rect
            var i: Int?
            
            init(edges: [Edge], bounds: Rect, i: Int? = nil) {
                self.edges = edges
                self.edgeSearchTree = .init(edges)!
                self.bounds = bounds
                self.i = i
            }
        }
        let edgeLines: [EdgeLine] = lines.enumerated().compactMap { (i, line) in
            let lineWidth = max(2 / renderingScale, line.size - 2 / renderingScale)
            let path = Path(line)
            guard let pathBounds = path.bounds else { return nil }
            let ops = path.outlinePointsWith(lineWidth: lineWidth)
            for ps in ops {
                bitmap.fill(ps)
            }
            let edges = Edge.edges(from: ops.flatMap { $0 })
            return edges.isEmpty ? nil : .init(edges: edges, bounds: pathBounds, i: i)
        } + borders.compactMap {
            let lineWidth = 2 / renderingScale
            let borderBounds: Rect
            switch $0.orientation {
            case .horizontal:
                if $0.location == bounds.minY || $0.location == bounds.maxY {
                    return nil
                }
                borderBounds = Rect(x: bounds.minX, y: $0.location - lineWidth / 2,
                                    width: bounds.width, height: lineWidth)
            case .vertical:
                if $0.location == bounds.minX || $0.location == bounds.maxX {
                    return nil
                }
                borderBounds = Rect(x: $0.location - lineWidth / 2, y: bounds.minY,
                                    width: lineWidth, height: bounds.height)
            }
            bitmap.fill(borderBounds)
            let edge = $0.edge(with: bounds)
            return .init(edges: [edge], bounds: edge.bounds)
        } + bounds.edges.map {
            .init(edges: [$0], bounds: $0.bounds)
        }
        
        struct LinePoint: Rectable {
            var p: Point, d: Double, vector: Point, i: Int, fol: FirstOrLast, bounds: Rect
        }
        
        let edgeLineSearchTree = RectSearchTree(edgeLines)
        
        var lps = [LinePoint](capacity: lines.count * 2)
        for (li, line) in lines.enumerated() {
            let fp = line.firstPoint, lp = line.lastPoint, d = line.size / 2
            lps.append(.init(p: fp, d: d, vector: -line.firstVector,
                             i: li, fol: .first, bounds: .init(fp, distance: scd * d)))
            lps.append(.init(p: lp, d: d, vector: line.lastVector,
                             i: li, fol: .last, bounds: .init(lp, distance: scd * d)))
        }
        let lpSearchTree = RectSearchTree(lps)!
        
        for lp0 in lps {
            let minDSq = (lp0.d / 2).squared
            let maxD = cd * lp0.d
            let maxDSq = maxD * maxD
            
            lpSearchTree.intersects(from: lp0.bounds) { lp1i in
                let lp1 = lps[lp1i]
                guard lp0.p != lp1.p else { return }
                let dSq = lp0.p.distanceSquared(lp1.p)
                let maxD0 = maxD + cd * lp1.d
                guard dSq >= maxD0 * maxD0 else { return }
                let maxD1 = scd * (lp0.d + lp1.d)
                let v0 = lp0.vector, v1 = lp1.vector, v2 = lp1.p - lp0.p
                let angle = abs(Point.differenceAngle(v0, v2)) + abs(Point.differenceAngle(v2, -v1))
                guard angle < .pi / 8 else { return }
                let maxND = angle.clipped(min: .pi / 8, max: 0, newMin: maxD0, newMax: maxD1)
                if dSq < maxND * maxND {
                    bitmap.stroke(Edge(lp0.p, lp1.p))
                }
            }
            
            let pBounds = Rect(lp0.p, distance: maxD)
            edgeLineSearchTree?.intersects(from: pBounds) { eli in
                let edgeLine = edgeLines[eli]
                if edgeLine.i != lp0.i {
                    var vMinDSq = Double.infinity, vMinNP: Point?
                    edgeLine.edgeSearchTree.intersects(from: pBounds) {
                        let edge = edgeLine.edges[$0]
                        let np = edge.nearestPoint(from: lp0.p)
                        let dSq = np.distanceSquared(lp0.p)
                        if dSq < vMinDSq && dSq > minDSq && dSq < maxDSq {
                            vMinDSq = dSq
                            vMinNP = np
                        }
                    }
                    if let vMinNP {
                        bitmap.stroke(Edge(lp0.p, vMinNP).extendedLast(withDistance: 2 / renderingScale))
                    }
                }
            }
        }
        
        let mPolys = Picture.makePlanesByFillAll(from: bitmap, renderingScale: renderingScale)
        
        let position = Point(x: -bounds.centerPoint.x * renderingScale + size.width / 2,
                             y: -bounds.centerPoint.y * renderingScale + size.height / 2)
        let invertedTransform = Attitude(position: position,
                                         scale: Size(square: renderingScale)).transform.inverted()
        return mPolys.map { $0 * invertedTransform }
    }
    private static func makePlanesByFillAll(from bitmap: Bitmap<UInt16>,
                                            renderingScale: Double) -> [Topolygon] {
        let w = bitmap.width, h = bitmap.height
        let lineValue = UInt16.max
        
        func containsAt(_ x: Int, _ y: Int, _ fillValue: UInt16) -> Bool {
            !(x >= 0 && x < w && y >= 0 && y < h) || bitmap[x, y] != fillValue
        }
        var fillValue: UInt16 = 1
        for y in 0 ..< h {
            for x in 0 ..< w {
                if bitmap[x, y] == 0 {
                    bitmap.floodFill(fillValue, atX: x, y: y)
                    
                    if containsAt(x - 1, y, fillValue) && containsAt(x + 1, y, fillValue)
                        && containsAt(x, y - 1, fillValue) && containsAt(x, y + 1, fillValue) {
                        
                        bitmap[x, y] = lineValue
                    } else {
                        fillValue = fillValue < .max - 1 ? fillValue + 1 : 1
                    }
                }
            }
        }
        
        func aroundFilledValue(x: Int, y: Int) -> UInt16? {
            if x > 0 && bitmap[x - 1, y] != lineValue {
                return bitmap[x - 1, y]
            }
            if x + 1 < w && bitmap[x + 1, y] != lineValue {
                return bitmap[x + 1, y]
            }
            if y > 0 && bitmap[x, y - 1] != lineValue {
                return bitmap[x, y - 1]
            }
            if y + 1 < h && bitmap[x, y + 1] != lineValue {
                return bitmap[x, y + 1]
            }
            return nil
        }
        
        var nes = [IntPoint](capacity: w * h), fvs = [(IntPoint, UInt16)](capacity: w * h)
        for y in 0 ..< h {
            for x in 0 ..< w {
                if bitmap[x, y] == lineValue {
                    if let filledValue = aroundFilledValue(x: x, y: y) {
                        fvs.append((.init(x, y), filledValue))
                    } else {
                        nes.append(.init(x, y))
                    }
                }
            }
        }
        var nnes = [IntPoint](capacity: nes.count)
        repeat {
            for fv in fvs {
                bitmap[fv.0.x, fv.0.y] = fv.1
            }
            fvs.removeAll(keepingCapacity: true)
            for ne in nes {
                if let filledValue = aroundFilledValue(x: ne.x, y: ne.y) {
                    fvs.append((ne, filledValue))
                } else {
                    nnes.append(ne)
                }
            }
            nes = nnes
            nnes.removeAll(keepingCapacity: true)
        } while !nes.isEmpty
        
        struct IntTopolygon {
            var points: [IntPoint]
            var holePoints: [[IntPoint]]
        }
        var iPolys = [IntTopolygon](), iis = [UInt16: Int](minimumCapacity: Int(fillValue) - 2)
        var aroundValues = [UInt16: Set<IntPoint>](), oldV: UInt16 = 0
        for y in 0 ..< h {
            for x in 0 ..< w {
                var v = bitmap[x, y]
                guard x == 0 || v != oldV else { continue }
                if let points = aroundValues[v] {
                    if !points.contains(IntPoint(x, y)) {
                        let nPoints = bitmap.aroundPoints(with: v, atX: x, y: y)
                        if IntPoint.orientation(from: nPoints) == .counterClockwise {
                            aroundValues[v]?.formUnion(Set(nPoints))
                            if let i = iis[v] {
                                iPolys[i].holePoints.append(nPoints)
                            }
                        } else {
                            fillValue = fillValue < .max - 1 ? fillValue + 1 : 1
                            v = fillValue
                            bitmap.floodFill(v, atX: x, y: y)
                            
                            aroundValues[v] = Set(nPoints)
                            iis[v] = iPolys.count
                            iPolys.append(.init(points: nPoints, holePoints: []))
                        }
                    }
                } else {
                    let nPoints = bitmap.aroundPoints(with: v, atX: x, y: y)
                    aroundValues[v] = Set(nPoints)
                    iis[v] = iPolys.count
                    iPolys.append(.init(points: nPoints, holePoints: []))
                }
                oldV = v
            }
        }
        
        var pDic = [[IntPoint]: [Point]]()
        
        func smoothPoints(with points: [IntPoint]) -> [Point] {
            func isVertex(at p: IntPoint) -> Bool {
                let x = p.x, y = p.y
                var vSet = Set<UInt16>(minimumCapacity: 4), outCount = 0
                func insert(_ x: Int, _ y: Int) {
                    if x >= 0 && x < w && y >= 0 && y < h {
                        vSet.insert(bitmap[x, y])
                    } else {
                        outCount += 1
                    }
                }
                insert(x - 1, y - 1)
                insert(x, y - 1)
                insert(x - 1, y)
                insert(x, y)
                return if outCount == 0 {
                    vSet.count >= 3
                } else if outCount == 2 {
                    vSet.count >= 2
                } else {
                    true
                }
            }
            func minVertexIndex() -> Int? {
                for (i, p) in points.enumerated() {
                    if isVertex(at: p) {
                        return i
                    }
                }
                return nil
            }
            
            func appendEdgeWith(start si: Int, end ei: Int,
                                from mPoints: [IntPoint],
                                in nPoints: inout [Point],
                                isReverse: Bool,
                                maxD: Double = 1 - .ulpOfOne) {
                let maxDSq = maxD * maxD
                
                func append<T: RandomAccessCollection>(_ rPoints: T, in lPoints: inout [Point])
                where T.Index == Int, T.Element == IntPoint {
                    var rrPoints = [Point]()
                    rrPoints.reserveCapacity(rPoints.endIndex - rPoints.startIndex)
                    rrPoints.append(.init(rPoints[rPoints.startIndex]))
                    for i in (rPoints.startIndex + 1) ..< rPoints.endIndex {
                        rrPoints.append(.init(rPoints[i - 1]).mid(.init(rPoints[i])))
                    }
                    rrPoints.append(.init(rPoints[rPoints.endIndex - 1]))
                    
                    var preP = rrPoints[1], sp = rrPoints[0], oldJ = 1
                    for j in 2 ..< rrPoints.count {
                        let ep = rrPoints[j]
                        for k in oldJ ..< j {
                            let dSq = LinearLine(sp, ep).distanceSquared(from: rrPoints[k])
                            if dSq >= maxDSq {
                                lPoints.append(Point(preP.x, Double(h) - preP.y))
                                sp = preP
                                oldJ = j
                                break
                            }
                        }
                        preP = ep
                    }
                }
                
                if ei - si == 1 {
                    nPoints.append(Point(mPoints[si].x, h - mPoints[si].y))
                } else if let ps = pDic[Array(mPoints[si ... ei])] {
                    nPoints += ps
                } else {
                    var lPoints = [Point]()
                    lPoints.reserveCapacity(ei - si)
                    if isReverse {
                        append(mPoints[si ... ei].reversed(), in: &lPoints)
                        lPoints.reverse()
                        nPoints.append(Point(mPoints[si].x, h - mPoints[si].y))
                        nPoints += lPoints
                        lPoints.append(Point(mPoints[ei].x, h - mPoints[ei].y))
                        lPoints.reverse()
                        pDic[Array(mPoints[si ... ei].reversed())] = lPoints
                    } else {
                        append(mPoints[si ... ei], in: &lPoints)
                        nPoints.append(Point(mPoints[si].x, h - mPoints[si].y))
                        nPoints += lPoints
                        lPoints.append(Point(mPoints[ei].x, h - mPoints[ei].y))
                        lPoints.reverse()
                        pDic[Array(mPoints[si ... ei].reversed())] = lPoints
                    }
                }
            }
            
            if let firstI = minVertexIndex() {
                var newPoints = [Point](capacity: points.count)
                let fPoints = if firstI == 0 {
                    points + [points[0]]
                } else {
                    Array(points[firstI...] + points[...firstI])
                }
                var si = 0
                for ei in 1 ..< fPoints.count {
                    let ep = fPoints[ei]
                    if !isVertex(at: ep) { continue }
                    let sp = fPoints[si]
                    let isReverse = ep == sp ?
                        IntPoint.orientation(from: fPoints[si ... ei]) != .counterClockwise :
                        (ep.x == sp.x ? ep.y < sp.y : ep.x < sp.x)
                    appendEdgeWith(start: si, end: ei,
                                   from: fPoints, in: &newPoints,
                                   isReverse: isReverse)
                    si = ei
                }
                return newPoints
            } else {
                func leftDownSort(_ ps: [IntPoint]) -> [IntPoint] {
                    guard !ps.isEmpty else { return [] }
                    let y = ps.min { $0.y < $1.y }!.y
                    let i = ps.enumerated().filter { $0.element.y == y }
                        .min { $0.element.x < $1.element.x }!.offset
                    return if i == 0 {
                        ps
                    } else {
                        Array(ps[i...] + ps[..<i])
                    }
                }
                var points = leftDownSort(points)
                points.append(points[0])
                var newPoints = [Point](capacity: points.count)
                let isReverse = IntPoint.orientation(from: points) != .counterClockwise
                appendEdgeWith(start: 0, end: points.count - 1,
                               from: points, in: &newPoints,
                               isReverse: isReverse)
                return newPoints
            }
        }
        
        return iPolys.compactMap {
            let nps = smoothPoints(with: $0.points)
            guard !nps.isEmpty else { return nil }
            let holePolygons: [Polygon] = $0.holePoints.compactMap {
                let nps = smoothPoints(with: $0)
                return if !nps.isEmpty {
                    .init(points: nps)
                } else {
                    nil
                }
            }
            return .init(polygon: .init(points: nps), holePolygons: holePolygons)
        }
    }
}

private struct BitmapScan {
    var minX, maxX, y: Int
    var isTop: Bool
}
extension Bitmap {
    func floodFill(_ value: Value, atX fx: Int, y fy: Int) {
        let inValue = self[fx, fy]
        
        var stack = Stack<BitmapScan>()
        stack.push(.init(minX: fx, maxX: fx, y: fy, isTop: false))
        
        func isFill(_ x: Int, _ y: Int) -> Bool {
            self[x, y] == inValue
        }
        func pushScans(minX: Int, maxX: Int, y: Int, isTop: Bool) {
            var mx = minX
            while mx < maxX {
                while mx < maxX && !isFill(mx, y) {
                    mx += 1
                }
                let nMinX = mx
                while mx < maxX && isFill(mx, y) {
                    self[mx, y] = value
                    mx += 1
                }
                stack.push(.init(minX: nMinX, maxX: mx, y: y, isTop: isTop))
            }
        }
        
        while let scan = stack.pop() {
            let y = scan.y
            var minX = scan.minX - 1
            while minX >= 0 && isFill(minX, y) {
                self[minX, y] = value
                minX -= 1
            }
            minX += 1
            var maxX = scan.maxX
            while maxX < width && isFill(maxX, y) {
                self[maxX, y] = value
                maxX += 1
            }
            let by = y - 1, ty = y + 1
            if scan.isTop {
                if by >= 0 {
                    pushScans(minX: minX, maxX: scan.minX, y: by, isTop: false)
                    pushScans(minX: scan.maxX, maxX: maxX, y: by, isTop: false)
                }
                if ty < height {
                    pushScans(minX: minX, maxX: maxX, y: ty, isTop: true)
                }
            } else {
                if ty < height {
                    pushScans(minX: minX, maxX: scan.minX, y: ty, isTop: true)
                    pushScans(minX: scan.maxX, maxX: maxX, y: ty, isTop: true)
                }
                if by >= 0 {
                    pushScans(minX: minX, maxX: maxX, y: by, isTop: false)
                }
            }
        }
    }
}

private enum AroundDirection {
    case left, top, right, bottom
    
    mutating func next() {
        self = switch self {
        case .left: .top
        case .top: .right
        case .right: .bottom
        case .bottom: .left
        }
    }
    mutating func inverted() {
        self = switch self {
        case .left: .right
        case .top: .bottom
        case .right: .left
        case .bottom: .top
        }
    }
    func movedPoint(from p: IntPoint) -> IntPoint {
        switch self {
        case .left: IntPoint(p.x - 1, p.y)
        case .top: IntPoint(p.x, p.y + 1)
        case .right: IntPoint(p.x + 1, p.y)
        case .bottom: IntPoint(p.x, p.y - 1)
        }
    }
    func aroundPoint(from p: IntPoint) -> IntPoint {
        switch self {
        case .left: p
        case .top: IntPoint(p.x, p.y + 1)
        case .right: IntPoint(p.x + 1, p.y + 1)
        case .bottom: IntPoint(p.x + 1, p.y)
        }
    }
}
extension Bitmap {
    func aroundPoints(with value: Value, atX fx: Int, y fy: Int) -> [IntPoint] {
        func isAround(_ p: IntPoint) -> Bool {
            p.x >= 0 && p.x < width && p.y >= 0 && p.y < height && self[p.x, p.y] == value
        }
        
        var points = [IntPoint]()
        let fp = IntPoint(fx, fy)
        points.append(fp)
        var p = fp, direction = AroundDirection.left, isEnd = false
        while true {
            for _ in 0 ..< 4 {
                direction.next()
                let np = direction.movedPoint(from: p)
                if isAround(np) {
                    p = np
                    direction.inverted()
                    break
                } else {
                    let mp = direction.aroundPoint(from: p)
                    if mp == fp {
                        isEnd = true
                        break
                    }
                    points.append(mp)
                }
            }
            if isEnd { break }
        }
        return points
    }
}
