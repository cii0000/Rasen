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
import struct Foundation.Data
import struct Foundation.URL
import struct Foundation.UUID

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

final class Document: @unchecked Sendable {
    let url: URL
    
    let rootNode = Node()
    let sheetsNode = Node()
    let gridNode = Node(lineType: .color(.border))
    let mapNode = Node(lineType: .color(.border))
    let currentMapNode = Node(lineType: .color(.border))
    let accessoryNodeIndex = 1
    
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
    
    init(url: URL) {
        self.url = url
        
        rootDirectory = Directory(url: url)
        
        worldRecord = rootDirectory
            .makeRecord(forKey: Document.worldRecordKey)
        world = worldRecord.decodedValue ?? World()
        
        worldHistoryRecord = rootDirectory
            .makeRecord(forKey: Document.worldHistoryRecordKey)
        history = worldHistoryRecord.decodedValue ?? WorldHistory()
        
        selectionsRecord
            = rootDirectory.makeRecord(forKey: Document.selectionsRecordKey)
        selections = selectionsRecord.decodedValue ?? []
        
        findingRecord
            = rootDirectory.makeRecord(forKey: Document.findingRecordKey)
        finding = findingRecord.decodedValue ?? Finding()
        
        cameraRecord
            = rootDirectory.makeRecord(forKey: Document.cameraRecordKey)
        let camera = cameraRecord.decodedValue ?? Document.defaultCamera
        self.camera = Document.clippedCamera(from: camera)
        
        sheetsDirectory = rootDirectory
            .makeDirectory(forKey: Document.sheetsDirectoryKey)
        sheetRecorders = Document.sheetRecorders(from: sheetsDirectory)
        
        var baseThumbnailBlocks = [SheetID: Texture.Block]()
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
        self.baseThumbnailBlocks = baseThumbnailBlocks
        
        rootNode.children = [sheetsNode, gridNode, mapNode, currentMapNode]
        
        rootDirectory.changedIsWillwriteByChildrenClosure = { [weak self] (_, isWillwrite) in
            if isWillwrite {
                self?.updateAutosavingTimer()
            }
        }
        cameraRecord.willwriteClosure = { [weak self] (record) in
            guard let self else { return }
            record.value = self.camera
        }
        selectionsRecord.willwriteClosure = { [weak self] (record) in
            guard let self else { return }
            record.value = self.selections
        }
        findingRecord.willwriteClosure = { [weak self] (record) in
            guard let self else { return }
            record.value = self.finding
        }
        worldRecord.willwriteClosure = { [weak self] (record) in
            guard let self else { return }
            record.value = self.world
            self.worldHistoryRecord.value = self.history
            self.worldHistoryRecord.isPreparedWrite = true
        }
        
        if camera.rotation != 0 {
            defaultCursor = Cursor.rotate(rotation: -camera.rotation + .pi / 2)
            cursor = defaultCursor
        }
        updateTransformsWithCamera()
        updateWithWorld()
        updateWithSelections(oldValue: [])
        updateWithFinding()
        backgroundColor = isEditingSheet ? .background : .disabled
        
//        rootNode.append(child: cursorNode)
//        updateCursorNode()
    }
    deinit {
        cancelTasks()
    }
    
    func cancelTasks() {
        autosavingTimer.cancel()
        sheetViewValues.forEach {
            $0.value.workItem?.cancel()
        }
        thumbnailNodeValues.forEach {
            $0.value.workItem?.cancel()
        }
        runners.forEach { $0.cancel() }
    }
    
    let queue = DispatchQueue(label: System.id + ".queue",
                              qos: .userInteractive)
    
