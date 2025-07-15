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
import Dispatch

@MainActor protocol Action {
    func updateNode()
}
extension Action {
    func updateNode() {}
}

protocol PinchEventAction: Action {
    func flow(with event: PinchEvent)
}
protocol RotateEventAction: Action {
    func flow(with event: RotateEvent)
}
protocol ScrollEventAction: Action {
    func flow(with event: ScrollEvent)
}
protocol SwipeEventAction: Action {
    func flow(with event: SwipeEvent)
}
protocol DragEventAction: Action {
    func flow(with event: DragEvent)
}
protocol InputKeyEventAction: Action {
    func flow(with event: InputKeyEvent)
}
protocol InputTextEventAction: Action {
    func flow(with event: InputTextEvent)
}

final class RootAction: Action {
    var rootView: RootView
    
    init(_ rootView: RootView) {
        self.rootView = rootView
        
        rootView.updateNodeNotifications.append { [weak self] _ in
            self?.updateActionNode()
        }
    }
    
    func cancelTasks() {
        runActions.forEach { $0.cancel() }
        
        textAction.cancelTasks()
        
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
        for (_, v) in rootView.sheetViewValues {
            if v.sheetView?.isPlaying ?? false {
                return true
            }
        }
        return false
    }
    
    var modifierKeys = ModifierKeys()
    
    func indicate(with event: DragEvent) {
        if !rootView.isUpdateWithCursorPosition {
            rootView.isUpdateWithCursorPosition = true
        }
        rootView.cursorPoint = event.screenPoint
        textAction.isMovedCursor = true
        textAction.moveEndInputKey(isStopFromMarkedText: true)
    }
    
    private(set) var oldPinchEvent: PinchEvent?, zoomAction: ZoomAction?
    func pinch(with event: PinchEvent) {
        switch event.phase {
        case .began:
            zoomAction = ZoomAction(self)
            zoomAction?.flow(with: event)
            oldPinchEvent = event
        case .changed:
            zoomAction?.flow(with: event)
            oldPinchEvent = event
        case .ended:
            oldPinchEvent = nil
            zoomAction?.flow(with: event)
            zoomAction = nil
        }
    }
    
    private(set) var oldScrollEvent: ScrollEvent?, scrollAction: ScrollAction?
    func scroll(with event: ScrollEvent) {
        textAction.moveEndInputKey()
        switch event.phase {
        case .began:
            scrollAction = ScrollAction(self)
            scrollAction?.flow(with: event)
            oldScrollEvent = event
        case .changed:
            scrollAction?.flow(with: event)
            oldScrollEvent = event
        case .ended:
            oldScrollEvent = nil
            scrollAction?.flow(with: event)
            scrollAction = nil
        }
    }
    
    private(set) var oldSwipeEvent: SwipeEvent?, swipeAction: SelectFrameAction?
    func swipe(with event: SwipeEvent) {
        textAction.moveEndInputKey()
        switch event.phase {
        case .began:
            stopDragEvent()
            stopInputTextEvent()
            updateLastEditedIntPoint(from: event)
            swipeAction = SelectFrameAction(self)
            swipeAction?.flow(with: event)
            oldSwipeEvent = event
        case .changed:
            swipeAction?.flow(with: event)
            oldSwipeEvent = event
        case .ended:
            oldSwipeEvent = nil
            swipeAction?.flow(with: event)
            swipeAction = nil
        }
    }
    
    private(set) var oldRotateEvent: RotateEvent?, rotateAction: RotateAction?
    func rotate(with event: RotateEvent) {
        switch event.phase {
        case .began:
            rotateAction = RotateAction(self)
            rotateAction?.flow(with: event)
            oldRotateEvent = event
        case .changed:
            rotateAction?.flow(with: event)
            oldRotateEvent = event
        case .ended:
            oldRotateEvent = nil
            rotateAction?.flow(with: event)
            rotateAction = nil
        }
    }
    
    func strongDrag(with event: DragEvent) {}
    
