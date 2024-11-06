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

protocol PinchEventEditor: Editor {
    func send(_ event: PinchEvent)
}
protocol RotateEventEditor: Editor {
    func send(_ event: RotateEvent)
}
protocol ScrollEventEditor: Editor {
    func send(_ event: ScrollEvent)
}
protocol SwipeEventEditor: Editor {
    func send(_ event: SwipeEvent)
}
protocol DragEventEditor: Editor {
    func send(_ event: DragEvent)
}
protocol InputKeyEventEditor: Editor {
    func send(_ event: InputKeyEvent)
}

final class RootEditor: Editor {
    var rootView: RootView
    
    init(_ rootView: RootView) {
        self.rootView = rootView
        
        rootView.updateNodeNotifications.append { [weak self] _ in
            self?.updateEditorNode()
        }
    }
    
    func cancelTasks() {
        runEditors.forEach { $0.cancel() }
        
        textEditor.cancelTasks()
        
        rootView.cancelTasks()
    }
    
    func containsAllTimelines(with event: any Event) -> Bool {
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        guard let sheetView = rootView.sheetView(at: p) else { return false }
        let inP = sheetView.convertFromWorld(p)
        return sheetView.animationView.containsTimeline(inP, scale: rootView.screenToWorldScale)
        || sheetView.containsOtherTimeline(inP, scale: rootView.screenToWorldScale)
    }
    func isPlaying(with event: any Event) -> Bool {
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        if let sheetView = rootView.sheetView(at: p), sheetView.isPlaying {
            return true
        }
        for shp in rootView.aroundSheetPositions(atCenter: rootView.sheetPosition(at: p)) {
            if let sheetView = rootView.sheetView(at: shp), sheetView.isPlaying {
                return true
            }
        }
        return false
    }
    
    var modifierKeys = ModifierKeys()
    
    func indicate(with event: DragEvent) {
        rootView.cursorPoint = event.screenPoint
        textEditor.isMovedCursor = true
        textEditor.moveEndInputKey(isStopFromMarkedText: true)
    }
    
    private(set) var oldPinchEvent: PinchEvent?, zoomEditor: ZoomEditor?
    func pinch(_ event: PinchEvent) {
        switch event.phase {
        case .began:
            zoomEditor = ZoomEditor(self)
            zoomEditor?.send(event)
            oldPinchEvent = event
        case .changed:
            zoomEditor?.send(event)
            oldPinchEvent = event
        case .ended:
            oldPinchEvent = nil
            zoomEditor?.send(event)
            zoomEditor = nil
        }
    }
    
    private(set) var oldScrollEvent: ScrollEvent?, scrollEditor: ScrollEditor?
    func scroll(_ event: ScrollEvent) {
        textEditor.moveEndInputKey()
        switch event.phase {
        case .began:
            scrollEditor = ScrollEditor(self)
            scrollEditor?.send(event)
            oldScrollEvent = event
        case .changed:
            scrollEditor?.send(event)
            oldScrollEvent = event
        case .ended:
            oldScrollEvent = nil
            scrollEditor?.send(event)
            scrollEditor = nil
        }
    }
    
    private(set) var oldSwipeEvent: SwipeEvent?, swipeEditor: SelectFrameEditor?
    func swipe(_ event: SwipeEvent) {
        textEditor.moveEndInputKey()
        switch event.phase {
        case .began:
            swipeEditor = SelectFrameEditor(self)
            swipeEditor?.send(event)
            oldSwipeEvent = event
        case .changed:
            swipeEditor?.send(event)
            oldSwipeEvent = event
        case .ended:
            oldSwipeEvent = nil
            swipeEditor?.send(event)
            swipeEditor = nil
        }
    }
    
    private(set) var oldRotateEvent: RotateEvent?, rotateEditor: RotateEditor?
    func rotate(_ event: RotateEvent) {
        switch event.phase {
        case .began:
            rotateEditor = RotateEditor(self)
            rotateEditor?.send(event)
            oldRotateEvent = event
        case .changed:
            rotateEditor?.send(event)
            oldRotateEvent = event
        case .ended:
            oldRotateEvent = nil
            rotateEditor?.send(event)
            rotateEditor = nil
        }
    }
    
    func strongDrag(_ event: DragEvent) {}
    
