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
import struct Foundation.UUID
import struct Foundation.URL

protocol Editor {
    func updateNode()
}
extension Editor {
    func updateNode() {}
}

protocol PinchEditor: Editor {
    func send(_ event: PinchEvent)
}

protocol RotateEditor: Editor {
    func send(_ event: RotateEvent)
}

protocol ScrollEditor: Editor {
    func send(_ event: ScrollEvent)
}

protocol SwipeEditor: Editor {
    func send(_ event: SwipeEvent)
}

protocol DragEditor: Editor {
    func send(_ event: DragEvent)
}

protocol InputKeyEditor: Editor {
    func send(_ event: InputKeyEvent)
}

final class Zoomer: PinchEditor {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    let correction = 3.0
    func send(_ event: PinchEvent) {
        guard event.magnification != 0 else { return }
        let oldIsEditingSheet = document.isEditingSheet
        
        var transform = document.camera.transform
        let p = event.screenPoint * document.screenToWorldTransform
        let log2Scale = transform.log2Scale
        let newLog2Scale = (log2Scale - (event.magnification * correction))
            .clipped(min: Document.minCameraLog2Scale,
                     max: Document.maxCameraLog2Scale) - log2Scale
        transform.translate(by: -p)
        transform.scale(byLog2Scale: newLog2Scale)
        transform.translate(by: p)
        document.camera = Document.clippedCamera(from: Camera(transform))
        
        if oldIsEditingSheet != document.isEditingSheet {
            document.textEditor.moveEndInputKey()
            document.updateTextCursor()
        }
        
        if document.selectedNode != nil {
            document.updateSelectedNode()
        }
        if !document.finding.isEmpty {
            document.updateFindingNodes()
        }
    }
}

final class Rotater: RotateEditor {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    let correction = .pi / 40.0, clipD = .pi / 8.0
    var isClipped = false
    func send(_ event: RotateEvent) {
        switch event.phase {
        case .began: isClipped = false
        default: break
        }
        guard !isClipped && event.rotationQuantity != 0 else { return }
        var transform = document.camera.transform
        let p = event.screenPoint * document.screenToWorldTransform
        let r = transform.angle
        let rotation = r - event.rotationQuantity * correction
        let nr: Double
        if (rotation < clipD && rotation >= 0 && r < 0)
            || (rotation > -clipD && rotation <= 0 && r > 0) {
            
            nr = 0
            Feedback.performAlignment()
            isClipped = true
        } else {
            nr = rotation.loopedRotation
        }
        transform.translate(by: -p)
        transform.rotate(by: nr - r)
        transform.translate(by: p)
        var camera = Document.clippedCamera(from: Camera(transform))
        if isClipped {
            camera.rotation = 0
            document.camera = camera
        } else {
            document.camera = camera
        }
        if document.camera.rotation != 0 {
            Document.defaultCursor
                = Cursor.rotate(rotation: -document.camera.rotation + .pi / 2)
            document.cursor = Document.defaultCursor
        } else {
            Document.defaultCursor = .drawLine
            document.cursor = Document.defaultCursor
        }
    }
}

final class Scroller: ScrollEditor {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    enum SnapType {
        case began, none, x, y
    }
    private let correction = 1.0
    private let updateSpeed = 1000.0
    private var isHighSpeed = false, oldTime = 0.0, oldDeltaPoint = Point()
    private var oldSpeedTime = 0.0, oldSpeedDistance = 0.0,
                oldSpeed = 0.0
    private var isMoveTime = false, timeMover: FrameSelecter?
    func send(_ event: ScrollEvent) {
        switch event.phase {
        case .began:
            oldTime = event.time
            oldSpeedTime = oldTime
            oldDeltaPoint = Point()
            oldSpeedDistance = 0.0
            oldSpeed = 0.0
        case .changed:
            guard !event.scrollDeltaPoint.isEmpty else { return }
            let dt = event.time - oldTime
            var dp = event.scrollDeltaPoint.mid(oldDeltaPoint)
            if document.camera.rotation != 0 {
                dp = dp * Transform(rotation: document.camera.rotation)
            }
            
            oldDeltaPoint = event.scrollDeltaPoint
            
            let length = dp.length()
            let lengthDt = length / dt
            
            var transform = document.camera.transform
            let newPoint = dp * correction * transform.absXScale
            
            let oldPosition = transform.position
            let newP = Document.clippedCameraPosition(from: oldPosition - newPoint) - oldPosition
            
            transform.translate(by: newP)
            document.camera = Camera(transform)
            
            document.isUpdateWithCursorPosition = lengthDt < updateSpeed / 2
            document.updateWithCursorPosition()
            if !document.isUpdateWithCursorPosition {
                document.textCursorNode.isHidden = true
                document.textMaxTypelineWidthNode.isHidden = true
            }
            
            oldTime = event.time
        case .ended:
            if !document.isUpdateWithCursorPosition {
                document.isUpdateWithCursorPosition = true
            }
            break
        }
    }
}

final class DraftChanger: InputKeyEditor {
    let editor: DraftEditor
    