    private(set) var oldSubDragEvent: DragEvent?, subDragEventAction: (any DragEventAction)?
    func subDrag(with event: DragEvent) {
        switch event.phase {
        case .began:
            updateLastEditedIntPoint(from: event)
            stopInputTextEvent()
            subDragEventAction = SelectByRangeAction(self)
            subDragEventAction?.flow(with: event)
            oldSubDragEvent = event
            rootView.textCursorNode.isHidden = true
            rootView.textMaxTypelineWidthNode.isHidden = true
        case .changed:
            subDragEventAction?.flow(with: event)
            oldSubDragEvent = event
        case .ended:
            oldSubDragEvent = nil
            subDragEventAction?.flow(with: event)
            subDragEventAction = nil
            rootView.cursorPoint = event.screenPoint
        }
    }
    
    private(set) var oldMiddleDragEvent: DragEvent?, middleDragEventAction: (any DragEventAction)?
    func middleDrag(with event: DragEvent) {
        switch event.phase {
        case .began:
            updateLastEditedIntPoint(from: event)
            stopInputTextEvent()
            middleDragEventAction = LassoCutAction(self)
            middleDragEventAction?.flow(with: event)
            oldMiddleDragEvent = event
            rootView.textCursorNode.isHidden = true
            rootView.textMaxTypelineWidthNode.isHidden = true
        case .changed:
            middleDragEventAction?.flow(with: event)
            oldMiddleDragEvent = event
        case .ended:
            oldMiddleDragEvent = nil
            middleDragEventAction?.flow(with: event)
            middleDragEventAction = nil
            rootView.cursorPoint = event.screenPoint
        }
    }
    
    private func dragAction(with quasimode: Quasimode) -> (any DragEventAction)? {
        switch quasimode {
        case .drawLine: DrawLineAction(self)
        case .drawStraightLine: DrawStraightLineAction(self)
        case .lassoCut: LassoCutAction(self)
        case .selectByRange: SelectByRangeAction(self)
        case .changeLightness: ChangeLightnessAction(self)
        case .changeTint: ChangeTintAction(self)
        case .changeOpacity: ChangeOpacityAction(self)
        case .keySelectFrame: SelectFrameAction(self)
        case .selectVersion: SelectVersionAction(self)
        case .move: MoveAction(self)
        case .moveLineZ: MoveLineZAction(self)
        default: nil
        }
    }
    private(set) var oldDragEvent: DragEvent?, dragAction: (any DragEventAction)?
    func drag(with event: DragEvent) {
        switch event.phase {
        case .began:
            updateLastEditedIntPoint(from: event)
            stopInputTextEvent()
            let quasimode = Quasimode(modifier: modifierKeys, .drag)
            if quasimode != .selectFrame {
                stopInputKeyEvent()
            }
            dragAction = self.dragAction(with: quasimode)
            dragAction?.flow(with: event)
            oldDragEvent = event
            rootView.textCursorNode.isHidden = true
            rootView.textMaxTypelineWidthNode.isHidden = true
            
            rootView.isUpdateWithCursorPosition = false
            rootView.cursorPoint = event.screenPoint
        case .changed:
            dragAction?.flow(with: event)
            oldDragEvent = event
            
            rootView.cursorPoint = event.screenPoint
        case .ended:
            oldDragEvent = nil
            dragAction?.flow(with: event)
            dragAction = nil
            
            rootView.isUpdateWithCursorPosition = true
            rootView.cursorPoint = event.screenPoint
        }
    }
    
    private(set) var oldInputTextKeys = Set<InputKeyType>()
    lazy private(set) var textAction: TextAction = { TextAction(self) } ()
    func inputText(with event: InputTextEvent) {
        switch event.phase {
        case .began:
            updateLastEditedIntPoint(from: event)
            oldInputTextKeys.insert(event.inputKeyType)
            textAction.flow(with: event)
        case .changed:
            textAction.flow(with: event)
        case .ended:
            oldInputTextKeys.remove(event.inputKeyType)
            textAction.flow(with: event)
        }
    }
    