    private(set) var oldSubDragEvent: DragEvent?, subDragEventEditor: (any DragEventEditor)?
    func subDrag(_ event: DragEvent) {
        switch event.phase {
        case .began:
            updateLastEditedIntPoint(from: event)
            stopInputTextEvent()
            subDragEventEditor = SelectByRangeEditor(self)
            subDragEventEditor?.send(event)
            oldSubDragEvent = event
            rootView.textCursorNode.isHidden = true
            rootView.textMaxTypelineWidthNode.isHidden = true
        case .changed:
            subDragEventEditor?.send(event)
            oldSubDragEvent = event
        case .ended:
            oldSubDragEvent = nil
            subDragEventEditor?.send(event)
            subDragEventEditor = nil
            rootView.cursorPoint = event.screenPoint
        }
    }
    
    private(set) var oldMiddleDragEvent: DragEvent?, middleDragEventEditor: (any DragEventEditor)?
    func middleDrag(_ event: DragEvent) {
        switch event.phase {
        case .began:
            updateLastEditedIntPoint(from: event)
            stopInputTextEvent()
            middleDragEventEditor = LassoCutEditor(self)
            middleDragEventEditor?.send(event)
            oldMiddleDragEvent = event
            rootView.textCursorNode.isHidden = true
            rootView.textMaxTypelineWidthNode.isHidden = true
        case .changed:
            middleDragEventEditor?.send(event)
            oldMiddleDragEvent = event
        case .ended:
            oldMiddleDragEvent = nil
            middleDragEventEditor?.send(event)
            middleDragEventEditor = nil
            rootView.cursorPoint = event.screenPoint
        }
    }
    
    private func dragEditor(with quasimode: Quasimode) -> (any DragEventEditor)? {
        switch quasimode {
        case .drawLine: DrawLineEditor(self)
        case .drawStraightLine: DrawStraightLineEditor(self)
        case .lassoCut: LassoCutEditor(self)
        case .selectByRange: SelectByRangeEditor(self)
        case .changeLightness: ChangeLightnessEditor(self)
        case .changeTint: ChangeTintEditor(self)
        case .changeOpacity: ChangeOpacityEditor(self)
        case .selectFrame: SelectFrameEditor(self)
        case .selectVersion: SelectVersionEditor(self)
        case .move: MoveEditor(self)
        case .moveLinePoint: MoveLinePointEditor(self)
        case .moveLineZ: MoveLineZEditor(self)
        default: nil
        }
    }
    private(set) var oldDragEvent: DragEvent?, dragEditor: (any DragEventEditor)?
    func drag(_ event: DragEvent) {
        switch event.phase {
        case .began:
            updateLastEditedIntPoint(from: event)
            stopInputTextEvent()
            let quasimode = Quasimode(modifier: modifierKeys, .drag)
            if quasimode != .selectFrame {
                stopInputKeyEvent()
            }
            dragEditor = self.dragEditor(with: quasimode)
            dragEditor?.send(event)
            oldDragEvent = event
            rootView.textCursorNode.isHidden = true
            rootView.textMaxTypelineWidthNode.isHidden = true
            
            rootView.isUpdateWithCursorPosition = false
            rootView.cursorPoint = event.screenPoint
        case .changed:
            dragEditor?.send(event)
            oldDragEvent = event
            
            rootView.cursorPoint = event.screenPoint
        case .ended:
            oldDragEvent = nil
            dragEditor?.send(event)
            dragEditor = nil
            
            rootView.isUpdateWithCursorPosition = true
            rootView.cursorPoint = event.screenPoint
        }
    }
    
    private(set) var oldInputTextKeys = Set<InputKeyType>()
    lazy private(set) var textEditor: TextEditor = { TextEditor(self) } ()
    func inputText(_ event: InputTextEvent) {
        switch event.phase {
        case .began:
            updateLastEditedIntPoint(from: event)
            oldInputTextKeys.insert(event.inputKeyType)
            textEditor.send(event)
        case .changed:
            textEditor.send(event)
        case .ended:
            oldInputTextKeys.remove(event.inputKeyType)
            textEditor.send(event)
        }
    }
    
    var runEditors = Set<RunEditor>() {
        didSet {
            rootView.updateRunEditorNodes(fromWorldPrintOrigins: runEditors.map { $0.worldPrintOrigin })
        }
    }
    
