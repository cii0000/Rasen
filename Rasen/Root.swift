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

import struct Foundation.UUID
import struct Foundation.Data
import struct Foundation.URL

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

struct Road {
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
    case insertSheets(_ sids: [IntPoint: UUID])
    case removeSheets(_ shps: [IntPoint])
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
            self = .insertSheets(try [IntPoint: UUID](sids))
        case .removeSheets(let shps):
            self = .removeSheets(try [IntPoint](shps))
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
            self = .insertSheets(try container.decode([IntPoint: UUID].self))
        case .removeSheets:
            self = .removeSheets(try container.decode([IntPoint].self))
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

extension Dictionary where Key == UUID, Value == IntPoint {
    init(_ pb: PBIntPointStringDic) throws {
        var shps = [UUID: IntPoint]()
        for e in pb.value {
            if let sid = UUID(uuidString: e.key) {
                shps[sid] = try IntPoint(e.value)
            }
        }
        self = shps
    }
    var pb: PBIntPointStringDic {
        var pbips = [String: PBIntPoint]()
        for (sid, shp) in self {
            pbips[sid.uuidString] = shp.pb
        }
        return .with {
            $0.value = pbips
        }
    }
}
extension Dictionary where Key == IntPoint, Value == UUID {
    init(_ pb: PBStringIntPointDic) throws {
        var sids = [IntPoint: UUID]()
        for e in pb.value {
            sids[try .init(e.key)] = UUID(uuidString: e.value)
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

struct World {
    var sheetIDs = [IntPoint: UUID]()
    var sheetPositions = [UUID: IntPoint]()
}
extension World: Protobuf {
    init(_ pb: PBWorld) throws {
        let shps = try [UUID: IntPoint](pb.sheetPositions)
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
    func sheetID(at p: IntPoint) -> UUID? {
        sheetIDs[IntPoint(p.x, p.y)]
    }
    
    static func sheetIDs(with shps: [UUID: IntPoint]) -> [IntPoint: UUID] {
        var sids = [IntPoint: UUID]()
        sids.reserveCapacity(shps.count)
        for (sid, shp) in shps {
            sids[shp] = sid
        }
        return sids
    }
    static func sheetPositions(with sids: [IntPoint: UUID]) -> [UUID: IntPoint] {
        var shps = [UUID: IntPoint]()
        shps.reserveCapacity(sids.count)
        for (shp, sid) in sids {
            shps[sid] = shp
        }
        return shps
    }
    init(_ sids: [IntPoint: UUID] = [:]) {
        self.sheetIDs = sids
        self.sheetPositions = World.sheetPositions(with: sids)
    }
    init(_ shps: [UUID: IntPoint] = [:]) {
        self.sheetIDs = World.sheetIDs(with: shps)
        self.sheetPositions = shps
    }
}

typealias WorldHistory = History<WorldUndoItem>

typealias Document = Root

final class Root: @unchecked Sendable {
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
    
    struct SheetRecorder: @unchecked Sendable {
        let sheetID: UUID
        let directory: Directory
        
        static let sheetKey = "sheet.pb"
        let sheetRecord: Record<Sheet>
        
        static let sheetHistoryKey = "sheet_h.pb"
        let sheetHistoryRecord: Record<SheetHistory>
        
        static let contentsDirectoryKey = "contents"
        let contentsDirectory: Directory
        
        static let thumbnail4Key = "t4.jpg"
        let thumbnail4Record: Record<Image>
        static let thumbnail16Key = "t16.jpg"
        let thumbnail16Record: Record<Image>
        static let thumbnail64Key = "t64.jpg"
        let thumbnail64Record: Record<Image>
        static let thumbnail256Key = "t256.jpg"
        let thumbnail256Record: Record<Image>
        static let thumbnail1024Key = "t1024.jpg"
        let thumbnail1024Record: Record<Image>
        
        static let stringKey = "string.txt"
        let stringRecord: Record<String>
        
        var fileSize: Int {
            var size = 0
            size += sheetRecord.size ?? 0
            size += sheetHistoryRecord.size ?? 0
            size += thumbnail4Record.size ?? 0
            size += thumbnail16Record.size ?? 0
            size += thumbnail64Record.size ?? 0
            size += thumbnail256Record.size ?? 0
            size += thumbnail1024Record.size ?? 0
            size += contentsDirectory.size ?? 0
            size += stringRecord.size ?? 0
            return size
        }
        var fileSizeWithoutHistory: Int {
            var size = 0
            size += sheetRecord.size ?? 0
            size += thumbnail4Record.size ?? 0
            size += thumbnail16Record.size ?? 0
            size += thumbnail64Record.size ?? 0
            size += thumbnail256Record.size ?? 0
            size += thumbnail1024Record.size ?? 0
            size += contentsDirectory.size ?? 0
            size += stringRecord.size ?? 0
            return size
        }
        
        init(_ directory: Directory, _ sid: UUID, isLoadOnly: Bool = false) {
            self.sheetID = sid
            self.directory = directory
            sheetRecord = directory.makeRecord(forKey: Self.sheetKey, isLoadOnly: isLoadOnly)
            sheetHistoryRecord = directory.makeRecord(forKey: Self.sheetHistoryKey, isLoadOnly: isLoadOnly)
            contentsDirectory = directory.makeDirectory(forKey: Self.contentsDirectoryKey, isLoadOnly: isLoadOnly)
            thumbnail4Record = directory.makeRecord(forKey: Self.thumbnail4Key, isLoadOnly: isLoadOnly)
            thumbnail16Record = directory.makeRecord(forKey: Self.thumbnail16Key, isLoadOnly: isLoadOnly)
            thumbnail64Record = directory.makeRecord(forKey: Self.thumbnail64Key, isLoadOnly: isLoadOnly)
            thumbnail256Record = directory.makeRecord(forKey: Self.thumbnail256Key, isLoadOnly: isLoadOnly)
            thumbnail1024Record = directory.makeRecord(forKey: Self.thumbnail1024Key, isLoadOnly: isLoadOnly)
            stringRecord = directory.makeRecord(forKey: Self.stringKey, isLoadOnly: isLoadOnly)
        }
    }
    
    var url: URL
    
    let rootDirectory: Directory
    
    static let worldRecordKey = "world.pb"
    let worldRecord: Record<World>
    
    static let worldHistoryRecordKey = "world_h.pb"
    let worldHistoryRecord: Record<WorldHistory>
    
    static let selectionsRecordKey = "selections.pb"
    var selectionsRecord: Record<[Selection]>
    
    static let findingRecordKey = "finding.pb"
    var findingRecord: Record<Finding>
    
    static let povRecordKey = "pov.pb"
    var povRecord: Record<Attitude>
    
    static let sheetsDirectoryKey = "sheets"
    let sheetsDirectory: Directory
    
    private(set) var sheetRecorders: [UUID: SheetRecorder]
    
    init(_ url: URL, isLoadOnly: Bool = false) {
        self.url = url
        
        rootDirectory = .init(url: url)
        
        worldRecord = rootDirectory.makeRecord(forKey: Self.worldRecordKey, isLoadOnly: isLoadOnly)
        worldHistoryRecord = rootDirectory.makeRecord(forKey: Self.worldHistoryRecordKey, isLoadOnly: isLoadOnly)
        selectionsRecord = rootDirectory.makeRecord(forKey: Self.selectionsRecordKey, isLoadOnly: isLoadOnly)
        findingRecord = rootDirectory.makeRecord(forKey: Self.findingRecordKey, isLoadOnly: isLoadOnly)
        povRecord = rootDirectory.makeRecord(forKey: Self.povRecordKey, isLoadOnly: isLoadOnly)
        sheetsDirectory = rootDirectory.makeDirectory(forKey: Self.sheetsDirectoryKey, isLoadOnly: isLoadOnly)
        sheetRecorders = Self.sheetRecorders(from: sheetsDirectory, isLoadOnly: isLoadOnly)
    }
    static func sheetID(forKey key: String) -> UUID? { UUID(uuidString: key) }
    static func sheetIDKey(at sid: UUID) -> String { sid.uuidString }
    private static func sheetRecorders(from sheetsDirectory: Directory,
                                       isLoadOnly: Bool = false) -> [UUID: SheetRecorder] {
        var srrs = [UUID: SheetRecorder]()
        srrs.reserveCapacity(sheetsDirectory.childrenURLs.count)
        for (key, _) in sheetsDirectory.childrenURLs {
            guard let sid = sheetID(forKey: key) else { continue }
            let directory = sheetsDirectory.makeDirectory(forKey: sheetIDKey(at: sid), isLoadOnly: isLoadOnly)
            srrs[sid] = SheetRecorder(directory, sid, isLoadOnly: isLoadOnly)
        }
        return srrs
    }
    
    func write() throws {
        rootDirectory.prepareToWriteAll()
        do {
            try rootDirectory.writeAll()
            rootDirectory.resetWriteAll()
        } catch {
            rootDirectory.resetWriteAll()
            throw error
        }
    }
    
    func world() -> World {
        worldRecord.decodedValue ?? .init()
    }
    func history() -> WorldHistory {
        worldHistoryRecord.decodedValue ?? .init()
    }
    func selections() -> [Selection] {
        selectionsRecord.decodedValue ?? []
    }
    func finding() -> Finding {
        findingRecord.decodedValue ?? .init()
    }
    func pov() -> Attitude {
        povRecord.decodedValue ?? Self.defaultPOV
    }
    
    func baseThumbnailBlocks() -> [UUID: Texture.Block] {
        var baseThumbnailBlocks = [UUID: Texture.Block]()
        sheetRecorders.forEach {
            guard let data = $0.value.thumbnail4Record.decodedData else { return }
            if let block = try? Texture.block(from: data) {
                baseThumbnailBlocks[$0.key] = block
            } else if let image = Image(size: Size(width: 4, height: 4),
                                        color: .init(red: 1.0, green: 0, blue: 0)) {
                $0.value.thumbnail4Record.value = image
                $0.value.thumbnail4Record.isWillwrite = true
                baseThumbnailBlocks[$0.key] = try? Texture.block(from: image)
            } else {
                baseThumbnailBlocks[$0.key] = nil
            }
        }
        return baseThumbnailBlocks
    }
    
    enum ThumbnailType: Int {
        case w4 = 4, w16 = 16, w64 = 64, w256 = 256, w1024 = 1024
    }
    func thumbnailRecord(at sid: UUID,
                         with type: ThumbnailType) -> Record<Image>? {
        switch type {
        case .w4: sheetRecorders[sid]?.thumbnail4Record
        case .w16: sheetRecorders[sid]?.thumbnail16Record
        case .w64: sheetRecorders[sid]?.thumbnail64Record
        case .w256: sheetRecorders[sid]?.thumbnail256Record
        case .w1024: sheetRecorders[sid]?.thumbnail1024Record
        }
    }
    
    func sheet(at sid: UUID) -> Sheet? {
        sheetRecorders[sid]?.sheetRecord.decodedValue
    }
    func sheetHistory(at sid: UUID) -> SheetHistory? {
        sheetRecorders[sid]?.sheetHistoryRecord.decodedValue
    }
    
    func makeSheetRecorder(at sid: UUID) -> SheetRecorder {
        let sheetRecoder = SheetRecorder(sheetsDirectory.makeDirectory(forKey: Self.sheetIDKey(at: sid)), sid)
        sheetRecorders[sid] = sheetRecoder
        return sheetRecoder
    }
    func removeSheetRecoder(at sid: UUID) throws {
        if let sheetRecoder = sheetRecorders[sid] {
            sheetRecorders[sid] = nil
            try sheetsDirectory.remove(sheetRecoder.directory)
        }
    }
    func remove(_ srr: SheetRecorder) throws {
        sheetRecorders[srr.sheetID] = nil
        try sheetsDirectory.remove(srr.directory)
    }
    func removeSheetHistory(at sid: UUID) throws {
        if let srr = sheetRecorders[sid] {
            try srr.directory.remove(srr.sheetHistoryRecord)
        }
    }
    func contains(at sid: UUID) -> Bool {
        sheetsDirectory.childrenURLs[Self.sheetIDKey(at: sid)] != nil
    }
}
extension Root {
    static let defaultPOV = Attitude(position: Sheet.defaultBounds.centerPoint,
                                     scale: Size(width: 1.25, height: 1.25))
}
