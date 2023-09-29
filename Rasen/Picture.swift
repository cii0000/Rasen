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

struct Picture {
    var lines = [Line](), planes = [Plane]()
}
extension Picture: Protobuf {
    init(_ pb: PBPicture) throws {
        lines = pb.lines.compactMap { try? Line($0) }
        planes = pb.planes.compactMap { try? Plane($0) }
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
    static func * (lhs: Picture, rhs: Transform) -> Picture {
        Self(lines: lhs.lines.map { $0 * rhs },
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
    static let renderingScale = 4.0
    private typealias LineUInt = UInt8
    private typealias FilledUInt = UInt16
    private static let backgroundColor = Color(red: 0.0, green: 0, blue: 0)
    private static let lineColor = Color(red: 1.0, green: 1, blue: 1)
    private static func planesRenderingNode(with bounds: Rect,
                                            from lines: [Line]) -> Node {
        let lineNodes = lines
            .compactMap { $0.autoFillNode(lineColor: Picture.lineColor) }
        return Node(children: lineNodes, path: Path(bounds))
    }
    enum AutoFillResult {
        case planes(_ planes: [Plane])
        case planeValue(_ planeValue: PlaneValue)
        case none
    }
    
    func autoFill(fromOther otherPlanes: [Plane]? = nil,
                  inFrame bounds: Rect,
                  clipingPath: Path?,
                  scale: Double = Picture.renderingScale,
                  borders: [Border] = [],
                  isSelection: Bool) -> AutoFillResult {
        let nPolys = makePolygons(inFrame: bounds, clipingPath: clipingPath,
                                  isSelection: isSelection)
        return Self.autoFill(fromOther: otherPlanes, from: nPolys,
                             from: planes,
                             inFrame: bounds,
                             clipingPath: clipingPath, isSelection: isSelection)
    }
    func makePolygons(inFrame bounds: Rect,
                      clipingPath: Path?,
                      scale: Double = Picture.renderingScale,
                      borders: [Border] = [],
                      isSelection: Bool) -> [Topolygon] {
        let bounds = (isSelection ?
                        bounds :
                        (clipingPath?.bounds ?? bounds)).integral
        return Self.topolygons(with: bounds, from: lines,
                               scale: scale, borders: borders)
    }
    static func autoFill(fromOther otherPlanes: [Plane]? = nil,
                         from nPolys: [Topolygon],
                         from planes: [Plane],
                         inFrame bounds: Rect,
                         clipingPath: Path?,
                         scale: Double = Picture.renderingScale,
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
                                   scale: Double,
                                   borders: [Border]) -> [Topolygon] {
        let size = bounds.size * scale
        let node = planesRenderingNode(with: bounds, from: lines)
        if !borders.isEmpty {
            node.children += borders.map {
                Node(path: $0.path(with: bounds),
                     lineWidth: 2, lineType: .color(Picture.lineColor))
            }
        }
        guard let texture
                = node.imageInBounds(size: size,
                                     backgroundColor: Picture.backgroundColor,
                                     colorSpace: .sRGB,
                                     isAntialias: false) else { return [] }
        
        let w = Int(size.width), h = Int(size.height)
        guard let lineBitmap
                = Bitmap<LineUInt>(width: w, height: h,
                                   colorSpace: .grayscale) else { return [] }
        guard let filledBitmap
                = Bitmap<FilledUInt>(width: w, height: h,
                                     colorSpace: .grayscale) else { return [] }
        
        lineBitmap.draw(texture, in: Rect(size: size))
        
        let mPolys = Picture.makePlanesByFillAll(in: filledBitmap, from: lineBitmap,
                                         scale: scale)
        
        let position = Point(x: -bounds.centerPoint.x * scale + size.width / 2,
                             y: -bounds.centerPoint.y * scale + size.height / 2)
        let invertedTransform
            = Attitude(position: position,
                       scale: Size(square: scale)).transform.inverted()
        return mPolys.map { $0 * invertedTransform }
    }
    private static func makePlanesByFillAll(in filledBitmap: Bitmap<FilledUInt>,
                                     from lineBitmap: Bitmap<LineUInt>,
                                     scale: Double,
                                     threshold: Double = 0.85) -> [Topolygon] {
        let t = LineUInt(threshold * Double(LineUInt.max))
        let w = lineBitmap.width, h = lineBitmap.height
        
        let nearestR = Int(scale)
        let nearestRSq = nearestR * nearestR
        let maxNearestR = nearestR * 4
        let maxNearestRSq = maxNearestR * maxNearestR
        
        func floodFill(_ value: FilledUInt, atX fx: Int, y fy: Int) {
            let inValue = filledBitmap[fx, fy]
            
            struct Scan {
                var minX, maxX, y: Int
                var isTop: Bool
            }
            
            var stack = Stack<Scan>()
            stack.push(Scan(minX: fx, maxX: fx, y: fy, isTop: false))
            
            func isFill(_ x: Int, _ y: Int) -> Bool {
                filledBitmap[x, y] == inValue
            }
            func pushScans(minX: Int, maxX: Int, y: Int, isTop: Bool) {
                var mx = minX
                while mx < maxX {
                    while mx < maxX && !isFill(mx, y) {
                        mx += 1
                    }
                    let nMinX = mx
                    while mx < maxX && isFill(mx, y) {
                        filledBitmap[mx, y] = value
                        mx += 1
                    }
                    stack.push(Scan(minX: nMinX, maxX: mx,
                                    y: y, isTop: isTop))
                }
            }
            
            while let scan = stack.pop() {
                let y = scan.y
                var minX = scan.minX - 1
                while minX >= 0 && isFill(minX, y) {
                    filledBitmap[minX, y] = value
                    minX -= 1
                }
                minX += 1
                var maxX = scan.maxX
                while maxX < w && isFill(maxX, y) {
                    filledBitmap[maxX, y] = value
                    maxX += 1
                }
                let by = y - 1, ty = y + 1
                if scan.isTop {
                    if by >= 0 {
                        pushScans(minX: minX, maxX: scan.minX, y: by, isTop: false)
                        pushScans(minX: scan.maxX, maxX: maxX, y: by, isTop: false)
                    }
                    if ty < h {
                        pushScans(minX: minX, maxX: maxX, y: ty, isTop: true)
                    }
                } else {
                    if ty < h {
                        pushScans(minX: minX, maxX: scan.minX, y: ty, isTop: true)
                        pushScans(minX: scan.maxX, maxX: maxX, y: ty, isTop: true)
                    }
                    if by >= 0 {
                        pushScans(minX: minX, maxX: maxX, y: by, isTop: false)
                    }
                }
            }
        }
        
        func isLine(x: Int, y: Int) -> Bool {
            lineBitmap[x, y] >= t
        }
        
        func nearestValueAt(x: Int, y: Int,
                            r: Int, rSquared: Int) -> FilledUInt? {
            let minX = max(x - r, 0), maxX = min(x + r, w - 1)
            let minY = max(y - r, 0), maxY = min(y + r, h - 1)
            guard minX <= maxX && minY <= maxY else {
                return nil
            }
            var minValue: FilledUInt?, minDSquared = Int.max
            for iy in minY ... maxY {
                for ix in minX ... maxX {
                    if !isLine(x: ix, y: iy) {
                        let dx = ix - x, dy = iy - y
                        let dSquared = dx * dx + dy * dy
                        if dSquared < rSquared && dSquared < minDSquared {
                            minDSquared = dSquared
                            minValue = filledBitmap[ix, iy]
                        }
                    }
                }
            }
            return minValue
        }
        
        func orientation<T: BidirectionalCollection>(from points: T) -> CircularOrientation? where T.Element == IntPoint {
            guard var p0 = points.last else {
                return nil
            }
            var area = 0
            for p1 in points {
                area += p0.cross(p1)
                p0 = p1
            }
            if area > 0 {
                return .counterClockwise
            } else if area < 0 {
                return .clockwise
            } else {
                return nil
            }
        }
        
        func aroundPoints(with value: FilledUInt,
                          atX fx: Int, y fy: Int) -> [IntPoint] {
            enum Direction {
                case left, top, right, bottom
                
                mutating func next() {
                    switch self {
                    case .left: self = .top
                    case .top: self = .right
                    case .right: self = .bottom
                    case .bottom: self = .left
                    }
                }
                mutating func inverted() {
                    switch self {
                    case .left: self = .right
                    case .top: self = .bottom
                    case .right: self = .left
                    case .bottom: self = .top
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
            
            func isAround(_ p: IntPoint) -> Bool {
                p.x >= 0 && p.x < w && p.y >= 0 && p.y < h
                    && filledBitmap[p.x, p.y] == value
            }
            
            var points = [IntPoint]()
            let fp = IntPoint(fx, fy)
            points.append(fp)
            var p = fp, direction = Direction.left, isEnd = false
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
        
        var pDic = [[IntPoint]: [Point]]()
        
        func smoothPoints(with points: [IntPoint]) -> [Point] {
            func isVertex(at p: IntPoint) -> Bool {
                let x = p.x, y = p.y
                var vSet = Set<FilledUInt>(), outCount = 0
                func insert(_ x: Int, _ y: Int) {
                    if x >= 0 && x < w && y >= 0 && y < h {
                        vSet.insert(filledBitmap[x, y])
                    } else {
                        outCount += 1
                    }
                }
                insert(x - 1, y - 1)
                insert(x, y - 1)
                insert(x - 1, y)
                insert(x, y)
                if outCount == 0 {
                    return vSet.count >= 3
                } else if outCount == 2 {
                    return vSet.count >= 2
                } else {
                    return true
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
                                maxD: Double = 0.5 - .ulpOfOne) {
                let maxDSquared = maxD * maxD
                
                func append<T: RandomAccessCollection>(_ rPoints: T,
                                                       in lPoints: inout [Point])
                where T.Index == Int, T.Element == IntPoint {
                
                    var rrPoints = [Point]()
                    rrPoints.reserveCapacity(rPoints.endIndex - rPoints.startIndex)
                    rrPoints.append(rPoints[rPoints.startIndex].double())
                    for i in (rPoints.startIndex + 1) ..< rPoints.endIndex {
                        rrPoints.append(rPoints[i - 1].double()
                                            .mid(rPoints[i].double()))
                    }
                    rrPoints.append(rPoints[rPoints.endIndex - 1].double())
                    
                    var preP = rrPoints[1], sp = rrPoints[0], oldJ = 1
                    for j in 2 ..< rrPoints.count {
                        let ep = rrPoints[j]
                        for k in oldJ ..< j {
                            let dSquared = LinearLine(sp, ep)
                                .distanceSquared(from: rrPoints[k])
                            if dSquared >= maxDSquared {
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
                var newPoints = [Point]()
                newPoints.reserveCapacity(points.count)
                let fPoints: [IntPoint]
                if firstI == 0 {
                    fPoints = points + [points[0]]
                } else {
                    fPoints = Array(points[firstI...] + points[...firstI])
                }
                var si = 0
                for ei in 1 ..< fPoints.count {
                    let ep = fPoints[ei]
                    if !isVertex(at: ep) { continue }
                    let sp = fPoints[si]
                    let isReverse = ep == sp ?
                        orientation(from: fPoints[si ... ei]) != .counterClockwise :
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
                    if i == 0 {
                        return ps
                    } else {
                        return Array(ps[i...] + ps[..<i])
                    }
                }
                var points = leftDownSort(points)
                points.append(points[0])
                var newPoints = [Point]()
                newPoints.reserveCapacity(points.count)
                let isReverse = orientation(from: points) != .counterClockwise
                appendEdgeWith(start: 0, end: points.count - 1,
                               from: points, in: &newPoints,
                               isReverse: isReverse)
                return newPoints
            }
        }
        
        func containsAt(_ x: Int, _ y: Int) -> Bool {
            !(x >= 0 && x < w && y >= 0 && y < h) || isLine(x: x, y: y)
        }
        for y in 0 ..< h {
            for x in 0 ..< w {
                if !isLine(x: x, y: y) &&
                    (containsAt(x - 1, y) && containsAt(x + 1, y)
                        && containsAt(x, y - 1) && containsAt(x, y + 1)) {
                    
                    lineBitmap[x, y] = t
                }
            }
        }
        
        let lineValue: FilledUInt = 1
        for y in 0 ..< h {
            for x in 0 ..< w {
                if isLine(x: x, y: y) {
                    filledBitmap[x, y] = lineValue
                }
            }
        }
        
        var fillValue: FilledUInt = 2
        for y in 0 ..< h {
            for x in 0 ..< w {
                if filledBitmap[x, y] == 0 {
                    floodFill(fillValue, atX: x, y: y)
                    fillValue = fillValue + 1 <= FilledUInt.max ?
                        fillValue + 1 :
                        2
                }
            }
        }
        
        for y in 0 ..< h {
            for x in 0 ..< w {
                if isLine(x: x, y: y) {
                    if let v = nearestValueAt(x: x, y: y, r: nearestR,
                                              rSquared: nearestRSq) {
                        filledBitmap[x, y] = v
                    } else if let v = nearestValueAt(x: x, y: y, r: maxNearestR,
                                                     rSquared: maxNearestRSq) {
                        filledBitmap[x, y] = v
                    }
                }
            }
        }
        
        struct IntTopolygon {
            var points: [IntPoint]
            var holePoints: [[IntPoint]]
        }
        var ipolys = [IntTopolygon](), iis = [FilledUInt: Int]()
        ipolys.reserveCapacity(Int(fillValue) - 2)
        var aroundValues = [FilledUInt: Set<IntPoint>](), oldV: FilledUInt = 0
        for y in 0 ..< h {
            for x in 0 ..< w {
                var v = filledBitmap[x, y]
                guard x == 0 || v != oldV else { continue }
                if let points = aroundValues[v] {
                    if !points.contains(IntPoint(x, y)) {
                        let nPoints = aroundPoints(with: v, atX: x, y: y)
                        if orientation(from: nPoints) == .counterClockwise {
                            aroundValues[v]?.formUnion(Set(nPoints))
                            if let i = iis[v] {
                                ipolys[i].holePoints.append(nPoints)
                            }
                        } else {
                            fillValue = fillValue + 1 <= FilledUInt.max ?
                                fillValue + 1 : 2
                            v = fillValue
                            floodFill(v, atX: x, y: y)
                            
                            aroundValues[v] = Set(nPoints)
                            iis[v] = ipolys.count
                            ipolys.append(IntTopolygon(points:  nPoints,
                                                       holePoints: []))
                        }
                    }
                } else {
                    let nPoints = aroundPoints(with: v, atX: x, y: y)
                    aroundValues[v] = Set(nPoints)
                    iis[v] = ipolys.count
                    ipolys.append(IntTopolygon(points: nPoints,
                                               holePoints: []))
                }
                oldV = v
            }
        }
        
        return ipolys.compactMap {
            let nps = smoothPoints(with: $0.points)
            if !nps.isEmpty {
                let holePolygons: [Polygon] = $0.holePoints.compactMap {
                    let nps = smoothPoints(with: $0)
                    if !nps.isEmpty {
                        return Polygon(points: nps)
                    } else {
                        return nil
                    }
                }
                return Topolygon(polygon: Polygon(points: nps),
                                 holePolygons: holePolygons)
            } else {
                return nil
            }
        }
    }
}