    private func inputKeyEditor(with quasimode: Quasimode) -> (any InputKeyEventEditor)? {
        switch quasimode {
        case .cut: CutEditor(self)
        case .copy, .controlCopy: CopyEditor(self)
        case .copyLineColor: CopyLineColorEditor(self)
        case .paste: PasteEditor(self)
        case .undo: UndoEditor(self)
        case .redo: RedoEditor(self)
        case .find: FindEditor(self)
        case .lookUp: LookUpEditor(self)
        case .changeToVerticalText: ChangeToVerticalTextEditor(self)
        case .changeToHorizontalText: ChangeToHorizontalTextEditor(self)
        case .changeToSuperscript: ChangeToSuperscriptEditor(self)
        case .changeToSubscript: ChangeToSubscriptEditor(self)
        case .run: RunEditor(self)
        case .changeToDraft: ChangeToDraftEditor(self)
        case .cutDraft: CutDraftEditor(self)
        case .makeFaces: MakeFacesEditor(self)
        case .cutFaces: CutFacesEditor(self)
        case .play: PlayEditor(self)
        case .goPrevious: GoPreviousEditor(self)
        case .goNext: GoNextEditor(self)
        case .goPreviousFrame: GoPreviousFrameEditor(self)
        case .goNextFrame: GoNextFrameEditor(self)
        case .insertKeyframe: InsertKeyframeEditor(self)
        case .addScore: AddScoreEditor(self)
        case .interpolate, .controlInterpolate: InterpolateEditor(self)
        case .crossErase: CrossEraseEditor(self)
        case .stop: StopEditor(self)
        default: nil
        }
    }
    private(set) var oldInputKeyEvent: InputKeyEvent?
    private(set) var inputKeyEditor: (any InputKeyEventEditor)?
    func inputKey(_ event: InputKeyEvent) {
        switch event.phase {
        case .began:
            updateLastEditedIntPoint(from: event)
            guard inputKeyEditor == nil else { return }
            let quasimode = Quasimode(modifier: modifierKeys,
                                      event.inputKeyType)
            if rootView.editingTextView != nil
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
    
    func updateLastEditedIntPoint(from event: any Event) {
        rootView.updateLastEditedIntPoint(fromScreen: event.screenPoint)
    }
    
    func keepOut(with event: any Event) {
        switch event.phase {
        case .began:
            rootView.cursor = .block
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
    func stopPlaying(with event: any Event) {
        switch event.phase {
        case .began:
            rootView.cursor = .stop
            
            for (_, v) in rootView.sheetViewValues {
                v.sheetView?.stop()
            }
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
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
        if var event = oldPinchEvent, let zoomEditor {
            event.phase = .ended
            self.zoomEditor = nil
            oldPinchEvent = nil
            zoomEditor.send(event)
        }
    }
    func stopScrollEvent() {
        if var event = oldScrollEvent, let scrollEditor {
            event.phase = .ended
            self.scrollEditor = nil
            oldScrollEvent = nil
            scrollEditor.send(event)
        }
    }
    func stopSwipeEvent() {
        if var event = oldSwipeEvent, let swipeEditor {
            event.phase = .ended
            self.swipeEditor = nil
            oldSwipeEvent = nil
            swipeEditor.send(event)
        }
    }
    func stopDragEvent() {
        if var event = oldDragEvent, let dragEditor {
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
        if var event = oldInputKeyEvent, let inputKeyEditor {
            event.phase = .ended
            self.inputKeyEditor = nil
            oldInputKeyEvent = nil
            inputKeyEditor.send(event)
        }
    }
    func updateEditorNode() {
        zoomEditor?.updateNode()
        scrollEditor?.updateNode()
        swipeEditor?.updateNode()
        dragEditor?.updateNode()
        inputKeyEditor?.updateNode()
    }
}

final class ZoomEditor: PinchEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
    }
    
    let correction = 4.0
    func send(_ event: PinchEvent) {
        guard event.magnification != 0 else { return }
        let oldIsEditingSheet = rootView.isEditingSheet
        
        var transform = rootView.camera.transform
        let p = event.screenPoint * rootView.screenToWorldTransform
        let log2Scale = transform.log2Scale
        let newLog2Scale = (log2Scale - (event.magnification * correction))
            .clipped(min: RootView.minCameraLog2Scale,
                     max: RootView.maxCameraLog2Scale) - log2Scale
        transform.translate(by: -p)
        transform.scale(byLog2Scale: newLog2Scale)
        transform.translate(by: p)
        rootView.camera = RootView.clippedCamera(from: Camera(transform))
        
        if oldIsEditingSheet != rootView.isEditingSheet {
            rootEditor.textEditor.moveEndInputKey()
            rootView.updateTextCursor()
        }
        
        if rootView.selectedNode != nil {
            rootView.updateSelectedNode()
        }
        if !rootView.finding.isEmpty {
            rootView.updateFindingNodes()
        }
    }
}

final class RotateEditor: RotateEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
    }
    
    let correction = .pi / 40.0, clipD = .pi / 8.0
    var isClipped = false
    func send(_ event: RotateEvent) {
        switch event.phase {
        case .began: isClipped = false
        default: break
        }
        guard !isClipped && event.rotationQuantity != 0 else { return }
        var transform = rootView.camera.transform
        let p = event.screenPoint * rootView.screenToWorldTransform
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
        var camera = RootView.clippedCamera(from: Camera(transform))
        if isClipped {
            camera.rotation = 0
            rootView.camera = camera
        } else {
            rootView.camera = camera
        }
        if rootView.camera.rotation != 0 {
            rootView.defaultCursor = Cursor.rotate(rotation: -rootView.camera.rotation + .pi / 2)
            rootView.cursor = rootView.defaultCursor
        } else {
            rootView.defaultCursor = .drawLine
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class ScrollEditor: ScrollEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
    }
    
    enum SnapType {
        case began, none, x, y
    }
    private let correction = 1.0
    private let updateSpeed = 1000.0
    private var isHighSpeed = false, oldTime = 0.0, oldDeltaPoint = Point()
    private var oldSpeedTime = 0.0, oldSpeedDistance = 0.0, oldSpeed = 0.0
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
            if rootView.camera.rotation != 0 {
                dp = dp * Transform(rotation: rootView.camera.rotation)
            }
            
            oldDeltaPoint = event.scrollDeltaPoint
            
            let length = dp.length()
            let lengthDt = length / dt
            
            var transform = rootView.camera.transform
            let newPoint = dp * correction * transform.absXScale
            
            let oldPosition = transform.position
            let newP = RootView.clippedCameraPosition(from: oldPosition - newPoint) - oldPosition
            
            transform.translate(by: newP)
            rootView.camera = Camera(transform)
            
            rootView.isUpdateWithCursorPosition = lengthDt < updateSpeed / 2
            rootView.updateWithCursorPosition()
            if !rootView.isUpdateWithCursorPosition {
                rootView.textCursorNode.isHidden = true
                rootView.textMaxTypelineWidthNode.isHidden = true
            }
            
            oldTime = event.time
        case .ended:
            if !rootView.isUpdateWithCursorPosition {
                rootView.isUpdateWithCursorPosition = true
            }
            break
        }
    }
}

final class SelectByRangeEditor: DragEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
    }
    
    private var firstP = Point(), multiSelectFrameEditor: MultiSelectFrameEditor?
    let snappedDistance = 4.0
    
    func send(_ event: DragEvent) {
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            if let sheetView = rootView.sheetView(at: p),
               sheetView.animationView.containsTimeline(sheetView.convertFromWorld(p),
                                                        scale: rootView.screenToWorldScale) {
                
                multiSelectFrameEditor = .init(rootEditor)
                multiSelectFrameEditor?.send(event)
                return
            }
            
            rootView.cursor = .arrow
            rootView.selections.append(Selection(rect: Rect(Edge(p, p)),
                                             rectCorner: .maxXMinY))
            firstP = p
        case .changed:
            if let multiSelectFrameEditor {
                multiSelectFrameEditor.send(event)
                return
            }
//            guard firstP.distance(p) >= snappedDistance * rootView.screenToWorldScale else {
//                rootView.selections = []
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
            if rootView.selections.isEmpty {
                rootView.selections = [Selection(rect: Rect(Edge(p, p)),
                                                 rectCorner: .maxXMinY)]
            } else {
                rootView.selections[.last] = Selection(rect: Rect(Edge(firstP, p)),
                                                        rectCorner: orientation)
            }
            
        case .ended:
            if let multiSelectFrameEditor {
                multiSelectFrameEditor.send(event)
                return
            }
            rootView.cursor = rootView.defaultCursor
        }
    }
}
final class MultiSelectFrameEditor: DragEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private var sheetView: SheetView?
    private var beganRootBeatPosition = Animation.RootBeatPosition(),
                movedBeganRootBeatPosition = Animation.RootBeatPosition(),
                beganSelectedRootBeat = Rational(0),
                beganSelectedFrameIndexes = [Int]()
    private var lastRootBeats = [(sec: Double, rootBeat: Rational)](capacity: 128)
    private var minLastSec = 1 / 12.0
    
    private func updateSelected(fromRootBeeat nRootBeat: Rational,
                                in animationView: AnimationView) {
        var isSelects = [Bool](repeating: false, count: animationView.model.keyframes.count)
        let beganRootIndex = animationView.model.nearestRootIndex(atRootBeat: beganSelectedRootBeat)
        let ni = animationView.model.nearestRootIndex(atRootBeat: nRootBeat)
        let range = beganRootIndex <= ni ? beganRootIndex ... ni : ni ... beganRootIndex
        for i in range {
            let ki = animationView.model.index(atRoot: i)
            isSelects[ki] = true
        }
        beganSelectedFrameIndexes.forEach { isSelects[$0] = true }
        let fis = isSelects.enumerated().compactMap { $0.element ? $0.offset : nil }
        animationView.selectedFrameIndexes = fis
    }
    
    func send(_ event: DragEvent) {
        guard isEditingSheet else {
            rootEditor.keepOut(with: event)
            return
        }
        if rootEditor.isPlaying(with: event) {
            rootEditor.stopPlaying(with: event)
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            if let sheetView = rootView.sheetView(at: p),
               sheetView.animationView.containsTimeline(sheetView.convertFromWorld(p),
                                                        scale: rootView.screenToWorldScale) {
                self.sheetView = sheetView
                let animationView = sheetView.animationView
                beganRootBeatPosition = sheetView.rootBeatPosition
                
                var rbp = movedBeganRootBeatPosition
                rbp.beat = animationView.beat(atX: sheetView.convertFromWorld(p).x)
                let nRootBeat = animationView.model.rootBeat(at: rbp)
                if animationView.rootBeat != nRootBeat {
                    sheetView.rootBeat = nRootBeat
                    rootEditor.updateEditorNode()
                    rootView.updateSelects()
                }
                animationView.shownInterTypeKeyframeIndex = animationView.model.index
                
                movedBeganRootBeatPosition = sheetView.rootBeatPosition
                beganSelectedFrameIndexes = animationView.selectedFrameIndexes
                beganSelectedRootBeat = nRootBeat
                lastRootBeats.append((event.time, beganSelectedRootBeat))
                var isSelects = [Bool](repeating: false, count: animationView.model.keyframes.count)
                let beganRootIndex = animationView.model.nearestRootIndex(atRootBeat: beganSelectedRootBeat)
                let ni = animationView.model.nearestRootIndex(atRootBeat: nRootBeat)
                let range = beganRootIndex <= ni ? beganRootIndex ... ni : ni ... beganRootIndex
                
                for i in range {
                    let ki = animationView.model.index(atRoot: i)
                    isSelects[ki] = true
                }
                beganSelectedFrameIndexes.forEach { isSelects[$0] = true }
                let fis = isSelects.enumerated().compactMap { $0.element ? $0.offset : nil }
                animationView.selectedFrameIndexes = fis
            }
        case .changed:
            if let sheetView {
                let animationView = sheetView.animationView
                let oldKI = animationView.model.index
                var bp = movedBeganRootBeatPosition
                bp.beat = animationView.beat(atX: sheetView.convertFromWorld(p).x)
                let nRootBeat = animationView.model.rootBeat(at: bp)
                
                if sheetView.rootBeat != nRootBeat {
                    sheetView.rootBeat = nRootBeat
                    rootEditor.updateEditorNode()
                    rootView.updateSelects()
                    
                    lastRootBeats.append((event.time, nRootBeat))
                    for (i, v) in lastRootBeats.enumerated().reversed() {
                        if event.time - v.sec > minLastSec {
                            if i > 0 {
                                lastRootBeats.removeFirst(i - 1)
                            }
                            break
                        }
                    }
                    
                    if oldKI != animationView.model.index {
                        animationView.shownInterTypeKeyframeIndex = animationView.model.index
                        
                        updateSelected(fromRootBeeat: nRootBeat, in: animationView)
                    }
                }
            }
        case .ended:
            if let sheetView {
                let animationView = sheetView.animationView
                animationView.shownInterTypeKeyframeIndex = nil
                
                sheetView.rootBeatPosition = beganRootBeatPosition
                
                for (sec, rootBeat) in lastRootBeats.reversed() {
                    if event.time - sec > minLastSec {
                        let animationView = sheetView.animationView
                        updateSelected(fromRootBeeat: rootBeat, in: animationView)
                        break
                    }
                }
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}
final class UnselectEditor: InputKeyEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
    }
    
    func send(_ event: InputKeyEvent) {
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            rootView.closeLookingUp()
            rootView.selections = []
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class ChangeToDraftEditor: InputKeyEventEditor {
    let editor: DraftEditor
    
    init(_ rootEditor: RootEditor) {
        editor = DraftEditor(rootEditor)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.changeToDraft(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class CutDraftEditor: InputKeyEventEditor {
    let editor: DraftEditor
    
    init(_ rootEditor: RootEditor) {
        editor = DraftEditor(rootEditor)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.cutDraft(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class DraftEditor: Editor {
    let rootEditor: RootEditor, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    func changeToDraft(with event: InputKeyEvent) {
        guard isEditingSheet else {
            rootEditor.keepOut(with: event)
            return
        }
        if rootEditor.isPlaying(with: event) {
            rootEditor.stopPlaying(with: event)
        }
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            if rootView.isSelectNoneCursor(at: p), !rootView.isSelectedText {
                for (shp, _) in rootView.sheetViewValues {
                    let ssFrame = rootView.sheetFrame(with: shp)
                    if rootView.selections.contains(where: { ssFrame.intersects($0.rect) }),
                       let sheetView = rootView.sheetView(at: shp) {
                        
                        if sheetView.model.score.enabled {
                            let nis = sheetView.noteIndexes(from: rootView.selections)
                            if !nis.isEmpty {
                                sheetView.newUndoGroup()
                                sheetView.changeToDraft(withNoteInexes: nis)
                                rootView.updateSelects()
                            }
                        } else {
                            let lis = sheetView.lineIndexes(from: rootView.selections)
                            let pis = sheetView.planeIndexes(from: rootView.selections)
                            if !lis.isEmpty {
                                sheetView.newUndoGroup()
                                sheetView.changeToDraft(withLineInexes: lis,
                                                        planeInexes: pis)
                                rootView.updateSelects()
                            }
                        }
                    }
                }
            } else {
                if let sheetView = rootView.sheetView(at: p) {
                    let inP = sheetView.convertFromWorld(p)
                    if sheetView.model.score.enabled {
                        let nis = (0 ..< sheetView.model.score.notes.count).map { $0 }
                        if !nis.isEmpty {
                            sheetView.newUndoGroup()
                            sheetView.changeToDraft(withNoteInexes: nis)
                            rootView.updateSelects()
                        }
                    } else if sheetView.animationView.containsTimeline(inP, scale: rootView.screenToWorldScale),
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
            rootView.cursor = rootView.defaultCursor
        }
    }
    func cutDraft(with event: InputKeyEvent) {
        guard isEditingSheet else {
            rootEditor.keepOut(with: event)
            return
        }
        if rootEditor.isPlaying(with: event) {
            rootEditor.stopPlaying(with: event)
        }
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            if rootView.isSelectNoneCursor(at: p), !rootView.isSelectedText,
               !rootView.selections.isEmpty {
                
                var value = SheetValue()
                for selection in rootView.selections {
                    for (shp, _) in rootView.sheetViewValues {
                        let ssFrame = rootView.sheetFrame(with: shp)
                        if ssFrame.intersects(selection.rect),
                           let sheetView = rootView.sheetView(at: shp) {
                           
                            if sheetView.model.score.enabled {
                                let nis = sheetView.draftNoteIndexes(from: rootView.selections)
                                if !nis.isEmpty {
                                    let scoreView = sheetView.scoreView
                                    let scoreP = scoreView.convertFromWorld(p)
                                    let pitchInterval = rootView.currentPitchInterval
                                    let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                                    let beatInterval = rootView.currentBeatInterval
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
                rootView.selections = []
            } else {
                if let sheetView = rootView.sheetView(at: p) {
                    let inP = sheetView.convertFromWorld(p)
                    if sheetView.model.score.enabled {
                        let nis = (0 ..< sheetView.model.score.draftNotes.count).map { $0 }
                        if !nis.isEmpty {
                            let scoreView = sheetView.scoreView
                            let scoreP = scoreView.convertFromWorld(p)
                            let pitchInterval = rootView.currentPitchInterval
                            let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                            let beatInterval = rootView.currentBeatInterval
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
                    } else if sheetView.animationView.containsTimeline(inP, scale: rootView.screenToWorldScale),
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
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MakeFacesEditor: InputKeyEventEditor {
    let editor: FaceEditor
    
    init(_ rootEditor: RootEditor) {
        editor = FaceEditor(rootEditor)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.makeFaces(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class CutFacesEditor: InputKeyEventEditor {
    let editor: FaceEditor
    
    init(_ rootEditor: RootEditor) {
        editor = FaceEditor(rootEditor)
    }
    
    func send(_ event: InputKeyEvent) {
        editor.cutFaces(with: event)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class FaceEditor: Editor {
    let rootEditor: RootEditor, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    func makeFaces(with event: InputKeyEvent) {
        guard isEditingSheet else {
            rootEditor.keepOut(with: event)
            return
        }
        if rootEditor.isPlaying(with: event) {
            rootEditor.stopPlaying(with: event)
        }
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled {
                let score = sheetView.scoreView.model
                let nis = rootView.isSelectNoneCursor(at: p) && !rootView.isSelectedText ?
                sheetView.noteIndexes(from: rootView.selections) :
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
                                let tone = Tone(overtone: .init(evenAmp: .random(in: 0 ..< 1)),
                                                spectlope: spectlope)
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
            
            if rootView.isSelectNoneCursor(at: p), !rootView.isSelectedText {
                for (shp, _) in rootView.sheetViewValues {
                    let ssFrame = rootView.sheetFrame(with: shp)
                    if rootView.multiSelection.intersects(ssFrame),
                       let sheetView = rootView.sheetView(at: shp) {
                        
                        let rects = rootView.selections
                            .map { sheetView.convertFromWorld($0.rect) }
                        let path = Path(rects.map { Pathline($0) })
                        sheetView.makeFaces(with: path, isSelection: true)
                    }
                }
            } else {
                let (_, sheetView, frame, isAll) = rootView.sheetViewAndFrame(at: p)
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
            rootView.cursor = rootView.defaultCursor
        }
    }
    func cutFaces(with event: InputKeyEvent) {
        guard isEditingSheet else {
            rootEditor.keepOut(with: event)
            return
        }
        if rootEditor.isPlaying(with: event) {
            rootEditor.stopPlaying(with: event)
        }
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled {
                let score = sheetView.scoreView.model
                let nis = rootView.isSelectNoneCursor(at: p) && !rootView.isSelectedText ?
                sheetView.noteIndexes(from: rootView.selections) :
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
            
            if rootView.isSelectNoneCursor(at: p), !rootView.isSelectedText {
                var value = SheetValue()
                for (shp, _) in rootView.sheetViewValues {
                    let ssFrame = rootView.sheetFrame(with: shp)
                    if rootView.multiSelection.intersects(ssFrame),
                       let sheetView = rootView.sheetView(at: shp) {
                        
                        let rects = rootView.selections
                            .map { sheetView.convertFromWorld($0.rect).inset(by: 1) }
                        let path = Path(rects.map { Pathline($0) })
                        if let v = sheetView.removeFilledFaces(with: path, at: p) {
                            value += v
                        }
                    }
                }
                Pasteboard.shared.copiedObjects = [.sheetValue(value)]
                
                rootView.selections = []
            } else {
                let (_, sheetView, frame, isAll) = rootView.sheetViewAndFrame(at: p)
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
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class AddScoreEditor: InputKeyEventEditor {
    let rootEditor: RootEditor, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootEditor: RootEditor) {
        self.rootEditor = rootEditor
        rootView = rootEditor.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    func send(_ event: InputKeyEvent) {
        guard isEditingSheet else {
            rootEditor.keepOut(with: event)
            return
        }
        if rootEditor.isPlaying(with: event) {
            rootEditor.stopPlaying(with: event)
        }
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            if let sheetView = rootView.madeSheetView(at: p) {
                let inP = sheetView.convertFromWorld(p)
                let option = ScoreOption(tempo: sheetView.nearestTempo(at: inP) ?? Music.defaultTempo,
                                         enabled: true)
                
                sheetView.newUndoGroup()
                sheetView.set(option)
                
                rootEditor.updateEditorNode()
                rootView.updateSelects()
            }
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
}