    var runActions = Set<RunAction>() {
        didSet {
            rootView.updateRunningNodes(fromWorldPrintOrigins: runActions.map { $0.worldPrintOrigin })
        }
    }
    
    private func inputKeyAction(with quasimode: Quasimode) -> (any InputKeyEventAction)? {
        switch quasimode {
        case .cut: CutAction(self)
        case .copy, .controlCopy: CopyAction(self)
        case .copyLineColor: CopyLineColorAction(self)
        case .paste: PasteAction(self)
        case .undo: UndoAction(self)
        case .redo: RedoAction(self)
        case .find: FindAction(self)
        case .lookUp, .keyLookUp: LookUpAction(self)
        case .changeToVerticalText: ChangeToVerticalTextAction(self)
        case .changeToHorizontalText: ChangeToHorizontalTextAction(self)
        case .changeToSuperscript: ChangeToSuperscriptAction(self)
        case .changeToSubscript: ChangeToSubscriptAction(self)
        case .runOrClose: RunAction(self)
        case .changeToDraft: ChangeToDraftAction(self)
        case .cutDraft: CutDraftAction(self)
        case .makeFaces: MakeFacesAction(self)
        case .cutFaces: CutFacesAction(self)
        case .controlPlay: PlayAction(self)
        case .goPrevious: GoPreviousAction(self)
        case .goNext: GoNextAction(self)
        case .goPreviousFrame: GoPreviousFrameAction(self)
        case .goNextFrame: GoNextFrameAction(self)
        case .insertKeyframe: InsertKeyframeAction(self)
        case .addScore: AddScoreAction(self)
        case .interpolate, .controlInterpolate: InterpolateAction(self)
        case .disconnect: DisconnectAction(self)
        case .stop: StopAction(self)
        default: nil
        }
    }
    private(set) var oldInputKeyEvent: InputKeyEvent?
    private(set) var inputKeyAction: (any InputKeyEventAction)?
    func inputKey(with event: InputKeyEvent) {
        switch event.phase {
        case .began:
            updateLastEditedIntPoint(from: event)
            guard inputKeyAction == nil else { return }
            let quasimode = Quasimode(modifier: modifierKeys,
                                      event.inputKeyType)
            if rootView.editingTextView != nil
                && quasimode != .changeToSuperscript
                && quasimode != .changeToSubscript
                && quasimode != .changeToHorizontalText
                && quasimode != .changeToVerticalText
                && quasimode != .paste {
                
                stopInputTextEvent(isEndEdit: quasimode != .undo && quasimode != .redo)
            }
            if quasimode == .runOrClose {
                textAction.moveEndInputKey()
            }
            stopDragEvent()
            inputKeyAction = self.inputKeyAction(with: quasimode)
            inputKeyAction?.flow(with: event)
            oldInputKeyEvent = event
        case .changed:
            inputKeyAction?.flow(with: event)
            oldInputKeyEvent = event
        case .ended:
            oldInputKeyEvent = nil
            inputKeyAction?.flow(with: event)
            inputKeyAction = nil
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
            textAction.moveEndInputKey()
        }
        modifierKeys = []
    }
    func stopPinchEvent() {
        if var event = oldPinchEvent, let zoomAction {
            event.phase = .ended
            self.zoomAction = nil
            oldPinchEvent = nil
            zoomAction.flow(with: event)
        }
    }
    func stopScrollEvent() {
        if var event = oldScrollEvent, let scrollAction {
            event.phase = .ended
            self.scrollAction = nil
            oldScrollEvent = nil
            scrollAction.flow(with: event)
        }
    }
    func stopSwipeEvent() {
        if var event = oldSwipeEvent, let swipeAction {
            event.phase = .ended
            self.swipeAction = nil
            oldSwipeEvent = nil
            swipeAction.flow(with: event)
        }
    }
    func stopDragEvent() {
        if var event = oldDragEvent, let dragAction {
            event.phase = .ended
            self.dragAction = nil
            oldDragEvent = nil
            dragAction.flow(with: event)
        }
    }
    func stopInputTextEvent(isEndEdit: Bool = true) {
        oldInputTextKeys.removeAll()
        textAction.stopInputKey(isEndEdit: isEndEdit)
    }
    func stopInputKeyEvent() {
        if var event = oldInputKeyEvent, let inputKeyAction {
            event.phase = .ended
            self.inputKeyAction = nil
            oldInputKeyEvent = nil
            inputKeyAction.flow(with: event)
        }
    }
    func updateActionNode() {
        zoomAction?.updateNode()
        scrollAction?.updateNode()
        swipeAction?.updateNode()
        dragAction?.updateNode()
        inputKeyAction?.updateNode()
    }
}