    init(_ document: Document) {
        editor = DraftEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.changeToDraft(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class DraftCutter: InputKeyEditor {
    let editor: DraftEditor
    
    init(_ document: Document) {
        editor = DraftEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.cutDraft(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class DraftEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    func changeToDraft(with event: InputKeyEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        if document.isPlaying(with: event) {
            document.stopPlaying(with: event)
        }
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if document.isSelectNoneCursor(at: p), !document.isSelectedText {
                for (shp, _) in document.sheetViewValues {
                    let ssFrame = document.sheetFrame(with: shp)
                    if document.selections.contains(where: { ssFrame.intersects($0.rect) }),
                       let sheetView = document.sheetView(at: shp) {
                        
                        if sheetView.model.score.enabled {
                            let nis = sheetView.noteIndexes(from: document.selections)
                            if !nis.isEmpty {
                                sheetView.newUndoGroup()
                                sheetView.changeToDraft(withNoteInexes: nis)
                                document.updateSelects()
                            }
                        } else {
                            let lis = sheetView.lineIndexes(from: document.selections)
                            let pis = sheetView.planeIndexes(from: document.selections)
                            if !lis.isEmpty {
                                sheetView.newUndoGroup()
                                sheetView.changeToDraft(withLineInexes: lis,
                                                        planeInexes: pis)
                                document.updateSelects()
                            }
                        }
                    }
                }
            } else {
                if let sheetView = document.sheetView(at: p) {
                    let inP = sheetView.convertFromWorld(p)
                    if sheetView.model.score.enabled {
                        let nis = (0 ..< sheetView.model.score.notes.count).map { $0 }
                        if !nis.isEmpty {
                            sheetView.newUndoGroup()
                            sheetView.changeToDraft(withNoteInexes: nis)
                            document.updateSelects()
                        }
                    } else if sheetView.animationView.containsTimeline(inP),
                       let ki = sheetView.animationView.keyframeIndex(at: inP) {
                        
                        let animationView = sheetView.animationView
                        
                        let isSelected = animationView.selectedFrameIndexes.contains(ki)
                        let indexes = isSelected ?
                            animationView.selectedFrameIndexes.sorted() : [ki]
                        let kiovs: [IndexValue<KeyframeOption>] = indexes.compactMap {
                            let keyframe = animationView.model.keyframes[$0]
                            guard keyframe.previousNext != .previousAndNext else { return nil }
                            let ko = KeyframeOption(beat: keyframe.beat, previousNext: .previousAndNext)
                            return IndexValue(value: ko, index: $0)
                        }
                        
                        sheetView.newUndoGroup()
                        sheetView.set(kiovs)
                    } else {
                        sheetView.changeToDraft(with: nil)
                    }
                }
            }
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
    func cutDraft(with event: InputKeyEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        if document.isPlaying(with: event) {
            document.stopPlaying(with: event)
        }
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if document.isSelectNoneCursor(at: p), !document.isSelectedText,
               !document.selections.isEmpty {
                
                var value = SheetValue()
                for selection in document.selections {
                    for (shp, _) in document.sheetViewValues {
                        let ssFrame = document.sheetFrame(with: shp)
                        if ssFrame.intersects(selection.rect),
                           let sheetView = document.sheetView(at: shp) {
                           
                            if sheetView.model.score.enabled {
                                let nis = sheetView.draftNoteIndexes(from: document.selections)
                                if !nis.isEmpty {
                                    let scoreView = sheetView.scoreView
                                    let scoreP = scoreView.convertFromWorld(p)
                                    let pitch = document.pitch(from: scoreView, at: scoreP)
                                    let interval = document.currentNoteBeatInterval
                                    let beat = scoreView.beat(atX: scoreP.x, interval: interval)
                                    let notes: [Note] = nis.map {
                                        var note = scoreView.model.draftNotes[$0]
                                        note.pitch -= pitch
                                        note.beatRange.start -= beat
                                        return note
                                    }
                                    
                                    sheetView.newUndoGroup()
                                    sheetView.removeDraftNotes(at: nis)
                                    
                                    Pasteboard.shared.copiedObjects = [.notesValue(.init(notes: notes))]//
                                }
                            } else {
                                let line = Line(selection.rect.inset(by: -0.5))
                                let nLine = sheetView.convertFromWorld(line)
                                if let v = sheetView.removeDraft(with: nLine, at: p) {
                                    value += v
                                }
                            }
                        }
                    }
                }
                if !value.isEmpty {
                    Pasteboard.shared.copiedObjects = [.sheetValue(value)]
                }
                document.selections = []
            } else {
                if let sheetView = document.sheetView(at: p) {
                    let inP = sheetView.convertFromWorld(p)
                    if sheetView.model.score.enabled {
                        let nis = (0 ..< sheetView.model.score.draftNotes.count).map { $0 }
                        if !nis.isEmpty {
                            let scoreView = sheetView.scoreView
                            let scoreP = scoreView.convertFromWorld(p)
                            let pitch = document.pitch(from: scoreView, at: scoreP)
                            let interval = document.currentNoteBeatInterval
                            let beat = scoreView.beat(atX: scoreP.x, interval: interval)
                            let notes: [Note] = sheetView.model.score.draftNotes.map {
                                var note = $0
                                note.pitch -= pitch
                                note.beatRange.start -= beat
                                return note
                            }
                            
                            sheetView.newUndoGroup()
                            sheetView.removeDraftNotes(at: nis)
                            
                            Pasteboard.shared.copiedObjects = [.notesValue(.init(notes: notes))]//
                        }
                    } else if sheetView.animationView.containsTimeline(inP),
                       let ki = sheetView.animationView.keyframeIndex(at: inP) {
                        
                        let animationView = sheetView.animationView
                        
                        let isSelected = animationView.selectedFrameIndexes.contains(ki)
                        let indexes = isSelected ?
                            animationView.selectedFrameIndexes.sorted() : [ki]
                        let kiovs: [IndexValue<KeyframeOption>]
                        = indexes.compactMap {
                            let keyframe = animationView.model.keyframes[$0]
                            guard keyframe.previousNext != .none else { return nil }
                            let ko = KeyframeOption(beat: keyframe.beat, previousNext: .none)
                            return IndexValue(value: ko, index: $0)
                        }
                        
                        sheetView.newUndoGroup()
                        sheetView.set(kiovs)
                    } else {
                        sheetView.cutDraft(with: nil, at: p)
                    }
                }
            }
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
}

final class FacesMaker: InputKeyEditor {
    let editor: FaceEditor
    
    init(_ document: Document) {
        editor = FaceEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.makeFaces(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class FacesCutter: InputKeyEditor {
    let editor: FaceEditor
    
    init(_ document: Document) {
        editor = FaceEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.cutFaces(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class FaceEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    func makeFaces(with event: InputKeyEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        if document.isPlaying(with: event) {
            document.stopPlaying(with: event)
        }
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if document.isSelectNoneCursor(at: p), !document.isSelectedText {
                for (shp, _) in document.sheetViewValues {
                    let ssFrame = document.sheetFrame(with: shp)
                    if document.multiSelection.intersects(ssFrame),
                       let sheetView = document.sheetView(at: shp) {
                        
                        let rects = document.selections
                            .map { sheetView.convertFromWorld($0.rect) }
                        let path = Path(rects.map { Pathline($0) })
                        sheetView.makeFaces(with: path, isSelection: true)
                    }
                }
            } else {
                let (_, sheetView, frame, isAll) = document.sheetViewAndFrame(at: p)
                if let sheetView = sheetView {
                    if isAll {
                        sheetView.makeFaces(with: nil, isSelection: false)
                    } else {
                        let f = sheetView.convertFromWorld(frame)
                        sheetView.makeFaces(with: Path(f), isSelection: false)
                    }
                }
            }
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
    func cutFaces(with event: InputKeyEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        if document.isPlaying(with: event) {
            document.stopPlaying(with: event)
        }
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if document.isSelectNoneCursor(at: p), !document.isSelectedText {
                var value = SheetValue()
                for (shp, _) in document.sheetViewValues {
                    let ssFrame = document.sheetFrame(with: shp)
                    if document.multiSelection.intersects(ssFrame),
                       let sheetView = document.sheetView(at: shp) {
                        
                        let rects = document.selections
                            .map { sheetView.convertFromWorld($0.rect).inset(by: 1) }
                        let path = Path(rects.map { Pathline($0) })
                        if let v = sheetView.removeFilledFaces(with: path, at: p) {
                            value += v
                        }
                    }
                }
                Pasteboard.shared.copiedObjects = [.sheetValue(value)]
                
                document.selections = []
            } else {
                let (_, sheetView, frame, isAll) = document.sheetViewAndFrame(at: p)
                if let sheetView = sheetView {
                    if isAll {
                        sheetView.cutFaces(with: nil)
                    } else {
                        let f = sheetView.convertFromWorld(frame).inset(by: 1)
                        sheetView.cutFaces(with: Path(f))
                    }
                }
            }
        case .changed:
            break
        case .ended:
            document.cursor = Document.defaultCursor
        }
    }
}

final class Importer: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.import(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class Exporter: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.export(with: event, .image)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class ImageExporter: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.export(with: event, .image)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class PDFExporter: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.export(with: event, .pdf)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class GIFExporter: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.export(with: event, .gif)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class MovieExporter: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        
        editor.export(with: event, .movie)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class HighQualityMovieExporter: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.export(with: event, .highQualityMovie)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class SoundExporter: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.export(with: event, .sound)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class CaptionExporter: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.export(with: event, .caption)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class DocumentExporter: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.export(with: event, .documentWithHistory)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class DocumentWithoutHistoryExporter: InputKeyEditor {
    let editor: IOEditor
    
    init(_ document: Document) {
        editor = IOEditor(document)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.export(with: event, .document)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class IOEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    var fp = Point()
    
    let pngMaxWidth = 2048.0, pdfMaxWidth = 512.0
    
    let selectingLineNode = Node(lineWidth: 1.5)
    func updateNode() {
        selectingLineNode.lineWidth = document.worldLineWidth
    }
    func end(isUpdateSelect: Bool = false, isUpdateCursor: Bool = true) {
        selectingLineNode.removeFromParent()
        
        if isUpdateSelect {
            document.updateSelects()
        }
        if isUpdateCursor {
            document.cursor = Document.defaultCursor
        }
        document.updateSelectedColor(isMain: true)
    }
    func name(from shp: Sheetpos) -> String {
        return "\(shp.x)_\(shp.y)"
    }
    func name(from shps: [Sheetpos]) -> String {
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
    
    @discardableResult
    func beginImport(at sp: Point) -> Sheetpos {
        fp = document.convertScreenToWorld(sp)
        selectingLineNode.lineWidth = document.worldLineWidth
        selectingLineNode.fillType = .color(.subSelected)
        selectingLineNode.lineType = .color(.selected)
        let shp = document.sheetPosition(at: fp)
        let frame = document.sheetFrame(with: shp)
        selectingLineNode.path = Path(frame)
        document.rootNode.append(child: selectingLineNode)
        
        document.textCursorNode.isHidden = true
        document.textMaxTypelineWidthNode.isHidden = true
        
        document.updateSelectedColor(isMain: false)
        
        return shp
    }
    func `import`(from urls: [URL], at shp: Sheetpos) {
        var mshp = shp
        var nSHPs = [Sheetpos](), willremoveSHPs = [Sheetpos]()
        for url in urls {
            let importedDocument = Document(url: url)
            
            var maxX = mshp.x
            for (osid, _) in importedDocument.sheetRecorders {
                guard let oshp = importedDocument.sheetPosition(at: osid) else {
                    continue
                }
                let nshp = oshp + mshp
                if document.sheetID(at: nshp) != nil {
                    willremoveSHPs.append(nshp)
                }
                
                nSHPs.append(nshp)
                
                if nshp.x > maxX {
                    maxX = nshp.x
                }
            }
            mshp.x = maxX + 2
        }
        
        var oldP: Point?
        let viewSHPs = sorted(nSHPs.map { SelectingValue(shp: $0, bounds: Rect()) }, with: .maxXMinY)
            .map { $0.shp }
        selectingLineNode.children = viewSHPs.map {
            let frame = document.sheetFrame(with: $0)
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
            Node(path: Path(document.sheetFrame(with: $0)),
                 lineWidth: selectingLineNode.lineWidth * 2,
                 lineType: selectingLineNode.lineType,
                 fillType: selectingLineNode.fillType)
        }
        
        let length = urls.reduce(0) { $0 + ($1.fileSize ?? 0) }
        
        let contentURLs = urls.filter { Content.type(from: $0) != .none }
        if !contentURLs.isEmpty {
            var dshp = Sheetpos()
            let xCount = max(1, Int(Double(contentURLs.count).squareRoot()))
            for url in contentURLs {
                if let sheetView = document.madeSheetView(at: shp + dshp) {
                    let np = contentURLs.count == 1 ? sheetView.convertFromWorld(fp) : Point(10, 50)
                    let filename = url.lastPathComponent
                    let name = UUID().uuidString + "." + url.pathExtension
                    
                    try? document.contentsDirectory.copy(name: name, from: url)
                    
                    let log10Scale: Double = .log10(document.worldToScreenScale)
                    let clipScale = max(0.0, log10Scale)
                    let decimalPlaces = Int(clipScale + 2)
                    let nnp = np.rounded(decimalPlaces: decimalPlaces)
                    
                    var content = Content(name: name, origin: nnp)
                    if let size = content.image?.size {
                        var size = size / 2
                        if size.width > Sheet.width || size.height > Sheet.height {
                            size *= min(Sheet.width / size.width, Sheet.height / size.height)
                        }
                        content.size = size
                    }
                    if content.type.hasDur {
                        let tempo = sheetView.nearestTempo(at: np) ?? Music.defaultTempo
                        let interval = document.currentNoteBeatInterval
                        let startBeat = sheetView.animationView.beat(atX: np.x, interval: interval)
                        let durBeat = ContentTimeOption.beat(fromSec: content.durSec,
                                                             tempo: tempo,
                                                             beatRate: Keyframe.defaultFrameRate,
                                                             rounded: .up)
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
                
                dshp.x += 1
                if dshp.x >= xCount {
                    dshp.x = 0
                    dshp.y -= 1
                }
            }
            end(isUpdateSelect: true)
            return
        }
        
        let ok: () -> () = {
            self.load(from: urls, at: shp)
            
            self.end(isUpdateSelect: true)
        }
        let cancel: () -> () = {
            self.end(isUpdateSelect: true)
        }
        
        if willremoveSHPs.isEmpty && urls.count == 1 {
            ok()
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
            document.rootNode
                .show(message: message,
                      infomation: "This operation can be undone when in root mode, but the data will remain until the root history is cleared.".localized,
                      okTitle: "Import".localized,
                      isSaftyCheck: nSHPs.count > 100 || length > 20*1024*1024,
                      okClosure: ok, cancelClosure: cancel)
        }
    }
    func load(from urls: [URL], at shp: Sheetpos) {
        var mshp = shp
        var nSIDs = [Sheetpos: SheetID](), willremoveSHPs = [Sheetpos]()
        var resetSIDs = Set<SheetID>()
        for url in urls {
            let importedDocument = Document(url: url)
            
            var maxX = mshp.x
            for (osid, osrr) in importedDocument.sheetRecorders {
                guard let oshp = importedDocument.sheetPosition(at: osid) else {
                    let nsid = document.appendSheet(from: osrr)
                    resetSIDs.insert(nsid)
                    continue
                }
                let nshp = oshp + mshp
                if document.sheetID(at: nshp) != nil {
                    willremoveSHPs.append(nshp)
                }
                nSIDs[nshp] = document.appendSheet(from: osrr)
                
                if nshp.x > maxX {
                    maxX = nshp.x + (oshp.isRight ? 1 : 0)
                }
            }
            mshp.x = maxX + 2
        }
        if !willremoveSHPs.isEmpty || !nSIDs.isEmpty || !resetSIDs.isEmpty {
            document.history.newUndoGroup()
            if !willremoveSHPs.isEmpty {
                document.removeSheets(at: willremoveSHPs)
            }
            if !nSIDs.isEmpty {
                document.append(nSIDs)
            }
            if !resetSIDs.isEmpty {
                document.moveSheetsToUpperRightCorner(with: Array(resetSIDs),
                                                      isNewUndoGroup: false)
            }
            document.updateNode()
        }
    }
    func `import`(with event: InputKeyEvent) {
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            let sp = document.lastEditedSheetScreenCenterPositionNoneSelectedNoneCursor
                ?? event.screenPoint
            beginImport(at: sp)
        case .changed:
            break
        case .ended:
            let shp = document.sheetPosition(at: fp)
            let complete: ([IOResult]) -> () = { ioResults in
                self.import(from: ioResults.map { $0.url }, at: shp)
            }
            let cancel: () -> () = {
                self.end(isUpdateSelect: true)
            }
            URL.load(prompt: "Import".localized,
                     allowsMultipleSelection: true,
                     fileTypes: Document.FileType.allCases + Content.FileType.allCases,
                     completionClosure: complete, cancelClosure: cancel)
        }
    }
    
    struct SelectingValue {
        var shp: Sheetpos, bounds: Rect
    }
    
    enum ExportType {
        case image, pdf, gif, movie, highQualityMovie,
             sound, caption, documentWithHistory, document
        var isDocument: Bool {
            self == .document || self == .documentWithHistory
        }
    }
    
    func export(with event: InputKeyEvent, _ type: ExportType) {
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
                ?? event.screenPoint
            fp = document.convertScreenToWorld(sp)
            if document.isSelectNoneCursor(at: fp),
               !document.isSelectedText, !document.selections.isEmpty {
                
                var nvs = [SelectingValue]()
                for selection in document.selections {
                    let vs: [SelectingValue] = document.world.sheetIDs.keys.compactMap { shp in
                        let frame = document.sheetFrame(with: shp)
                        if let rf = selection.rect.intersection(frame) {
                            if document.isEditingSheet {
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
                
                if let unionFrame = document.isEditingSheet
                    && nvs.count > 1 && !type.isDocument ?
                        document.multiSelection.firstSelection(at: fp)?.rect : nil {
                    
                    selectingLineNode.lineWidth = document.worldLineWidth
                    selectingLineNode.fillType = .color(.subSelected)
                    selectingLineNode.lineType = .color(.selected)
                    selectingLineNode.path = Path(unionFrame)
                } else {
                    var oldP: Point?
                    selectingLineNode.children = nvs.map {
                        let frame = !type.isDocument ?
                        ($0.bounds + document.sheetFrame(with: $0.shp).origin) :
                        document.sheetFrame(with: $0.shp)
                        
                        if !type.isDocument, let op = oldP {
                            let cp = frame.centerPoint
                            let a = op.angle(cp) - .pi
                            let d = min(frame.width, frame.height) / 4
                            let p0 = cp.movedWith(distance: d, angle: a + .pi / 6)
                            let p1 = cp.movedWith(distance: d, angle: a - .pi / 6)
                            let path = Path([Pathline([op, cp]),
                                             Pathline([p0, cp, p1])])
                            let arrowNode = Node(path: path,
                                                 lineWidth: document.worldLineWidth,
                                                 lineType: .color(.selected))
                            oldP = frame.centerPoint
                            return Node(children: [arrowNode],
                                        path: Path(frame),
                                        lineWidth: document.worldLineWidth,
                                        lineType: .color(.selected),
                                        fillType: .color(.subSelected))
                        } else {
                            oldP = frame.centerPoint
                            return Node(path: Path(frame),
                                        lineWidth: document.worldLineWidth,
                                        lineType: .color(.selected),
                                        fillType: .color(.subSelected))
                        }
                    }
                }
            } else {
                selectingLineNode.lineWidth = document.worldLineWidth
                selectingLineNode.fillType = .color(.subSelected)
                selectingLineNode.lineType = .color(.selected)
                if !type.isDocument {
                    let (_, _, frame, _) = document.sheetViewAndFrame(at: fp)
                    selectingLineNode.path = Path(frame)
                } else {
                    let frame = document.sheetFrame(with: document.sheetPosition(at: fp))
                    selectingLineNode.path = Path(frame)
                }
                
                document.updateSelectedColor(isMain: false)
            }
            document.rootNode.append(child: selectingLineNode)
            
            document.textCursorNode.isHidden = true
            document.textMaxTypelineWidthNode.isHidden = true
        case .changed:
            break
        case .ended:
            beginExport(type, at: fp)
        }
    }
    func beginExport(_ type: ExportType, at p: Point) {
        var nvs = [SelectingValue]()
        
        let unionFrame: Rect?
        if document.isSelectNoneCursor(at: p), !document.isSelectedText {
            for selection in document.selections {
                let vs: [SelectingValue] = document.world.sheetIDs.keys.compactMap { shp in
                    let frame = document.sheetFrame(with: shp)
                    if let rf = selection.rect.intersection(frame) {
                        if document.isEditingSheet {
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
            
            unionFrame = document.isEditingSheet
                && nvs.count > 1 && !type.isDocument ?
                    document.multiSelection.firstSelection(at: p)?.rect : nil
        } else {
            unionFrame = nil
            let (shp, sheetView, frame, _) = document.sheetViewAndFrame(at: p)
            if let sheetView = sheetView {
                let bounds = sheetView.model.boundsTuple(at: sheetView.convertFromWorld(p), in: document.sheetFrame(with: shp).bounds).bounds.integral
                nvs.append(SelectingValue(shp: shp, bounds: bounds))
            } else {
                let bounds = Rect(size: frame.size)
                nvs.append(SelectingValue(shp: shp, bounds: bounds))
            }
        }
        
        guard let fv = nvs.first else {
            end()
            return
        }
        let size = unionFrame?.size ??
        (nvs.count >= 2 ? document.sheetView(at: fv.shp)?.model.mainFrame?.size : nil) ?? fv.bounds.size
        guard size.width > 0 && size.height > 0 else {
            end()
            return
        }
        
        let complete: (IOResult) -> () = { (ioResult) in
            self.document.syncSave()
            switch type {
            case .image:
                self.exportImage(from: nvs, unionFrame: unionFrame,
                                 size: size,
                                 scale: Picture.renderingScale, at: ioResult)
            case .pdf:
                self.exportPDF(from: nvs, unionFrame: unionFrame,
                               size: size, at: ioResult)
            case .gif:
                let nSize = size.snapped(Size(width: 800, height: 1200)).rounded()
                self.exportGIF(from: nvs, size: nSize, at: ioResult)
            case .movie:
                let nSize = size == Size(width: 426, height: 240) || size == Size(width: 800, height: 450) ?
                    Size(width: 1920, height: 1080) :
                (size == Size(width: 426, height: 320) ?
                        Size(width: 1440, height: 1080) :
                        size.snapped(Size(width: 1200, height: 1920)).rounded())
                self.exportMovie(from: nvs, isHighQuality: false,
                                 size: nSize, at: ioResult)
            case .sound:
                self.exportSound(from: nvs, at: ioResult)
            case .caption:
                self.exportCaption(from: nvs, at: ioResult)
            case .highQualityMovie:
                let nSize = size == Size(width: 426, height: 240) || size == Size(width: 800, height: 450) ?
                    Size(width: 3840, height: 2160) :
                (size == Size(width: 426, height: 320) ?
                        Size(width: 2880, height: 2160) :
                        size.snapped(Size(width: 3840, height: 2160)).rounded())
                self.exportMovie(from: nvs,  isHighQuality: true,
                                 size: nSize, at: ioResult)
            case .document:
                self.exportDocument(from: nvs, isHistory: false, at: ioResult)
            case .documentWithHistory:
                self.exportDocument(from: nvs, isHistory: true, at: ioResult)
            }
            self.end()
        }
        let cancel: () -> () = {
            self.end()
        }
        let fileSize: () -> (Int?) = {
            switch type {
            case .image:
                if nvs.count == 1 {
                    let v = nvs[0]
                    if let sid = self.document.sheetID(at: v.shp),
                       let node = self.document.renderableSheetNode(at: sid) {
                        let image = node.renderedAntialiasFillImage(in: v.bounds, to: size * 4, backgroundColor: .background)
                        return image?.data(.png)?.count ?? 0
                    } else {
                        let node = Node(path: Path(v.bounds),
                                        fillType: .color(.background))
                        let image = node.image(in: v.bounds, size: size, backgroundColor: .background, colorSpace: .sRGB)
                        return image?.data(.png)?.count ?? 0
                    }
                }
            case .pdf:
                if nvs.count == 1 {
                    let v = nvs[0]
                    if let pdf = try? PDF(mediaBox: Rect(size: size)) {
                        if let sid = self.document.sheetID(at: v.shp),
                           let node = self.document.renderableSheetNode(at: sid) {
                            node.render(in: v.bounds, to: size,
                                        in: pdf)
                        } else {
                            let node = Node(path: Path(v.bounds),
                                            fillType: .color(.background))
                            node.render(in: v.bounds, to: size,
                                        backgroundColor: .background,
                                        in: pdf)
                        }
                        pdf.finish()
                        return pdf.dataSize
                    }
                }
            case .gif, .movie, .highQualityMovie, .caption: break
            case .document:
                let sids = nvs.reduce(into: [Sheetpos: SheetID]()) {
                    $0[$1.shp] = self.document.sheetID(at: $1.shp)
                }
                let csv = CopiedSheetsValue(deltaPoint: Point(), sheetIDs: sids)
                
                var fileSize = 0
                csv.sheetIDs.forEach {
                    if let v = self.document.sheetRecorders[$0.value] {
                        fileSize += v.fileSizeWithoutHistory
                    }
                }
                return fileSize
            case .sound: break
            case .documentWithHistory:
                let sids = nvs.reduce(into: [Sheetpos: SheetID]()) {
                    $0[$1.shp] = self.document.sheetID(at: $1.shp)
                }
                let csv = CopiedSheetsValue(deltaPoint: Point(), sheetIDs: sids)
                
                var fileSize = 0
                csv.sheetIDs.forEach {
                    if let v = self.document.sheetRecorders[$0.value] {
                        fileSize += v.fileSize
                    }
                }
                return fileSize
            }
            return nil
        }
        
        let fType: FileTypeProtocol = switch type {
        case .image:
            nvs.count > 1 && unionFrame == nil ?
                Image.FileType.pngs : Image.FileType.png
        case .gif:
            Image.FileType.gif
        case .pdf:
            PDF.FileType.pdf
        case .movie, .highQualityMovie:
            Movie.FileType.mp4
        case .sound:
            Content.FileType.wav
        case .caption:
            Caption.FileType.scc
        case .document:
            Document.FileType.rasendoc
        case .documentWithHistory:
            Document.FileType.rasendoch
        }
        
        URL.export(name: name(from: nvs.map { $0.shp }),
                   fileType: fType,
                   fileSizeHandler: fileSize,
                   completionClosure: complete, cancelClosure: cancel)
    }
    
    func exportImage(from vs: [SelectingValue], unionFrame: Rect?,
                     size: Size, scale: Double, at ioResult: IOResult) {
        let size = size * scale
        if vs.isEmpty {
            return
        } else if vs.count == 1 || unionFrame != nil {
            do {
                try ioResult.remove()
                
                let colorSpace = document.colorSpace
                if let unionFrame = unionFrame {
                    var nImage = Image(size: unionFrame.size * scale,
                                       color: .background)
                    for v in vs {
                        let origin = document.sheetFrame(with: v.shp).origin - unionFrame.origin
                        
                        if let sid = self.document.sheetID(at: v.shp),
                           let node = self.document.renderableSheetNode(at: sid) {
                            if let image = node.renderedAntialiasFillImage(in: v.bounds, to: size, backgroundColor: .background) {
                                nImage = nImage?.drawn(image, in: (v.bounds + origin) * Transform(scale: scale))
                            }
                        } else {
                            let node = Node(path: Path(v.bounds),
                                            fillType: .color(.background))
                            if let image = node.image(in: v.bounds, size: size, backgroundColor: .background, colorSpace: colorSpace) {
                                nImage = nImage?.drawn(image, in: (v.bounds + origin) * Transform(scale: scale))
                            }
                        }
                    }
                    try nImage?.write(.png, to: ioResult.url)
                } else {
                    let v = vs[0]
                    if let sid = self.document.sheetID(at: v.shp),
                       let node = self.document.renderableSheetNode(at: sid) {
                        let image = node.renderedAntialiasFillImage(in: v.bounds, to: size, backgroundColor: .background)
                        try image?.write(.png, to: ioResult.url)
                    } else {
                        let node = Node(path: Path(v.bounds),
                                        fillType: .color(.background))
                        let image = node.image(in: v.bounds, size: size, backgroundColor: .background,
                                               colorSpace: colorSpace)
                        try image?.write(.png, to: ioResult.url)
                    }
                }
                
                try ioResult.setAttributes()
            } catch {
                self.document.rootNode.show(error)
            }
        } else {
            let message = "Exporting Images".localized
            let progressPanel = ProgressPanel(message: message)
            self.document.rootNode.show(progressPanel)
            do {
                try ioResult.remove()
                try ioResult.makeDirectory()
                
                func export(progressHandler: (Double, inout Bool) -> ()) throws {
                    let colorSpace = self.document.colorSpace
                    var isStop = false
                    for (j, v) in vs.enumerated() {
                        if let sid = self.document.sheetID(at: v.shp),
                           let node = self.document.renderableSheetNode(at: sid) {
                            let image = node.renderedAntialiasFillImage(in: v.bounds, to: size, backgroundColor: .background)
                            let subIOResult = ioResult.sub(name: "\(j).png")
                            try image?.write(.png, to: subIOResult.url)
                            
                            try subIOResult.setAttributes()
                        } else {
                            let node = Node(path: Path(v.bounds),
                                            fillType: .color(.background))
                            let image = node.image(in: v.bounds, size: size,
                                                   backgroundColor: .background, colorSpace: colorSpace)
                            let subIOResult = ioResult.sub(name: "\(j).png")
                            try image?.write(.png, to: subIOResult.url)
                            
                            try subIOResult.setAttributes()
                        }
                        progressHandler(Double(j + 1) / Double(vs.count), &isStop)
                        if isStop { break }
                    }
                }
                
                DispatchQueue.global().async {
                    do {
                        try export { (progress, isStop) in
                            if progressPanel.isCancel {
                                isStop = true
                            } else {
                                DispatchQueue.main.async {
                                    progressPanel.progress = progress
                                }
                            }
                        }
                        DispatchQueue.main.async {
                            progressPanel.closePanel()
                            self.end()
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.document.rootNode.show(error)
                            progressPanel.closePanel()
                            self.end()
                        }
                    }
                }
            } catch {
                self.document.rootNode.show(error)
                progressPanel.closePanel()
                self.end()
            }
        }
    }
    
    func exportPDF(from vs: [SelectingValue],  unionFrame: Rect?,
                   size: Size, at ioResult: IOResult) {
        func export(progressHandler: (Double, inout Bool) -> ()) throws {
            var isStop = false
            let pdf = try PDF(url: ioResult.url, mediaBox: Rect(size: size))
            
            if let unionFrame = unionFrame {
                pdf.newPage { pdf in
                    for v in vs {
                        let origin = document.sheetFrame(with: v.shp).origin - unionFrame.origin
                        
                        if let sid = self.document.sheetID(at: v.shp),
                           let node = self.document.renderableSheetNode(at: sid) {
                            node.render(in: v.bounds, to: v.bounds + origin,
                                        in: pdf)
                        } else {
                            let node = Node(path: Path(v.bounds),
                                            fillType: .color(.background))
                            node.render(in: v.bounds, to: v.bounds + origin,
                                        backgroundColor: .background,
                                        in: pdf)
                        }
                    }
                }
            } else {
                for (i, v) in vs.enumerated() {
                    if let sid = self.document.sheetID(at: v.shp),
                       let node = self.document.renderableSheetNode(at: sid) {
                        node.render(in: v.bounds, to: size,
                                    in: pdf)
                    } else {
                        let node = Node(path: Path(v.bounds),
                                        fillType: .color(.background))
                        node.render(in: v.bounds, to: size,
                                    backgroundColor: .background,
                                    in: pdf)
                    }
                    
                    progressHandler(Double(i + 1) / Double(vs.count), &isStop)
                    if isStop { break }
                }
            }
            
            pdf.finish()
            
            try ioResult.setAttributes()
        }
        
        if vs.count == 1 {
            do {
                try export { (_, isStop) in }
                self.end()
            } catch {
                self.document.rootNode.show(error)
                self.end()
            }
        } else {
            let message = "Exporting PDF".localized
            let progressPanel = ProgressPanel(message: message)
            self.document.rootNode.show(progressPanel)
            do {
                try ioResult.remove()
                
                DispatchQueue.global().async {
                    do {
                        try export { (progress, isStop) in
                            if progressPanel.isCancel {
                                isStop = true
                            } else {
                                DispatchQueue.main.async {
                                    progressPanel.progress = progress
                                }
                            }
                        }
                        DispatchQueue.main.async {
                            progressPanel.closePanel()
                            self.end()
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.document.rootNode.show(error)
                            progressPanel.closePanel()
                            self.end()
                        }
                    }
                }
            } catch {
                self.document.rootNode.show(error)
                progressPanel.closePanel()
                self.end()
            }
        }
    }
    
    func exportMovie(from vs: [SelectingValue], isHighQuality: Bool,
                     size: Size, at ioResult: IOResult) {
        func export(progressHandler: (Double, inout Bool) -> (),
                    completionHandler handler: @escaping (Bool, Error?) -> ()) {
            do {
                let colorSpace = self.document.colorSpace
                let movie = try Movie(url: ioResult.url, renderSize: size,
                                      isLinearPCM: isHighQuality,
                                      colorSpace: colorSpace)
                var isStop = false, t = 0.0
                let isMainFrame = !self.document.isEditingSheet
                var filledShps = Set<Sheetpos>()
                for v in vs {
                    if let sid = self.document.sheetID(at: v.shp),
                       let sheet = self.document.renderableSheet(at: sid) {
                        
                        let sheetBounds = self.document.sheetFrame(with: v.shp).bounds
                        var frameRate = sheet.mainFrameRate
                        var bottomSheets = [(sheet: Sheet, bounds: Rect)]()
                        var shp = v.shp
                        shp.y -= 1
                        while let sid = self.document.sheetID(at: shp),
                              let sheet = self.document.renderableSheet(at: sid),
                              sheet.enabledAnimation {
                            
                            guard filledShps.contains(shp) else { continue }
                            filledShps.insert(shp)
                            let sheetBounds = self.document.sheetFrame(with: shp).bounds
                            bottomSheets.append((sheet, sheetBounds))
                            frameRate = max(frameRate, sheet.mainFrameRate)
                            shp.y -= 1
                        }
                        
                        var topSheets = [(sheet: Sheet, bounds: Rect)]()
                        shp = v.shp
                        shp.y += 1
                        while let sid = self.document.sheetID(at: shp),
                              let sheet = self.document.renderableSheet(at: sid),
                           sheet.enabledAnimation {
                            
                            guard filledShps.contains(shp) else { continue }
                            filledShps.insert(shp)
                            let sheetBounds = self.document.sheetFrame(with: shp).bounds
                            topSheets.append((sheet, sheetBounds))
                            frameRate = max(frameRate, sheet.mainFrameRate)
                            shp.y += 1
                        }
                        
                        let origin = self.document.sheetFrame(with: v.shp).origin
                        let ot = t
                        let b = isMainFrame ? (sheet.mainFrame ?? v.bounds) : v.bounds
                        
                        let duration = sheet.animation.sec(fromBeat: sheet.allDurBeat)
                        let frameCount = sheet.animation.count(fromBeat: sheet.allDurBeat,
                                                               frameRate: frameRate)
                        
                        movie.writeMovie(frameCount: frameCount,
                                         duration: duration, 
                                         frameRate: frameRate) { (sec) -> (Image?) in
                            //tempo -> startTime
                            let beat = sheet.animation.beat(fromSec: sec)
                            let node: Node
                            if !bottomSheets.isEmpty || !topSheets.isEmpty {
                                var children = [Node]()
                                for (bottomSheet, sheetBounds) in bottomSheets.reversed() {
                                    children.append(bottomSheet.node(isBorder: false, atRootBeat: beat,
                                                                     renderingCaptionFrame: b,
                                                                     isBackground: false,
                                                                     in: sheetBounds))
                                }
                                children.append(sheet.node(isBorder: false, atRootBeat: beat,
                                                           renderingCaptionFrame: b,
                                                           isBackground: false, 
                                                           in: sheetBounds))
                                for (topSheet, sheetBounds) in topSheets {
                                    children.append(topSheet.node(isBorder: false, atRootBeat: beat,
                                                                  renderingCaptionFrame: b,
                                                                  isBackground: false,
                                                                  in: sheetBounds))
                                }
                                node = Node(children: children, path: Path(sheetBounds))
                            } else {
                                node = sheet.node(isBorder: false, atRootBeat: beat,
                                                      renderingCaptionFrame: b,
                                                  in: sheetBounds)
                            }
                            node.attitude.position = origin
                           
                            if let image =  node.renderedAntialiasFillImage(in: b, to: size, backgroundColor: .background) {
                                return image
                            } else {
                                return nil
                            }
                        } progressHandler: { (d, stop) in
                            t = ot + d / Double(vs.count)
                            progressHandler(t * 0.7, &isStop)
                            if isStop {
                                stop = true
                            }
                        }
                    } else {
                        let ot = t
                        let node = Node(path: Path(v.bounds),
                                        fillType: .color(.background))
                        if let image = node.image(in: v.bounds, size: size,
                                                  backgroundColor: .background, colorSpace: colorSpace) {
                            let duration = Animation.sec(fromBeat: Keyframe.defaultDurBeat,
                                                        tempo: Music.defaultTempo)
                            let frameCount = Animation.count(fromBeat: Keyframe.defaultDurBeat,
                                                         tempo: Music.defaultTempo,
                                                         frameRate: 24)
                            movie.writeMovie(frameCount: frameCount,
                                             duration: duration,
                                             frameRate: 24) { (time) -> (Image?) in
                                image
                            } progressHandler: { (d, stop) in
                                t = ot + d / Double(vs.count)
                                progressHandler(t * 0.7, &isStop)
                                if isStop {
                                    stop = true
                                }
                            }
                        }
                    }
                    
                    if isStop { break }
                }
                
                var audiotracks = [Audiotrack]()
                
                if !isStop {
                    for (i, v) in vs.enumerated() {
                        var audiotrack: Audiotrack?
                        if let sid = self.document.sheetID(at: v.shp),
                           let sheet = self.document.renderableSheet(at: sid) {
                            
                            audiotrack += sheet.audiotrack
                        }
                        var shp = v.shp
                        shp.y -= 1
                        while let sid = self.document.sheetID(at: shp),
                              let sheet = self.document.renderableSheet(at: sid),
                              sheet.enabledTimeline {
                            
                            audiotrack += sheet.audiotrack
                            shp.y -= 1
                        }
                        shp = v.shp
                        shp.y += 1
                        while let sid = self.document.sheetID(at: shp),
                              let sheet = self.document.renderableSheet(at: sid),
                              sheet.enabledTimeline {
                            
                            audiotrack += sheet.audiotrack
                            shp.y += 1
                        }
                        
                        if let audiotrack = audiotrack {
                            audiotracks.append(audiotrack)
                        }
                        
                        let t = (Double(i) / Double(vs.count - 1)) * 0.1 + 0.7
                        progressHandler(t, &isStop)
                        if isStop { break }
                    }
                    if !isStop {
                        if let sequencer = Sequencer(audiotracks: audiotracks) {
                            try movie.writeAudio(from: sequencer) { t, stop in
                                progressHandler(t * 0.2 + 0.8, &isStop)
                                if isStop {
                                    stop = true
                                }
                            }
                        }
                    }
                }
                
                movie.finish { (stop, error) in
                    handler(stop, error)
                }
            } catch {
                handler(false, error)
            }
        }
        
        let message = "Exporting Movie".localized
        let progressPanel = ProgressPanel(message: message)
        self.document.rootNode.show(progressPanel)
        do {
            try ioResult.remove()
            
            DispatchQueue.global().async {
                export(progressHandler: { (progress, isStop) in
                    if progressPanel.isCancel {
                        isStop = true
                    } else {
                        DispatchQueue.main.async {
                            progressPanel.progress = progress
                        }
                    }
                }, completionHandler: { (stop, error) in
                    DispatchQueue.main.async {
                        if !stop {
                            if let error = error {
                                self.document.rootNode.show(error)
                            } else {
                                do {
                                    try ioResult.setAttributes()
                                } catch {
                                    self.document.rootNode.show(error)
                                }
                            }
                        }
                        progressPanel.closePanel()
                        self.end()
                    }
                })
            }
        } catch {
            self.document.rootNode.show(error)
            progressPanel.closePanel()
            self.end()
        }
    }
    
    func exportSound(from vs: [SelectingValue], at ioResult: IOResult) {
        func export(progressHandler: (Double, inout Bool) -> (),
                    completionHandler handler: @escaping (Error?) -> ()) {
            do {
                var audiotracks = [Audiotrack]()
                
                var isStop = false
                for (i, v) in vs.enumerated() {
                    if let sid = self.document.sheetID(at: v.shp),
                       let sheet = self.document.renderableSheet(at: sid) {
                        audiotracks.append(sheet.audiotrack)
                    }
                    let t = 0.2 * Double(i) / Double(vs.count - 1)
                    progressHandler(t, &isStop)
                    if isStop { break }
                }
                if !isStop {
                    if let sequencer = Sequencer(audiotracks: audiotracks) {
                        try sequencer.export(url: ioResult.url,
                                             sampleRate: Audio.defaultSampleRate) { (t, stop) in
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
        
        let message = "Exporting Sound".localized
        let progressPanel = ProgressPanel(message: message)
        self.document.rootNode.show(progressPanel)
        do {
            try ioResult.remove()
            
            DispatchQueue.global().async {
                export(progressHandler: { (progress, isStop) in
                    if progressPanel.isCancel {
                        isStop = true
                    } else {
                        DispatchQueue.main.async {
                            progressPanel.progress = progress
                        }
                    }
                }, completionHandler: { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.document.rootNode.show(error)
                        } else {
                            do {
                                try ioResult.setAttributes()
                            } catch {
                                self.document.rootNode.show(error)
                            }
                        }
                        progressPanel.closePanel()
                        self.end()
                    }
                })
            }
        } catch {
            self.document.rootNode.show(error)
            progressPanel.closePanel()
            self.end()
        }
    }
    
    func exportCaption(from vs: [SelectingValue], at ioResult: IOResult) {
        func export(progressHandler: (Double, inout Bool) -> (),
                    completionHandler handler: @escaping (Error?) -> ()) {
            do {
                let cce = try CaptionRenderer(url: ioResult.url)
                
                var isStop = false, t = 0.0
                for v in vs {
                    if let sid = self.document.sheetID(at: v.shp),
                       let sheet = self.document.renderableSheet(at: sid) {
                        let tl = sheet.animation.localDurBeat
                        let ot = t
                        let captions = sheet.captions
                        cce.write(captions: captions, duration: tl,
                                  frameRate: sheet.mainFrameRate) { (d, stop) in
                            t = ot + d / Double(vs.count)
                            progressHandler(t, &isStop)
                            if isStop {
                                stop = true
                            }
                        }
                    }
                    
                    if isStop { break }
                }
                cce.finish { error in
                    handler(error)
                }
            } catch {
                handler(error)
            }
        }
        
        let message = "Exporting Caption".localized
        let progressPanel = ProgressPanel(message: message)
        self.document.rootNode.show(progressPanel)
        do {
            try ioResult.remove()
            
            DispatchQueue.global().async {
                export(progressHandler: { (progress, isStop) in
                    if progressPanel.isCancel {
                        isStop = true
                    } else {
                        DispatchQueue.main.async {
                            progressPanel.progress = progress
                        }
                    }
                }, completionHandler: { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.document.rootNode.show(error)
                        } else {
                            do {
                                try ioResult.setAttributes()
                            } catch {
                                self.document.rootNode.show(error)
                            }
                        }
                        progressPanel.closePanel()
                        self.end()
                    }
                })
            }
        } catch {
            self.document.rootNode.show(error)
            progressPanel.closePanel()
            self.end()
        }
    }
    
    func exportGIF(from vs: [SelectingValue],
                   size: Size, at ioResult: IOResult) {
        func export(progressHandler: (Double, inout Bool) -> ()) throws {
            var images = [(image: Image, time: Rational)]()
            var isStop = false, t = 0.0
            let allC = vs.count + 1
            for v in vs {
                if let sid = self.document.sheetID(at: v.shp),
                   let sheet = self.document.renderableSheet(at: sid) {
                    let sheetBounds = self.document.sheetFrame(with: v.shp).bounds
                    let ot = t
                    var time = Rational(0)
                    for (i, _) in sheet.animation.keyframes.enumerated() {
                        let node = sheet.node(isBorder: false, atRootBeat: time,
                                              in: sheetBounds)
                        node.attitude.position = sheetBounds.origin
                        let durBeat = sheet.animation.rendableKeyframeDurBeat(at: i)
                        if let image = node.image(in: v.bounds, size: size,
                                                  backgroundColor: .background, colorSpace: .sRGB) {
                            images.append((image, sheet.animation.sec(fromBeat: durBeat)))
                        }
                        time += durBeat
                        let d = Double(i) / Double(sheet.animation.keyframes.count - 1)
                        t = ot + d / Double(allC)
                        progressHandler(t, &isStop)
                    }
                } else {
                    let ot = t
                    let node = Node(path: Path(v.bounds),
                                    fillType: .color(.background))
                    if let image = node.image(in: v.bounds, size: size,
                                              backgroundColor: .background, colorSpace: .sRGB) {
                        images.append((image, Keyframe.defaultDurBeat))
                        t = ot + 1 / Double(allC)
                        progressHandler(t, &isStop)
                    }
                }
                
                if isStop { break }
            }
            
            try Image.writeGIF(images, to: ioResult.url)
            progressHandler(1, &isStop)
            try ioResult.setAttributes()
        }
        
        let message = "Exporting Movie".localized
        let progressPanel = ProgressPanel(message: message)
        self.document.rootNode.show(progressPanel)
        do {
            try ioResult.remove()
            
            DispatchQueue.global().async {
                do {
                    try export { (progress, isStop) in
                        if progressPanel.isCancel {
                            isStop = true
                        } else {
                            DispatchQueue.main.async {
                                progressPanel.progress = progress
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        progressPanel.closePanel()
                        self.end()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.document.rootNode.show(error)
                        progressPanel.closePanel()
                        self.end()
                    }
                }
            }
        } catch {
            document.rootNode.show(error)
            progressPanel.closePanel()
            end()
        }
    }
    
    func exportDocument(from vs: [SelectingValue],
                        isHistory: Bool,
                        at ioResult: IOResult) {
        guard let shp0 = vs.first?.shp else { return }
        
        func export(progressHandler: (Double, inout Bool) -> ()) throws {
            try ioResult.remove()
            
            let sids = vs.reduce(into: [Sheetpos: SheetID]()) {
                $0[$1.shp - shp0] = document.sheetID(at: $1.shp)
            }
            let csv = CopiedSheetsValue(deltaPoint: Point(), sheetIDs: sids)
            
            var isStop = false
            let nDocument = Document(url: ioResult.url)
            for (i, v) in csv.sheetIDs.enumerated() {
                let (shp, osid) = v
                guard let osrr = document.sheetRecorders[osid] else { continue }
                let nsid = SheetID()
                let nsrr = nDocument.makeSheetRecorder(at: nsid)
                if let oldSID = nDocument.world.sheetIDs[shp] {
                    nDocument.world.sheetPositions[oldSID] = nil
                }
                nDocument.world.sheetIDs[shp] = nsid
                nDocument.world.sheetPositions[nsid] = shp
                
                nsrr.sheetRecord.data
                    = osrr.sheetRecord.decodedData
                nsrr.thumbnail4Record.data
                    = osrr.thumbnail4Record.decodedData
                nsrr.thumbnail16Record.data
                    = osrr.thumbnail16Record.decodedData
                nsrr.thumbnail64Record.data
                    = osrr.thumbnail64Record.decodedData
                nsrr.thumbnail256Record.data
                    = osrr.thumbnail256Record.decodedData
                nsrr.thumbnail1024Record.data
                    = osrr.thumbnail1024Record.decodedData
                nsrr.stringRecord.data = osrr.stringRecord.decodedData
                nsrr.sheetRecord.isWillwrite = true
                nsrr.thumbnail4Record.isWillwrite = true
                nsrr.thumbnail16Record.isWillwrite = true
                nsrr.thumbnail64Record.isWillwrite = true
                nsrr.thumbnail256Record.isWillwrite = true
                nsrr.thumbnail1024Record.isWillwrite = true
                nsrr.stringRecord.isWillwrite = true
                
                if isHistory {
                    nsrr.sheetHistoryRecord.data
                        = osrr.sheetHistoryRecord.decodedData
                    nsrr.sheetHistoryRecord.isWillwrite = true
                }
                
                progressHandler(Double(i + 1) / Double(csv.sheetIDs.count + 1), &isStop)
                if isStop { break }
            }
            nDocument.camera = document.camera
            nDocument.syncSave()
            
            try ioResult.setAttributes()
        }
        
        if vs.count == 1 {
            do {
                try export { (_, isStop) in }
                self.end()
            } catch {
                self.document.rootNode.show(error)
                self.end()
            }
        } else {
            let message = "Exporting Document".localized
            let progressPanel = ProgressPanel(message: message)
            self.document.rootNode.show(progressPanel)
            DispatchQueue.global().async {
                do {
                    try export { (progress, isStop) in
                        if progressPanel.isCancel {
                            isStop = true
                        } else {
                            DispatchQueue.main.async {
                                progressPanel.progress = progress
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        progressPanel.closePanel()
                        self.end()
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.document.rootNode.show(error)
                        progressPanel.closePanel()
                        self.end()
                    }
                }
            }
        }
    }
}
