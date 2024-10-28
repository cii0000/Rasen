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

import struct Foundation.URL

typealias Camera = Attitude
typealias Thumbnail = Image
typealias SheetID = UUID

struct CornerRectValue {
    var rect: Rect
    var rectCorner: RectCorner
}
extension CornerRectValue {
    var firstOrigin: Point {
        switch rectCorner {
        case .minXMinY: rect.maxXMaxYPoint
        case .minXMaxY: rect.maxXMinYPoint
        case .maxXMinY: rect.minXMaxYPoint
        case .maxXMaxY: rect.minXMinYPoint
        }
    }
    var lastOrigin: Point {
        switch rectCorner {
        case .minXMinY: rect.minXMinYPoint
        case .minXMaxY: rect.minXMaxYPoint
        case .maxXMinY: rect.maxXMinYPoint
        case .maxXMaxY: rect.maxXMaxYPoint
        }
    }
}
extension CornerRectValue: Protobuf {
    init(_ pb: PBCornerRectValue) throws {
        rect = try .init(pb.rect)
        rectCorner = try .init(pb.rectCorner)
    }
    var pb: PBCornerRectValue {
        .with {
            $0.rect = rect.pb
            $0.rectCorner = rectCorner.pb
        }
    }
}
extension CornerRectValue: Codable {}

typealias Selection = CornerRectValue
extension Array: Serializable where Element == Selection {}
extension Array: Protobuf where Element == Selection {
    init(_ pb: PBCornerRectValueArray) throws {
        self = try pb.value.map { try .init($0) }
    }
    var pb: PBCornerRectValueArray {
        .with { $0.value = map { $0.pb } }
    }
}
extension Selection: AppliableTransform {
    static func * (lhs: Self, rhs: Transform) -> Self {
        .init(rect: lhs.rect * rhs, rectCorner: lhs.rectCorner)
    }
}

struct MultiSelection {
    var selections = [Selection]()
}
extension MultiSelection {
    var isEmpty: Bool {
        selections.isEmpty
    }
    func intersects(_ rect: Rect) -> Bool {
        selections.contains { $0.rect.intersects(rect) }
    }
    func intersects(_ line: Line) -> Bool {
        selections.contains { line.intersects($0.rect) }
    }
    func intersects(_ lineView: SheetLineView) -> Bool {
        selections.contains { lineView.intersects($0.rect) }
    }
    func contains(_ p : Point) -> Bool {
        selections.contains { $0.rect.contains(p) }
    }
    func firstSelection(at p: Point) -> Selection? {
        selections.reversed().first { $0.rect.contains(p) }
    }
}
extension MultiSelection: AppliableTransform {
    static func * (lhs: Self, rhs: Transform) -> Self {
        .init(selections: lhs.selections.map { $0 * rhs })
    }
}

struct Finding {
    var worldPosition = Point()
    var string = ""
}
extension Finding {
    var isEmpty: Bool { string.isEmpty }
}
extension Finding: Protobuf {
    init(_ pb: PBFinding) throws {
        worldPosition = try .init(pb.worldPosition)
        string = pb.string
    }
    var pb: PBFinding {
        .with {
            $0.worldPosition = worldPosition.pb
            $0.string = string
        }
    }
}
extension Finding: Codable {}

private struct Road {
    var shp0: IntPoint, shp1: IntPoint
}
extension Road {
    func pathlineWith(width: Double, height: Double) -> Pathline? {
        let hw = width / 2, hh = height / 2
        let dx = shp1.x - shp0.x, dy = shp1.y - shp0.y
        if abs(dx) <= 1 && abs(dy) <= 1 {
            return nil
        }
        if dx == 0 {
            let sy = dy < 0 ? shp1.y : shp0.y
            let ey = dy < 0 ? shp0.y : shp1.y
            let x = Double(shp0.x) * width + hw
            return Pathline([Point(x, Double(sy) * height + 2 * hh),
                             Point(x, Double(ey) * height)])
        } else if dy == 0 {
            let sx = dx < 0 ? shp1.x : shp0.x
            let ex = dx < 0 ? shp0.x : shp1.x
            let y = Double(shp0.y) * height + hh
            return Pathline([Point(Double(sx) * width + hw + hw, y),
                             Point(Double(ex) * width - hw + hw, y)])
        } else {
            var points = [Point]()
            let isReversed = shp0.y > shp1.y
            let sSHP = isReversed ? shp1 : shp0,
                eSHP = isReversed ? shp0 : shp1
            let sx = sSHP.x, sy = sSHP.y
            let ex = eSHP.x, ey = eSHP.y
            if sx < ex {
                var oldXI = sx
                for nyi in sy ... ey {
                    let nxi = Int(Double(ex - sx) * Double(nyi - sy)
                                    / Double(ey - sy) + Double(sx))
                    if nyi == sy {
                        points.append(Point(Double(sx) * width + hw,
                                            Double(sy + 1) * height))
                    } else if nyi == ey {
                        let y = Double(nyi) * height + hh
                        if oldXI < nxi {
                            points.append(Point(Double(oldXI) * width + hw, y))
                        }
                        points.append(Point(Double(nxi) * width, y))
                    } else if nxi != oldXI && nxi < ex {
                        let y = Double(nyi) * height + hh
                        points.append(Point(Double(oldXI) * width + hw, y))
                        points.append(Point(Double(nxi) * width + hw, y))
                        oldXI = nxi
                    }
                }
            } else {
                var oldXI = ex
                for nyi in (sy ... ey).reversed() {
                    let nxi = Int(Double(ex - sx) * Double(nyi - sy)
                                    / Double(ey - sy) + Double(sx))
                    if nyi == sy {
                        let y = Double(nyi) * height + hh
                        if oldXI < nxi {
                            points.append(Point(Double(oldXI) * width + hw, y))
                        }
                        points.append(Point(Double(nxi) * width, y))
                    } else if nyi == ey {
                        points.append(Point(Double(ex) * width + hw,
                                            Double(ey) * height))
                    } else if nxi != oldXI && nxi > sx {
                        let y = Double(nyi) * height + hh
                        points.append(Point(Double(oldXI) * width + hw, y))
                        points.append(Point(Double(nxi) * width + hw, y))
                        oldXI = nxi
                    }
                }
            }
            return Pathline(points)
        }
    }
}