final class ZoomAction: PinchEventAction {
    let rootAction: RootAction, rootView: RootView
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
    }
    
    let correction = 3.25
    func flow(with event: PinchEvent) {
        guard event.magnification != 0 else { return }
        let oldIsEditingSheet = rootView.isEditingSheet
        
        var transform = rootView.pov.transform
        let p = event.screenPoint * rootView.screenToWorldTransform
        let log2Scale = transform.log2Scale
        let newLog2Scale = (log2Scale - (event.magnification * correction))
            .clipped(min: RootView.minPOVLog2Scale,
                     max: RootView.maxPOVLog2Scale) - log2Scale
        transform.translate(by: -p)
        transform.scale(byLog2Scale: newLog2Scale)
        transform.translate(by: p)
        rootView.pov = RootView.clippedPOV(from: .init(transform))
        
        if oldIsEditingSheet != rootView.isEditingSheet {
            rootAction.textAction.moveEndInputKey()
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

final class RotateAction: RotateEventAction {
    let rootAction: RootAction, rootView: RootView
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
    }
    
    private var cursorTimer: (any DispatchSourceTimer)?
    private var oldRotation = 0.0
    
    let correction = .pi / 50.0, clipD = .pi / 8.0
    var isClipped = false, worldCenterP = Point()
    func flow(with event: RotateEvent) {
        switch event.phase {
        case .began:
            isClipped = false
            worldCenterP = event.screenPoint * rootView.screenToWorldTransform
            oldRotation = rootView.pov.rotation
        default: break
        }
        
        if !isClipped && event.rotationQuantity != 0 {
            var transform = rootView.pov.transform
            let p = worldCenterP
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
            var pov = RootView.clippedPOV(from: .init(transform))
            if isClipped {
                pov.rotation = 0
                rootView.pov = pov
            } else {
                rootView.pov = pov
            }
        }
        
        switch event.phase {
        case .began:
            cursorTimer = DispatchSource.scheduledTimer(withTimeInterval: 1 / 60) { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard let self, !(self.cursorTimer?.isCancelled ?? true) else { return }
                    let rootView = self.rootView
                    guard rootView.pov.rotation != self.oldRotation else { return }
                    self.oldRotation = rootView.pov.rotation
                    if rootView.pov.rotation != 0 {
                        rootView.defaultCursor = Cursor.rotate(rotation: -rootView.pov.rotation + .pi / 2)
                        rootView.cursor = rootView.defaultCursor
                    } else {
                        rootView.defaultCursor = .drawLine
                        rootView.cursor = rootView.defaultCursor
                    }
                }
            }
        case .changed: break
        case .ended:
            cursorTimer?.cancel()
            
            if rootView.pov.rotation != 0 {
                rootView.defaultCursor = Cursor.rotate(rotation: -rootView.pov.rotation + .pi / 2)
                rootView.cursor = rootView.defaultCursor
            } else {
                rootView.defaultCursor = .drawLine
                rootView.cursor = rootView.defaultCursor
            }
        }
    }
}

