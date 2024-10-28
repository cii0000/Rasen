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

import struct Foundation.UUID

@MainActor protocol Editor {
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

final class RootEditor: Editor {
    var document: Document
    
    init(_ document: Document) {
        self.document = document
        
        document.updateNodeNotifications.append { [weak self] _ in
            self?.updateEditorNode()
        }
    }
    
    func cancelTasks() {
        runners.forEach { $0.cancel() }
        
        textEditor.cancelTasks()
        
        document.cancelTasks()
    }
    
    func containsAllTimelines(with event: any Event) -> Bool {
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        guard let sheetView = document.sheetView(at: p) else { return false }
        let inP = sheetView.convertFromWorld(p)
        return sheetView.animationView.containsTimeline(inP, scale: document.screenToWorldScale)
        || sheetView.containsOtherTimeline(inP, scale: document.screenToWorldScale)
    }
    func isPlaying(with event: any Event) -> Bool {
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        if let sheetView = document.sheetView(at: p), sheetView.isPlaying {
            return true
        }
        for shp in document.aroundSheetpos(atCenter: document.intPosition(at: p)) {
            if let sheetView = document.sheetView(at: shp.shp), sheetView.isPlaying {
                return true
            }
        }
        return false
    }
    
    var modifierKeys = ModifierKeys()
    
    func indicate(with event: DragEvent) {
        document.cursorPoint = event.screenPoint
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
            document.textCursorNode.isHidden = true
            document.textMaxTypelineWidthNode.isHidden = true
        case .changed:
            subDragEditor?.send(event)
            oldSubDragEvent = event
        case .ended:
            oldSubDragEvent = nil
            subDragEditor?.send(event)
            subDragEditor = nil
            document.cursorPoint = event.screenPoint
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
            document.textCursorNode.isHidden = true
            document.textMaxTypelineWidthNode.isHidden = true
        case .changed:
            middleDragEditor?.send(event)
            oldMiddleDragEvent = event
        case .ended:
            oldMiddleDragEvent = nil
            middleDragEditor?.send(event)
            middleDragEditor = nil
            document.cursorPoint = event.screenPoint
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
        case .slide: MoveEditor(self)
        case .selectFrame: FrameSelecter(self)
            
        case .moveLinePoint, .fnMoveLinePoint: LineSlider(self)
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
            document.textCursorNode.isHidden = true
            document.textMaxTypelineWidthNode.isHidden = true
            
            document.isUpdateWithCursorPosition = false
            document.cursorPoint = event.screenPoint
        case .changed:
            dragEditor?.send(event)
            oldDragEvent = event
            
            document.cursorPoint = event.screenPoint
        case .ended:
            oldDragEvent = nil
            dragEditor?.send(event)
            dragEditor = nil
            
            document.isUpdateWithCursorPosition = true
            document.cursorPoint = event.screenPoint
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
            document.updateRunners(fromWorldPrintOrigins: runners.map { $0.worldPrintOrigin })
        }
    }
    