    let autosavingDelay = 60.0
    private var autosavingTimer = OneshotTimer()
    private func updateAutosavingTimer() {
        if !autosavingTimer.isWait {
            autosavingTimer.start(afterTime: autosavingDelay,
                                  dispatchQueue: .main,
                                  beginClosure: {}, waitClosure: {},
                                  cancelClosure: {},
                                  endClosure: { [weak self] in self?.asyncSave() })
        }
    }
    private var savingItem: DispatchWorkItem?
    private var savingFuncs = [() -> ()]()
    private func asyncSave() {
        rootDirectory.prepareToWriteAll()
        if let item = savingItem {
            item.wait()
        }
        
        let item = DispatchWorkItem(flags: .barrier) { [weak self] in
            do {
                try self?.rootDirectory.writeAll()
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.rootNode.show(error)
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.rootDirectory.resetWriteAll()
                self?.savingItem = nil
                
                self?.savingFuncs.forEach { $0() }
                self?.savingFuncs = []
            }
        }
        savingItem = item
        queue.async(execute: item)
    }
    func syncSave() {
        if autosavingTimer.isWait {
            autosavingTimer.cancel()
            autosavingTimer = OneshotTimer()
            
            rootDirectory.prepareToWriteAll()
            do {
                try rootDirectory.writeAll()
            } catch {
                rootNode.show(error)
            }
            rootDirectory.resetWriteAll()
        }
    }
    @MainActor func endSave(completionHandler: @escaping (Document?) -> ()) {
        runners.forEach { $0.cancel() }
        
        let progressPanel = ProgressPanel(message: "Saving".localized,
                                          isCancel : false,
                                          isIndeterminate: true)
        
        let timer = OneshotTimer()
        timer.start(afterTime: 2, dispatchQueue: .main,
                    beginClosure: {}, waitClosure: {},
                    cancelClosure: { progressPanel.close() },
                    endClosure: { progressPanel.show() })
        if autosavingTimer.isWait {
            autosavingTimer.cancel()
            autosavingTimer = OneshotTimer()
            rootDirectory.prepareToWriteAll()
            let workItem = DispatchWorkItem(flags: .barrier) { [weak self] in
                do {
                    try self?.rootDirectory.writeAll()
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        self?.rootNode.show(error)
                    }
                }
                DispatchQueue.main.async { [weak self] in
                    self?.rootDirectory.resetWriteAll()
                    timer.cancel()
                    progressPanel.close()
                    completionHandler(self)
                }
            }
            queue.async(execute: workItem)
        } else if let workItem = savingItem {
            workItem.notify(queue: .main) { [weak self] in
                timer.cancel()
                progressPanel.close()
                completionHandler(self)
            }
        } else {
            timer.cancel()
            progressPanel.close()
            completionHandler(self)
        }
    }
    
    let rootDirectory: Directory
    
    static let worldRecordKey = "world.pb"
    let worldRecord: Record<World>
    
    static let worldHistoryRecordKey = "world_h.pb"
    let worldHistoryRecord: Record<WorldHistory>
    
    static let selectionsRecordKey = "selections.pb"
    var selectionsRecord: Record<[Selection]>
    
    static let findingRecordKey = "finding.pb"
    var findingRecord: Record<Finding>
    
    static let cameraRecordKey = "camera.pb"
    var cameraRecord: Record<Camera>
    
    static let sheetsDirectoryKey = "sheets"
    let sheetsDirectory: Directory
    
    var world = World() {
        didSet {
            worldRecord.isWillwrite = true
        }
    }
    var history = WorldHistory()
    
    func updateWithWorld() {
        for (shp, _) in world.sheetIDs {
            let sf = sheetFrame(with: shp)
            thumbnailNode(at: shp)?.attitude.position = sf.origin
            sheetView(at: shp)?.node.attitude.position = sf.origin
        }
        updateMap()
    }
    
    func newUndoGroup() {
        history.newUndoGroup()
    }
    
    private func append(undo undoItem: WorldUndoItem,
                        redo redoItem: WorldUndoItem) {
        history.append(undo: undoItem, redo: redoItem)
    }
    @discardableResult
    private func set(_ item: WorldUndoItem, enableNode: Bool = true,
                     isMakeRect: Bool = false) -> Rect? {
        if enableNode {
            switch item {
            case .insertSheets(let sids):
                var rect = Rect?.none
                sids.forEach { (shp, sid) in
                    let sheetFrame = self.sheetFrame(with: shp)
                    let fillType = readFillType(at: sid) ?? .color(.disabled)
                    let node = Node(path: Path(sheetFrame), fillType: fillType)
                    thumbnailNodeValues[shp]?.workItem?.cancel()
                    sheetViewValues[shp]?.workItem?.cancel()
                    thumbnailNode(at: shp)?.removeFromParent()
                    sheetView(at: shp)?.node.removeFromParent()
                    sheetsNode.append(child: node)
                    thumbnailNodeValues[shp] = .init(type: thumbnailType, sheetID: sid, node: node)
                    
                    if let oldSID = world.sheetIDs[shp] {
                        world.sheetPositions[oldSID] = nil
                    }
                    world.sheetIDs[shp] = sid
                    world.sheetPositions[sid] = shp
                    
                    if isMakeRect {
                        rect += sheetFrame
                    }
                }
                updateMap()
                updateGrid(with: screenToWorldTransform, in: screenBounds)
                updateWithCursorPosition()
                return rect
            case .removeSheets(let shps):
                var rect = Rect?.none
                shps.forEach { shp in
                    if let sid = sheetID(at: shp) {
                        if isMakeRect {
                            rect += sheetFrame(with: shp)
                        }
                        
                        readAndClose(.none, at: sid, shp)
                        
                        thumbnailNode(at: shp)?.removeFromParent()
                        let tv = thumbnailNodeValues[shp]
                        thumbnailNodeValues[shp] = nil
                        tv?.workItem?.cancel()
                        
                        world.sheetPositions[sid] = nil
                    }
                    world.sheetIDs[shp] = nil
                }
                updateMap()
                updateGrid(with: screenToWorldTransform, in: screenBounds)
                updateWithCursorPosition()
                return rect
            }
        } else {
            switch item {
            case .insertSheets(let sids):
                var rect = Rect?.none
                sids.forEach { (shp, sid) in
                    let sheetFrame = self.sheetFrame(with: shp)
                    
                    if let oldSID = world.sheetIDs[shp] {
                        world.sheetPositions[oldSID] = nil
                    }
                    world.sheetIDs[shp] = sid
                    world.sheetPositions[sid] = shp
                    
                    if isMakeRect {
                        rect += sheetFrame
                    }
                }
                return rect
            case .removeSheets(let shps):
                var rect = Rect?.none
                shps.forEach { shp in
                    if let sid = sheetID(at: shp) {
                        if isMakeRect {
                            rect += sheetFrame(with: shp)
                        }
                        world.sheetPositions[sid] = nil
                    }
                    world.sheetIDs[shp] = nil
                }
                return rect
            }
        }
    }
    func append(_ sids: [Sheetpos: SheetID], enableNode: Bool = true) {
        let undoItem = WorldUndoItem.removeSheets(sids.map { $0.key })
        let redoItem = WorldUndoItem.insertSheets(sids)
        append(undo: undoItem, redo: redoItem)
        set(redoItem, enableNode: enableNode)
    }
    func removeSheets(at shps: [Sheetpos]) {
        var sids = [Sheetpos: SheetID]()
        shps.forEach {
            sids[$0] = world.sheetIDs[$0]
        }
        let undoItem = WorldUndoItem.insertSheets(sids)
        let redoItem = WorldUndoItem.removeSheets(shps)
        append(undo: undoItem, redo: redoItem)
        set(redoItem)
    }
    
    @discardableResult
    func undo(to toTopIndex: Int) -> Rect? {
        var frame = Rect?.none
        let results = history.undoAndResults(to: toTopIndex)
        for result in results {
            let item: UndoItemValue<WorldUndoItem>?
            if result.item.loadType == .unload {
                _ = history[result.version].values[result.valueIndex].loadRedoItem()
                loadCheck(with: result)
                item = history[result.version].values[result.valueIndex].undoItemValue
            } else {
                item = result.item.undoItemValue
            }
            switch result.type {
            case .undo:
                if let undoItem = item?.undoItem {
                    if let aFrame = set(undoItem, isMakeRect: true) {
                        frame += aFrame
                    }
                }
            case .redo:
                if let redoItem = item?.redoItem {
                    if let aFrame = set(redoItem, isMakeRect: true) {
                        frame += aFrame
                    }
                }
            }
        }
        return frame
    }
    func loadCheck(with result: WorldHistory.UndoResult) {
        guard let uiv = history[result.version].values[result.valueIndex]
                .undoItemValue else { return }
        
        let isReversed = result.type == .undo
        
        switch !isReversed ? uiv.undoItem : uiv.redoItem {
        case .insertSheets(let sids):
            for (shp, sid) in sids {
                if world.sheetIDs[shp] != sid {
                    history[result.version].values[result.valueIndex].error()
                    break
                }
            }
        default: break
        }
        
        switch isReversed ? uiv.undoItem : uiv.redoItem {
        case .insertSheets(_): break
        case .removeSheets(_): break
        }
    }
    
    func restoreDatabase() {
        var resetSIDs = Set<SheetID>()
        for sid in sheetRecorders.keys {
            if world.sheetPositions[sid] == nil {
                resetSIDs.insert(sid)
            }
        }
        history.rootBranch.all { (_, branch) in
            for group in branch.groups {
                for udv in group.values {
                    if let item = udv.loadedRedoItem() {
                        if case .insertSheets(let sids) = item.undoItem {
                            for sid in sids.values {
                                resetSIDs.remove(sid)
                            }
                        }
                        if case .insertSheets(let sids) = item.redoItem {
                            for sid in sids.values {
                                resetSIDs.remove(sid)
                            }
                        }
                    }
                }
            }
        }
        if !resetSIDs.isEmpty {
            moveSheetsToUpperRightCorner(with: Array(resetSIDs))
        }
    }
    func moveSheetsToUpperRightCorner(with sids: [SheetID],
                                      isNewUndoGroup: Bool = true) {
        let xCount = Int(Double(sids.count).squareRoot())
        let fxi = (world.sheetPositions.values.max { $0.x < $1.x }?.x ?? 0) + 2
        var dxi = 0
        var yi = (world.sheetPositions.values.max { $0.y < $1.y }?.y ?? 0) + 2
        var newSIDs = [Sheetpos: SheetID]()
        for sid in sids {
            let shp = Sheetpos(x: fxi + dxi, y: yi, isRight: false)
            newSIDs[shp] = sid
            dxi += 1
            if dxi >= xCount {
                dxi = 0
                yi += 1
            }
        }
        if isNewUndoGroup {
            newUndoGroup()
        }
        append(newSIDs)
        rootNode.show(message: "There are sheets added in the upper right corner because the positions data is not found.".localized)
    }
    
    func resetAllThumbnails(_ handler: (String) -> (Bool)) {
        for (i, v) in sheetRecorders.enumerated() {
            let (sheetID, sheetRecorder) = v
            guard handler("\(i) / \(sheetRecorders.count - 1)") else { return }
            autoreleasepool {
                let record = sheetRecorder.sheetRecord
                guard let sheet = record.decodedValue,
                      let shp = sheetPosition(at: sheetID) else { return }
                let sheetBinder = RecordBinder(value: sheet,
                                               record: record)
                let sheetView = SheetView(binder: sheetBinder,
                                          keyPath: \SheetBinder.value)
                let frame = self.sheetFrame(with: shp)
                sheetView.bounds = Rect(size: frame.size)
                sheetView.node.allChildrenAndSelf { $0.updateDatas() }
                
                makeThumbnailRecord(at: sheetID, with: sheetView)
                syncSave()
            }
        }
    }
    func resetAllSheets(_ handler: (String) -> (Bool)) {
        for (i, v) in sheetRecorders.enumerated() {
            let (_, sheetRecorder) = v
            guard handler("\(i) / \(sheetRecorders.count - 1)") else { return }
            autoreleasepool {
                let record = sheetRecorder.sheetRecord
                guard let sheet = record.decodedValue else { return }
                record.value = sheet
                record.isWillwrite = true
                syncSave()
            }
        }
    }
    func resetAllAnimationSheets(_ handler: (String) -> (Bool)) {
        for (i, v) in sheetRecorders.enumerated() {
            let (_, sheetRecorder) = v
            guard handler("\(i) / \(sheetRecorders.count - 1)") else { return }
            autoreleasepool {
                let record = sheetRecorder.sheetRecord
                guard let sheet = record.decodedValue else { return }
                if sheet.enabledAnimation {
                    record.value = sheet
                    record.isWillwrite = true
                    syncSave()
                }
            }
        }
    }
    func resetAllMusicSheets(_ handler: (String) -> (Bool)) {
        for (i, v) in sheetRecorders.enumerated() {
            let (_, sheetRecorder) = v
            guard handler("\(i) / \(sheetRecorders.count - 1)") else { return }
            autoreleasepool {
                let record = sheetRecorder.sheetRecord
                guard let sheet = record.decodedValue else { return }
                if sheet.enabledMusic {
                    record.value = sheet
                    record.isWillwrite = true
                    syncSave()
                }
            }
        }
    }
    func resetAllStrings(_ handler: (String) -> (Bool)) {
        for (i, v) in sheetRecorders.enumerated() {
            let (_, sheetRecorder) = v
            guard handler("\(i) / \(sheetRecorders.count - 1)") else { return }
            autoreleasepool {
                let record = sheetRecorder.sheetRecord
                guard let sheet = record.decodedValue else { return }
                sheetRecorder.stringRecord.value = sheet.allTextsString
                sheetRecorder.stringRecord.isWillwrite = true
                syncSave()
            }
        }
    }
    
    func clearHistory(progressHandler: (Double, inout Bool) -> ()) {
        syncSave()
        
        var resetSRRs = [SheetID: SheetRecorder]()
        for (sid, srr) in sheetRecorders {
            if world.sheetPositions[sid] == nil {
                resetSRRs[sid] = srr
            }
        }
        var isStop = false
        if !resetSRRs.isEmpty {
            for (i, v) in resetSRRs.enumerated() {
                remove(v.value)
                sheetRecorders[v.key] = nil
                progressHandler(Double(i + 1) / Double(resetSRRs.count), &isStop)
                if isStop { break }
            }
        }
        
        history.reset()
        worldHistoryRecord.value = history
        worldHistoryRecord.isWillwrite = true
    }
    
    func clearContents(from sheetView: SheetView) {
        if let directory = sheetRecorders[sheetView.id]?.contentsDirectory {
            let nUrls = Set(sheetView.model.contents.map { $0.url })
            directory.childrenURLs.filter { !nUrls.contains($0.value) }.forEach {
                try? directory.remove(from: $0.value, key: $0.key)
            }
        }
    }
    
    var defaultCursor = Cursor.drawLine
    var cursorNotifications = [((Document, Cursor) -> ())]()
    var cursor = Cursor.drawLine {
        didSet {
            guard cursor != oldValue else { return }
            cursorNotifications.forEach { $0(self, cursor) }
        }
    }
    
    static let defaultBackgroundColor = Color.background
    var backgroundColorNotifications = [((Document, Color) -> ())]()
    var backgroundColor = Document.defaultBackgroundColor {
        didSet {
            guard backgroundColor != oldValue else { return }
            backgroundColorNotifications.forEach { $0(self, backgroundColor) }
        }
    }
    
    static let maxSheetCount = 10000
    static let maxSheetAABB = AABB(maxValueX: Double(maxSheetCount) * Sheet.width,
                                   maxValueY: Double(maxSheetCount) * Sheet.height)
    static let minCameraLog2Scale = -12.0, maxCameraLog2Scale = 10.0
    static func clippedCameraPosition(from p: Point) -> Point {
        var p = p
        if p.x < maxSheetAABB.minX {
            p.x = maxSheetAABB.minX
        } else if p.x > maxSheetAABB.maxX {
            p.x = maxSheetAABB.maxX
        }
        if p.y < maxSheetAABB.minY {
            p.y = maxSheetAABB.minY
        } else if p.y > maxSheetAABB.maxY {
            p.y = maxSheetAABB.maxY
        }
        return p
    }
    static func clippedCamera(from camera: Camera) -> Camera {
        var camera = camera
        camera.position = clippedCameraPosition(from: camera.position)
        let s = camera.scale.width
        if s != camera.scale.height {
            camera.scale = Size(square: s)
        }
        
        let logScale = camera.logScale
        if logScale.isNaN {
            camera.logScale = 0
        } else if logScale < minCameraLog2Scale {
            camera.logScale = minCameraLog2Scale
        } else if logScale > maxCameraLog2Scale {
            camera.logScale = maxCameraLog2Scale
        }
        return camera
    }
    static let defaultCamera
        = Camera(position: Sheet.defaultBounds.centerPoint,
                 scale: Size(width: 1.25, height: 1.25))
    var cameraNotifications = [((Document, Camera) -> ())]()
    var camera = Document.defaultCamera {
        didSet {
            updateTransformsWithCamera()
            cameraRecord.isWillwrite = true
            cameraNotifications.forEach { $0(self, camera) }
        }
    }
    var drawableSize = Size() {
        didSet {
            updateNode()
        }
    }
    var screenBounds = Rect() {
        didSet {
            centeringCameraTransform = Transform(translation: -screenBounds.centerPoint)
            viewportToScreenTransform = Transform(viewportSize: screenBounds.size)
            screenToViewportTransform = Transform(invertedViewportSize: screenBounds.size)
            updateTransformsWithCamera()
        }
    }
    var worldBounds: Rect { screenBounds * screenToWorldTransform }
    private(set) var screenToWorldTransform = Transform.identity
    var screenToWorldScale: Double { screenToWorldTransform.absXScale }
    private(set) var worldToScreenTransform = Transform.identity
    private(set) var worldToScreenScale = 1.0
    private(set) var centeringCameraTransform = Transform.identity
    private(set) var viewportToScreenTransform = Transform.identity
    private(set) var screenToViewportTransform = Transform.identity
    private(set) var worldToViewportTransform = Transform.identity
    private func updateTransformsWithCamera() {
        screenToWorldTransform = centeringCameraTransform * camera.transform
        worldToScreenTransform = screenToWorldTransform.inverted()
        worldToScreenScale = worldToScreenTransform.absXScale
        worldToViewportTransform = worldToScreenTransform * screenToViewportTransform
        updateNode()
    }
    func updateNode() {
        guard !drawableSize.isEmpty else { return }
        thumbnailType = self.thumbnailType(withScale: worldToScreenScale)
        readAndClose(with: screenBounds, screenToWorldTransform)
        updateMapWith(worldToScreenTransform: worldToScreenTransform,
                      screenToWorldTransform: screenToWorldTransform,
                      camera: camera,
                      in: screenBounds)
        updateGrid(with: screenToWorldTransform, in: screenBounds)
        updateEditorNode()
        updateRunnerNodesPosition()
        updateSheetViewsWithCamera()
//        updateCursorNode()
    }
    let editableMapScale = 2.0 ** -4
    var isEditingSheet: Bool {
        worldToScreenScale > editableMapScale
    }
    var worldLineWidth: Double {
        Line.defaultLineWidth * screenToWorldScale
    }
    func convertScreenToWorld<T: AppliableTransform>(_ v: T) -> T {
        v * screenToWorldTransform
    }
    func convertWorldToScreen<T: AppliableTransform>(_ v: T) -> T {
        v * worldToScreenTransform
    }
    
    func roundedPoint(from p: Point) -> Point {
        Self.roundedPoint(from: p, scale: worldToScreenScale)
    }
    static func roundedPoint(from p: Point, scale: Double) -> Point {
        let decimalPlaces = Int(max(0, .log10(scale)) + 2)
        return p.rounded(decimalPlaces: decimalPlaces)
    }
    
    func updateSheetViewsWithCamera() {
        sheetViewValues.forEach {
            if let view = $0.value.view {
                updateWithIsFullEdit(in: view)
                view.screenToWorldScale = screenToWorldScale
            }
        }
    }
    func updateWithIsFullEdit(in sheetView: SheetView) {
        let isFullEdit = isFullEditNote
        sheetView.textsView.elementViews.forEach { $0.isFullEdit = isFullEdit }
        sheetView.contentsView.elementViews.forEach { $0.isFullEdit = isFullEdit }
        sheetView.scoreView.isFullEdit = isFullEdit
        sheetView.animationView.isFullEdit = isFullEdit
    }
    
    var colorSpace = Color.defaultColorSpace
    
    var sheetLineWidth: Double { Line.defaultLineWidth }
    var sheetTextSize: Double { camera.logScale > 2 ? 100.0 : Font.defaultSize }
    
    var selections = [Selection]() {
        didSet {
            selectionsRecord.isWillwrite = true
            updateWithSelections(oldValue: oldValue)
        }
    }
    var multiSelection: MultiSelection {
        MultiSelection(selections: selections)
    }
    func sheetposWithSelection() -> [Sheetpos] {
        world.sheetIDs.keys.compactMap {
            multiSelection
                .intersects(sheetFrame(with: $0)) ? $0 : nil
        }
    }
    private(set) var selectedNode: Node?, selectedOrientationNode: Node?
    private(set) var selectedFrames = [Rect](), selectedFramesNode: Node?
    private(set) var selectedClippedFrame: Rect?, selectedClippedNode: Node?
    private(set) var selectedLinesNode: Node?,
                     selectedLineNodes = [Line: Node]()
    private(set) var selectedNotesNode: Node?,
                     selectedNoteNodes = [Pointline: Node]()
    private(set) var isOldSelectedSheet = false, isSelectedText = false
    func updateWithSelections(oldValue: [Selection]) {
        if !selections.isEmpty {
            if oldValue.isEmpty {
                let oNode = Node()
                selectedOrientationNode = oNode
                rootNode.append(child: oNode)
                
                let node = Node(lineWidth: Line.defaultLineWidth,
                                lineType: .color(.selected),
                                fillType: .color(.subSelected))
                selectedNode = node
                rootNode.append(child: node)
                
                let soNode = Node()
                selectedFramesNode = soNode
                rootNode.append(child: soNode)
                
                let slNode = Node()
                selectedLinesNode = slNode
                rootNode.append(child: slNode)
                
                let snNode = Node()
                selectedNotesNode = snNode
                rootNode.append(child: snNode)
                
                let ssNode = Node(lineWidth: Line.defaultLineWidth,
                                  lineType: .color(.selected),
                                  fillType: .color(.subSelected))
                selectedClippedNode = ssNode
                rootNode.append(child: ssNode)
                
                isOldSelectedSheet = isEditingSheet
            }
            updateSelects()
            updateSelectedNode()
        } else {
            selectedFrames = []
            if !oldValue.isEmpty {
                selectedNode?.removeFromParent()
                selectedOrientationNode?.removeFromParent()
                selectedFramesNode?.removeFromParent()
                selectedLinesNode?.removeFromParent()
                selectedNotesNode?.removeFromParent()
                selectedClippedNode?.removeFromParent()
                selectedNode = nil
                selectedOrientationNode = nil
                selectedFramesNode = nil
                selectedLinesNode = nil
                selectedNotesNode = nil
                selectedClippedNode = nil
            }
        }
    }
    func updateSelects() {
        guard !selections.isEmpty else { 
            for key in selectedLineNodes.keys {
                selectedLineNodes[key]?.removeFromParent()
                selectedLineNodes[key] = nil
            }
            return
        }
        let centerSHPs = Set(self.centerSHPs)
        var rectsSet = Set<Rect>()
        var rects = [Rect](), isSelectedText = false, selectedCount = 0
        var firstOrientation = Orientation.horizontal, lineNodes = [Node]()
        var sLines = [Line](), sPointlines = [Pointline]()
        var addedLineIndexes = Set<IntPoint>()
        var cr: Rect?, oldRect: Rect?
        for selection in selections {
            let rect = selection.rect
            if isEditingSheet {
                sheetViewValues.enumerated().forEach { (si, svv) in
                    guard let shp = sheetPosition(at: svv.value.sheetID),
                          centerSHPs.contains(shp) else { return }
                    let frame = sheetFrame(with: shp)
                    guard let inFrame = rect.intersection(frame) else { return }
                    guard let sheetView = svv.value.view else { return }
                    let rectInSheet = sheetView.convertFromWorld(selection.rect)
                    cr = cr == nil ? inFrame : cr!.union(inFrame)
                    for textView in sheetView.textsView.elementViews {
                        let nRect = textView.convertFromWorld(rect)
                        guard textView.intersectsHalf(nRect) else { continue }
                        let tfp = textView.convertFromWorld(selection.firstOrigin)
                        let tlp = textView.convertFromWorld(selection.lastOrigin)
                        if textView.characterIndex(for: tfp) != nil {
                            isSelectedText = true
                        }
                        
                        guard let fi = textView.characterIndexWithOutOfBounds(for: tfp),
                              let li = textView.characterIndexWithOutOfBounds(for: tlp) else { continue }
                        let range = fi < li ? fi ..< li : li ..< fi
                        for nf in textView.transformedPaddingRects(with: range) {
                            let frame = sheetView.convertToWorld(nf)
                            if !rectsSet.contains(frame) {
                                rects.append(frame)
                                rectsSet.insert(frame)
                            }
                        }
                        if selectedCount == 0 {
                            firstOrientation = textView.model.orientation
                        }
                        selectedCount += 1
                    }
                    
                    //
                    for (li, lineView) in sheetView.linesView.elementViews.enumerated() {
                        let sli = IntPoint(si, li)
                        if !addedLineIndexes.contains(sli),
                            lineView.intersects(rectInSheet) {
                            if case .line(let line) =  lineView.node.path.pathlines.first?.elements.first,
                               case .color(let color) = lineView.node.lineType {//
                                
                                var nLine = sheetView.convertToWorld(line)
                                nLine.uuColor.value = color//
                                sLines.append(nLine)
                                addedLineIndexes.insert(sli)
                            }
                        }
                    }
                    
//                    for (li, lineView) in sheetView.linesView.elementViews.enumerated() {
//                        let sli = IntPoint(si, li)
//                        if !addedLineIndexes.contains(sli),
//                            lineView.intersects(rectInSheet) {
//                            if case .line(let line) =  lineView.node.path.pathlines.first?.elements.first,
//                               case .color(let color) = lineView.node.lineType {//
//                                
//                                var nLine = sheetView.convertToWorld(line)
//                                nLine.uuColor.value = color//
//                                sLines.append(nLine)
//                                addedLineIndexes.insert(sli)
//                            }
//                        }
//                    }
                    
                    let scoreView = sheetView.scoreView
                    if scoreView.model.enabled {
                        let score = sheetView.scoreView.model
                        let nis = sheetView.noteIndexes(from: selections)
                        if !nis.isEmpty {
                            for ni in nis {
                                var nLine = scoreView.pointline(from: score.notes[ni])
                                nLine = sheetView.convertToWorld(nLine)
                                sPointlines.append(nLine)
                            }
                        }
                    }
                }
                if selectedCount == 1 && rects.count >= 2 {
                    let r0 = rects[0], r1 = rects[1]
                    switch firstOrientation {
                    case .horizontal:
                        let w = r0.minX - r1.maxX
                        if w > 0 {
                            lineNodes.append(Node(path: Path(Edge(r0.minXMinYPoint,
                                                                  r1.maxXMaxYPoint)),
                                                  lineWidth: worldLineWidth,
                                                  lineType: .color(.selected)))
                        }
                    case .vertical:
                        let h = r1.minY - r0.maxY
                        if h > 0 {
                            lineNodes.append(Node(path: Path(Edge(r0.minXMaxYPoint,
                                                                  r1.maxXMinYPoint)),
                                                  lineWidth: worldLineWidth,
                                                  lineType: .color(.selected)))
                        }
                    }
                }
                if selections.count == 1 {
                    if let cr = cr, cr != rect, isEditingSheet {
                        selectedClippedNode?.lineWidth = worldLineWidth
                        selectedClippedNode?.path = Path(cr)
                    } else {
                        selectedClippedNode?.path = Path()
                    }
                    selectedClippedFrame = cr
                }
            } else {
                world.sheetIDs.keys.forEach {
                    let frame = sheetFrame(with: $0)
                    guard rect.intersects(frame) else { return }
                    if !rectsSet.contains(frame) {
                        rects.append(frame)
                        rectsSet.insert(frame)
                    }
                }
            }
            if let oldRect = oldRect, let pathline = selection.rect.minLine(oldRect) {
                lineNodes.append(Node(path: Path([pathline]),
                                      lineWidth: worldLineWidth,
                                      lineType: .color(.selected)))
            }
            oldRect = selection.rect
        }
        
        selectedFramesNode?.children = rects.map {
            Node(path: Path($0),
                 lineWidth: worldLineWidth,
                 lineType: .color(.selected),
                 fillType: .color(.subSelected))
        } + lineNodes
        
        let sLinesSet = Set(sLines)
        for key in selectedLineNodes.keys {
            if !sLinesSet.contains(key) {
                selectedLineNodes[key]?.removeFromParent()
                selectedLineNodes[key] = nil
            }
        }
        for sLine in sLines {
            if selectedLineNodes[sLine] == nil {
                let node = Node(path: Path(sLine),
                                lineWidth: sLine.size * 1.5,
                                lineType: .color(.linear(.selected, sLine.uuColor.value, t: sLine.uuColor.value.lightness / 100 * 0.5)))
                selectedLineNodes[sLine] = node
                selectedLinesNode?.append(child: node)
            }
        }
        
        let sPointlinesSet = Set(sPointlines)
        for key in selectedNoteNodes.keys {
            if !sPointlinesSet.contains(key) {
                selectedNoteNodes[key]?.removeFromParent()
                selectedNoteNodes[key] = nil
            }
        }
        for sPointline in sPointlines {
            if selectedNoteNodes[sPointline] == nil {
                let node = Node(path: Path(sPointline.controls.map { $0.point }),
                                lineWidth: worldLineWidth * 1.5,
                                lineType: .color(.selected))
                selectedNoteNodes[sPointline] = node
                selectedNotesNode?.append(child: node)
            }
        }
        
        selectedFrames = rects
        self.isSelectedText = isSelectedText && selectedCount == 1
    }
    func updateSelectedNode() {
        guard !selections.isEmpty else { return }
        let l = worldLineWidth
        
        if let cr = selectedClippedFrame, cr != selections.first?.rect, isEditingSheet {
            selectedClippedNode?.lineWidth = l
            selectedClippedNode?.path = Path(cr)
        } else {
            selectedClippedNode?.path = Path()
        }
        selectedNode?.isHidden = isSelectedText
//        selectedNode?.lineWidth = l
//        selectedNode?.path = Path(rect)
        selectedNode?.children = selections.map {
            Node(path: Path($0.rect),
                 lineWidth: l,
                 lineType: .color(.selected),
                 fillType: .color(.subSelected))
        }
        
        let attitude = Attitude(screenToWorldTransform)
        selectedOrientationNode?.isHidden = isSelectedText
        selectedOrientationNode?.children = selections.map {
            var nAttitude = attitude
            switch $0.rectCorner {
            case .minXMinY: nAttitude.position = $0.rect.minXMinYPoint
            case .minXMaxY: nAttitude.position = $0.rect.minXMaxYPoint
            case .maxXMinY: nAttitude.position = $0.rect.maxXMinYPoint
            case .maxXMaxY: nAttitude.position = $0.rect.maxXMaxYPoint
            }
            return Node(attitude: nAttitude,
                        path: Path(circleRadius: 3),
                        fillType: .color(.selected))
        }
        
        selectedFramesNode?.children.forEach { $0.lineWidth = l }
        
        let isS = isEditingSheet
        if isS != isOldSelectedSheet {
            isOldSelectedSheet = isS
            updateSelects()
        }
    }
    func isSelect(at p: Point) -> Bool {
        let d = 1.0 * screenToWorldScale
        if isSelectedText {
            return selectedFrames.contains(where: { $0.outset(by: d).contains(p) })
        } else {
            for s in selections {
                let r = s.rect
                if r.outset(by: d).contains(p) {
                    return true
                }
            }
            return selectedFrames.contains(where: { $0.outset(by: d).contains(p) })
        }
    }
    func isSelect(at rect: Rect) -> Bool {
        let d = 1.0 * screenToWorldScale
        if isSelectedText {
            return selectedFrames.contains(where: { $0.outset(by: d).intersects(rect) })
        } else {
            for s in selections {
                let r = s.rect
                if r.outset(by: d).intersects(rect) {
                    return true
                }
            }
            return selectedFrames.contains(where: { $0.outset(by: d).intersects(rect) })
        }
    }
    func updateSelectedColor(isMain: Bool) {
        if !selections.isEmpty {
            let selectedColor = isMain ? Color.selected : Color.diselected
            let subSelectedColor = isMain ? Color.subSelected : Color.subDiselected
            selectedNode?.children.forEach {
                $0.fillType = .color(subSelectedColor)
                $0.lineType = .color(selectedColor)
            }
            selectedClippedNode?.fillType = .color(subSelectedColor)
            selectedClippedNode?.lineType = .color(selectedColor)
            selectedFramesNode?.children.forEach {
                $0.fillType = .color(subSelectedColor)
                $0.lineType = .color(selectedColor)
            }
            selectedLinesNode?.children.forEach {
                $0.lineType = .color(selectedColor)
            }
            selectedNotesNode?.children.forEach {
                $0.lineType = .color(selectedColor)
            }
            selectedOrientationNode?.children.forEach {
                $0.fillType = .color(selectedColor)
            }
        }
    }
    
    var finding = Finding() {
        didSet {
            findingRecord.isWillwrite = true
            updateWithFinding()
        }
    }
    private var findingNode: Node?
    private(set) var findingNodes = [Sheetpos: Node]()
    let findingSplittedWidth
        = (Double.hypot(Sheet.width / 2, Sheet.height / 2) * 1.25).rounded()
    var findingLineWidth: Double {
        isEditingFinding ? worldLineWidth * 2 : worldLineWidth
    }
    var isEditingFinding = false {
        didSet {
            guard isEditingFinding != oldValue else { return }
            let l = findingLineWidth
            findingNodes.forEach { v in
                v.value.children.forEach { $0.lineWidth = l }
            }
            if !isEditingFinding {
                editingFindingSheetView = nil
                editingFindingTextView = nil
                editingFindingRange = nil
                editingFindingOldString = nil
                editingFindingOldRemovedString = nil
            }
        }
    }
    weak var editingFindingSheetView: SheetView?,
             editingFindingTextView: SheetTextView?
    var editingFindingRange: Range<Int>?,
        editingFindingOldString: String?,
        editingFindingOldRemovedString: String?
    func updateWithFinding() {
        guard !finding.isEmpty else {
            if findingNode != nil {
                findingNodes = [:]
                findingNode?.removeFromParent()
                findingNode = nil
            }
            return
        }
        
        let isSelected = isSelect(at: finding.worldPosition)
        var nodes = [Node]()
        var findingNodes = [Sheetpos: Node]()
        for sr in sheetRecorders {
            guard let shp = sheetPosition(at: sr.key) else { continue }
            if isSelected && !isSelect(at: sheetFrame(with: shp)) { continue }
            let string = sheetViewValues[shp]?.view?.model.allTextsString
                ?? sr.value.stringRecord.decodedValue
            if string?.contains(finding.string) ?? false {
                let node = Node()
                findingNodes[shp] = node
                nodes.append(node)
            }
        }
        
        self.findingNodes = findingNodes
        findingNode?.removeFromParent()
        let node = Node(children: nodes)
        rootNode.append(child: node)
        findingNode = node
        findingNodes.forEach { updateFindingNodes(at: $0.key) }
    }
    func updateFinding(at p: Point) {
        guard !finding.isEmpty else { return }
        if let sheetView = sheetView(at: p) {
            updateFinding(from: sheetView)
        }
    }
    func updateFinding(from sheetView: SheetView) {
        guard !finding.isEmpty,
              let shp = sheetPosition(from: sheetView) else { return }
        updateFindingNodes(at: shp)
    }
    func sheetPosition(from sheetView: SheetView) -> Sheetpos? {
        for svv in sheetViewValues {
            if sheetView == svv.value.view {
                return svv.key
            }
        }
        return nil
    }
    private func updateFindingNodes(at shp: Sheetpos) {
        guard let node = findingNodes[shp] else { return }
        
        let sf = sheetFrame(with: shp)
        let l = findingLineWidth, p: Point
        var nodes = [Node]()
        if finding.worldPosition.distance(sf.centerPoint) < findingSplittedWidth {
            p = finding.worldPosition
        } else {
            let angle = sf.centerPoint.angle(finding.worldPosition)
            p = sf.centerPoint.movedWith(distance: findingSplittedWidth,
                                         angle: angle)
            let node = Node(path: Path([Pathline([finding.worldPosition, p])]),
                            lineWidth: l,
                            lineType: .color(.selected))
            nodes.append(node)
        }
        if let nSheetView = sheetView(at: shp) {
            let isSelected = isSelect(at: finding.worldPosition)
            
            for textView in nSheetView.textsView.elementViews {
                let text = textView.model
                
                var ranges = text.string.ranges(of: finding.string)
                if nSheetView == editingFindingSheetView
                    && textView == editingFindingTextView,
                   let oldRemovedString = editingFindingOldRemovedString,
                   let (intRange, substring) = oldRemovedString
                    .difference(to: textView.model.string) {
                    
                    let nr = intRange.lowerBound ..< (intRange.lowerBound + substring.count)
                    let editingRange = textView.model.string.range(fromInt: nr)
                    ranges = ranges.filter { !$0.intersects(editingRange) }
                    ranges.append(editingRange)
                }
                
                for range in ranges {
                    var rects = textView.transformedPaddingRects(with: range).map {
                        nSheetView.convertToWorld($0)
                    }
                    if isSelected {
                        rects = rects.filter { isSelect(at: $0) }
                    }
                    rects.forEach {
                        nodes.append(Node(path: Path($0),
                                          lineWidth: l,
                                          lineType: .color(.selected),
                                          fillType: .color(.subSelected)))
                    }
                    if let rect = rects.first {
                        nodes.append(Node(path: Path([Pathline([p,
                                                                rect.centerPoint])]),
                                          lineWidth: l,
                                          lineType: .color(.selected)))
                    }
                    if rects.count >= 2 {
                        let r0 = rects[0], r1 = rects[1]
                        switch text.orientation {
                        case .horizontal:
                            let w = r0.minX - r1.maxX
                            if w > 0 {
                                nodes.append(Node(path: Path(Edge(r0.minXMinYPoint,
                                                                      r1.maxXMaxYPoint)),
                                                      lineWidth: l,
                                                      lineType: .color(.selected)))
                            }
                        case .vertical:
                            let h = r1.minY - r0.maxY
                            if h > 0 {
                                nodes.append(Node(path: Path(Edge(r0.minXMaxYPoint,
                                                                      r1.maxXMinYPoint)),
                                                      lineWidth: l,
                                                      lineType: .color(.selected)))
                            }
                        }
                    }
                }
            }
            if let uuid = UUID(uuidString: finding.string) {
                for planeView in nSheetView.planesView.elementViews {
                    if planeView.model.uuColor.id == uuid {
                        if let pp = planeView.model.topolygon.polygon.points.first {
                            let ppp = nSheetView.convertToWorld(pp)
                            nodes.append(Node(path: Path([Pathline([p,
                                                                    ppp])]),
                                              lineWidth: l,
                                              lineType: .color(.selected)))
                        }
                    }
                }
            }
        } else {
            nodes.append(Node(path: Path(sf),
                              lineWidth: l,
                              lineType: .color(.selected),
                              fillType: .color(.subSelected)))
            nodes.append(Node(path: Path([Pathline([p,
                                                    sf.centerPoint])]),
                              lineWidth: l,
                              lineType: .color(.selected)))
        }
        node.children = nodes
    }
    func updateFindingNodes() {
        if !findingNodes.isEmpty {
            let l = findingLineWidth
            findingNodes.values.forEach {
                $0.children.forEach { $0.lineWidth = l }
            }
        }
    }
    func findingNode(at p: Point) -> Node? {
        let shp = sheetPosition(at: p)
        for (nshp, node) in findingNodes {
            guard nshp == shp else { continue }
            for child in node.children {
                if child.contains(p) {
                    return child
                }
            }
        }
        return nil
    }
    func replaceFinding(from toStr: String,
                        oldString: String? = nil,
                        oldTextView: SheetTextView? = nil) {
        let fromStr = finding.string
        @Sendable func make(isRecord: Bool = false) {
            @Sendable func make(_ sheetView: SheetView) -> Bool {
                var isNewUndoGroup = true
                func updateUndoGroup() {
                    if isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = false
                    }
                }
                let sb = sheetView.bounds.inset(by: Sheet.textPadding)
                for (i, textView) in sheetView.textsView.elementViews.enumerated() {
                    var text = textView.model
                    if text.string.contains(fromStr) {
                        let rRange = 0 ..< text.string.count
                        var ns = text.string
                        if let oldString = oldString, let oldTextView = oldTextView,
                           oldTextView == textView {
                            ns = oldString
                        }
                        ns = ns.replacingOccurrences(of: fromStr, with: toStr)
                        text.replaceSubrange(ns, from: rRange, clipFrame: sb)
                        let origin = textView.model.origin != text.origin ?
                            text.origin : nil
                        let size = textView.model.size != text.size ?
                            text.size : nil
                        let widthCount = textView.model.widthCount != text.widthCount ?
                            text.widthCount : nil
                        let tv = TextValue(string: ns,
                                           replacedRange: rRange,
                                           origin: origin, size: size,
                                           widthCount: widthCount)
                        updateUndoGroup()
                        sheetView.replace(IndexValue(value: tv, index: i))
                    }
                }
                return !isNewUndoGroup
            }
            
            if isRecord {
                syncSave()
                
                let progressPanel = ProgressPanel(message: "Replacing sheets".localized)
                rootNode.show(progressPanel)
                let task = Task.detached {
                    let progress = ActorProgress(total: self.findingNodes.count)
                    for v in self.findingNodes {
                        Task { @MainActor in
                            let shp = v.key
                            if let sheetView = self.sheetViewValues[shp]?.view {
                                _ = make(sheetView)
                            } else if let sid = self.sheetID(at: shp),
                                      let sheetRecorder = self.sheetRecorders[sid] {
                                let record = sheetRecorder.sheetRecord
                                guard let sheet = record.decodedValue else { return }
                                
                                let sheetBinder = RecordBinder(value: sheet, record: record)
                                let sheetView = SheetView(binder: sheetBinder, keyPath: \SheetBinder.value)
                                let frame = self.sheetFrame(with: shp)
                                sheetView.bounds = Rect(size: frame.size)
                                sheetView.node.allChildrenAndSelf { $0.updateDatas() }
                                
                                if make(sheetView) {
                                    if self.savingItem != nil {
                                        self.savingFuncs.append { [model = sheetView.model, um = sheetView.history,
                                                                   tm = self.thumbnailMipmap(from: sheetView),
                                                                   weak self] in
                                            
                                            sheetRecorder.sheetRecord.value = model
                                            sheetRecorder.sheetRecord.isWillwrite = true
                                            sheetRecorder.sheetHistoryRecord.value = um
                                            sheetRecorder.sheetHistoryRecord.isWillwrite = true
                                            self?.updateStringRecord(at: sid, with: sheetView)
                                            if let tm = tm {
                                                self?.saveThumbnailRecord(tm, in: sheetRecorder)
                                                self?.baseThumbnailBlocks[sid]
                                                = try? Texture.block(from: tm.thumbnail4Data)
                                            }
                                        }
                                    } else {
                                        sheetRecorder.sheetRecord.value = sheetView.model
                                        sheetRecorder.sheetHistoryRecord.value = sheetView.history
                                        sheetRecorder.sheetHistoryRecord.isWillwrite = true
                                        self.makeThumbnailRecord(at: sid, with: sheetView)
                                        sheetRecorder.sheetRecord.willwriteClosure = { (_) in }
                                    }
                                }
                            }
                        }
                        
                        guard !Task.isCancelled else { return }
                        Sleep.start(atTime: 0.1)
                        
                        await progress.addCount()
                        Task { @MainActor in
                            progressPanel.progress = await progress.fractionCompleted
                        }
                    }

                    Task { @MainActor in
                        progressPanel.closePanel()
                        self.finding.string = toStr
                    }
                }
                progressPanel.cancelHandler = { task.cancel() }
            } else {
                for (shp, _) in findingNodes {
                    if let sheetView = sheetViewValues[shp]?.view {
                        _ = make(sheetView)
                    }
                }
                finding.string = toStr
            }
        }
        
        var recordCount = 0
        for (shp, _) in findingNodes {
            if sheetViewValues[shp]?.view == nil,
               let sid = sheetID(at: shp),
               sheetRecorders[sid] != nil {
                recordCount += 1
            }
        }
        if recordCount > 0 {
            for (shp, _) in findingNodes {
                if sheetViewValues[shp]?.view != nil,
                   let sid = sheetID(at: shp),
                   sheetRecorders[sid] != nil {
                    recordCount += 1
                }
            }
            let nRecordCount = recordCount
            
            Task { @MainActor in
                let result = await rootNode
                    .show(message: String(format: "Do you want to replace the \"%2$@\" written on the %1$d sheets with the \"%3$@\"?".localized, nRecordCount, fromStr.omit(count: 12), toStr.omit(count: 12)),
                              infomation: "This operation can be undone for each sheet, but not for all sheets at once.".localized,
                              okTitle: "Replace".localized,
                              isDefaultButton: true)
                switch result {
                case .ok: make(isRecord: true)
                case .cancel: break
                }
            }
        } else {
            make()
        }
    }
    
    func string(at p: Point) -> String? {
        if isSelect(at: p), !selections.isEmpty {
            let se = LineEditor(self)
            se.updateClipBoundsAndIndexRange(at: p)
            if let r = selections.map({ $0.rect }).union() {
                se.tempLine = Line(r) * Transform(translation: -se.centerOrigin)
                let value = se.sheetValue(isRemove: false,
                                          isEnableLine: !isSelectedText,
                                          isEnablePlane: !isSelectedText,
                                          selections: selections,
                                          at: p)
                if !value.isEmpty {
                    return value.allTextsString
                }
            }
        } else if let sheetView = sheetView(at: p),
                  let textView = sheetView.textTuple(at: sheetView.convertFromWorld(p))?.textView {
            
            return textView.model.string
        }
        return nil
    }
    
    func containsLookingUp(at wp: Point) -> Bool {
        lookingUpBoundsNode?.path
            .contains(lookingUpNode.convertFromWorld(wp)) ?? false
    }
    private(set) var isShownLookingUp = false
    private(set) var lookingUpNode = Node(), lookingUpBoundsNode: Node?,
                     lookingUpString = ""
    func show(_ string: String, at origin: Point) {
        show(string,
             fromSize: isEditingSheet ? Font.defaultSize : 400,
             rects: [Rect(origin: origin)],
             .horizontal,
             clipRatio: isEditingSheet ? 1 : nil)
    }
    func show(_ string: String, fromSize: Double, toSize: Double = 8,
              rects: [Rect], _ orientation: Orientation,
              clipRatio: Double? = 1,
              padding: Double = 3,
              textPadding: Double = 3,
              cornerRadius: Double = 4) {
        closeLookingUpNode()
        guard !rects.isEmpty else {
            lookingUpString = ""
            return
        }
        let ratio = clipRatio != nil ?
            min(fromSize / Font.defaultSize, clipRatio!) :
            fromSize / Font.defaultSize
        let origin: Point
        let pd = (padding + 3.75 + textPadding + toSize / 2 + 1) * ratio
        let lpd = padding * ratio
        var backNodes = [Node](), lineNodes = [Node]()
        func backNode(from path: Path) -> Node {
            return Node(path: path,
                        lineWidth: 1 * ratio,
                        lineType: .color(.subBorder),
                        fillType: .color(.transparentDisabled))
        }
        func lineNode(from path: Path) -> Node {
            return Node(path: path,
                        lineWidth: 1 * ratio,
                        lineType: .color(.subBorder),
                        fillType: .color(.transparentDisabled))
        }
        if rects.count == 1 && rects[0].size.isEmpty {
            let fOrigin = rects[0].origin
            origin = fOrigin + Point(0, -pd)
            backNodes = [Node(path: Path(circleRadius: 3 * ratio,
                                         position: fOrigin),
                              lineWidth: 1 * ratio,
                              lineType: .color(.subBorder),
                              fillType: .color(.transparentDisabled))]
            lineNodes = [Node(path: Path(circleRadius: 1 * ratio,
                                         position: fOrigin),
                              fillType: .color(.content))]
        } else {
            switch orientation {
            case .horizontal:
                origin = rects[0].minXMinYPoint + Point(0, -pd)
                backNodes = rects.map {
                    let rect = Rect(Edge($0.minXMinYPoint + Point(0, -lpd),
                                         $0.maxXMinYPoint + Point(0, -lpd)))
                    return backNode(from: Path(rect.inset(by: -2 * ratio),
                                               cornerRadius: 1 * ratio))
                }
                lineNodes = rects.map {
                    Node(path: Path(Edge($0.minXMinYPoint + Point(0, -lpd),
                                         $0.maxXMinYPoint + Point(0, -lpd))),
                         lineWidth: 1 * ratio, lineType: .color(.content))
                }
            case .vertical:
                origin = rects[0].minXMaxYPoint + Point(-pd, 0)
                backNodes = rects.map {
                    let rect = Rect(Edge($0.minXMaxYPoint + Point(-lpd, 0),
                                         $0.minXMinYPoint + Point(-lpd, 0)))
                    return backNode(from: Path(rect.inset(by: -2 * ratio),
                                               cornerRadius: 1 * ratio))
                }
                lineNodes = rects.map {
                    Node(path: Path(Edge($0.minXMaxYPoint + Point(-lpd, 0),
                                         $0.minXMinYPoint + Point(-lpd, 0))),
                         lineWidth: 1 * ratio, lineType: .color(.content))
                }
            }
        }
        let text = Text(string: string, orientation: orientation,
                        size: toSize * ratio, widthCount: 30, origin: origin)
        var typobute = text.typobute
        typobute.clippedMaxTypelineWidth = text.size * 30
        let typesetter = Typesetter(string: text.string, typobute: typobute)
        guard let b = typesetter.typoBounds?
                .outset(by: (toSize / 2 + 1) * ratio) else { return }
        let textNode = Node(attitude: Attitude(position: text.origin),
                            path: typesetter.path(), fillType: .color(.content))
        let boundsNode = Node(path: Path(b + text.origin,
                                         cornerRadius: cornerRadius * ratio),
                              lineWidth: 1 * ratio,
                              lineType: .color(.subBorder),
                              fillType: .color(.transparentDisabled))
        lookingUpNode.children = backNodes + lineNodes + [boundsNode, textNode]
        lookingUpBoundsNode = boundsNode
        if lookingUpNode.parent == nil {
            rootNode.append(child: lookingUpNode)
        }
        isShownLookingUp = true
        lookingUpString = string
    }
    func closeLookingUpNode() {
        lookingUpBoundsNode = nil
        lookingUpNode.children = []
        lookingUpNode.path = Path()
        lookingUpNode.removeFromParent()
    }
    func closeLookingUp() {
        if isShownLookingUp {
            closeLookingUpNode()
            isShownLookingUp = false
        }
    }
    
    func closePanel(at p: Point) -> Bool {
        if let i = selections.firstIndex(where: { $0.rect.contains(p) }) {
            selections.remove(at: i)
            return true
        } else {
            return false
        }
    }
    func closeAllPanels(at p: Point) {
        if isShownLookingUp,
           let b = lookingUpBoundsNode?.transformedBounds,
           !b.contains(p) {
            
            closeLookingUp()
        }
        
        if let i = selections.firstIndex(where: { $0.rect.contains(p) }) {
            selections.remove(at: i)
        } else {
            selections = []
        }
        
        if let sheetView = sheetView(at: p), sheetView.isSelectedKeyframes {
            sheetView.unselectKeyframes()
        }
        
        finding = Finding()
    }
    
    private var menuNode: Node?
    
    var textMaxTypelineWidthNode = Node(lineWidth: 0.5, lineType: .color(.border))
    var textCursorWidthNode = Node(lineWidth: 3, lineType: .color(.border))
    var textCursorNode = Node(lineWidth: 0.5, lineType: .color(.background),
                              fillType: .color(.content))
    func updateTextCursor(isMove: Bool = false) {
        func close() {
            textEditor.isIndicated = false
            
            if textCursorNode.parent != nil {
                textCursorNode.removeFromParent()
            }
            if textCursorWidthNode.parent != nil {
                textCursorWidthNode.removeFromParent()
            }
            if textMaxTypelineWidthNode.parent != nil {
                textMaxTypelineWidthNode.removeFromParent()
            }
        }
        if isEditingSheet && textEditor.editingTextView == nil,
           let sheetView = sheetView(at: cursorSHP) {
            
            if isMove {
                sheetView.selectedTextView = nil
            }
            
            if !sheetView.model.texts.isEmpty {
                let cp = convertScreenToWorld(cursorPoint)
                let vp = sheetView.convertFromWorld(cp)
                if let textView = sheetView.selectedTextView,
                   let i = textView.selectedRange?.lowerBound {
                    
                    textEditor.isIndicated = true
                    
                    if textMaxTypelineWidthNode.parent == nil {
                        rootNode.append(child: textMaxTypelineWidthNode)
                    }
                    if textMaxTypelineWidthNode.isHidden {
                        textMaxTypelineWidthNode.isHidden = false
                    }
                    if textCursorWidthNode.parent == nil {
                        rootNode.append(child: textCursorWidthNode)
                    }
                    if textCursorNode.parent == nil {
                        rootNode.append(child: textCursorNode)
                    }
                    if textCursorWidthNode.isHidden {
                        textCursorWidthNode.isHidden = false
                    }
                    if textCursorNode.isHidden {
                        textCursorNode.isHidden = false
                    }
                    let path = textView.typesetter.cursorPath(at: i)
                    textCursorNode.path = textView.convertToWorld(path)
                    textCursorWidthNode.path = textCursorNode.path
                    let mPath = textView.typesetter.maxTypelineWidthPath
                    textMaxTypelineWidthNode.path = textView.convertToWorld(mPath)
                } else if let (textView, _, _, cursorIndex) = sheetView.textTuple(at: vp) {
                    textEditor.isIndicated = true
                    
                    if textMaxTypelineWidthNode.parent == nil {
                        rootNode.append(child: textMaxTypelineWidthNode)
                    }
                    if textMaxTypelineWidthNode.isHidden {
                        textMaxTypelineWidthNode.isHidden = false
                    }
                    if textCursorWidthNode.parent == nil {
                        rootNode.append(child: textCursorWidthNode)
                    }
                    if textCursorNode.parent == nil {
                        rootNode.append(child: textCursorNode)
                    }
                    if textCursorNode.isHidden {
                        textCursorNode.isHidden = false
                    }
                    let ratio = textView.model.size / Font.defaultSize
                    textCursorWidthNode.lineWidth = 1 * ratio
                    textCursorNode.lineWidth = 0.5 * ratio
                    textMaxTypelineWidthNode.lineWidth = 0.5 * ratio
                    
                    if let wcpath = textView.typesetter.warpCursorPath(at: textView.convertFromWorld(cp)) {
                        
                        textCursorWidthNode.path = textView.convertToWorld(wcpath)
                        textCursorWidthNode.isHidden = false
                    } else {
                        textCursorWidthNode.isHidden = true
                    }
                    let path = textView.typesetter
                        .cursorPath(at: cursorIndex,
                                    halfWidth: 0.75, heightRatio: 0.3)
                    textCursorNode.path = textView.convertToWorld(path)
                    let mPath = textView.typesetter.maxTypelineWidthPath
                    textMaxTypelineWidthNode.path = textView.convertToWorld(mPath)
                } else {
                    close()
                }
            } else {
                close()
            }
        } else {
            close()
        }
    }
    
    enum ThumbnailType: Int {
        case w4 = 4, w16 = 16, w64 = 64, w256 = 256, w1024 = 1024
    }
    let thumbnail4Scale = 2.0 ** -8
    let thumbnail16Scale = 2.0 ** -6
    let thumbnail64Scale = 2.0 ** -4
    let thumbnail256Scale = 2.0 ** -2
    let thumbnail1024Scale = 2.0 ** 0
    var thumbnailType = ThumbnailType.w4
    func thumbnailType(withScale scale: Double) -> ThumbnailType {
        if scale < thumbnail4Scale {
            .w4
        } else if scale < thumbnail16Scale {
            .w16
        } else if scale < thumbnail64Scale {
            .w64
        } else if scale < thumbnail256Scale {
            .w256
        } else {
            .w1024
        }
    }
    
    struct SheetRecorder {
        let directory: Directory
        
        static let sheetKey = "sheet.pb"
        let sheetRecord: Record<Sheet>
        
        static let sheetHistoryKey = "sheet_h.pb"
        let sheetHistoryRecord: Record<SheetHistory>
        
        static let contentsDirectoryKey = "contents"
        let contentsDirectory: Directory
        
        static let thumbnail4Key = "t4.jpg"
        let thumbnail4Record: Record<Thumbnail>
        static let thumbnail16Key = "t16.jpg"
        let thumbnail16Record: Record<Thumbnail>
        static let thumbnail64Key = "t64.jpg"
        let thumbnail64Record: Record<Thumbnail>
        static let thumbnail256Key = "t256.jpg"
        let thumbnail256Record: Record<Thumbnail>
        static let thumbnail1024Key = "t1024.jpg"
        let thumbnail1024Record: Record<Thumbnail>
        
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
        
        init(_ directory: Directory) {
            self.directory = directory
            sheetRecord = directory.makeRecord(forKey: SheetRecorder.sheetKey)
            sheetHistoryRecord = directory.makeRecord(forKey: SheetRecorder.sheetHistoryKey)
            contentsDirectory = directory.makeDirectory(forKey: SheetRecorder.contentsDirectoryKey)
            thumbnail4Record = directory.makeRecord(forKey: SheetRecorder.thumbnail4Key)
            thumbnail16Record = directory.makeRecord(forKey: SheetRecorder.thumbnail16Key)
            thumbnail64Record = directory.makeRecord(forKey: SheetRecorder.thumbnail64Key)
            thumbnail256Record = directory.makeRecord(forKey: SheetRecorder.thumbnail256Key)
            thumbnail1024Record = directory.makeRecord(forKey: SheetRecorder.thumbnail1024Key)
            stringRecord = directory.makeRecord(forKey: SheetRecorder.stringKey)
        }
    }
    
    struct SheetViewValue {
        let sheetID: SheetID
        var view: SheetView?
        weak var workItem: DispatchWorkItem?
    }
    struct ThumbnailNodeValue {
        var type: ThumbnailType?
        let sheetID: SheetID
        var node: Node?
        weak var workItem: DispatchWorkItem?
    }
    private(set) var sheetRecorders: [SheetID: SheetRecorder]
    private(set) var baseThumbnailBlocks: [SheetID: Texture.Block]
    private(set) var sheetViewValues = [Sheetpos: SheetViewValue]()
    private(set) var thumbnailNodeValues = [Sheetpos: ThumbnailNodeValue]()
    
    static func sheetRecorders(from sheetsDirectory: Directory) -> [SheetID: SheetRecorder] {
        var srrs = [SheetID: SheetRecorder]()
        srrs.reserveCapacity(sheetsDirectory.childrenURLs.count)
        for (key, _) in sheetsDirectory.childrenURLs {
            guard let sid = sheetID(forKey: key) else { continue }
            let directory = sheetsDirectory.makeDirectory(forKey: sheetIDKey(at: sid))
            srrs[sid] = SheetRecorder(directory)
        }
        return srrs
    }
    
    func makeSheetRecorder(at sid: SheetID) -> SheetRecorder {
        SheetRecorder(sheetsDirectory.makeDirectory(forKey: Document.sheetIDKey(at: sid)))
    }
    func append(_ srr: SheetRecorder, at sid: SheetID) {
        sheetRecorders[sid] = srr
        if let data = srr.thumbnail4Record.decodedData {
            baseThumbnailBlocks[sid] = try? Texture.block(from: data)
        }
    }
    func remove(_ srr: SheetRecorder) {
        try? sheetsDirectory.remove(srr.directory)
    }
    func removeUndo(at shp: Sheetpos) {
        if let sid = sheetID(at: shp), let srr = sheetRecorders[sid] {
            try? srr.directory.remove(srr.sheetHistoryRecord)
        }
    }
    func contains(at sid: SheetID) -> Bool {
        sheetsDirectory.childrenURLs[Document.sheetIDKey(at: sid)] != nil
    }
    
    static func sheetID(forKey key: String) -> SheetID? { SheetID(uuidString: key) }
    static func sheetIDKey(at sid: SheetID) -> String { sid.uuidString }
    
    func thumbnailRecord(at sid: SheetID,
                         with type: ThumbnailType) -> Record<Thumbnail>? {
        switch type {
        case .w4: sheetRecorders[sid]?.thumbnail4Record
        case .w16: sheetRecorders[sid]?.thumbnail16Record
        case .w64: sheetRecorders[sid]?.thumbnail64Record
        case .w256: sheetRecorders[sid]?.thumbnail256Record
        case .w1024: sheetRecorders[sid]?.thumbnail1024Record
        }
    }
    
    @discardableResult
    func readThumbnailNode(at sid: SheetID) -> Node? {
        guard let shp = sheetPosition(at: sid) else { return nil }
        if let tv = thumbnailNodeValues[shp]?.node { return tv }
        let ssFrame = sheetFrame(with: shp)
        return Node(attitude: Attitude(position: ssFrame.origin),
                    path: Path(Rect(size: ssFrame.size)),
                    fillType: readFillType(at: sid) ?? .color(.disabled))
    }
    func readThumbnail(at sid: SheetID) -> Texture? {
        if let shp = sheetPosition(at: sid) {
            if let fillType = thumbnailNode(at: shp)?.fillType,
               case .texture(let thumbnailTexture) = fillType {
                
                if Int(thumbnailTexture.size.width) != thumbnailType.rawValue {
                    guard let data = readThumbnailData(at: sid),
                          let nThumbnailTexture = try? Texture(imageData: data, isOpaque: true) else { return nil }
                    return nThumbnailTexture
                }
                return thumbnailTexture
            }
        }
        
        guard let data = readThumbnailData(at: sid),
              let thumbnailTexture = try? Texture(imageData: data, isOpaque: true) else {
            return thumbnailRecord(at: sid, with: thumbnailType)?.decodedValue?.texture
        }
        return thumbnailTexture
    }
    func readFillType(at sid: SheetID) -> Node.FillType? {
        if let shp = sheetPosition(at: sid) {
            if let fillType = thumbnailNode(at: shp)?.fillType {
                return fillType
            }
        }
        
        guard let data = readThumbnailData(at: sid),
              let thumbnailTexture = try? Texture(imageData: data, isOpaque: true) else {
            guard let thumbnailTexture = thumbnailRecord(at: sid, with: thumbnailType)?.decodedValue?.texture else {
                return nil
            }
            return .texture(thumbnailTexture)
        }
        return .texture(thumbnailTexture)
    }
    func readThumbnailData(at sid: SheetID) -> Data? {
        thumbnailRecord(at: sid, with: thumbnailType)?.decodedData
    }
    func readSheet(at sid: SheetID) -> Sheet? {
        if let shp = sheetPosition(at: sid), let sheet = sheetView(at: shp)?.model {
            return sheet
        }
        if let sheetRecorder = sheetRecorders[sid] {
            return sheetRecorder.sheetRecord.decodedValue
        } else {
            return nil
        }
    }
    func readSheetHistory(at sid: SheetID) -> SheetHistory? {
        if let shp = sheetPosition(at: sid), let history = sheetView(at: shp)?.history {
            return history
        }
        if let sheetRecorder = sheetRecorders[sid] {
            return sheetRecorder.sheetHistoryRecord.decodedValue
        } else {
            return nil
        }
    }
    
    func updateStringRecord(at sid: SheetID, with sheetView: SheetView,
                            isPreparedWrite: Bool = false) {
        guard let sheetRecorder = sheetRecorders[sid] else { return }
        sheetRecorder.stringRecord.value = sheetView.model.allTextsString
        if isPreparedWrite {
            sheetRecorder.stringRecord.isPreparedWrite = true
        } else {
            sheetRecorder.stringRecord.isWillwrite = true
        }
    }
    
    struct ThumbnailMipmap {
        var thumbnail4Data: Data
        var thumbnail4: Thumbnail?
        var thumbnail16: Thumbnail?
        var thumbnail64: Thumbnail?
        var thumbnail256: Thumbnail?
        var thumbnail1024: Thumbnail?
    }
    func hideSelectedRange(_ handler: () -> ()) {
        var isHiddenSelectedRange = false
        if let textView = textEditor.editingTextView, !textView.isHiddenSelectedRange {
            
            textView.isHiddenSelectedRange = true
            isHiddenSelectedRange = true
        }
        
        handler()
        
        if isHiddenSelectedRange, let textView = textEditor.editingTextView {
            textView.isHiddenSelectedRange = false
        }
    }
    func makeThumbnailRecord(at sid: SheetID, with sheetView: SheetView,
                             isPreparedWrite: Bool = false) {
        hideSelectedRange {
            if let tm = thumbnailMipmap(from: sheetView),
               let sheetRecorder = sheetRecorders[sid] {
                
                saveThumbnailRecord(tm, in: sheetRecorder,
                                    isPreparedWrite: isPreparedWrite)
                baseThumbnailBlocks[sid] = try? Texture.block(from: tm.thumbnail4Data)
            }
        }
        updateStringRecord(at: sid, with: sheetView,
                           isPreparedWrite: isPreparedWrite)
    }
    func thumbnailMipmap(from sheetView: SheetView) -> ThumbnailMipmap? {
        var size = sheetView.bounds.size * (2.0 ** 1)
        let bColor = sheetView.model.backgroundUUColor.value
        let baseImage = sheetView.node.imageInBounds(size: size, backgroundColor: bColor,
                                                     colorSpace: colorSpace.noHDR)
        guard let thumbnail1024 = baseImage else { return nil }
        size = size / 4
        let thumbnail256 = thumbnail1024.resize(with: size)
        size = size / 4
        let thumbnail64 = thumbnail256?.resize(with: size)
        size = size / 4
        let thumbnail16 = thumbnail64?.resize(with: size)
        size = size / 4
        let thumbnail4 = thumbnail16?.resize(with: size)
        guard let thumbnail4Data = thumbnail4?.data(.jpeg) else { return nil }
        return ThumbnailMipmap(thumbnail4Data: thumbnail4Data,
                               thumbnail4: thumbnail4,
                               thumbnail16: thumbnail16,
                               thumbnail64: thumbnail64,
                               thumbnail256: thumbnail256,
                               thumbnail1024: thumbnail1024)
    }
    func saveThumbnailRecord(_ tm: ThumbnailMipmap,
                             in srr: SheetRecorder,
                             isPreparedWrite: Bool = false) {
        srr.thumbnail4Record.value = tm.thumbnail4
        srr.thumbnail16Record.value = tm.thumbnail16
        srr.thumbnail64Record.value = tm.thumbnail64
        srr.thumbnail256Record.value = tm.thumbnail256
        srr.thumbnail1024Record.value = tm.thumbnail1024
        if isPreparedWrite {
            srr.thumbnail4Record.isPreparedWrite = true
            srr.thumbnail16Record.isPreparedWrite = true
            srr.thumbnail64Record.isPreparedWrite = true
            srr.thumbnail256Record.isPreparedWrite = true
            srr.thumbnail1024Record.isPreparedWrite = true
        } else {
            srr.thumbnail4Record.isWillwrite = true
            srr.thumbnail16Record.isWillwrite = true
            srr.thumbnail64Record.isWillwrite = true
            srr.thumbnail256Record.isWillwrite = true
            srr.thumbnail1024Record.isWillwrite = true
        }
    }
    func emptyNode(at shp: Sheetpos) -> Node {
        let ssFrame = sheetFrame(with: shp)
        return Node(path: Path(ssFrame), fillType: baseFillType(at: shp))
    }
    func baseFillType(at shp: Sheetpos) -> Node.FillType {
        guard let sid = sheetID(at: shp), let block = baseThumbnailBlocks[sid] else {
            return .color(.disabled)
        }
        guard let texture = try? Texture(block: block, isOpaque: true) else {
            return .color(.disabled)
        }
        return .texture(texture)
    }
    
    func containsAllTimelines(with event: any Event) -> Bool {
        let sp = lastEditedSheetScreenCenterPositionNoneCursor ?? event.screenPoint
        let p = convertScreenToWorld(sp)
        guard let sheetView = sheetView(at: p) else { return false }
        let inP = sheetView.convertFromWorld(p)
        return sheetView.animationView.containsTimeline(inP, scale: screenToWorldScale)
        || sheetView.containsOtherTimeline(inP, scale: screenToWorldScale)
    }
    func isPlaying(with event: any Event) -> Bool {
        let sp = lastEditedSheetScreenCenterPositionNoneCursor ?? event.screenPoint
        let p = convertScreenToWorld(sp)
        if let sheetView = sheetView(at: p), sheetView.isPlaying {
            return true
        }
        for shp in aroundSheetpos(atCenter: intPosition(at: p)) {
            if let sheetView = sheetView(at: shp.shp), sheetView.isPlaying {
                return true
            }
        }
        return false
    }
    
    var isUpdateWithCursorPosition = true
    var cursorPoint = Point() {
        didSet {
            updateWithCursorPosition()
//            updateCursorNode()
        }
    }
    func aroundSheetpos(atCenter cip: IntPoint) -> [(shp: Sheetpos, isCorner: Bool)] {
        var shpSet = Set<Sheetpos>(), shps = [(shp: Sheetpos, isCorner: Bool)]()
        let centerShp = world.sheetpos(at: cip)
        func append(_ ip: IntPoint, isCorner: Bool) {
            let shp = world.sheetpos(at: ip)
            if centerShp != shp, !shpSet.contains(shp) {
                shpSet.insert(shp)
                shps.append((shp, isCorner))
            }
        }
        if centerShp == world.sheetpos(at: .init(cip.x + 1, cip.y)) {
            append(.init(cip.x + 2, cip.y), isCorner: false)
        }
        append(.init(cip.x + 1, cip.y), isCorner: false)
        append(.init(cip.x - 1, cip.y), isCorner: false)
        if centerShp == world.sheetpos(at: .init(cip.x - 1, cip.y)) {
            append(.init(cip.x - 2, cip.y), isCorner: false)
        }
        append(.init(cip.x, cip.y + 1), isCorner: false)
        append(.init(cip.x, cip.y - 1), isCorner: false)
        append(.init(cip.x + 1, cip.y + 1), isCorner: true)
        append(.init(cip.x + 1, cip.y - 1), isCorner: true)
        append(.init(cip.x - 1, cip.y - 1), isCorner: true)
        append(.init(cip.x - 1, cip.y + 1), isCorner: true)
        return shps
    }
    
    var cursorSHP = Sheetpos()
    var centerSHPs = [Sheetpos]()
    func updateWithCursorPosition() {
        if isUpdateWithCursorPosition {
            updateWithCursorPositionAlways()
        }
    }
    private func updateWithCursorPositionAlways() {
        var shps = [Sheetpos]()
        let ip = intPosition(at: convertScreenToWorld(cursorPoint))
        let shp = sheetPosition(at: ip)
        cursorSHP = shp
        shps.append(shp)
        let aroundShps = aroundSheetpos(atCenter: ip)
        shps += aroundShps.map { $0.shp }
        centerSHPs = shps
        if let leshp = lastEditedSheetpos {
            shps.append(leshp)
        }
        
        let utilitySHPs = Set(aroundShps.compactMap { $0.isCorner ? $0.shp : nil })
        
        var nshps = sheetViewValues
        let oshps = nshps
        for shp in shps {
            nshps[shp] = nil
        }
        nshps.forEach { readAndClose(.none, qos: .default, at: $0.value.sheetID, $0.key) }
        for nshp in shps {
            if oshps[nshp] == nil, let sid = sheetID(at: nshp) {
                readAndClose(.sheet,
                             qos: nshp == shp ? .userInteractive : (utilitySHPs.contains(nshp) ? .utility : .default),
                             at: sid, nshp)
            }
        }
        
        updateTextCursor(isMove: true)
    }
    
    private enum NodeType {
        case none, sheet
    }
    func readAndClose(with aBounds: Rect, _ transform: Transform) {
        readAndClose(with: aBounds, transform, sheetRecorders)
    }
    func readAndClose(with aBounds: Rect, _ transform: Transform,
                      _ sheetRecorders: [SheetID: SheetRecorder]) {
        let bounds = aBounds * transform
        let d = transform.log2Scale.clipped(min: 0, max: 4, newMin: 1440, newMax: 360)
        let thumbnailsBounds = bounds.inset(by: -d)
        let minXIndex = Int((thumbnailsBounds.minX / Sheet.width).rounded(.down))
        let maxXIndex = Int((thumbnailsBounds.maxX / Sheet.width).rounded(.up))
        let minYIndex = Int((thumbnailsBounds.minY / Sheet.height).rounded(.down))
        let maxYIndex = Int((thumbnailsBounds.maxY / Sheet.height).rounded(.up))
        
        for (sid, _) in sheetRecorders {
            guard let shp = sheetPosition(at: sid) else { continue }
            let type: ThumbnailType?
            if shp.x >= minXIndex && shp.x <= maxXIndex
                && shp.y >= minYIndex && shp.y <= maxYIndex {
                
                type = thumbnailType
            } else {
                type = nil
            }
            let tv = thumbnailNodeValues[shp] ?? .init(type: .none, sheetID: sid, node: nil)
            if tv.type != type {
                set(type, in: tv, at: sid, shp)
            }
        }
    }
    private func set(_ type: ThumbnailType?, in tv: ThumbnailNodeValue,
                     at sid: SheetID, _ shp: Sheetpos) {
        if sheetViewValues[shp]?.view != nil { return }
        if let type = type {
            if let oldType = tv.type {
                if type != oldType {
                    tv.workItem?.cancel()
                    openThumbnail(at: shp, sid, tv.node, type)
                }
            } else {
                openThumbnail(at: shp, sid, tv.node, type)
            }
        } else {
            if tv.type != nil {
                tv.workItem?.cancel()
                tv.node?.removeFromParent()
                thumbnailNodeValues[shp]?.node?.removeFromParent()
                thumbnailNodeValues[shp] = .init(type: type, sheetID: sid, node: nil)
            }
        }
    }
    func openThumbnail(at shp: Sheetpos, _ sid: SheetID, _ node: Node?,
                       _ type: ThumbnailType) {
        let node = node ?? emptyNode(at: shp)
        guard type != .w4, let thumbnailRecord = self.thumbnailRecord(at: sid, with: type) else {
            node.fillType = baseFillType(at: shp)
            thumbnailNodeValues[shp]?.node?.removeFromParent()
            thumbnailNodeValues[shp] = .init(type: type, sheetID: sid, node: node)
            sheetsNode.append(child: node)
            return
        }
        
        var workItem: DispatchWorkItem!
        workItem = DispatchWorkItem() { [weak thumbnailRecord, weak node] in
            defer { workItem = nil }
            guard !workItem.isCancelled else { return }
            
            guard let thumbnailRecord,
                  let block = try? Texture.block(from: thumbnailRecord, isMipmapped: true) else { return }
            DispatchQueue.main.async { [weak node] in
                if let thumbnailTexture = try? Texture(block: block) {
                    node?.fillType = .texture(thumbnailTexture)
                }
            }
        }
        DispatchQueue.global().async(execute: workItem)
        
        thumbnailNodeValues[shp]?.node?.removeFromParent()
        thumbnailNodeValues[shp] = .init(type: type, sheetID: sid, node: node, workItem: workItem)
        sheetsNode.append(child: node)
    }
    
    func close(from shps: [Sheetpos]) {
        shps.forEach {
            if let sid = sheetID(at: $0) {
                readAndClose(.none, qos: .default, at: sid, $0)
            }
        }
    }
    func close(from sids: [SheetID]) {
        sids.forEach {
            if let shp = sheetPosition(at: $0) {
                readAndClose(.none, qos: .default, at: $0, shp)
            }
        }
    }
    private func updateThumbnail(_ sheetViewValue: SheetViewValue,
                                 at shp: Sheetpos, _ sid: SheetID) {
        if let sheetView = sheetViewValue.view {
            if let texture = sheetView.node.cacheTexture {
                if let tv = thumbnailNodeValues[shp], let tNode = tv.node {
                    tNode.fillType = .texture(texture)
                    if tNode.parent == nil {
                        sheetsNode.append(child: tNode)
                    }
                } else if sheetViewValues[shp] != nil {
                    let ssFrame = sheetFrame(with: shp)
                    let tNode = Node(path: Path(ssFrame), fillType: .color(.disabled))
                    tNode.fillType = .texture(texture)
                    thumbnailNodeValues[shp]?.node?.removeFromParent()
                    thumbnailNodeValues[shp] = .init(type: thumbnailType, sheetID: sid, node: tNode)
                    sheetsNode.append(child: tNode)
                }
            } else if let tv = thumbnailNodeValues[shp] {
                openThumbnail(at: shp, sid, tv.node, thumbnailType)
            }
        }
    }
    struct ReadingError: Error {}
    private func readAndClose(_ type: NodeType, qos: DispatchQoS = .default,
                              at sid: SheetID, _ shp: Sheetpos) {
        switch type {
        case .none:
            if let sheetViewValue = sheetViewValues[shp] {
                sheetViewValue.workItem?.cancel()
                
                if let sheetView = sheetViewValue.view {
                    sheetView.node.updateCache()
                }
                if let sheetView = sheetViewValue.view,
                   let sheetRecorder = sheetRecorders[sheetViewValue.sheetID],
                   sheetRecorder.sheetRecord.isWillwrite {
                    
                    if savingItem != nil {
                        savingFuncs.append { [sid = sheetViewValue.sheetID,
                                              model = sheetView.model, um = sheetView.history,
                                              tm = thumbnailMipmap(from: sheetView), weak self] in
                            
                            sheetRecorder.sheetRecord.value = model
                            sheetRecorder.sheetRecord.isWillwrite = true
                            sheetRecorder.sheetHistoryRecord.value = um
                            sheetRecorder.sheetHistoryRecord.isWillwrite = true
                            self?.updateStringRecord(at: sid, with: sheetView)
                            if let tm = tm {
                                self?.saveThumbnailRecord(tm, in: sheetRecorder)
                                self?.baseThumbnailBlocks[sid]
                                = try? Texture.block(from: tm.thumbnail4Data)
                            }
                        }
                    } else {
                        sheetRecorder.sheetRecord.value = sheetView.model
                        sheetRecorder.sheetHistoryRecord.value = sheetView.history
                        sheetRecorder.sheetHistoryRecord.isWillwrite = true
                        makeThumbnailRecord(at: sheetViewValue.sheetID, with: sheetView)
                        sheetRecorder.sheetRecord.willwriteClosure = { (_) in }
                    }
                }
                
                updateThumbnail(sheetViewValue, at: shp, sid)
                sheetViewValues[shp]?.view?.node.removeFromParent()
                sheetViewValues[shp] = nil
                sheetViewValue.view?.node.removeFromParent()
                updateFindingNodes(at: shp)
            }
            updateSelects()
        case .sheet:
            if sheetViewValues.contains(where: { $0.value.sheetID == sid }) { return }
            
            var workItem: DispatchWorkItem!
            workItem = DispatchWorkItem(qos: qos) { [weak self] in
                defer { workItem = nil }
                guard let self, !workItem.isCancelled,
                      let sheetRecorder = self.sheetRecorders[sid] else { return }
                let sheetRecord = sheetRecorder.sheetRecord
                let historyRecord = sheetRecorder.sheetHistoryRecord
                
                let sheet = sheetRecord.decodedValue ?? Sheet(message: "Failed to load".localized)
                let sheetBinder = RecordBinder(value: sheet, record: sheetRecord)
                let sheetView = SheetView(binder: sheetBinder, keyPath: \SheetBinder.value)
                sheetView.screenToWorldScale = self.screenToWorldScale
                sheetView.id = sid
                if let history = historyRecord.decodedValue {
                    sheetView.history = history
                }
                let frame = self.sheetFrame(with: shp)
                sheetView.bounds = Rect(size: frame.size)
                sheetView.node.attitude.position = frame.origin
                sheetView.node.allChildrenAndSelf { $0.updateDatas() }
                updateWithIsFullEdit(in: sheetView)
                do {
                    guard let thumbnail = sheetRecorder.thumbnail1024Record.decodedValue else { throw ReadingError() }
                    let block = try Texture.block(from: thumbnail, isMipmapped: true)
                    DispatchQueue.main.async {
                        sheetView.node.cacheTexture = try? .init(block: block)
                    }
                } catch {
//                    sheetView.enableCache = true
                }
                
                DispatchQueue.main.async {
                    guard self.sheetID(at: shp) == sid,
                          self.sheetViewValues[shp] != nil else { return }
                    sheetRecord.willwriteClosure = { [weak sheetView, weak self, weak historyRecord] (record) in
                        if let sheetView = sheetView {
                            record.value = sheetView.model
                            historyRecord?.value = sheetView.history
                            historyRecord?.isPreparedWrite = true
                            self?.makeThumbnailRecord(at: sid, with: sheetView,
                                                      isPreparedWrite: true)// -> write
                        }
                    }
                    
                    self.sheetView(at: shp)?.node.removeFromParent()
                    self.sheetViewValues[shp] = .init(sheetID: sid, view: sheetView, workItem: nil)
                    if sheetView.node.parent == nil {
                        self.sheetsNode.append(child: sheetView.node)
                        sheetView.node.enableCache = true
                    }
                    self.thumbnailNodeValues[shp]?.node?.removeFromParent()
                    
                    self.updateSelects()
                    self.updateFindingNodes(at: shp)
                    if shp == self.sheetPosition(at: self.convertScreenToWorld(self.cursorPoint)) {
                        self.updateTextCursor()
                    }
                }
            }
            sheetViewValues[shp]?.view?.node.removeFromParent()
            sheetViewValues[shp] = .init(sheetID: sid, view: nil, workItem: workItem)
            DispatchQueue.global().async(execute: workItem)
        }
    }
    
    func renderableSheet(at sid: SheetID) -> Sheet? {
        sheetRecorders[sid]?.sheetRecord.decodedValue
    }
    func renderableSheetNode(at sid: SheetID) -> Node? {
        guard let shp = sheetPosition(at: sid) else { return nil }
        guard let sheet = sheetRecorders[sid]?
                .sheetRecord.decodedValue else { return nil }
        let bounds = sheetFrame(with: shp).bounds
        let node = sheet.node(isBorder: false, in: bounds)
        node.attitude.position = sheetFrame(with: shp).origin
        return node
    }
    
    func readSheetView(at sid: SheetID) -> SheetView? {
        guard let shp = sheetPosition(at: sid) else { return nil }
        return sheetView(at: shp) ?? readSheetView(at: sid, shp)
    }
    func readSheetView(at shp: Sheetpos) -> SheetView? {
        if let sheetView = sheetView(at: shp) {
            sheetView
        } else if let sid = sheetID(at: shp) {
            readSheetView(at: sid, shp)
        } else {
            nil
        }
    }
    func readSheetView(at p: Point) -> SheetView? {
        readSheetView(at: sheetPosition(at: p))
    }
    func readSheetView(at sid: SheetID, _ shp: Sheetpos,
                       isUpdateNode: Bool = false) -> SheetView? {
        guard let sheetRecorder = sheetRecorders[sid] else { return nil }
        let sheetRecord = sheetRecorder.sheetRecord
        let sheetHistoryRecord = sheetRecorder.sheetHistoryRecord
        
        guard let sheet = sheetRecord.decodedValue else { return nil }
        let sheetBinder = RecordBinder(value: sheet, record: sheetRecord)
        let sheetView = SheetView(binder: sheetBinder, keyPath: \SheetBinder.value)
        sheetView.screenToWorldScale = screenToWorldScale
        sheetView.id = sid
        if let history = sheetHistoryRecord.decodedValue {
            sheetView.history = history
        }
        let frame = sheetFrame(with: shp)
        sheetView.bounds = Rect(size: frame.size)
        sheetView.node.attitude.position = frame.origin
        sheetView.node.allChildrenAndSelf { $0.updateDatas() }
        sheetView.node.enableCache = true
        updateWithIsFullEdit(in: sheetView)
        
        sheetRecord.willwriteClosure = { [weak sheetView, weak sheetHistoryRecord, weak self] (record) in
            if let sheetView = sheetView {
                record.value = sheetView.model
                sheetHistoryRecord?.value = sheetView.history
                sheetHistoryRecord?.isPreparedWrite = true
                self?.makeThumbnailRecord(at: sid, with: sheetView,
                                          isPreparedWrite: true)// -> write
            }
        }
        
        if isUpdateNode {
            self.sheetView(at: shp)?.node.removeFromParent()
            sheetViewValues[shp] = SheetViewValue(sheetID: sid, view: sheetView, workItem: nil)
            if sheetView.node.parent == nil {
                sheetsNode.append(child: sheetView.node)
            }
            thumbnailNodeValues[shp]?.node?.removeFromParent()
            updateWithIsFullEdit(in: sheetView)
        }
        
        return sheetView
    }
    
    func firstAudiotracks(from shp: Sheetpos) -> [Audiotrack] {
        guard let sheetView = sheetViewValue(at: shp)?.view else { return [] }
        var firstAudiotracks = [Audiotrack]()
        var nip = IntPoint((sheetView.previousSheetView != nil ? -2 : -1) + shp.x, shp.y)
        while true {
            let shp = sheetPosition(at: nip)
            if shp.isRight { nip.x -= 1 }
            if let id = sheetID(at: shp),
               let sr = sheetRecorders[id],
               let sheet = sr.sheetRecord.decodedValue {
                
                firstAudiotracks.append(sheet.audiotrack)
                
                nip.x -= 1
            } else {
                break
            }
        }
        return firstAudiotracks
    }
    func lastAudiotracks(from shp: Sheetpos) -> [Audiotrack] {
        guard let sheetView = sheetViewValue(at: shp)?.view else { return [] }
        var lastAudiotracks = [Audiotrack]()
        var nip = IntPoint((sheetView.nextSheetView != nil ? 2 : 1) + shp.x, shp.y)
        while true {
            let shp = sheetPosition(at: nip)
            if shp.isRight { nip.x += 1 }
            if let id = sheetID(at: shp),
               let sr = sheetRecorders[id],
               let sheet = sr.sheetRecord.decodedValue {
                
                lastAudiotracks.append(sheet.audiotrack)
                
                nip.x += 1
            } else {
                break
            }
        }
        return lastAudiotracks
    }
    
    func sheetPosition(at sid: SheetID) -> Sheetpos? {
        world.sheetPositions[sid]
    }
    func sheetID(at shp: Sheetpos) -> SheetID? {
        world.sheetIDs[shp]
    }
    func intPosition(at p: Point) -> IntPoint {
        let p = Document.maxSheetAABB.clippedPoint(with: p)
        let x = Int((p.x / Sheet.width).rounded(.down))
        let y = Int((p.y / Sheet.height).rounded(.down))
        return .init(x, y)
    }
    func sheetPosition(at p: IntPoint) -> Sheetpos {
        world.sheetpos(at: p)
    }
    func sheetPosition(at p: Point) -> Sheetpos {
        world.sheetpos(at: intPosition(at: p))
    }
    func sheetFrame(with shp: Sheetpos) -> Rect {
        Rect(x: Double(shp.x) * Sheet.width,
             y: Double(shp.y) * Sheet.height,
             width: shp.isRight ? Sheet.width * 2 : Sheet.width,
             height: Sheet.height)
    }
    func sheetView(at p: Point) -> SheetView? {
        sheetViewValues[sheetPosition(at: p)]?.view
    }
    func sheetViewValue(at shp: Sheetpos) -> SheetViewValue? {
        sheetViewValues[shp]
    }
    func sheetView(at shp: Sheetpos) -> SheetView? {
        sheetViewValues[shp]?.view
    }
    func thumbnailNode(at shp: Sheetpos) -> Node? {
        thumbnailNodeValues[shp]?.node
    }
    
    func madeReadSheetView(at p: Point,
                           isNewUndoGroup: Bool = true) -> SheetView? {
        let shp = sheetPosition(at: p)
        return if let ssv = madeSheetView(at: shp,
                                   isNewUndoGroup: isNewUndoGroup) {
            ssv
        } else if let sid = sheetID(at: shp) {
            readSheetView(at: sid, shp, isUpdateNode: true)
        } else {
            nil
        }
    }
    
    @discardableResult
    func madeSheetView(at p: Point,
                       isNewUndoGroup: Bool = true) -> SheetView? {
        madeSheetView(at: sheetPosition(at: p), isNewUndoGroup: isNewUndoGroup)
    }
    @discardableResult
    func madeSheetView(at shp: Sheetpos,
                       isNewUndoGroup: Bool = true) -> SheetView? {
        if let sheetView = sheetView(at: shp) { return sheetView }
        if sheetID(at: shp) != nil { return nil }
        let newSID = SheetID()
        guard !contains(at: newSID) else { return nil }
        return append(Sheet(), history: nil, at: newSID, at: shp,
                      isNewUndoGroup: isNewUndoGroup)
    }
    @discardableResult
    func madeSheetViewIsNew(at shp: Sheetpos,
                            isNewUndoGroup: Bool = true) -> (SheetView,
                                                             isNew: Bool)? {
        if let sheetView = sheetView(at: shp) { return (sheetView, false) }
        if sheetID(at: shp) != nil { return nil }
        let newSID = SheetID()
        guard !contains(at: newSID) else { return nil }
        return (append(Sheet(), history: nil, at: newSID, at: shp,
                       isNewUndoGroup: isNewUndoGroup), true)
    }
    @discardableResult
    func madeSheetView(with sheet: Sheet,
                       history: SheetHistory?,
                       at shp: Sheetpos,
                       isNewUndoGroup: Bool = true) -> SheetView? {
        if let sheetView = sheetView(at: shp) {
            sheetView.node.removeFromParent()
        }
        let newSID = SheetID()
        guard !contains(at: newSID) else { return nil }
        return append(sheet, history: history,
                      at: newSID, at: shp,
                      isNewUndoGroup: isNewUndoGroup)
    }
    @discardableResult
    func append(_ sheet: Sheet, history: SheetHistory?,
                at sid: SheetID, at shp: Sheetpos,
                isNewUndoGroup: Bool = true) -> SheetView {
        if isNewUndoGroup {
            newUndoGroup()
        }
        append([shp: sid], enableNode: false)
        
        let sheetRecorder = makeSheetRecorder(at: sid)
        let sheetRecord = sheetRecorder.sheetRecord
        let sheetHistoryRecord = sheetRecorder.sheetHistoryRecord
        
        let sheetBinder = RecordBinder(value: sheet, record: sheetRecord)
        let sheetView = SheetView(binder: sheetBinder, keyPath: \SheetBinder.value)
        sheetView.screenToWorldScale = screenToWorldScale
        sheetView.id = sid
        if let history = history {
            sheetView.history = history
        }
        let frame = sheetFrame(with: shp)
        sheetView.bounds = Rect(size: frame.size)
        sheetView.node.attitude.position = frame.origin
        sheetView.node.allChildrenAndSelf { $0.updateDatas() }
        sheetView.node.enableCache = true
        updateWithIsFullEdit(in: sheetView)
        
        sheetRecord.willwriteClosure = { [weak sheetView, weak sheetHistoryRecord, weak self] (record) in
            if let sheetView = sheetView {
                record.value = sheetView.model
                sheetHistoryRecord?.value = sheetView.history
                sheetHistoryRecord?.isPreparedWrite = true
                self?.makeThumbnailRecord(at: sid, with: sheetView,
                                          isPreparedWrite: true)// -> write
            }
        }
        
        self.sheetView(at: shp)?.node.removeFromParent()
        sheetRecorders[sid] = sheetRecorder
        sheetViewValues[shp]?.view?.node.removeFromParent()
        sheetViewValues[shp] = SheetViewValue(sheetID: sid, view: sheetView, workItem: nil)
        sheetsNode.append(child: sheetView.node)
        updateMap()
        updateWithIsFullEdit(in: sheetView)
        
        return sheetView
    }
    @discardableResult
    func duplicateSheet(from sid: SheetID) -> SheetID {
        let nsid = SheetID()
        let nsrr = makeSheetRecorder(at: nsid)
        if let shp = sheetPosition(at: sid),
           let sheetView = sheetView(at: shp) {
            nsrr.sheetRecord.value = sheetView.model
            nsrr.sheetHistoryRecord.value = sheetView.history
            hideSelectedRange {
                if let t = thumbnailMipmap(from: sheetView) {
                    saveThumbnailRecord(t, in: nsrr)
                }
            }
        } else if let osrr = sheetRecorders[sid] {
            nsrr.sheetRecord.data = osrr.sheetRecord.valueDataOrDecodedData
            nsrr.thumbnail4Record.data = osrr.thumbnail4Record.valueDataOrDecodedData
            nsrr.thumbnail16Record.data = osrr.thumbnail16Record.valueDataOrDecodedData
            nsrr.thumbnail64Record.data = osrr.thumbnail64Record.valueDataOrDecodedData
            nsrr.thumbnail256Record.data = osrr.thumbnail256Record.valueDataOrDecodedData
            nsrr.thumbnail1024Record.data = osrr.thumbnail1024Record.valueDataOrDecodedData
            nsrr.sheetHistoryRecord.data = osrr.sheetHistoryRecord.valueDataOrDecodedData
            nsrr.stringRecord.data = osrr.stringRecord.valueDataOrDecodedData
        }
        
        if let osrr = sheetRecorders[sid], !osrr.contentsDirectory.childrenURLs.isEmpty {
            nsrr.contentsDirectory.isWillwrite = true
            try? nsrr.contentsDirectory.write()
            for (key, url) in osrr.contentsDirectory.childrenURLs {
                try? nsrr.contentsDirectory.copy(name: key, from: url)
            }
            if var sheet = nsrr.sheetRecord.decodedValue {
                if !sheet.contents.isEmpty {
                    let dn = nsid.uuidString
                    for i in sheet.contents.count.range {
                        sheet.contents[i].directoryName = dn
                    }
                    nsrr.sheetRecord.data = try? sheet.serializedData()
                }
            }
        }
        nsrr.sheetRecord.isWillwrite = true
        nsrr.thumbnail4Record.isWillwrite = true
        nsrr.thumbnail16Record.isWillwrite = true
        nsrr.thumbnail64Record.isWillwrite = true
        nsrr.thumbnail256Record.isWillwrite = true
        nsrr.thumbnail1024Record.isWillwrite = true
        nsrr.sheetHistoryRecord.isWillwrite = true
        nsrr.stringRecord.isWillwrite = true
        append(nsrr, at: nsid)
        return nsid
    }
    func appendSheet(from osrr: SheetRecorder) -> SheetID {
        let nsid = SheetID()
        let nsrr = makeSheetRecorder(at: nsid)
        nsrr.sheetRecord.data = osrr.sheetRecord.valueDataOrDecodedData
        nsrr.thumbnail4Record.data = osrr.thumbnail4Record.valueDataOrDecodedData
        nsrr.thumbnail16Record.data = osrr.thumbnail16Record.valueDataOrDecodedData
        nsrr.thumbnail64Record.data = osrr.thumbnail64Record.valueDataOrDecodedData
        nsrr.thumbnail256Record.data = osrr.thumbnail256Record.valueDataOrDecodedData
        nsrr.thumbnail1024Record.data = osrr.thumbnail1024Record.valueDataOrDecodedData
        nsrr.sheetHistoryRecord.data = osrr.sheetHistoryRecord.valueDataOrDecodedData
        nsrr.stringRecord.data = osrr.stringRecord.valueDataOrDecodedData
        
        if !osrr.contentsDirectory.childrenURLs.isEmpty {
            nsrr.contentsDirectory.isWillwrite = true
            try? nsrr.contentsDirectory.write()
            for (key, url) in osrr.contentsDirectory.childrenURLs {
                try? nsrr.contentsDirectory.copy(name: key, from: url)
            }
            if var sheet = nsrr.sheetRecord.decodedValue {
                if !sheet.contents.isEmpty {
                    let dn = nsid.uuidString
                    for i in sheet.contents.count.range {
                        sheet.contents[i].directoryName = dn
                    }
                    nsrr.sheetRecord.data = try? sheet.serializedData()
                }
            }
        }
        nsrr.sheetRecord.isWillwrite = true
        nsrr.thumbnail4Record.isWillwrite = true
        nsrr.thumbnail16Record.isWillwrite = true
        nsrr.thumbnail64Record.isWillwrite = true
        nsrr.thumbnail256Record.isWillwrite = true
        nsrr.thumbnail1024Record.isWillwrite = true
        nsrr.sheetHistoryRecord.isWillwrite = true
        nsrr.stringRecord.isWillwrite = true
        append(nsrr, at: nsid)
        return nsid
    }
    func removeSheet(at sid: SheetID, for shp: Sheetpos) {
        if let sheetRecorder = sheetRecorders[sid] {
            remove(sheetRecorder)
            sheetRecorders[sid] = nil
        }
        if let sheetViewValue = sheetViewValues[shp] {
            sheetViewValue.view?.node.removeFromParent()
            sheetViewValues[shp] = nil
        }
        updateMap()
    }
    
    private(set) var lastEditedSheetpos: Sheetpos?
    private var lastEditedSheetNode: Node?
    func updateLastEditedSheetpos(from event: any Event) {
        lastEditedSheetpos
            = sheetPosition(at: convertScreenToWorld(event.screenPoint))
    }
    var isShownLastEditedSheet = false {
        didSet {
            updateSelectedColor(isMain: true)
            lastEditedSheetNode?.removeFromParent()
            lastEditedSheetNode = nil
            if isShownLastEditedSheet {
                if let shp = lastEditedSheetpos {
                    let f = sheetFrame(with: shp)
                    var isSelection = false
                    for selection in selections {
                        let r = selection.rect
                        if worldBounds.intersects(r) && !r.intersects(f)
                            && worldBounds.intersects(f) {
                            
                            isSelection = true
                            break
                        }
                    }
                    if isSelection {
                        updateSelectedColor(isMain: false)
                    }
                    let selectedSheetNode = Node(path: Path(f),
                                                 lineWidth: worldLineWidth,
                                                 lineType: .color(.selected),
                                                 fillType: .color(.subSelected))
                    rootNode.append(child: selectedSheetNode)
                    self.lastEditedSheetNode = selectedSheetNode
                }
            }
        }
    }
    var isNoneCursor = false
    private var lastEditedSheetposInView: Sheetpos? {
        if let shp = lastEditedSheetpos {
            let f = sheetFrame(with: shp)
            if worldBounds.intersects(f) {
                if !selections.isEmpty {
                    for selection in selections {
                        let r = selection.rect
                        if !f.contains(r)
                            && (!worldBounds.intersects(r) || !r.intersects(f)) {
                            return shp
                        }
                    }
                } else {
                    return shp
                }
            }
        }
        return nil
    }
    var lastEditedSheetposNoneCursor: Sheetpos? {
        guard isNoneCursor else { return nil }
        return lastEditedSheetposInView
    }
    func isSelectNoneCursor(at p: Point) -> Bool {
        (isNoneCursor && lastEditedSheetposNoneCursor == nil)
            || isSelect(at: p)
    }
    var lastEditedSheetWorldCenterPositionNoneCursor: Point? {
        if let shp = lastEditedSheetposNoneCursor {
            sheetFrame(with: shp).centerPoint
        } else {
            nil
        }
    }
    var lastEditedSheetScreenCenterPositionNoneCursor: Point? {
        if let p = lastEditedSheetWorldCenterPositionNoneCursor {
            convertWorldToScreen(p)
        } else {
            nil
        }
    }
    var selectedScreenPositionNoneCursor: Point? {
        guard isNoneCursor else { return nil }
        if !selections.isEmpty {
            if let shp = lastEditedSheetpos {
                let f = sheetFrame(with: shp)
                for selection in selections {
                    if worldBounds.intersects(f), selection.rect.intersects(f) {
                        return convertWorldToScreen(selection.rect.centerPoint)
                    }
                }
            }
        }
        return lastEditedSheetScreenCenterPositionNoneCursor
    }
    func isSelectSelectedNoneCursor(at p: Point) -> Bool {
        (isNoneCursor && selectedScreenPositionNoneCursor == nil)
            || isSelect(at: p)
    }
    var selectedSheetViewNoneCursor: SheetView? {
        guard isNoneCursor else { return nil }
        return if let shp = lastEditedSheetpos {
            readSheetView(at: shp)
        } else {
            nil
        }
    }
    var lastEditedSheetWorldCenterPositionNoneSelectedNoneCursor: Point? {
        guard isNoneCursor else { return nil }
        if let shp = lastEditedSheetpos {
            let f = sheetFrame(with: shp)
            if worldBounds.intersects(f) {
                return f.centerPoint
            }
        }
        return nil
    }
    var lastEditedSheetScreenCenterPositionNoneSelectedNoneCursor: Point? {
        if let p = lastEditedSheetWorldCenterPositionNoneSelectedNoneCursor {
            convertWorldToScreen(p)
        } else {
            nil
        }
    }
    var isSelectedNoneCursor: Bool {
        guard isNoneCursor else { return false }
        if lastEditedSheetposInView != nil {
            return true
        } else if !selections.isEmpty {
            var isIntersects = false
            for shp in world.sheetIDs.keys {
                let frame = sheetFrame(with: shp)
                if multiSelection.intersects(frame) && worldBounds.intersects(frame) {
                    isIntersects = true
                }
            }
            return isIntersects
        } else {
            return false
        }
    }
    var isSelectedOnlyNoneCursor: Bool {
        guard isNoneCursor else { return false }
        if !selections.isEmpty {
            if let shp = lastEditedSheetpos {
                let f = sheetFrame(with: shp)
                if worldBounds.intersects(f), multiSelection.intersects(f) {
                    return true
                }
            }
        }
        return false
    }
    
    func sheetViewAndFrame(at p: Point) -> (shp: Sheetpos,
                                              sheetView: SheetView?,
                                              frame: Rect,
                                              isAll: Bool) {
        let shp = sheetPosition(at: p)
        let frame = sheetFrame(with: shp)
        if let sheetView = sheetView(at: p) {
            if !isEditingSheet {
                return (shp, sheetView, frame, true)
            } else {
                let (bounds, isAll) = sheetView.model
                    .boundsTuple(at: sheetView.convertFromWorld(p),
                                 in: frame.bounds)
                return (shp, sheetView, bounds + frame.origin, isAll)
            }
        } else {
            return (shp, nil, frame, false)
        }
    }
    
    func worldBorder(at p: Point,
                     distance d: Double) -> (border: Border, edge: Edge)? {
        let shp = sheetPosition(at: p)
        let b = sheetFrame(with: shp)
        let topEdge = b.topEdge
        if topEdge.distance(from: p) < d {
            return (Border(.horizontal), topEdge)
        }
        let bottomEdge = b.bottomEdge
        if bottomEdge.distance(from: p) < d {
            return (Border(.horizontal), bottomEdge)
        }
        let leftEdge = b.leftEdge
        if leftEdge.distance(from: p) < d {
            return (Border(.vertical), leftEdge)
        }
        let rightEdge = b.rightEdge
        if rightEdge.distance(from: p) < d {
            return (Border(.vertical), rightEdge)
        }
        return nil
    }
    func border(at p: Point,
                distance d: Double) -> (border: Border, index: Int, edge: Edge)? {
        let shp = sheetPosition(at: p)
        guard let sheetView = sheetView(at: shp) else { return nil }
        let b = sheetFrame(with: shp)
        let inP = sheetView.convertFromWorld(p)
        for (i, border) in sheetView.model.borders.enumerated() {
            switch border.orientation {
            case .horizontal:
                if abs(inP.y - border.location) < d {
                    return (border, i,
                            Edge(Point(0, border.location) + b.origin,
                                 Point(b.width, border.location) + b.origin))
                }
            case .vertical:
                if abs(inP.x - border.location) < d {
                    return (border, i,
                            Edge(Point(border.location, 0) + b.origin,
                                 Point(border.location, b.height) + b.origin))
                }
            }
        }
        return nil
    }
    
    func colorPathValue(at p: Point, toColor: Color?,
                        color: Color, subColor: Color) -> ColorPathValue {
        if let sheetView = sheetView(at: p) {
            let inP = sheetView.convertFromWorld(p)
            return sheetView.sheetColorOwner(at: inP, 
                                             scale: screenToWorldScale).value
                .colorPathValue(toColor: toColor, color: color, subColor: subColor)
        } else {
            let shp = sheetPosition(at: p)
            return ColorPathValue(paths: [Path(sheetFrame(with: shp))],
                                  lineType: .color(color),
                                  fillType: .color(subColor))
        }
    }
    func uuColor(at p: Point) -> UUColor {
        if let sheetView = sheetView(at: p) {
            let inP = sheetView.convertFromWorld(p)
            return sheetView.sheetColorOwner(at: inP, 
                                             scale: screenToWorldScale).value.uuColor
        } else {
            return Sheet.defalutBackgroundUUColor
        }
    }
    func madeColorOwner(at p: Point,
                        removingUUColor: UUColor? = Line.defaultUUColor) -> [SheetColorOwner] {
        guard let sheetView = madeSheetView(at: p) else {
            return []
        }
        let inP = sheetView.convertFromWorld(p)
        return [sheetView.sheetColorOwner(at: inP,
                                          removingUUColor: removingUUColor,
                                          scale: screenToWorldScale).value]
    }
    func madeColorOwnersWithSelection(at p: Point) -> (firstUUColor: UUColor,
                                                       owners: [SheetColorOwner])? {
        guard let sheetView = madeSheetView(at: p) else {
            return nil
        }
        
        let inP = sheetView.convertFromWorld(p)
        let (isLine, topOwner) = sheetView.sheetColorOwner(at: inP,
                                                           scale: screenToWorldScale)
        let uuColor = topOwner.uuColor
        
        if isSelect(at: p), !isSelectedText {
            var colorOwners = [SheetColorOwner]()
            for selection in selections {
                let f = selection.rect
                for (shp, _) in sheetViewValues {
                    let ssFrame = sheetFrame(with: shp)
                    if ssFrame.intersects(f),
                       let sheetView = self.sheetView(at: shp) {
                        
                        let b = sheetView.convertFromWorld(f)
                        for co in sheetView.sheetColorOwner(at: b,
                                                            isLine: isLine) {
                            colorOwners.append(co)
                        }
                    }
                }
            }
            return (uuColor, colorOwners)
        } else {
            var colorOwners = [SheetColorOwner]()
            if let co = sheetView.sheetColorOwner(with: uuColor) {
                colorOwners.append(co)
            }
            return (uuColor, colorOwners)
        }
    }
    func colors(minArea: Double = 9, at p: Point) -> [Color] {
        guard let sheetView = sheetView(at: p) else {
            return []
        }
        let scale = screenToWorldScale
        let minArea = minArea * scale * scale
        return sheetView.model.picture.planes.compactMap {
            guard let area = $0.bounds?.area, area > minArea else {
                return nil
            }
            return $0.uuColor.value
        }
    }
    func readColorOwners(at p: Point) -> [SheetColorOwner] {
        guard let sheetView = readSheetView(at: p) else {
            return []
        }
        let inP = sheetView.convertFromWorld(p)
        let uuColor = sheetView.sheetColorOwner(at: inP,
                                                scale: screenToWorldScale).value.uuColor
        if let co = sheetView.sheetColorOwner(with: uuColor) {
            return [co]
        } else {
            return []
        }
    }
    func colorOwners(at p: Point) -> [SheetColorOwner] {
        guard let sheetView = readSheetView(at: p) else {
            return []
        }
        let inP = sheetView.convertFromWorld(p)
        return [sheetView.sheetColorOwner(at: inP,
                                          scale: screenToWorldScale).value]
    }
    func isDefaultUUColor(at p: Point) -> Bool {
        if let sheetView = sheetView(at: p) {
            let inP = sheetView.convertFromWorld(p)
            return sheetView.sheetColorOwner(at: inP,
                                             scale: screenToWorldScale).value.uuColor
                == Sheet.defalutBackgroundUUColor
        } else {
            return true
        }
    }
    
    var worldKnobEditDistance: Double {
        Sheet.knobEditDistance * screenToWorldScale
    }
    
    var isFullEditNote: Bool {
        camera.logScale < -4
    }
    var currentBeatInterval: Rational {
        isFullEditNote ? Sheet.fullEditBeatInterval : Sheet.beatInterval
    }
    var currentKeyframeBeatInterval: Rational {
        currentBeatInterval
    }
    var currentPitchInterval: Rational {
        isFullEditNote ? Sheet.fullEditPitchInterval : Sheet.pitchInterval
    }
    func smoothPitch(from scoreView: ScoreView, at scoreP: Point) -> Double? {
        scoreView.smoothPitch(atY: scoreP.y)
    }
    
    static let mapScale = 16
    let mapWidth = Sheet.width * Double(mapScale), mapHeight = Sheet.height * Double(mapScale)
    private var mapIntPositions = Set<IntPoint>()
    func mapIntPosition(at p: IntPoint) -> IntPoint {
        let x = (Rational(p.x) / Rational(Self.mapScale)).rounded(.down).integralPart
        let y = (Rational(p.y) / Rational(Self.mapScale)).rounded(.down).integralPart
        return .init(x, y)
    }
    func mapPosition(at ip: IntPoint) -> Point {
        Point(Double(ip.x) * mapWidth + mapWidth / 2,
              Double(ip.y) * mapHeight + mapHeight / 2)
    }
    func mapFrame(at shp: Sheetpos) -> Rect {
        Rect(x: Double(shp.x) * mapWidth,
             y: Double(shp.y) * mapHeight,
             width: mapWidth, height: mapHeight)
    }
    private var roads = [Road]()
    func updateMap() {
        mapIntPositions = Set(sheetRecorders.keys.reduce(into: [IntPoint]()) {
            if let shp = sheetPosition(at: $1) {
                if shp.isRight {
                    $0 += [mapIntPosition(at: IntPoint(shp.x, shp.y)),
                           mapIntPosition(at: IntPoint(shp.x + 1, shp.y))]
                } else {
                    $0.append(mapIntPosition(at: IntPoint(shp.x, shp.y)))
                }
            }
        })
        var roads = [Road]()
        
        var xSHPs = [Int: [IntPoint]]()
        for mSHP in mapIntPositions {
            if xSHPs[mSHP.y] != nil {
                xSHPs[mSHP.y]?.append(mSHP)
            } else {
                xSHPs[mSHP.y] = [mSHP]
            }
        }
        let sortedSHPs = xSHPs.sorted { $0.key < $1.key }
        var previousSHPs = [IntPoint]()
        for shpV in sortedSHPs {
            let sortedXSHPs = shpV.value.sorted { $0.x < $1.x }
            if sortedXSHPs.count > 1 {
                for i in 1 ..< sortedXSHPs.count {
                    roads.append(Road(shp0: sortedXSHPs[i - 1],
                                                        shp1: sortedXSHPs[i]))
                }
            }
            if !previousSHPs.isEmpty {
                roads.append(Road(shp0: previousSHPs[0],
                                  shp1: sortedXSHPs[0]))
            }
            previousSHPs = sortedXSHPs
        }
        
        self.roads = roads
        
        let pathlines = roads.compactMap {
            $0.pathlineWith(width: mapWidth, height: mapHeight)
        }
        mapNode.path = Path(pathlines, isCap: false)
    }
    func updateMapWith(worldToScreenTransform: Transform,
                       screenToWorldTransform: Transform,
                       camera: Camera,
                       in screenBounds: Rect) {
        let worldBounds = screenBounds * screenToWorldTransform
        for road in roads {
            if worldBounds.intersects(Edge(mapPosition(at: road.shp0),
                                           mapPosition(at: road.shp1))) {
                currentMapNode.isHidden = true
                currentMapNode.path = Path()
                return
            }
        }
        if currentMapNode.isHidden {
            currentMapNode.isHidden = false
        }
        
        let worldCP = screenBounds.centerPoint * screenToWorldTransform
        
        let currentIP = intPosition(at: worldCP)
        let mapSHP = mapIntPosition(at: currentIP)
        var minMSHP: IntPoint?, minDSquared = Int.max
        for mshp in mapIntPositions {
            let dSquared = mshp.distanceSquared(mapSHP)
            if dSquared < minDSquared {
                minDSquared = dSquared
                minMSHP = mshp
            }
        }
        if let minMSHP = minMSHP {
            let road = Road(shp0: minMSHP, shp1: mapSHP)
            if let pathline = road.pathlineWith(width: mapWidth,
                                                height: mapHeight) {
                currentMapNode.path = Path([pathline])
            } else {
                currentMapNode.path = Path()
            }
        } else {
            currentMapNode.path = Path()
        }
    }
    func updateGrid(with transform: Transform, in bounds: Rect) {
        let bounds = bounds * transform, lw = gridNode.lineWidth
        let scale = isEditingSheet ? 1.0 : Double(Self.mapScale)
        let w = Sheet.width * scale, h = Sheet.height * scale
        let cp = Point()
        var pathlines = [Pathline]()
        let minXIndex = Int(((bounds.minX - cp.x - lw) / w).rounded(.down))
        let maxXIndex = Int(((bounds.maxX - cp.x + lw) / w).rounded(.up))
        let minYIndex = Int(((bounds.minY - cp.y - lw) / h).rounded(.down))
        let maxYIndex = Int(((bounds.maxY - cp.y + lw) / h).rounded(.up))
        if maxXIndex - minXIndex > 0 {
            for xi in minXIndex ..< maxXIndex {
                let x = Double(xi) * w + cp.x
                
                var preYI = minYIndex
                for yi in minYIndex ..< maxYIndex {
                    let shp = sheetPosition(at: IntPoint(xi, yi))
                    if shp.x != xi && shp.isRight {
                        let minY = Double(preYI) * h + cp.y
                        let maxY = Double(yi) * h + cp.y
                        if preYI < yi {
                            pathlines.append(Pathline(Edge(Point(x: x, y: minY),
                                                           Point(x: x, y: maxY))))
                        }
                        preYI = yi + 1
                    }
                }
                if preYI < maxYIndex {
                    let minY = Double(preYI) * h + cp.y
                    let maxY = Double(maxYIndex) * h + cp.y
                    pathlines.append(Pathline(Edge(Point(x: x, y: minY),
                                                   Point(x: x, y: maxY))))
                }
            }
        }
        if maxYIndex - minYIndex > 0 {
            let minX = bounds.minX, maxX = bounds.maxX
            for i in minYIndex ..< maxYIndex {
                let y = Double(i) * h + cp.y
                pathlines.append(Pathline(Edge(Point(x: minX, y: y),
                                               Point(x: maxX, y: y))))
            }
        }
        gridNode.path = Path(pathlines, isCap: false)
        gridNode.lineWidth = transform.absXScale
        
        updateMapColor(with: transform)
    }
    private enum MapType {
        case hidden, shown
    }
    private var oldMapType = MapType.hidden
    func updateMapColor(with transform: Transform) {
        let mapType: MapType = isEditingSheet ? .hidden : .shown
        switch mapType {
        case .hidden:
            if oldMapType != .hidden {
                mapNode.isHidden = true
                backgroundColor = .background
                mapNode.lineType = .color(.border)
                currentMapNode.lineType = .color(.border)
            }
        case .shown:
            let scale = transform.absXScale
            mapNode.lineWidth = 3 * scale
            currentMapNode.lineWidth = 3 * scale
            if oldMapType != .shown {
                if oldMapType == .hidden {
                    mapNode.isHidden = false
                    backgroundColor = .disabled
                    mapNode.lineType = .color(.subBorder)
                    currentMapNode.lineType = .color(.subBorder)
                }
            }
        }
        oldMapType = mapType
    }
    
    func cursor(from string: String) -> Cursor {
        if camera.rotation != 0 {
            .rotate(string: string,
                    rotation: -camera.rotation + .pi / 2)
        } else {
            .circle(string: string)
        }
    }
    
    var modifierKeys = ModifierKeys()
    
    func indicate(with event: DragEvent) {
        cursorPoint = event.screenPoint
        textEditor.isMovedCursor = true
        textEditor.moveEndInputKey(isStopFromMarkedText: true)
    }
    
    private(set) var oldPinchEvent: PinchEvent?, zoomer: Zoomer?
    func pinch(_ event: PinchEvent) {
        switch event.phase {
        case .began:
            zoomer = Zoomer(self)
            zoomer?.send(event)
            oldPinchEvent = event
        case .changed:
            zoomer?.send(event)
            oldPinchEvent = event
        case .ended:
            oldPinchEvent = nil
            zoomer?.send(event)
            zoomer = nil
        }
    }
    
    private(set) var oldScrollEvent: ScrollEvent?, scroller: Scroller?
    func scroll(_ event: ScrollEvent) {
        textEditor.moveEndInputKey()
        switch event.phase {
        case .began:
            scroller = Scroller(self)
            scroller?.send(event)
            oldScrollEvent = event
        case .changed:
            scroller?.send(event)
            oldScrollEvent = event
        case .ended:
            oldScrollEvent = nil
            scroller?.send(event)
            scroller = nil
        }
    }
    
    private(set) var oldSwipeEvent: SwipeEvent?, swiper: KeyframeSwiper?
    func swipe(_ event: SwipeEvent) {
        textEditor.moveEndInputKey()
        switch event.phase {
        case .began:
            swiper = KeyframeSwiper(self)
            swiper?.send(event)
            oldSwipeEvent = event
        case .changed:
            swiper?.send(event)
            oldSwipeEvent = event
        case .ended:
            oldSwipeEvent = nil
            swiper?.send(event)
            swiper = nil
        }
    }
    
    private(set) var oldRotateEvent: RotateEvent?, rotater: Rotater?
    func rotate(_ event: RotateEvent) {
        switch event.phase {
        case .began:
            rotater = Rotater(self)
            rotater?.send(event)
            oldRotateEvent = event
        case .changed:
            rotater?.send(event)
            oldRotateEvent = event
        case .ended:
            oldRotateEvent = nil
            rotater?.send(event)
            rotater = nil
        }
    }
    
    func strongDrag(_ event: DragEvent) {}
    
    private(set) var oldSubDragEvent: DragEvent?, subDragEditor: (any DragEditor)?
    func subDrag(_ event: DragEvent) {
        switch event.phase {
        case .began:
            updateLastEditedSheetpos(from: event)
            stopInputTextEvent()
            subDragEditor = RangeSelector(self)
            subDragEditor?.send(event)
            oldSubDragEvent = event
            textCursorNode.isHidden = true
            textMaxTypelineWidthNode.isHidden = true
        case .changed:
            subDragEditor?.send(event)
            oldSubDragEvent = event
        case .ended:
            oldSubDragEvent = nil
            subDragEditor?.send(event)
            subDragEditor = nil
            cursorPoint = event.screenPoint
        }
    }
    
    private(set) var oldMiddleDragEvent: DragEvent?, middleDragEditor: (any DragEditor)?
    func middleDrag(_ event: DragEvent) {
        switch event.phase {
        case .began:
            updateLastEditedSheetpos(from: event)
            stopInputTextEvent()
            middleDragEditor = LassoCutter(self)
            middleDragEditor?.send(event)
            oldMiddleDragEvent = event
            textCursorNode.isHidden = true
            textMaxTypelineWidthNode.isHidden = true
        case .changed:
            middleDragEditor?.send(event)
            oldMiddleDragEvent = event
        case .ended:
            oldMiddleDragEvent = nil
            middleDragEditor?.send(event)
            middleDragEditor = nil
            cursorPoint = event.screenPoint
        }
    }
    
    private func dragEditor(with quasimode: Quasimode) -> (any DragEditor)? {
        switch quasimode {
        case .drawLine: LineDrawer(self)
        case .drawStraightLine: StraightLineDrawer(self)
        case .lassoCut: LassoCutter(self)
        case .selectByRange: RangeSelector(self)
        case .changeLightness: LightnessChanger(self)
        case .changeTint: TintChanger(self)
        case .slide: Slider(self)
        case .selectFrame: FrameSelecter(self)
        case .moveLinePoint: LineSlider(self)
        case .moveLineZ: LineZSlider(self)
        case .selectVersion: VersionSelector(self)
        default: nil
        }
    }
    private(set) var oldDragEvent: DragEvent?, dragEditor: (any DragEditor)?
    func drag(_ event: DragEvent) {
        switch event.phase {
        case .began:
            updateLastEditedSheetpos(from: event)
            stopInputTextEvent()
            let quasimode = Quasimode(modifier: modifierKeys, .drag)
            if quasimode != .selectFrame {
                stopInputKeyEvent()
            }
            dragEditor = self.dragEditor(with: quasimode)
            dragEditor?.send(event)
            oldDragEvent = event
            textCursorNode.isHidden = true
            textMaxTypelineWidthNode.isHidden = true
            
            isUpdateWithCursorPosition = false
            cursorPoint = event.screenPoint
        case .changed:
            dragEditor?.send(event)
            oldDragEvent = event
            
            cursorPoint = event.screenPoint
        case .ended:
            oldDragEvent = nil
            dragEditor?.send(event)
            dragEditor = nil
            
            isUpdateWithCursorPosition = true
            cursorPoint = event.screenPoint
        }
    }
    
    private(set) var oldInputTextKeys = Set<InputKeyType>()
    lazy private(set) var textEditor: TextEditor = { TextEditor(self) } ()
    func inputText(_ event: InputTextEvent) {
        switch event.phase {
        case .began:
            updateLastEditedSheetpos(from: event)
            oldInputTextKeys.insert(event.inputKeyType)
            textEditor.send(event)
        case .changed:
            textEditor.send(event)
        case .ended:
            oldInputTextKeys.remove(event.inputKeyType)
            textEditor.send(event)
        }
    }
    
    var runners = Set<RunEditor>() {
        didSet {
            updateRunners()
        }
    }
    var runnerNodes = [(origin: Point, node: Node)]()
    var runnersNode: Node?
    func updateRunners() {
        runnerNodes.forEach { $0.node.removeFromParent() }
        runnerNodes = runners.map {
            let text = Text(string: "Calculating".localized)
            let textNode = text.node
            let node = Node(children: [textNode], isHidden: true,
                            path: Path(textNode.bounds?
                                        .inset(by: -10) ?? Rect(),
                                       cornerRadius: 8),
                            lineWidth: 1, lineType: .color(.border),
                            fillType: .color(.background))
            return ($0.worldPrintOrigin, node)
        }
        runnerNodes.forEach { rootNode.append(child: $0.node) }
        
        updateRunnerNodesPosition()
    }
    func updateRunnerNodesPosition() {
        guard !runnerNodes.isEmpty else { return }
        let b = screenBounds.inset(by: 5)
        for (p, node) in runnerNodes {
            let sp = convertWorldToScreen(p)
            if !b.contains(sp) || worldToScreenScale < 0.25 {
                node.isHidden = false
                
                let fp = b.centerPoint
                let ps = b.intersection(Edge(fp, sp))
                if !ps.isEmpty, let cvb = node.bounds {
                    let np = ps[0]
                    let cvf = Rect(x: np.x - cvb.width / 2,
                                   y: np.y - cvb.height / 2,
                                   width: cvb.width, height: cvb.height)
                    let nf = screenBounds.inset(by: 5).clipped(cvf)
                    node.attitude.position
                        = convertScreenToWorld(nf.origin - cvb.origin)
                } else {
                    node.attitude.position = p
                }
                node.attitude.scale = Size(square: 1 / worldToScreenScale)
                if camera.rotation != 0 {
                    node.attitude.rotation = camera.rotation
                }
            } else {
                node.isHidden = true
            }
        }
    }
    
    private func inputKeyEditor(with quasimode: Quasimode) -> (any InputKeyEditor)? {
        switch quasimode {
        case .cut: Cutter(self)
        case .copy: Copier(self)
        case .copyLineColor: LineColorCopier(self)
        case .copyTone: ToneCopier(self)
        case .paste: Paster(self)
        case .undo: Undoer(self)
        case .redo: Redoer(self)
        case .find: Finder(self)
        case .lookUp: Looker(self)
        case .changeToVerticalText: VerticalTextChanger(self)
        case .changeToHorizontalText: HorizontalTextChanger(self)
        case .changeToSuperscript: SuperscriptChanger(self)
        case .changeToSubscript: SubscriptChanger(self)
        case .run: Runner(self)
        case .changeToDraft: DraftChanger(self)
        case .cutDraft: DraftCutter(self)
        case .makeFaces: FacesMaker(self)
        case .cutFaces: FacesCutter(self)
        case .play, .sPlay: Player(self)
        case .movePreviousKeyframe: KeyframePreviousMover(self)
        case .moveNextKeyframe: KeyframeNextMover(self)
        case .movePreviousFrame: FramePreviousMover(self)
        case .moveNextFrame: FrameNextMover(self)
        case .insertKeyframe: KeyframeInserter(self)
        case .addScore: ScoreAdder(self)
        case .interpolate: Interpolater(self)
        case .crossErase: CrossEraser(self)
        case .showTone: ToneShower(self)
        default: nil
        }
    }
    private(set) var oldInputKeyEvent: InputKeyEvent?
    private(set) var inputKeyEditor: (any InputKeyEditor)?
    func inputKey(_ event: InputKeyEvent) {
        switch event.phase {
        case .began:
            updateLastEditedSheetpos(from: event)
            guard inputKeyEditor == nil else { return }
            let quasimode = Quasimode(modifier: modifierKeys,
                                      event.inputKeyType)
            if textEditor.editingTextView != nil
                && quasimode != .changeToSuperscript
                && quasimode != .changeToSubscript
                && quasimode != .changeToHorizontalText
                && quasimode != .changeToVerticalText
                && quasimode != .paste {
                
                stopInputTextEvent(isEndEdit: quasimode != .undo
                                    && quasimode != .redo)
            }
            if quasimode == .run {
                textEditor.moveEndInputKey()
            }
            stopDragEvent()
            inputKeyEditor = self.inputKeyEditor(with: quasimode)
            inputKeyEditor?.send(event)
            oldInputKeyEvent = event
        case .changed:
            inputKeyEditor?.send(event)
            oldInputKeyEvent = event
        case .ended:
            oldInputKeyEvent = nil
            inputKeyEditor?.send(event)
            inputKeyEditor = nil
        }
    }
    
    func stop(with event: any Event) {
        switch event.phase {
        case .began:
            cursor = .block
        case .changed:
            break
        case .ended:
            cursor = defaultCursor
        }
    }
    func stopPlaying(with event: any Event) {
        switch event.phase {
        case .began:
            cursor = .stop
            
            for (_, v) in sheetViewValues {
                v.view?.stop()
            }
        case .changed:
            break
        case .ended:
            cursor = defaultCursor
        }
    }
    
    func stopAllEvents(isEnableText: Bool = true) {
        stopPinchEvent()
        stopScrollEvent()
        stopSwipeEvent()
        stopDragEvent()
        if isEnableText {
            stopInputTextEvent()
        }
        stopInputKeyEvent()
        if isEnableText {
            textEditor.moveEndInputKey()
        }
        modifierKeys = []
    }
    func stopPinchEvent() {
        if var event = oldPinchEvent, let pinchEditor = zoomer {
            event.phase = .ended
            self.zoomer = nil
            oldPinchEvent = nil
            pinchEditor.send(event)
        }
    }
    func stopScrollEvent() {
        if var event = oldScrollEvent, let scrollEditor = scroller {
            event.phase = .ended
            self.scroller = nil
            oldScrollEvent = nil
            scrollEditor.send(event)
        }
    }
    func stopSwipeEvent() {
        if var event = oldSwipeEvent, let swiper {
            event.phase = .ended
            self.swiper = nil
            oldSwipeEvent = nil
            swiper.send(event)
        }
    }
    func stopDragEvent() {
        if var event = oldDragEvent, let dragEditor = dragEditor {
            event.phase = .ended
            self.dragEditor = nil
            oldDragEvent = nil
            dragEditor.send(event)
        }
    }
    func stopInputTextEvent(isEndEdit: Bool = true) {
        oldInputTextKeys.removeAll()
        textEditor.stopInputKey(isEndEdit: isEndEdit)
    }
    func stopInputKeyEvent() {
        if var event = oldInputKeyEvent, let inputKeyEditor = inputKeyEditor {
            event.phase = .ended
            self.inputKeyEditor = nil
            oldInputKeyEvent = nil
            inputKeyEditor.send(event)
        }
    }
    func updateEditorNode() {
        zoomer?.updateNode()
        scroller?.updateNode()
        swiper?.updateNode()
        dragEditor?.updateNode()
        inputKeyEditor?.updateNode()
    }
}