enum WorldUndoItem {
    case insertSheets(_ sids: [Sheetpos: SheetID])
    case removeSheets(_ shps: [Sheetpos])
}
extension WorldUndoItem: UndoItem {
    var type: UndoItemType {
        switch self {
        case .insertSheets: .reversible
        case .removeSheets: .unreversible
        }
    }
    func reversed() -> Self? {
        switch self {
        case .insertSheets(let shps):
            .removeSheets(shps.map { $0.key })
        case .removeSheets:
            nil
        }
    }
}
extension WorldUndoItem: Protobuf {
    init(_ pb: PBWorldUndoItem) throws {
        guard let value = pb.value else {
            throw ProtobufError()
        }
        switch value {
        case .insertSheets(let sids):
            self = .insertSheets(try [Sheetpos: SheetID](sids))
        case .removeSheets(let shps):
            self = .removeSheets(try [Sheetpos](shps))
        }
    }
    var pb: PBWorldUndoItem {
        .with {
            switch self {
            case .insertSheets(let sids):
                $0.value = .insertSheets(sids.pb)
            case .removeSheets(let shps):
                $0.value = .removeSheets(shps.pb)
            }
        }
    }
}
extension WorldUndoItem: Codable {
    private enum CodingTypeKey: String, Codable {
        case insertSheets = "0"
        case removeSheets = "1"
    }
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let key = try container.decode(CodingTypeKey.self)
        switch key {
        case .insertSheets:
            self = .insertSheets(try container.decode([Sheetpos: SheetID].self))
        case .removeSheets:
            self = .removeSheets(try container.decode([Sheetpos].self))
        }
    }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .insertSheets(let sids):
            try container.encode(CodingTypeKey.insertSheets)
            try container.encode(sids)
        case .removeSheets(let shps):
            try container.encode(CodingTypeKey.removeSheets)
            try container.encode(shps)
        }
    }
}

extension Dictionary where Key == SheetID, Value == Sheetpos {
    init(_ pb: PBSheetposStringDic) throws {
        var shps = [SheetID: Sheetpos]()
        for e in pb.value {
            if let sid = SheetID(uuidString: e.key) {
                shps[sid] = try Sheetpos(e.value)
            }
        }
        self = shps
    }
    var pb: PBSheetposStringDic {
        var pbips = [String: PBSheetpos]()
        for (sid, shp) in self {
            pbips[sid.uuidString] = shp.pb
        }
        return .with {
            $0.value = pbips
        }
    }
}
extension Dictionary where Key == Sheetpos, Value == SheetID {
    init(_ pb: PBStringIntPointDic) throws {
        var sids = [Sheetpos: SheetID]()
        for e in pb.value {
            sids[try .init(e.key)] = SheetID(uuidString: e.value)
        }
        self = sids
    }
    var pb: PBStringIntPointDic {
        var pbsipdes = [PBStringIntPointDicElement]()
        for (shp, sid) in self {
            pbsipdes.append(.with {
                $0.key = shp.pb
                $0.value = sid.uuidString
            })
        }
        return .with {
            $0.value = pbsipdes
        }
    }
}

