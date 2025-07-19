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

final class ImportAction: InputKeyEventAction {
    let action: IOAction
    
    init(_ rootAction: RootAction) {
        action = IOAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.importFile(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class StartExportAction: InputKeyEventAction {
    let action: IOAction
    
    init(_ rootAction: RootAction) {
        action = IOAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.exportFile(with: event, .image)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class ExportAsImageAction: InputKeyEventAction {
    let action: IOAction
    
    init(_ rootAction: RootAction) {
        action = IOAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.exportFile(with: event, .image)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class ExportAs4KImageAction: InputKeyEventAction {
    let action: IOAction
    
    init(_ rootAction: RootAction) {
        action = IOAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.exportFile(with: event, .image4K)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class ExportAsPDFAction: InputKeyEventAction {
    let action: IOAction
    
    init(_ rootAction: RootAction) {
        action = IOAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.exportFile(with: event, .pdf)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class ExportAsGIFAction: InputKeyEventAction {
    let action: IOAction
    
    init(_ rootAction: RootAction) {
        action = IOAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.exportFile(with: event, .gif)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class ExportAsMovieAction: InputKeyEventAction {
    let action: IOAction
    
    init(_ rootAction: RootAction) {
        action = IOAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        
        action.exportFile(with: event, .movie)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class ExportAs4KMovieAction: InputKeyEventAction {
    let action: IOAction
    
    init(_ rootAction: RootAction) {
        action = IOAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.exportFile(with: event, .movie4K)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class ExportAsSoundAction: InputKeyEventAction {
    let action: IOAction
    
    init(_ rootAction: RootAction) {
        action = IOAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.exportFile(with: event, .sound)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class ExportAsLinearPCMAction: InputKeyEventAction {
    let action: IOAction
    
    init(_ rootAction: RootAction) {
        action = IOAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.exportFile(with: event, .linearPCM)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class ExportAsDocumentAction: InputKeyEventAction {
    let action: IOAction
    
    init(_ rootAction: RootAction) {
        action = IOAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.exportFile(with: event, .document)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class ExportAsDocumentWithHistoryAction: InputKeyEventAction {
    let action: IOAction
    
    init(_ rootAction: RootAction) {
        action = IOAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.exportFile(with: event, .documentWithHistory)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class IOAction: Action {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    var fp = Point()
    
    let pngMaxWidth = 2048.0, pdfMaxWidth = 512.0
    
    let selectingLineNode = Node(lineWidth: 1.5)
    func updateNode() {
        selectingLineNode.lineWidth = rootView.worldLineWidth
    }
    func end(isUpdateSelect: Bool = false, isUpdateCursor: Bool = true) {
        selectingLineNode.removeFromParent()
        
        if isUpdateSelect {
            rootView.updateSelects()
        }
        if isUpdateCursor {
            rootView.cursor = rootView.defaultCursor
        }
        rootView.updateSelectedColor(isMain: true)
    }
    func name(from shp: IntPoint) -> String {
        return "\(shp.x)_\(shp.y)"
    }
    func name(from shps: [IntPoint]) -> String {
        if shps.isEmpty {
            return "Empty"
        } else if shps.count == 1 {
            return name(from: shps[0])
        } else {
            return "\(name(from: shps[.first]))__"
        }
    }
    
    func sorted(_ vs: [SelectingValue],
                with rectCorner: RectCorner) -> [SelectingValue] {
        switch rectCorner {
        case .minXMinY:
            vs.sorted {
                $0.shp.y != $1.shp.y ?
                    $0.shp.y > $1.shp.y :
                    $0.shp.x > $1.shp.x
            }
        case .minXMaxY:
            vs.sorted {
                $0.shp.y != $1.shp.y ?
                    $0.shp.y < $1.shp.y :
                    $0.shp.x > $1.shp.x
            }
        case .maxXMinY:
            vs.sorted {
                $0.shp.y != $1.shp.y ?
                    $0.shp.y > $1.shp.y :
                    $0.shp.x < $1.shp.x
            }
        case .maxXMaxY:
            vs.sorted {
                $0.shp.y != $1.shp.y ?
                    $0.shp.y < $1.shp.y :
                    $0.shp.x < $1.shp.x
            }
        }
    }
    
    @discardableResult func beginImportFile(at sp: Point) -> IntPoint {
        fp = rootView.convertScreenToWorld(sp)
        selectingLineNode.lineWidth = rootView.worldLineWidth
        selectingLineNode.fillType = .color(.subSelected)
        selectingLineNode.lineType = .color(.selected)
        let shp = rootView.sheetPosition(at: fp)
        let frame = rootView.sheetFrame(with: shp)
        selectingLineNode.path = Path(frame)
        rootView.node.append(child: selectingLineNode)
        
        rootView.textCursorNode.isHidden = true
        rootView.textMaxTypelineWidthNode.isHidden = true
        
        rootView.updateSelectedColor(isMain: false)
        
        return shp
    }
    func importFile(from urls: [URL], at shp: IntPoint) {
        var mshp = shp
        var onSHPs = [IntPoint](), willremoveSHPs = [IntPoint]()
        for url in urls {
            let importedDocument = Document(url, isLoadOnly: true)
            let world = importedDocument.world()
            
            var maxX = mshp.x
            for (osid, _) in importedDocument.sheetRecorders {
                guard let oshp = world.sheetPositions[osid] else {
                    continue
                }
                let nshp = oshp + mshp
                if rootView.sheetID(at: nshp) != nil {
                    willremoveSHPs.append(nshp)
                }
                
                onSHPs.append(nshp)
                
                if nshp.x > maxX {
                    maxX = nshp.x
                }
            }
            mshp.x = maxX + 2
        }
        let nSHPs = onSHPs
        
        var oldP: Point?
        let viewSHPs = sorted(nSHPs.map { SelectingValue(shp: $0, bounds: Rect()) }, with: .maxXMinY)
            .map { $0.shp }
        selectingLineNode.children = viewSHPs.map {
            let frame = rootView.sheetFrame(with: $0)
            if let op = oldP {
                let cp = frame.centerPoint
                let path = Path([Pathline([op, cp])])
                let arrowNode = Node(path: path,
                                     lineWidth: selectingLineNode.lineWidth,
                                     lineType: selectingLineNode.lineType)
                oldP = frame.centerPoint
                return Node(children: [arrowNode],
                            path: Path(frame),
                            lineWidth: selectingLineNode.lineWidth,
                            lineType: selectingLineNode.lineType,
                            fillType: selectingLineNode.fillType)
            } else {
                oldP = frame.centerPoint
                return Node(path: Path(frame),
                            lineWidth: selectingLineNode.lineWidth,
                            lineType: selectingLineNode.lineType,
                            fillType: selectingLineNode.fillType)
            }
        } + willremoveSHPs.map {
            Node(path: Path(rootView.sheetFrame(with: $0)),
                 lineWidth: selectingLineNode.lineWidth * 2,
                 lineType: selectingLineNode.lineType,
                 fillType: selectingLineNode.fillType)
        }
        
        let length = urls.reduce(0) { $0 + ($1.fileSize ?? 0) }
        
        let contentURLs = urls.filter { Content.type(from: $0) != .none }
        if !contentURLs.isEmpty {
            var dshp = IntPoint()
            let xCount = max(1, Int(Double(contentURLs.count).squareRoot()))
            for url in contentURLs {
                if let sheetView = rootView.madeSheetView(at: shp + dshp) {
                    let np = contentURLs.count == 1 ? sheetView.convertFromWorld(fp) : Point(10, 50)
                    let filename = url.deletingPathExtension().lastPathComponent
                    let name = UUID().uuidString + "." + url.pathExtension
                    
                    if let directory = rootView.model.sheetRecorders[sheetView.id]?.contentsDirectory {
                        directory.isWillwrite = true
                        try? directory.write()
                        try? directory.copy(name: name, from: url)
                    }
                    
                    let maxBounds = rootView.sheetFrame(with: shp).bounds.inset(by: Sheet.textPadding)
                    let content = Content(directoryName: sheetView.id.uuidString,
                                          name: name, origin: rootView.roundedPoint(from: np))
                    if content.type == .movie {
                        Task.detached(priority: .high) {
                            if let size = try? await Movie.size(from: content.url),
                               let durSec = try? await Movie.durSec(from: content.url),
                               let frameRate = try? await Movie.frameRate(from: content.url) {
                                
                                Task { @MainActor in
                                    var content = content
                                    var size = size / 2
                                    let maxSize = maxBounds.size
                                    if size.width > maxSize.width || size.height > maxSize.height {
                                        size *= min(maxSize.width / size.width, maxSize.height / size.height)
                                    }
                                    content.size = size
                                    let nnp = maxBounds.clipped(Rect(origin: content.origin,
                                                                     size: content.size)).origin
                                    content.origin = nnp
                                    
                                    content.durSec = durSec
                                    content.frameRate = Rational(Int(frameRate))
                                    
                                    let tempo = Music.defaultTempo
                                    let durBeat = ContentTimeOption.beat(fromSec: durSec, tempo: tempo)
                                    let beatRange = Range(start: 0, length: durBeat)
                                    content.timeOption = .init(beatRange: beatRange, tempo: tempo)
                                    
                                    var text = Text(string: filename, origin: nnp)
                                    text.origin.y -= (content.type.hasDur ? Sheet.timelineHalfHeight : 0) + text.size / 2 + 4
                                    if text.origin.y < Sheet.textPadding.height {
                                        let d = Sheet.textPadding.height - text.origin.y
                                        text.origin.y += d
                                        content.origin.y += d
                                    }
                                    sheetView.newUndoGroup()
                                    sheetView.append(text)
                                    sheetView.append(content)
                                }
                            }
                        }
                    } else {
                        var content = content
                        content.normalizeVolm()
                        if let size = content.image?.size {
                            var size = size / 2
                            let maxSize = maxBounds.size
                            if size.width > maxSize.width || size.height > maxSize.height {
                                size *= min(maxSize.width / size.width, maxSize.height / size.height)
                            }
                            content.size = size
                        }
                        let nnp = maxBounds.clipped(Rect(origin: content.origin,
                                                         size: content.size)).origin
                        content.origin = nnp
                        if content.type.hasDur {
                            let tempo = sheetView.nearestTempo(at: np) ?? Music.defaultTempo
                            let interval = rootView.currentBeatInterval
                            let startBeat = sheetView.animationView.beat(atX: np.x, interval: interval)
                            let durBeat = ContentTimeOption.beat(fromSec: content.durSec, tempo: tempo)
                            let beatRange = Range(start: startBeat, length: durBeat)
                            content.timeOption = .init(beatRange: beatRange, tempo: tempo)
                        }
                        
                        var text = Text(string: filename, origin: nnp)
                        text.origin.y -= (content.type.hasDur ? Sheet.timelineHalfHeight : 0) + text.size / 2 + 4
                        if text.origin.y < Sheet.textPadding.height {
                            let d = Sheet.textPadding.height - text.origin.y
                            text.origin.y += d
                            content.origin.y += d
                        }
                        sheetView.newUndoGroup()
                        sheetView.append(text)
                        sheetView.append(content)
                    }
                }
                
                dshp.x += 1
                if dshp.x >= xCount {
                    dshp.x = 0
                    dshp.y -= 1
                }
            }
            end(isUpdateSelect: true)
            return
        }
        
        if willremoveSHPs.isEmpty && urls.count == 1 {
            loadFile(from: urls, at: shp)
            end(isUpdateSelect: true)
        } else {
            let message: String
            if willremoveSHPs.isEmpty {
                if urls.count >= 2 {
                    message = String(format: "Do you want to import a total of %2$d sheets from %1$d documents?".localized, urls.count, nSHPs.count)
                } else {
                    message = String(format: "Do you want to import %1$d sheets?".localized, nSHPs.count)
                }
            } else {
                if urls.count >= 2 {
                    message = String(format: "Do you want to import a total of $2$d sheets from %1$d documents, replacing %3$d existing sheets?".localized, urls.count, nSHPs.count, willremoveSHPs.count)
                } else {
                    message = String(format: "Do you want to import $1$d sheets and replace the %2$d existing sheets?".localized, nSHPs.count, willremoveSHPs.count)
                }
            }
            Task { @MainActor in
                let result = await rootView.node
                    .show(message: message,
                          infomation: "This operation can be undone when in root mode, but the data will remain until the root history is cleared.".localized,
                          okTitle: "Import".localized,
                          isSaftyCheck: nSHPs.count > 100 || length > 20*1024*1024)
                switch result {
                case .ok:
                    loadFile(from: urls, at: shp)
                    end(isUpdateSelect: true)
                case .cancel:
                    end(isUpdateSelect: true)
                }
            }
        }
    }
    func loadFile(from urls: [URL], at shp: IntPoint) {
        var mshp = shp
        var nSIDs = [IntPoint: UUID](), willremoveSHPs = [IntPoint]()
        var resetSIDs = Set<UUID>()
        for url in urls {
            let importedDocument = Document(url, isLoadOnly: true)
            let world = importedDocument.world()
            
            var maxX = mshp.x
            for (osid, osrr) in importedDocument.sheetRecorders {
                guard let oshp = world.sheetPositions[osid] else {
                    let nsid = rootView.appendSheet(from: osrr)
                    resetSIDs.insert(nsid)
                    continue
                }
                let nshp = oshp + mshp
                if rootView.sheetID(at: nshp) != nil {
                    willremoveSHPs.append(nshp)
                }
                nSIDs[nshp] = rootView.appendSheet(from: osrr)
                
                if nshp.x > maxX {
                    maxX = nshp.x
                }
            }
            mshp.x = maxX + 2
        }
        if !willremoveSHPs.isEmpty || !nSIDs.isEmpty || !resetSIDs.isEmpty {
            rootView.history.newUndoGroup()
            if !willremoveSHPs.isEmpty {
                rootView.removeSheets(at: willremoveSHPs)
            }
            if !nSIDs.isEmpty {
                rootView.append(nSIDs)
            }
            if !resetSIDs.isEmpty {
                rootView.moveSheetsToUpperRightCorner(with: Array(resetSIDs),
                                                      isNewUndoGroup: false)
                rootView.node.show(RootView.ReadingError())
            }
            rootView.updateNode()
        }
    }
    func importFile(with event: InputKeyEvent) {
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            let sp = rootView.lastEditedSheetScreenCenterPositionNoneSelectedNoneCursor ?? event.screenPoint
            beginImportFile(at: sp)
        case .changed:
            break
        case .ended:
            Task { @MainActor in
                let result = await URL.load(prompt: "Import".localized,
                                            allowsMultipleSelection: true,
                                            fileTypes: Document.FileType.allCases + Content.FileType.allCases)
                switch result {
                case .complete(let ioResults):
                    let shp = rootView.sheetPosition(at: fp)
                    importFile(from: ioResults.map { $0.url }, at: shp)
                case .cancel:
                    end(isUpdateSelect: true)
                }
            }
        }
    }
    
    struct SelectingValue {
        var shp: IntPoint, bounds: Rect
    }
    
    enum ExportType {
        case image, image4K, pdf, gif, movie, movie4K,
             sound, linearPCM, document, documentWithHistory
        var isDocument: Bool {
            self == .document || self == .documentWithHistory
        }
    }
    
    func exportFile(with event: InputKeyEvent, _ type: ExportType) {
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
                ?? event.screenPoint
            fp = rootView.convertScreenToWorld(sp)
            if rootView.isSelectNoneCursor(at: fp),
               !rootView.isSelectedText, !rootView.selections.isEmpty {
                
                var nvs = [SelectingValue]()
                for selection in rootView.selections {
                    let vs: [SelectingValue] = rootView.world.sheetIDs.keys.compactMap { shp in
                        let frame = rootView.sheetFrame(with: shp)
                        if let rf = selection.rect.intersection(frame) {
                            if rootView.isEditingSheet {
                                let nf = rf - frame.origin
                                return SelectingValue(shp: shp,
                                                      bounds: nf)
                            } else {
                                return SelectingValue(shp: shp,
                                                      bounds: frame.bounds)
                            }
                        } else {
                            return nil
                        }
                    }
                    nvs += sorted(vs, with: selection.rectCorner)
                }
                
                if let unionFrame = rootView.isEditingSheet
                    && nvs.count > 1 && !type.isDocument ?
                        rootView.multiSelection.firstSelection(at: fp)?.rect : nil {
                    
                    selectingLineNode.lineWidth = rootView.worldLineWidth
                    selectingLineNode.fillType = .color(.subSelected)
                    selectingLineNode.lineType = .color(.selected)
                    selectingLineNode.path = Path(unionFrame)
                } else {
                    var oldP: Point?
                    selectingLineNode.children = nvs.map {
                        let frame = !type.isDocument ?
                        ($0.bounds + rootView.sheetFrame(with: $0.shp).origin) :
                        rootView.sheetFrame(with: $0.shp)
                        
                        if !type.isDocument, let op = oldP {
                            let cp = frame.centerPoint
                            let a = op.angle(cp) - .pi
                            let d = min(frame.width, frame.height) / 4
                            let p0 = cp.movedWith(distance: d, angle: a + .pi / 6)
                            let p1 = cp.movedWith(distance: d, angle: a - .pi / 6)
                            let path = Path([Pathline([op, cp]),
                                             Pathline([p0, cp, p1])])
                            let arrowNode = Node(path: path,
                                                 lineWidth: rootView.worldLineWidth,
                                                 lineType: .color(.selected))
                            oldP = frame.centerPoint
                            return Node(children: [arrowNode],
                                        path: Path(frame),
                                        lineWidth: rootView.worldLineWidth,
                                        lineType: .color(.selected),
                                        fillType: .color(.subSelected))
                        } else {
                            oldP = frame.centerPoint
                            return Node(path: Path(frame),
                                        lineWidth: rootView.worldLineWidth,
                                        lineType: .color(.selected),
                                        fillType: .color(.subSelected))
                        }
                    }
                }
            } else {
                selectingLineNode.lineWidth = rootView.worldLineWidth
                selectingLineNode.fillType = .color(.subSelected)
                selectingLineNode.lineType = .color(.selected)
                if !type.isDocument {
                    let (_, _, frame, _) = rootView.sheetViewAndFrame(at: fp)
                    selectingLineNode.path = Path(frame)
                } else {
                    let frame = rootView.sheetFrame(with: rootView.sheetPosition(at: fp))
                    selectingLineNode.path = Path(frame)
                }
                
                rootView.updateSelectedColor(isMain: false)
            }
            rootView.node.append(child: selectingLineNode)
            
            rootView.textCursorNode.isHidden = true
            rootView.textMaxTypelineWidthNode.isHidden = true
        case .changed:
            break
        case .ended:
            beginExportFile(type, at: fp)
        }
    }
    
    struct Rendering {
        struct Item {
            var sheet: Sheet?, data: Data?, url: URL?, frame = Rect()
            
            func decodedSheet() -> Sheet? {
                if let sheet {
                    sheet
                } else if let data {
                    try? .init(serializedData: data)
                } else if let url, let data = try? Data(contentsOf: url) {
                    try? .init(serializedData: data)
                } else {
                    nil
                }
            }
        }
        var mainItem: Item, bottomItems = [Item](), topItems = [Item]()
        var bounds: Rect
        
        func renderableMainSheetNode() -> CPUNode? {
            guard mainItem.url != nil else {
                return .init(path: .init(bounds), fillType: .color(.background))
            }
            guard let sheet = mainItem.decodedSheet() else { return nil }
            return sheet.node(isBorder: false, attitude: .init(position: mainItem.frame.origin), in: bounds)
        }
    }
    
    func beginExportFile(_ type: ExportType, at p: Point) {
        let nvs: [SelectingValue], unionFrame: Rect?
        if rootView.isSelectNoneCursor(at: p), !rootView.isSelectedText {
            nvs = rootView.selections.flatMap { selection in
                let vs: [SelectingValue] = rootView.world.sheetIDs.keys.compactMap { shp in
                    let frame = rootView.sheetFrame(with: shp)
                    if let rf = selection.rect.intersection(frame) {
                        if rootView.isEditingSheet {
                            let nf = rf - frame.origin
                            return SelectingValue(shp: shp,
                                                  bounds: nf)
                        } else {
                            return SelectingValue(shp: shp,
                                                  bounds: frame.bounds)
                        }
                    } else {
                        return nil
                    }
                }
                return sorted(vs, with: selection.rectCorner)
            }
            
            unionFrame = rootView.isEditingSheet && nvs.count > 1 && !type.isDocument ?
            rootView.multiSelection.firstSelection(at: p)?.rect : nil
        } else {
            let (shp, sheetView, frame, _) = rootView.sheetViewAndFrame(at: p)
            if let sheetView {
                let bounds = sheetView.model.boundsTuple(at: sheetView.convertFromWorld(p),
                                                         in: rootView.sheetFrame(with: shp).bounds).bounds.integral
                nvs = [SelectingValue(shp: shp, bounds: bounds)]
            } else {
                let bounds = Rect(size: frame.size)
                nvs = [SelectingValue(shp: shp, bounds: bounds)]
            }
            
            unionFrame = nil
        }
        
        guard let fv = nvs.first else {
            end()
            return
        }
        let size = unionFrame?.size ??
        (nvs.count >= 2 ? rootView.sheetView(at: fv.shp)?.model.mainFrame?.size : nil) ?? fv.bounds.size
        guard size.width > 0 && size.height > 0 else {
            end()
            return
        }
        
        let colorSpace = ColorSpace.export
        
        let renderings: [Rendering], documentRecorders: [Document.SheetRecorder]
        switch type {
        case .image, .image4K, .pdf:
            renderings = nvs.map {
                if let sid = rootView.sheetID(at: $0.shp),
                   let sheetRecord = rootView.model.sheetRecorders[sid]?.sheetRecord {
                    
                    .init(mainItem: .init(sheet: sheetRecord.value, data: sheetRecord.data, url: sheetRecord.url,
                                          frame: rootView.sheetFrame(with: $0.shp)),
                          bounds: $0.bounds)
                } else {
                    .init(mainItem: .init(sheet: nil, data: nil, url: nil,
                                          frame: rootView.sheetFrame(with: $0.shp)),
                          bounds: $0.bounds)
                }
            }
            documentRecorders = []
        case .gif, .movie, .movie4K, .sound, .linearPCM:
            renderings = nvs.map {
                var filledShps = Set<IntPoint>()
                
                var bottomItems = [Rendering.Item]()
                var shp = $0.shp
                shp.y -= 1
                while let sid = self.rootView.sheetID(at: shp),
                      let sheetRecord = rootView.model.sheetRecorders[sid]?.sheetRecord {
                    
                    if !filledShps.contains(shp) {
                        filledShps.insert(shp)
                        
                        bottomItems.append(.init(sheet: sheetRecord.value, data: sheetRecord.data,
                                                 url: sheetRecord.url,
                                                 frame: rootView.sheetFrame(with: shp)))
                    }
                    shp.y -= 1
                }
                
                var topItems = [Rendering.Item]()
                shp = $0.shp
                shp.y += 1
                while let sid = self.rootView.sheetID(at: shp),
                      let sheetRecord = rootView.model.sheetRecorders[sid]?.sheetRecord {
                    
                    if !filledShps.contains(shp) {
                        filledShps.insert(shp)
                        
                        topItems.append(.init(sheet: sheetRecord.value, data: sheetRecord.data,
                                              url: sheetRecord.url,
                                              frame: rootView.sheetFrame(with: shp)))
                    }
                    
                    shp.y += 1
                }
                
                return if let sid = rootView.sheetID(at: $0.shp),
                          let sheetRecord = rootView.model.sheetRecorders[sid]?.sheetRecord {
                    .init(mainItem: .init(sheet: sheetRecord.value, data: sheetRecord.data, url: sheetRecord.url,
                                          frame: rootView.sheetFrame(with: $0.shp)),
                          bottomItems: bottomItems, topItems: topItems,
                          bounds: $0.bounds)
                } else {
                    .init(mainItem: .init(sheet: nil, data: nil, url: nil,
                                          frame: rootView.sheetFrame(with: $0.shp)),
                          bottomItems: bottomItems, topItems: topItems,
                          bounds: $0.bounds)
                }
            }
            documentRecorders = []
        case .document, .documentWithHistory:
            let sids = nvs.reduce(into: [IntPoint: UUID]()) {
                $0[$1.shp] = rootView.sheetID(at: $1.shp)
            }
            let csv = CopiedSheetsValue(deltaPoint: Point(), sheetIDs: sids)
            renderings = []
            documentRecorders = csv.sheetIDs.compactMap { rootView.model.sheetRecorders[$0.value] }
        }
        
        let isAlphaChannel = (rootView.sheetView(at: p)?.model.backgroundUUColor.value.opacity ?? 1) != 1
        
        let fType: any FileTypeProtocol = switch type {
        case .image: nvs.count > 1 && unionFrame == nil ? Image.FileType.pngs : Image.FileType.png
        case .image4K: nvs.count > 1 && unionFrame == nil ? Image.FileType.pngs : Image.FileType.png
        case .pdf: PDF.FileType.pdf
        case .gif: Image.FileType.gif
        case .movie, .movie4K: isAlphaChannel ? Movie.FileType.mov : Movie.FileType.mp4
        case .sound: Content.FileType.m4a
        case .linearPCM: Content.FileType.wav
        case .document: Document.FileType.rasendoc
        case .documentWithHistory: Document.FileType.rasendoch
        }
        
        let fileSize: @Sendable () -> (Int?) = {
            switch type {
            case .image:
                if renderings.count == 1, let node = renderings[0].renderableMainSheetNode() {
                    let nSize = size * 4
                    let image = node.renderedAntialiasFillImage(in: renderings[0].bounds, to: nSize, colorSpace)
                    return image?.data(.png)?.count ?? 0
                } else {
                    return nil
                }
            case .image4K:
                if renderings.count == 1, let node = renderings[0].renderableMainSheetNode() {
                    let nSize = size.width > size.height ?
                    size.snapped(height: 2160).rounded(.down) :
                    size.snapped(max: Size(width: 2160, height: 3840)).rounded(.down)
                    let image = node.renderedAntialiasFillImage(in: renderings[0].bounds, to: nSize, colorSpace)
                    return image?.data(.png)?.count ?? 0
                } else {
                    return nil
                }
            case .pdf:
                if renderings.count == 1, let node = renderings[0].renderableMainSheetNode(),
                   let pdf = try? PDF(mediaBox: Rect(size: size)) {
                   
                    pdf.newPage { pdf in
                        node.render(in: renderings[0].bounds, to: size, in: pdf)
                    }
                    pdf.finish()
                    return pdf.dataSize
                } else {
                    return nil
                }
            case .gif, .movie, .movie4K: return nil
            case .sound, .linearPCM: return nil
            case .document:
                return documentRecorders.sum { $0.fileSizeWithoutHistory }
            case .documentWithHistory:
                return documentRecorders.sum { $0.fileSize }
            }
        }
        
        let message = switch type {
        case .image: "Export as Image".localized
        case .image4K: "Export as 4K Image".localized
        case .pdf: "Export as PDF".localized
        case .gif: "Export as GIF".localized
        case .movie: "Export as Movie".localized
        case .movie4K: "Export as 4K Movie".localized
        case .sound: "Export as Sound".localized
        case .linearPCM: "Export as Linear PCM".localized
        case .document: "Export as Document".localized
        case .documentWithHistory: "Export as Document with History".localized
        }
        
        Task { @MainActor in
            let result = await URL.export(message: message,
                                          name: name(from: nvs.map { $0.shp }),
                                          fileType: fType,
                                          fileSizeHandler: fileSize)
            switch result {
            case .complete(let ioResult):
                rootView.syncSave()
                
                switch type {
                case .image:
                    let nSize = size * 4
                    exportImage(from: renderings, unionFrame: unionFrame, is4K: false, colorSpace,
                                size: nSize, at: ioResult)
                case .image4K:
                    let nSize = size.width > size.height ?
                    size.snapped(height: 2160).rounded(.down) :
                    size.snapped(max: Size(width: 2160, height: 3840)).rounded(.down)
                    exportImage(from: renderings, unionFrame: unionFrame, is4K: true, colorSpace,
                                size: nSize, at: ioResult)
                case .pdf:
                    exportPDF(from: renderings, unionFrame: unionFrame, size: size, at: ioResult)
                case .gif:
                    let nSize = size.snapped(max: Size(width: 800, height: 1200)).rounded(.down)
                    exportGIF(from: renderings, unionFrame: unionFrame, colorSpace, size: nSize, at: ioResult)
                case .movie:
                    let nSize = size.width > size.height ?
                    size.snapped(height: 1080).rounded(.down) :
                    size.snapped(max: Size(width: 1200, height: 1920).rounded(.down))
                    exportMovie(from: renderings, is4K: false, isAlphaChannel: isAlphaChannel,
                                colorSpace, size: nSize, at: ioResult)
                case .movie4K:
                    let nSize = size.width > size.height ?
                    size.snapped(height: 2160).rounded(.down) :
                    size.snapped(max: Size(width: 2160, height: 3840)).rounded(.down)
                    exportMovie(from: renderings, is4K: true, isAlphaChannel: isAlphaChannel,
                                colorSpace, size: nSize, at: ioResult)
                case .sound:
                    exportSound(from: renderings, isLinearPCM: false, at: ioResult)
                case .linearPCM:
                    exportSound(from: renderings, isLinearPCM: true, at: ioResult)
                case .document:
                    exportDocument(from: nvs, isHistory: false, at: ioResult)
                case .documentWithHistory:
                    exportDocument(from: nvs, isHistory: true, at: ioResult)
                }
                end()
            case .cancel:
                end()
            }
        }
    }
    
    func exportImage(from renderings: [Rendering], unionFrame: Rect?, is4K: Bool,
                     _ colorSpace: ColorSpace,
                     size: Size, at ioResult: IOResult) {
        if renderings.isEmpty {
            return
        } else if renderings.count == 1 || unionFrame != nil {
            do {
                try ioResult.remove()
                
                if let unionFrame {
                    let scaleX = size.width / unionFrame.width
                    let scaleY = size.height / unionFrame.height
                    var nImage = Image(size: size, color: .background.with(colorSpace))
                    for rendering in renderings {
                        let origin = rendering.mainItem.frame.origin - unionFrame.origin
                        if let node = rendering.renderableMainSheetNode(),
                           let image = node.renderedAntialiasFillImage(in: rendering.bounds, to: size, colorSpace) {
                            nImage = nImage?.drawn(image,
                                                   in: (rendering.bounds + origin)
                                                   * Transform(scaleX: scaleX, y: scaleY))
                        }
                    }
                    try nImage?.write(.png, to: ioResult.url)
                } else {
                    if let node = renderings[0].renderableMainSheetNode() {
                        let image = node.renderedAntialiasFillImage(in: renderings[0].bounds, to: size, colorSpace)
                        try image?.write(.png, to: ioResult.url)
                    }
                }
                
                try ioResult.setAttributes()
            } catch {
                rootView.node.show(error)
            }
        } else {
            let progressPanel = ProgressPanel(message: is4K ?
                                              "Exporting 4K Images".localized : "Exporting Images".localized)
            rootView.node.show(progressPanel)
            do {
                try ioResult.remove()
                try ioResult.makeDirectory()
                
                @Sendable func export(progressHandler: (Double, inout Bool) -> ()) throws {
                    var isStop = false
                    for (j, rendering) in renderings.enumerated() {
                        if let node = rendering.renderableMainSheetNode() {
                            let image = node.renderedAntialiasFillImage(in: rendering.bounds, to: size, colorSpace)
                            let subIOResult = ioResult.sub(name: "\(j).png")
                            try image?.write(.png, to: subIOResult.url)
                            try subIOResult.setAttributes()
                        }
                        progressHandler(Double(j + 1) / Double(renderings.count), &isStop)
                        if isStop { break }
                    }
                }
                
                let task = Task.detached(priority: .high) {
                    do {
                        try export { (progress, isStop) in
                            if Task.isCancelled {
                                isStop = true
                                return
                            }
                            Task { @MainActor in
                                progressPanel.progress = progress
                            }
                        }
                        Task { @MainActor in
                            progressPanel.closePanel()
                            self.end()
                        }
                    } catch {
                        Task { @MainActor in
                            self.rootView.node.show(error)
                            progressPanel.closePanel()
                            self.end()
                        }
                    }
                }
                progressPanel.cancelHandler = { task.cancel() }
            } catch {
                self.rootView.node.show(error)
                progressPanel.closePanel()
                self.end()
            }
        }
    }
    
    func exportPDF(from renderings: [Rendering], unionFrame: Rect?,
                   size: Size, at ioResult: IOResult) {
        @Sendable func export(progressHandler: (Double, inout Bool) -> ()) throws {
            var isStop = false
            let pdf = try PDF(url: ioResult.url, mediaBox: Rect(size: size))
            
            if let unionFrame {
                pdf.newPage { pdf in
                    for rendering in renderings {
                        if let node = rendering.renderableMainSheetNode() {
                            let origin = rendering.mainItem.frame.origin - unionFrame.origin
                            node.render(in: rendering.bounds, to: rendering.bounds + origin, in: pdf)
                        }
                    }
                }
            } else {
                for (i, rendering) in renderings.enumerated() {
                    if let node = rendering.renderableMainSheetNode() {
                        pdf.newPage { pdf in
                            node.render(in: rendering.bounds, to: size, in: pdf)
                        }
                    }
                    
                    progressHandler(Double(i + 1) / Double(renderings.count), &isStop)
                    if isStop { break }
                }
            }
            
            pdf.finish()
            
            try ioResult.setAttributes()
        }
        
        if renderings.count == 1 {
            do {
                try export { (_, isStop) in }
                end()
            } catch {
                rootView.node.show(error)
                end()
            }
        } else {
            let progressPanel = ProgressPanel(message: "Exporting PDF".localized)
            rootView.node.show(progressPanel)
            do {
                try ioResult.remove()
                
                let task = Task.detached(priority: .high) {
                    do {
                        try export { (progress, isStop) in
                            if Task.isCancelled {
                                isStop = true
                                return
                            }
                            Task { @MainActor in
                                progressPanel.progress = progress
                            }
                        }
                        Task { @MainActor in
                            progressPanel.closePanel()
                            self.end()
                        }
                    } catch {
                        Task { @MainActor in
                            self.rootView.node.show(error)
                            progressPanel.closePanel()
                            self.end()
                        }
                    }
                }
                progressPanel.cancelHandler = { task.cancel() }
            } catch {
                rootView.node.show(error)
                progressPanel.closePanel()
                end()
            }
        }
    }
    
    func exportGIF(from renderings: [Rendering], unionFrame: Rect?, _ colorSpace: ColorSpace,
                   size: Size, at ioResult: IOResult) {
        @Sendable func export(progressHandler: (Double, inout Bool) -> ()) throws {
            var images = [(image: Image, time: Rational)]()
            var isStop = false, t = 0.0
            let allC = renderings.count + 1
            
            if let unionFrame {
                let scaleX = size.width / unionFrame.width
                let scaleY = size.height / unionFrame.height
                var nImage = Image(size: size, color: .background.with(colorSpace))
                for rendering in renderings {
                    let origin = rendering.mainItem.frame.origin - unionFrame.origin
                    if let node = rendering.renderableMainSheetNode(),
                       let image = node.renderedAntialiasFillImage(in: rendering.bounds, to: size, colorSpace) {
                        nImage = nImage?.drawn(image,
                                               in: (rendering.bounds + origin)
                                               * Transform(scaleX: scaleX, y: scaleY))
                    }
                }
                try nImage?.write(.gif, to: ioResult.url)
            } else {
                for rendering in renderings {
                    if let sheet = rendering.mainItem.decodedSheet() {
                        let ot = t
                        var sec = Rational(0)
                        for (i, _) in sheet.animation.keyframes.enumerated() {
                            let node = sheet.node(isBorder: false, atSec: sec,
                                                  attitude: .init(position: rendering.mainItem.frame.origin),
                                                  in: rendering.bounds)
                            let durBeat = sheet.animation.rendableKeyframeDurBeat(at: i)
                            let durSec = sheet.animation.sec(fromBeat: durBeat)
                            if let image = node.renderedAntialiasFillImage(in: rendering.bounds, to: size, colorSpace) {
                                images.append((image, durSec))
                            }
                            sec += durSec
                            let d = Double(i) / Double(sheet.animation.keyframes.count - 1)
                            t = ot + d / Double(allC)
                            progressHandler(t, &isStop)
                        }
                    } else {
                        let ot = t
                        if let node = renderings[0].renderableMainSheetNode(),
                           let image = node.renderedAntialiasFillImage(in: renderings[0].bounds, to: size,
                                                                       colorSpace) {
                            images.append((image, Keyframe.defaultDurBeat))
                            t = ot + 1 / Double(allC)
                            progressHandler(t, &isStop)
                        }
                    }
                    
                    if isStop { break }
                }
                
                try Image.writeGIF(images, to: ioResult.url)
            }
            progressHandler(1, &isStop)
            try ioResult.setAttributes()
        }
        
        let progressPanel = ProgressPanel(message: "Exporting GIF".localized)
        rootView.node.show(progressPanel)
        do {
            try ioResult.remove()
            
            let task = Task.detached(priority: .high) {
                do {
                    try export { (progress, isStop) in
                        if Task.isCancelled {
                            isStop = true
                            return
                        }
                        Task { @MainActor in
                            progressPanel.progress = progress
                        }
                    }
                    Task { @MainActor in
                        progressPanel.closePanel()
                        self.end()
                    }
                } catch {
                    Task { @MainActor in
                        self.rootView.node.show(error)
                        progressPanel.closePanel()
                        self.end()
                    }
                }
            }
            progressPanel.cancelHandler = { task.cancel() }
        } catch {
            rootView.node.show(error)
            progressPanel.closePanel()
            end()
        }
    }
    
    func exportMovie(from renderings: [Rendering], is4K: Bool, isAlphaChannel: Bool,
                     _ colorSpace: ColorSpace,
                     size: Size, at ioResult: IOResult) {
        let isMainFrame = !rootView.isEditingSheet
        @Sendable func export(progressHandler: (Double, inout Bool) -> (),
                              completionHandler handler: @escaping (Bool, (any Error)?) -> ()) async {
            do {
                let movie = try Movie(url: ioResult.url, renderSize: size, isAlphaChannel: isAlphaChannel,
                                      isLinearPCM: is4K, colorSpace)
                var isStop = false, t = 0.0
                var durSecs = [Rational]()
                for rendering in renderings {
                    if let sheet = rendering.mainItem.decodedSheet() {
                        var frameRate = sheet.mainFrameRate
                        var bottomSheets = [(sheet: Sheet, bounds: Rect)]()
                        var maxEndSec: Rational = 0
                        for item in rendering.bottomItems {
                            guard let sheet = item.decodedSheet(), sheet.enabledTimeline else { break }
                            frameRate = max(frameRate, sheet.mainFrameRate)
                            bottomSheets.append((sheet, item.frame.bounds))
                            maxEndSec = max(sheet.allEndSec, maxEndSec)
                        }
                        var topSheets = [(sheet: Sheet, bounds: Rect)] ()
                        for item in rendering.topItems {
                            guard let sheet = item.decodedSheet(), sheet.enabledTimeline else { break }
                            frameRate = max(frameRate, sheet.mainFrameRate)
                            topSheets.append((sheet, item.frame.bounds))
                            maxEndSec = max(sheet.allEndSec, maxEndSec)
                        }
                        
                        let sheetBounds = rendering.mainItem.frame.bounds
                        let origin = rendering.mainItem.frame.origin
                        let ot = t
                        let b = isMainFrame ? (sheet.mainFrame ?? rendering.bounds) : rendering.bounds
                        
                        maxEndSec = max(sheet.allEndSec, maxEndSec)
                    
                        durSecs.append(maxEndSec)
                        let frameCount = sheet.animation.count(fromSec: maxEndSec,
                                                               frameRate: frameRate)
                        
                        movie.writeMovie(frameCount: frameCount,
                                         duration: maxEndSec,
                                         frameRate: frameRate) { (sec) -> (Image?) in
                            //tempo -> startTime
                            let node: CPUNode
                            if !bottomSheets.isEmpty || !topSheets.isEmpty {
                                var children = [CPUNode]()
                                for (bottomSheet, sheetBounds) in bottomSheets.reversed() {
                                    children.append(bottomSheet.node(isBorder: false, atSec: sec,
                                                                     renderingCaptionFrame: b,
                                                                     isBackground: false,
                                                                     in: sheetBounds))
                                }
                                children.append(sheet.node(isBorder: false, atSec: sec,
                                                           renderingCaptionFrame: b,
                                                           isBackground: false,
                                                           in: sheetBounds))
                                for (topSheet, sheetBounds) in topSheets {
                                    children.append(topSheet.node(isBorder: false, atSec: sec,
                                                                  renderingCaptionFrame: b,
                                                                  isBackground: false,
                                                                  in: sheetBounds))
                                }
                                node = CPUNode(children: children, attitude: .init(position: origin),
                                               path: Path(sheetBounds))
                            } else {
                                node = sheet.node(isBorder: false, atSec: sec,
                                                  renderingCaptionFrame: b,
                                                  attitude: .init(position: origin),
                                                  in: sheetBounds)
                            }
                           
                            return node.renderedAntialiasFillImage(in: b, to: size, colorSpace)
                        } progressHandler: { (d, stop) in
                            t = ot + d / Double(renderings.count)
                            progressHandler(t * 0.7, &isStop)
                            if isStop {
                                stop = true
                            }
                        }
                    } else {
                        let ot = t
                        let node = CPUNode(path: Path(rendering.bounds), fillType: .color(.background))
                        let duration = Animation.sec(fromBeat: Keyframe.defaultDurBeat,
                                                    tempo: Music.defaultTempo)
                        if let image = node.image(in: rendering.bounds, size: size,
                                                  backgroundColor: .background, colorSpace) {
                            let frameCount = Animation.count(fromBeat: Keyframe.defaultDurBeat,
                                                         tempo: Music.defaultTempo,
                                                         frameRate: 24)
                            movie.writeMovie(frameCount: frameCount,
                                             duration: duration,
                                             frameRate: 24) { (time) -> (Image?) in
                                image
                            } progressHandler: { (d, stop) in
                                t = ot + d / Double(renderings.count)
                                progressHandler(t * 0.7, &isStop)
                                if isStop {
                                    stop = true
                                }
                            }
                        }
                        durSecs.append(duration)
                    }
                    
                    if isStop { break }
                }
                
                var audiotracks = [Audiotrack]()
                
                if !isStop {
                    for (i, rendering) in renderings.enumerated() {
                        let durSec = durSecs[i]
                        
                        var audiotrack: Audiotrack?
                        if let sheet = rendering.mainItem.decodedSheet() {
                            audiotrack += sheet.audiotrack
                        }
                        for item in rendering.bottomItems {
                            guard let sheet = item.decodedSheet(), sheet.enabledTimeline else { break }
                            audiotrack += sheet.audiotrack
                        }
                        for item in rendering.topItems {
                            guard let sheet = item.decodedSheet(), sheet.enabledTimeline else { break }
                            audiotrack += sheet.audiotrack
                        }
                        audiotrack?.durSec = durSec
                        if let audiotrack {
                            audiotracks.append(audiotrack)
                        }
                        
                        let t = (Double(i) / Double(renderings.count - 1)) * 0.1 + 0.7
                        progressHandler(t, &isStop)
                        if isStop { break }
                    }
                    if !isStop {
                        if let sequencer = Sequencer(audiotracks: audiotracks, type: .normal) {
                            try movie.writeAudio(from: sequencer) { t, stop in
                                progressHandler(t * 0.2 + 0.8, &isStop)
                                if isStop {
                                    stop = true
                                }
                            }
                        }
                    }
                }
                
                do {
                    let stop = try await movie.finish()
                    handler(stop, nil)
                } catch {
                    handler(true, error)
                }
            } catch {
                handler(false, error)
            }
        }
        
        let progressPanel = ProgressPanel(message: is4K ?
                                          "Exporting 4K Movie".localized : "Exporting Movie".localized)
        rootView.node.show(progressPanel)
        do {
            try ioResult.remove()
            
            let task = Task.detached(priority: .high) {
                await export(progressHandler: { (progress, isStop) in
                    if Task.isCancelled {
                        isStop = true
                        return
                    }
                    Task { @MainActor in
                        progressPanel.progress = progress
                    }
                }, completionHandler: { (stop, error) in
                    Task { @MainActor in
                        if !stop {
                            if let error {
                                self.rootView.node.show(error)
                            } else {
                                do {
                                    try ioResult.setAttributes()
                                } catch {
                                    self.rootView.node.show(error)
                                }
                            }
                        }
                        progressPanel.closePanel()
                        self.end()
                    }
                })
            }
            progressPanel.cancelHandler = { task.cancel() }
        } catch {
            rootView.node.show(error)
            progressPanel.closePanel()
            end()
        }
    }
    
    func exportSound(from renderings: [Rendering], isLinearPCM: Bool, at ioResult: IOResult) {
        @Sendable func export(progressHandler: (Double, inout Bool) -> (),
                    completionHandler handler: @escaping ((any Error)?) -> ()) {
            do {
                var audiotracks = [Audiotrack]()
                
                var isStop = false
                for (i, rendering) in renderings.enumerated() {
                    var audiotrack: Audiotrack?
                    if let sheet = rendering.mainItem.decodedSheet() {
                        audiotrack += sheet.audiotrack
                    }
                    for item in rendering.bottomItems {
                        guard let sheet = item.decodedSheet(), sheet.enabledTimeline else { break }
                        audiotrack += sheet.audiotrack
                    }
                    for item in rendering.topItems {
                        guard let sheet = item.decodedSheet(), sheet.enabledTimeline else { break }
                        audiotrack += sheet.audiotrack
                    }
                    if let audiotrack {
                        audiotracks.append(audiotrack)
                    }
                    
                    let t = 0.2 * Double(i) / Double(renderings.count)
                    progressHandler(t, &isStop)
                    if isStop { break }
                }
                if !isStop {
                    if let sequencer = Sequencer(audiotracks: audiotracks, type: .normal) {
                        try sequencer.export(url: ioResult.url,
                                             sampleRate: Audio.defaultSampleRate,
                                             isLinearPCM: isLinearPCM) { (t, stop) in
                            progressHandler(t * 0.8 + 0.2, &isStop)
                            if isStop {
                                stop = true
                            }
                        }
                    }
                }
                
                handler(nil)
            } catch {
                handler(error)
            }
        }
        
        let progressPanel = ProgressPanel(message: isLinearPCM ?
                                          "Exporting Linear PCM".localized : "Exporting Sound".localized)
        rootView.node.show(progressPanel)
        do {
            try ioResult.remove()
            
            let task = Task.detached(priority: .high) {
                export(progressHandler: { (progress, isStop) in
                    if Task.isCancelled {
                        isStop = true
                        return
                    }
                    Task { @MainActor in
                        progressPanel.progress = progress
                    }
                }, completionHandler: { error in
                    Task { @MainActor in
                        if let error {
                            self.rootView.node.show(error)
                        } else {
                            do {
                                try ioResult.setAttributes()
                            } catch {
                                self.rootView.node.show(error)
                            }
                        }
                        progressPanel.closePanel()
                        self.end()
                    }
                })
            }
            progressPanel.cancelHandler = { task.cancel() }
        } catch {
            rootView.node.show(error)
            progressPanel.closePanel()
            end()
        }
    }
    
    func exportDocument(from vs: [SelectingValue],
                        isHistory: Bool,
                        at ioResult: IOResult) {
        guard let shp0 = vs.first?.shp else { return }
        
        @Sendable func export(progressHandler: (Double, inout Bool) -> ()) throws {
            try ioResult.remove()
            
            let sids = vs.reduce(into: [IntPoint: UUID]()) {
                $0[$1.shp - shp0] = rootView.sheetID(at: $1.shp)
            }
            let csv = CopiedSheetsValue(deltaPoint: Point(), sheetIDs: sids)
            
            var isStop = false
            let nDocument = Document(ioResult.url)
            var world = World()
            for (i, v) in csv.sheetIDs.enumerated() {
                let (shp, osid) = v
                guard let osrr = rootView.model.sheetRecorders[osid] else { continue }
                let nsid = UUID()
                let nsrr = nDocument.makeSheetRecorder(at: nsid)
                
                if let oldSID = world.sheetIDs[shp] {
                    world.sheetPositions[oldSID] = nil
                }
                world.sheetIDs[shp] = nsid
                world.sheetPositions[nsid] = shp
                
                nsrr.sheetRecord.data = osrr.sheetRecord.decodedData
                nsrr.thumbnail4Record.data = osrr.thumbnail4Record.decodedData
                nsrr.thumbnail16Record.data = osrr.thumbnail16Record.decodedData
                nsrr.thumbnail64Record.data = osrr.thumbnail64Record.decodedData
                nsrr.thumbnail256Record.data = osrr.thumbnail256Record.decodedData
                nsrr.thumbnail1024Record.data = osrr.thumbnail1024Record.decodedData
                nsrr.stringRecord.data = osrr.stringRecord.decodedData
                nsrr.sheetRecord.isWillwrite = true
                nsrr.thumbnail4Record.isWillwrite = true
                nsrr.thumbnail16Record.isWillwrite = true
                nsrr.thumbnail64Record.isWillwrite = true
                nsrr.thumbnail256Record.isWillwrite = true
                nsrr.thumbnail1024Record.isWillwrite = true
                nsrr.stringRecord.isWillwrite = true
                
                if isHistory {
                    nsrr.sheetHistoryRecord.data = osrr.sheetHistoryRecord.decodedData
                    nsrr.sheetHistoryRecord.isWillwrite = true
                }
                
                if !osrr.contentsDirectory.childrenURLs.isEmpty {
                    for (key, url) in osrr.contentsDirectory.childrenURLs {
                        nsrr.contentsDirectory.isWillwrite = true
                        try? nsrr.contentsDirectory.write()
                        try? nsrr.contentsDirectory.copy(name: key, from: url)
                    }
                    if var sheet = nsrr.sheetRecord.decodedValue {
                        if !sheet.contents.isEmpty {
                            let dn = nsid.uuidString
                            for i in sheet.contents.count.range {
                                sheet.contents[i].directoryName = dn
                            }
                            nsrr.sheetRecord.value = sheet
                        }
                    }
                }
                
                progressHandler(Double(i + 1) / Double(csv.sheetIDs.count + 1), &isStop)
                if isStop { break }
            }
            nDocument.worldRecord.data = try? world.serializedData()
            nDocument.worldRecord.isWillwrite = true
            nDocument.povRecord.data = try? rootView.pov.serializedData()
            nDocument.povRecord.isWillwrite = true
            try nDocument.write()
            
            try ioResult.setAttributes()
        }
        
        if vs.count == 1 {
            do {
                try export { (_, isStop) in }
                end()
            } catch {
                rootView.node.show(error)
                end()
            }
        } else {
            let progressPanel = ProgressPanel(message: "Exporting Document".localized)
            rootView.node.show(progressPanel)
            let task = Task.detached(priority: .high) {
                do {
                    try export { (progress, isStop) in
                        if Task.isCancelled {
                            isStop = true
                            return
                        }
                        Task { @MainActor in
                            progressPanel.progress = progress
                        }
                    }
                    Task { @MainActor in
                        progressPanel.closePanel()
                        self.end()
                    }
                } catch {
                    Task { @MainActor in
                        self.rootView.node.show(error)
                        progressPanel.closePanel()
                        self.end()
                    }
                }
            }
            progressPanel.cancelHandler = { task.cancel() }
        }
    }
}

final class ToMP4MovieAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
    }
    
    func flow(with event: InputKeyEvent) {
        Task { @MainActor in
            let result = await URL.load(prompt: "Import".localized,
                                        fileTypes: [Movie.FileType.mp4, Movie.FileType.mov])
            switch result {
            case .complete(let ioResult0s):
                let result = await URL.export(name: "",
                                              fileType: Movie.FileType.mp4,
                                              fileSizeHandler: { return nil })
                switch result {
                case .complete(let ioResult1):
                    let fromURL = ioResult0s[0].url
                    let toURL = ioResult1.url
                    Task {
                        do {
                            try await Movie.toMP4(from: fromURL, to: toURL)
                        } catch {
                            rootView.node.show(error)
                        }
                    }
                case .cancel: break
                }
            case .cancel: break
            }
        }
    }
}