final class ScrollAction: ScrollEventAction {
    let rootAction: RootAction, rootView: RootView
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
    }
    
    enum SnapType {
        case began, none, x, y
    }
    private let correction = 1.0
    private let updateSpeed = 1000.0
    private var isHighSpeed = false, oldTime = 0.0, oldDeltaPoint = Point()
    private var oldSpeedTime = 0.0, oldSpeedDistance = 0.0, oldSpeed = 0.0
    func flow(with event: ScrollEvent) {
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
            if rootView.pov.rotation != 0 {
                dp = dp * Transform(rotation: rootView.pov.rotation)
            }
            
            oldDeltaPoint = event.scrollDeltaPoint
            
            let length = dp.length()
            let lengthDt = length / dt
            
            var transform = rootView.pov.transform
            let newPoint = dp * correction * transform.absXScale
            
            let oldPosition = transform.position
            let newP = RootView.clippedPOVPosition(from: oldPosition - newPoint) - oldPosition
            
            transform.translate(by: newP)
            rootView.pov = .init(transform)
            
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
                rootView.updateWithCursorPosition()
            }
            break
        }
    }
}

final class SelectByRangeAction: DragEventAction {
    let rootAction: RootAction, rootView: RootView
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
    }
    
    private var firstP = Point(), multiSelectFrameAction: MultiSelectFrameAction?
    let snappedDistance = 3.5
    
    func flow(with event: DragEvent) {
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            if let sheetView = rootView.sheetView(at: p),
               sheetView.animationView.containsTimeline(sheetView.convertFromWorld(p),
                                                        scale: rootView.screenToWorldScale) {
                
                multiSelectFrameAction = .init(rootAction)
                multiSelectFrameAction?.flow(with: event)
                return
            }
            
            rootView.cursor = .arrow
            rootView.selections.append(Selection(rect: Rect(Edge(p, p)),
                                             rectCorner: .maxXMinY))
            firstP = p
        case .changed:
            if let multiSelectFrameAction {
                multiSelectFrameAction.flow(with: event)
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
            if let multiSelectFrameAction {
                multiSelectFrameAction.flow(with: event)
                return
            }
            rootView.cursor = rootView.defaultCursor
        }
    }
}
final class MultiSelectFrameAction: DragEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
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
    
    func flow(with event: DragEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        if rootAction.isPlaying(with: event) {
            rootAction.stopPlaying(with: event)
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
                    rootAction.updateActionNode()
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
                    rootAction.updateActionNode()
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
final class UnselectAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
    }
    
    func flow(with event: InputKeyEvent) {
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

final class ChangeToDraftAction: InputKeyEventAction {
    let action: DraftAction
    
    init(_ rootAction: RootAction) {
        action = DraftAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.changeToDraft(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class CutDraftAction: InputKeyEventAction {
    let action: DraftAction
    
    init(_ rootAction: RootAction) {
        action = DraftAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.cutDraft(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class DraftAction: Action {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    func changeToDraft(with event: InputKeyEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        if rootAction.isPlaying(with: event) {
            rootAction.stopPlaying(with: event)
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
                        let nis = if let i = sheetView.scoreView.noteIndex(at: sheetView.scoreView.convertFromWorld(p), scale: rootView.screenToWorldScale) {
                            [i]
                        } else {
                            (0 ..< sheetView.model.score.notes.count).map { $0 }
                        }
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
            rootAction.keepOut(with: event)
            return
        }
        if rootAction.isPlaying(with: event) {
            rootAction.stopPlaying(with: event)
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
                                let nis = if let i = sheetView.scoreView.noteIndex(at: sheetView.scoreView.convertFromWorld(p), scale: rootView.screenToWorldScale) {
                                    [i]
                                } else {
                                    sheetView.draftNoteIndexes(from: rootView.selections)
                                }
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
                                    
                                    Pasteboard.shared.copiedObjects = [.notesValue(.init(notes: notes, deltaPitch: pitch))]//
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
                            
                            Pasteboard.shared.copiedObjects = [.notesValue(.init(notes: notes, deltaPitch: pitch))]//
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

final class MakeFacesAction: InputKeyEventAction {
    let action: FaceAction
    
    init(_ rootAction: RootAction) {
        action = FaceAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.makeFaces(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class CutFacesAction: InputKeyEventAction {
    let action: FaceAction
    
    init(_ rootAction: RootAction) {
        action = FaceAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.cutFaces(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class FaceAction: Action {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    func makeFaces(with event: InputKeyEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        if rootAction.isPlaying(with: event) {
            rootAction.stopPlaying(with: event)
        }
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled {
                let score = sheetView.scoreView.model
                let nis = if rootView.isSelectNoneCursor(at: p) && !rootView.isSelectedText {
                    sheetView.noteIndexes(from: rootView.selections)
                } else if let i = sheetView.scoreView.noteIndex(at: sheetView.scoreView.convertFromWorld(p), scale: rootView.screenToWorldScale) {
                    [i]
                } else {
                    Array(score.notes.count.range)
                }
                let nnis = nis.filter { score.notes[$0].isDefaultTone }.sorted()
                if !nnis.isEmpty {
                    var tones = [UUID: Tone]()
                    var nivs = [IndexValue<Note>]()
                    for ni in nnis {
                        var note = score.notes[ni]
                        if note.isSimpleLyric {
                            note = note.withRendable(tempo: score.tempo)
                        } else {
                            for (pi, pit) in note.pits.enumerated() {
                                if let tone = tones[pit.tone.id] {
                                    note.pits[pi].tone = tone
                                } else if pit.tone.isDefault {
                                    let pitch = Double(pit.pitch + note.pitch)
                                    let tone = Tone(spectlope: .random(pitch: pitch))
                                    tones[pit.tone.id] = tone
                                    note.pits[pi].tone = tone
                                }
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
            rootAction.keepOut(with: event)
            return
        }
        if rootAction.isPlaying(with: event) {
            rootAction.stopPlaying(with: event)
        }
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled {
                let score = sheetView.scoreView.model
                let nis = if rootView.isSelectNoneCursor(at: p) && !rootView.isSelectedText {
                    sheetView.noteIndexes(from: rootView.selections)
                } else if let i = sheetView.scoreView.noteIndex(at: sheetView.scoreView.convertFromWorld(p), scale: rootView.screenToWorldScale) {
                    [i]
                } else {
                    Array(score.notes.count.range)
                }
                let nnis = nis
                    .filter { !score.notes[$0].isOneOvertone && !score.notes[$0].isFullNoise }
                    .sorted()
                if !nnis.isEmpty {
                    var nivs = [IndexValue<Note>]()
                    for ni in nnis {
                        var note = score.notes[ni]
                        if note.isRendableFromLyric {
                            note = note.withSimpleLyric
                        } else {
                            for (pi, pit) in note.pits.enumerated() {
                                if !pit.tone.overtone.isOne && !pit.tone.spectlope.isFullNoise {
                                    note.pits[pi].tone = .init()
                                }
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

final class AddScoreAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    func flow(with event: InputKeyEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        if rootAction.isPlaying(with: event) {
            rootAction.stopPlaying(with: event)
        }
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            if let sheetView = rootView.madeSheetView(at: p) {
                let inP = sheetView.convertFromWorld(p)
                let ph = Sheet.pitchHeight * .init(Score.pitchRange.length)
                + Sheet.isShownSpectrogramHeight
                let option = ScoreOption(tempo: sheetView.nearestTempo(at: inP) ?? Music.defaultTempo,
                                         timelineY: inP.y.clipped(min: Sheet.timelineY,
                                                                  max: Sheet.height - Sheet.timelineY - ph),
                                         enabled: true)
                
                sheetView.newUndoGroup()
                sheetView.set(option)
                
                rootAction.updateActionNode()
                rootView.updateSelects()
            }
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
}