    private func inputKeyEditor(with quasimode: Quasimode) -> (any InputKeyEditor)? {
        switch quasimode {
        case .cut: Cutter(self)
        case .copy: Copier(self)
        case .copyLineColor: LineColorCopier(self)
        case .paste: Paster(self)
        case .undo: Undoer(self)
        case .redo: Redoer(self)
        case .find: Finder(self)
        case .lookUp: Looker(self)
        case .changeToVerticalText: VerticalTextChanger(self)
        case .changeToHorizontalText: HorizontalTextChanger(self)
        case .changeToSuperscript: SuperscriptChanger(self)
        case .changeToSubscript: SubscriptChanger(self)
        case .run: RunEditor(self)
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
        case .stop: Stopper(self)
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
            if document.editingTextView != nil
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
    
    func updateLastEditedSheetpos(from event: any Event) {
        document.updateLastEditedSheetpos(fromScreen: event.screenPoint)
    }
    
    func keepOut(with event: any Event) {
        switch event.phase {
        case .began:
            document.cursor = .block
        case .changed:
            break
        case .ended:
            document.cursor = document.defaultCursor
        }
    }
    func stopPlaying(with event: any Event) {
        switch event.phase {
        case .began:
            document.cursor = .stop
            
            for (_, v) in document.sheetViewValues {
                v.view?.stop()
            }
        case .changed:
            break
        case .ended:
            document.cursor = document.defaultCursor
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

final class Zoomer: PinchEditor {
    let root: RootEditor, document: Document
    
    init(_ root: RootEditor) {
        self.root = root
        document = root.document
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
            root.textEditor.moveEndInputKey()
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
    let root: RootEditor, document: Document
    
    init(_ root: RootEditor) {
        self.root = root
        document = root.document
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
            document.defaultCursor = Cursor.rotate(rotation: -document.camera.rotation + .pi / 2)
            document.cursor = document.defaultCursor
        } else {
            document.defaultCursor = .drawLine
            document.cursor = document.defaultCursor
        }
    }
}

final class Scroller: ScrollEditor {
    let root: RootEditor, document: Document
    
    init(_ root: RootEditor) {
        self.root = root
        document = root.document
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
    
    init(_ root: RootEditor) {
        editor = DraftEditor(root)
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
    
    init(_ root: RootEditor) {
        editor = DraftEditor(root)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.cutDraft(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class DraftEditor: Editor {
    let root: RootEditor, document: Document
    let isEditingSheet: Bool
    
    init(_ root: RootEditor) {
        self.root = root
        document = root.document
        isEditingSheet = document.isEditingSheet
    }
    
    func changeToDraft(with event: InputKeyEvent) {
        guard isEditingSheet else {
            root.keepOut(with: event)
            return
        }
        if root.isPlaying(with: event) {
            root.stopPlaying(with: event)
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
                    } else if sheetView.animationView.containsTimeline(inP, scale: document.screenToWorldScale),
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
            document.cursor = document.defaultCursor
        }
    }
    func cutDraft(with event: InputKeyEvent) {
        guard isEditingSheet else {
            root.keepOut(with: event)
            return
        }
        if root.isPlaying(with: event) {
            root.stopPlaying(with: event)
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
                                    let pitchInterval = document.currentPitchInterval
                                    let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                                    let beatInterval = document.currentBeatInterval
                                    let beat = scoreView.beat(atX: scoreP.x, interval: beatInterval)
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
                            let pitchInterval = document.currentPitchInterval
                            let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                            let beatInterval = document.currentBeatInterval
                            let beat = scoreView.beat(atX: scoreP.x, interval: beatInterval)
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
                    } else if sheetView.animationView.containsTimeline(inP, scale: document.screenToWorldScale),
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
            document.cursor = document.defaultCursor
        }
    }
}

final class FacesMaker: InputKeyEditor {
    let editor: FaceEditor
    
    init(_ root: RootEditor) {
        editor = FaceEditor(root)
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
    
    init(_ root: RootEditor) {
        editor = FaceEditor(root)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.cutFaces(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class FaceEditor: Editor {
    let root: RootEditor, document: Document
    let isEditingSheet: Bool
    
    init(_ root: RootEditor) {
        self.root = root
        document = root.document
        isEditingSheet = document.isEditingSheet
    }
    
    func makeFaces(with event: InputKeyEvent) {
        guard isEditingSheet else {
            root.keepOut(with: event)
            return
        }
        if root.isPlaying(with: event) {
            root.stopPlaying(with: event)
        }
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if let sheetView = document.sheetView(at: p), sheetView.model.score.enabled {
                let score = sheetView.scoreView.model
                let nis = document.isSelectNoneCursor(at: p) && !document.isSelectedText ?
                sheetView.noteIndexes(from: document.selections) :
                Array(score.notes.count.range)
                let nnis = nis.filter { score.notes[$0].isDefaultTone }.sorted()
                if !nnis.isEmpty {
                    var tones = [UUID: Tone]()
                    var nivs = [IndexValue<Note>]()
                    for ni in nnis {
                        var note = score.notes[ni]
                        for (pi, pit) in note.pits.enumerated() {
                            if let tone = tones[pit.tone.id] {
                                note.pits[pi].tone = tone
                            } else if pit.tone.isDefault {
                                let pitch = Double(pit.pitch + note.pitch)
                                var spectlope = Spectlope(sprols: [
                                    .init(pitch: pitch - 12, volm: .random(in: 0 ..< 1), noise: 0),
                                    .init(pitch: pitch, volm: .random(in: 0 ..< 1), noise: 0),
                                    .init(pitch: pitch + 12, volm: .random(in: 0 ..< 1), noise: 0),
                                    .init(pitch: pitch + 24, volm: .random(in: 0 ..< 1), noise: 0),
                                    .init(pitch: pitch + 36, volm: .random(in: 0 ..< 0.5), noise: 0),
                                    .init(pitch: pitch + 48, volm: .random(in: 0 ..< 0.25), noise: 0)
                                ].filter { Score.doublePitchRange.contains($0.pitch) }).normarized()
                                if spectlope.sprols.count > 2 {
                                    spectlope.sprols[.first].volm = 0
                                    spectlope.sprols[.last].volm = 0
                                }
                                let tone = Tone(spectlope: spectlope)
                                tones[pit.tone.id] = tone
                                note.pits[pi].tone = tone
                            }
                        }
                        nivs.append(.init(value: note, index: ni))
                    }
                    
                    sheetView.newUndoGroup()
                    sheetView.replace(nivs)
                }
                return
            }
            
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
            document.cursor = document.defaultCursor
        }
    }
    func cutFaces(with event: InputKeyEvent) {
        guard isEditingSheet else {
            root.keepOut(with: event)
            return
        }
        if root.isPlaying(with: event) {
            root.stopPlaying(with: event)
        }
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if let sheetView = document.sheetView(at: p), sheetView.model.score.enabled {
                let score = sheetView.scoreView.model
                let nis = document.isSelectNoneCursor(at: p) && !document.isSelectedText ?
                sheetView.noteIndexes(from: document.selections) :
                Array(score.notes.count.range)
                let nnis = nis
                    .filter { !score.notes[$0].isOneOvertone && !score.notes[$0].isFullNoise }
                    .sorted()
                if !nnis.isEmpty {
                    var nivs = [IndexValue<Note>]()
                    for ni in nnis {
                        var note = score.notes[ni]
                        for (pi, pit) in note.pits.enumerated() {
                            if !pit.tone.overtone.isOne && !pit.tone.spectlope.isFullNoise {
                                note.pits[pi].tone = .init()
                            }
                        }
                        nivs.append(.init(value: note, index: ni))
                    }
                    
                    sheetView.newUndoGroup()
                    sheetView.replace(nivs)
                }
                return
            }
            
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
            document.cursor = document.defaultCursor
        }
    }
}

final class ScoreAdder: InputKeyEditor {
    let root: RootEditor, document: Document
    let isEditingSheet: Bool
    
    init(_ root: RootEditor) {
        self.root = root
        document = root.document
        isEditingSheet = document.isEditingSheet
    }
    
    func send(_ event: InputKeyEvent) {
        guard isEditingSheet else {
            root.keepOut(with: event)
            return
        }
        if root.isPlaying(with: event) {
            root.stopPlaying(with: event)
        }
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if let sheetView = document.madeSheetView(at: p) {
                let inP = sheetView.convertFromWorld(p)
                let option = ScoreOption(tempo: sheetView.nearestTempo(at: inP) ?? Music.defaultTempo,
                                         enabled: true)
                
                sheetView.newUndoGroup()
                sheetView.set(option)
                
                root.updateEditorNode()
                document.updateSelects()
            }
        case .changed:
            break
        case .ended:
            document.cursor = document.defaultCursor
        }
    }
}

final class ToneShower: InputKeyEditor {
    let root: RootEditor, document: Document
    let isEditingSheet: Bool
    
    init(_ root: RootEditor) {
        self.root = root
        document = root.document
        isEditingSheet = document.isEditingSheet
    }
    
    func send(_ event: InputKeyEvent) {
        guard isEditingSheet else {
            root.keepOut(with: event)
            return
        }
        if root.isPlaying(with: event) {
            root.stopPlaying(with: event)
        }
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            if let sheetView = document.sheetView(at: p), sheetView.model.score.enabled {
                if document.isSelectSelectedNoneCursor(at: p), !document.isSelectedText {
                    let scoreView = sheetView.scoreView
                    let toneIs = sheetView.noteIndexes(from: document.selections).filter {
                        !scoreView.model.notes[$0].isShownTone
                    }
                    if !toneIs.isEmpty {
                        sheetView.newUndoGroup()
                        sheetView.setIsShownTones(toneIs.map { .init(value: true, index: $0) })
                    }
                } else {
                    let inP = sheetView.scoreView.convertFromWorld(p)
                    if let (noteI, _) = sheetView.scoreView.noteAndPitIEnabledNote(at: inP, scale: document.screenToWorldScale) {
                        
                        let oldToneIs = sheetView.scoreView.model.notes.enumerated().compactMap {
                            $0.element.isShownTone && noteI != $0.offset ? $0.offset : nil
                        }
                        let toneIVs: [IndexValue<Bool>] = oldToneIs.map { .init(value: false, index: $0) }
                        + (!sheetView.scoreView.model.notes[noteI].isShownTone ? [.init(value: true, index: noteI)] : [])
                        if !toneIVs.isEmpty {
                            sheetView.newUndoGroup()
                            sheetView.setIsShownTones(toneIVs)
                        }
                    }
                }
            }
        case .changed:
            break
        case .ended:
            
            document.cursor = document.defaultCursor
        }
    }
}