struct Sheetpos: Hashable, Codable {
    var x = 0, y = 0, isRight = false
}
extension Sheetpos: Protobuf {
    init(_ pb: PBSheetpos) throws {
        x = Int(pb.x)
        y = Int(pb.y)
        isRight = pb.isRight
    }
    var pb: PBSheetpos {
        .with {
            $0.x = Int64(x)
            $0.y = Int64(y)
            $0.isRight = isRight
        }
    }
}
extension Sheetpos {
    func int() -> IntPoint {
        .init(x, y)
    }
    func double() -> Point {
        .init(x, y)
    }
    func cross(_ other: Self) -> Int {
        x * other.y - y * other.x
    }
    static func + (lhs: Self, rhs: Self) -> Self {
        .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y, isRight: lhs.isRight)
    }
    static func - (lhs: Self, rhs: Self) -> Self {
        .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y, isRight: lhs.isRight)
    }
    func distanceSquared(_ other: Self) -> Int {
        let x = self.x - other.x, y = self.y - other.y
        return x * x + y * y
    }
}
extension Array where Element == Sheetpos {
    init(_ pb: PBSheetposArray) throws {
        self = try pb.value.map { try Sheetpos($0) }
    }
    var pb: PBSheetposArray {
        .with { $0.value = map { $0.pb } }
    }
}

struct World {
    var sheetIDs = [Sheetpos: SheetID]()
    var sheetPositions = [SheetID: Sheetpos]()
}
extension World: Protobuf {
    init(_ pb: PBWorld) throws {
        let shps = try [SheetID: Sheetpos](pb.sheetPositions)
        self.sheetIDs = World.sheetIDs(with: shps)
        self.sheetPositions = shps
    }
    var pb: PBWorld {
        .with {
            $0.sheetPositions = sheetPositions.pb
        }
    }
}
extension World: Codable {}
extension World {
    func sheetID(at p: IntPoint) -> SheetID? {
        let leftShp = Sheetpos(x: p.x - 1, y: p.y, isRight: true)
        return if let sid = sheetIDs[leftShp] {
            sid
        } else {
            sheetIDs[Sheetpos(x: p.x, y: p.y, isRight: true)]
            ?? sheetIDs[Sheetpos(x: p.x, y: p.y, isRight: false)]
        }
    }
    func sheetpos(at p: IntPoint) -> Sheetpos {
        let leftShp = Sheetpos(x: p.x - 1, y: p.y, isRight: true)
        if sheetIDs[leftShp] != nil {
            return leftShp
        } else {
            let rightShp = Sheetpos(x: p.x, y: p.y, isRight: true)
            return Sheetpos(x: p.x, y: p.y,
                            isRight: sheetIDs[rightShp] != nil)
        }
    }
    
    static func sheetIDs(with shps: [SheetID: Sheetpos]) -> [Sheetpos: SheetID] {
        var sids = [Sheetpos: SheetID]()
        sids.reserveCapacity(shps.count)
        for (sid, shp) in shps {
            sids[shp] = sid
        }
        return sids
    }
    static func sheetPositions(with sids: [Sheetpos: SheetID]) -> [SheetID: Sheetpos] {
        var shps = [SheetID: Sheetpos]()
        shps.reserveCapacity(sids.count)
        for (shp, sid) in sids {
            shps[sid] = shp
        }
        return shps
    }
    init(_ sids: [Sheetpos: SheetID] = [:]) {
        self.sheetIDs = sids
        self.sheetPositions = World.sheetPositions(with: sids)
    }
    init(_ shps: [SheetID: Sheetpos] = [:]) {
        self.sheetIDs = World.sheetIDs(with: shps)
        self.sheetPositions = shps
    }
}

typealias WorldHistory = History<WorldUndoItem>

typealias Root = Document

final class Document {
    enum FileType: FileTypeProtocol, CaseIterable {
        case sksdoc
        case skshdoc
        case sksdata
        
        case rasendoc
        case rasendoch
        case rasendata
        
        var name: String {
            switch self {
            case .sksdoc: String(format: "%1$@ Document".localized, System.oldAppName)
            case .skshdoc: String(format: "%1$@ Document with History".localized, System.oldAppName)
            case .sksdata: System.oldDataName
                
            case .rasendoc: String(format: "%1$@ Document".localized, System.appName)
            case .rasendoch: String(format: "%1$@ Document with History".localized, System.appName)
            case .rasendata: System.dataName
            }
        }
        var utType: UTType {
            switch self {
            case .sksdoc: UTType(importedAs: "\(System.oldID).sksdoc")
            case .skshdoc: UTType(importedAs: "\(System.oldID).skshdoc")
            case .sksdata: UTType(importedAs: "\(System.oldID).sksdata")
                
            case .rasendoc: UTType(exportedAs: "\(System.id).rasendoc")
            case .rasendoch: UTType(exportedAs: "\(System.id).rasendoch")
            case .rasendata: UTType(exportedAs: "\(System.id).rasendata")
            }
        }
        var filenameExtension: String {
            switch self {
            case .sksdoc: "sksdoc"
            case .skshdoc: "skshdoc"
            case .sksdata: "sksdata"
                
            case .rasendoc: "rasendoc"
            case .rasendoch: "rasendoch"
            case .rasendata: "rasendata"
            }
        }
    }
    
    var url: URL
    
    init(_ url: URL) {
        self.url = url
    }
}
