// Copyright 2026 Cii
//
// This file is part of Shikisen.
//
// Shikisen is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Shikisen is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Shikisen.  If not, see <http://www.gnu.org/licenses/>.

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
        let p = rootView.convertScreenToWorld(event.screenPoint)
        guard let sheetView = rootView.sheetView(at: p) else { return false }
        let sheetP = sheetView.convertFromWorld(p)
        let timelineP = sheetView.animationView.timelineNode.convertFromWorld(p)
        return sheetView.animationView.containsTimeline(timelineP,
                                                        scale: rootView.screenToWorldScale)
        || sheetView.containsOtherTimeline(sheetP, scale: rootView.screenToWorldScale)
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
    
    private(set) var oldSwipeEvent: SwipeEvent?, swipeAction: SelectTimeAction?
    func swipe(with event: SwipeEvent) {
        textAction.moveEndInputKey()
        if !(dragAction is DrawLineAction || dragAction is DrawStraightLineAction) {
            stopDragEvent()
        }
        switch event.phase {
        case .began:
            stopInputTextEvent()
            updateLastEditedSheetPosition(from: event)
            swipeAction = SelectTimeAction(self)
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
            updateLastEditedSheetPosition(from: event)
            stopInputTextEvent()
            stopInputKeyEvent()
            stopDragEvent()
            let gesture = Gesture(modifier: modifierKeys, .subDrag)
            subDragEventAction = self.dragAction(with: gesture)
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
            updateLastEditedSheetPosition(from: event)
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
    
    private func dragAction(with gesture: Gesture) -> (any DragEventAction) {
        switch gesture {
        case .drawLine: DrawLineAction(self)
        case .drawStraightLine: DrawStraightLineAction(self)
        case .lassoCut: LassoCutAction(self)
        case .selectByRange: SelectByRangeAction(self)
        case .unselectByRange: UnselectByRangeAction(self)
        case .adjustBrightness: AdjustBrightnessAction(self)
        case .adjustTint: AdjustTintAction(self)
        case .selectVersion: SelectVersionAction(self)
        case .move: MoveAction(self)
//        case .moveZ: MoveZAction(self)
        case .keySelectTime: SelectTimeAction(self)
        case .selectByRange: SelectByRangeAction(self)
        case .unselectByRange: UnselectByRangeAction(self)
        default: EmptyDragAction(self)
        }
    }
    private(set) var oldDragEvent: DragEvent?, dragAction: (any DragEventAction)?
    func drag(with event: DragEvent) {
        switch event.phase {
        case .began:
            updateLastEditedSheetPosition(from: event)
            stopInputTextEvent()
            var gesture = Gesture(modifier: modifierKeys, .drag)
            if gesture == .selectByRange && event.isTablet {
                gesture = .drawLine
            }
            if gesture != .selectTime {
                stopInputKeyEvent()
            }
            stopDragEvent()
            stopSubDragEvent()
            dragAction = self.dragAction(with: gesture)
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
    lazy private(set) var textAction: InputTextAction = { InputTextAction(self) } ()
    func inputText(with event: InputTextEvent) {
        switch event.phase {
        case .began:
            updateLastEditedSheetPosition(from: event)
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
    
    private func inputKeyAction(with gesture: Gesture) -> (any InputKeyEventAction)? {
        switch gesture {
        case .undo: UndoAction(self)
        case .redo: RedoAction(self)
        case .cut: CutAction(self)
        case .copy: CopyAction(self)
        case .paste: PasteAction(self)
        case .insert: InsertAction(self)
        case .find: FindAction(self)
        case .changeToDraft: ChangeToDraftAction(self)
        case .cutDraft: CutDraftAction(self)
        case .fillAll: FillAllAction(self)
        case .cutColorsAll: CutColorsAllAction(self)
        case .interpolate: InterpolateAction(self)
        case .disconnect: DisconnectAction(self)
        case .changeToSuperscript: ChangeToSuperscriptAction(self)
        case .changeToSubscript: ChangeToSubscriptAction(self)
        case .changeToVerticalText: ChangeToVerticalTextAction(self)
        case .changeToHorizontalText: ChangeToHorizontalTextAction(self)
        case .addTime: AddTimeAction(self)
        case .addScore: AddScoreAction(self)
        case .lookUp, .keyLookUp: LookUpAction(self)
        case .runOrClose: RunAction(self)
        case .keyPlay: PlayAction(self)
        case .goPrevious: GoPreviousAction(self)
        case .goNext: GoNextAction(self)
        case .changeABC: ChangeLanguageAction(self)
        case .changeAIU: ChangeLanguageAction(self)
        default: gesture.inputKeyType?.isClick ?? false ? nil : EmptyKeyAction(self)
        }
    }
    private(set) var oldInputKeyEvent: InputKeyEvent?
    private(set) var inputKeyAction: (any InputKeyEventAction)?
    func inputKey(with event: InputKeyEvent) {
        switch event.phase {
        case .began:
            updateLastEditedSheetPosition(from: event)
            guard inputKeyAction == nil else { return }
            let gesture = Gesture(modifier: modifierKeys,
                                      event.inputKeyType)
            if rootView.editingTextView != nil
                && gesture != .changeToSuperscript
                && gesture != .changeToSubscript
                && gesture != .changeToHorizontalText
                && gesture != .changeToVerticalText
                && gesture != .cut
                && gesture != .paste
                && gesture != .changeABC && gesture != .changeAIU {
                
                stopInputTextEvent(isEndEdit: gesture != .undo && gesture != .redo)
            }
            if gesture == .runOrClose {
                textAction.moveEndInputKey()
            }
            stopInputKeyEvent()
            stopDragEvent()
            stopSubDragEvent()
            inputKeyAction = self.inputKeyAction(with: gesture)
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
    
    func updateLastEditedSheetPosition(from event: any Event) {
        rootView.updateLastEditedSheetPosition(fromScreen: event.screenPoint)
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
    
    func isPlaying(with event: any Event) -> Bool {
        for (_, v) in rootView.sheetViewValues {
            if v.sheetView?.isPlaying ?? false {
                return true
            }
        }
        return false
    }
    func stopPlaying(with event: any Event) {
        switch event.phase {
        case .began:
            rootView.cursor = .stop
            
            rootView.closeLookingUp()
            
            for (_, v) in rootView.sheetViewValues {
                v.sheetView?.stop()
            }
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
    
    @discardableResult
    func closeAllPanelsAndStop(at p: Point, enabledAlwaysSheet: Bool = true) -> Bool {
        rootView.finding = .init()
        return closeLookingUpAndStop(at: p, enabledAlwaysSheet: enabledAlwaysSheet)
    }
    @discardableResult
    func closeLookingUpAndStop(at p: Point, enabledAlwaysSheet: Bool = true) -> Bool {
        rootView.closeLookingUp()
        if enabledAlwaysSheet {
            for (_, v) in rootView.sheetViewValues {
                if let sheetView = v.sheetView, sheetView.isPlaying {
                    sheetView.stop()
                }
            }
            return true
        } else {
            var isStopCenter = false
            let cSheetView = rootView.sheetView(at: p)
            for (_, v) in rootView.sheetViewValues {
                if let sheetView = v.sheetView, sheetView.isPlaying {
                    sheetView.stop()
                    if sheetView == cSheetView, rootView.isEditingSheet,
                       !sheetView.model.score.enabled {
                        let timelineP = sheetView.animationView.timelineNode
                            .convertFromWorld(p)
                        if !sheetView.animationView.containsTimeline(timelineP,
                                                                     scale: rootView.screenToWorldScale)
                            && !isEditingText(in: sheetView) {
                            isStopCenter = true
                        }
                    }
                }
            }
            return isStopCenter
        }
    }
    func isEditingText(in sheetView: SheetView) -> Bool {
        if let aTextView = textAction.editingTextView,
           !aTextView.isHiddenSelectedRange,
           sheetView.textsView.elementViews.firstIndex(of: aTextView) != nil {
            true
        } else {
            false
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
    func stopSubDragEvent() {
        if var event = oldSubDragEvent, let subDragEventAction {
            event.phase = .ended
            self.subDragEventAction = nil
            oldSubDragEvent = nil
            subDragEventAction.flow(with: event)
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

final class EmptyKeyAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
    }
    
    func flow(with event: InputKeyEvent) {
        switch event.phase {
        case .began:
            rootView.cursor = .ban(string: "Empty Action".localized)
            Feedback.beep()
        case .changed: break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
}
final class EmptyDragAction: DragEventAction {
    let rootAction: RootAction, rootView: RootView
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
    }
    
    func flow(with event: DragEvent) {
        switch event.phase {
        case .began:
            rootView.cursor = .ban(string: "Empty Action".localized)
            Feedback.beep()
        case .changed: break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
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
        
        rootView.updateSelectedNodesWithScale()
        rootView.updateFindingNodes()
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
            cursorTimer = DispatchSource.scheduledTimer(withTimeInterval: 1 / 60.0) { [weak self] in
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
    let action: SelectAction
    
    init(_ rootAction: RootAction) {
        action = SelectAction(rootAction)
    }
    
    func flow(with event: DragEvent) {
        action.select(with: event, isUnselect: false)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class UnselectByRangeAction: DragEventAction {
    let action: SelectAction
    
    init(_ rootAction: RootAction) {
        action = SelectAction(rootAction)
    }
    
    func flow(with event: DragEvent) {
        action.select(with: event, isUnselect: true)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class SelectAction: Action {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private var firstP = Point(), selectKeyframeAction: SelectKeyframeAction?,
                captureSelections = [SheetView: SheetSelection](),
                beganWorldSelection: WorldSelection?, beganTime = 0.0,
                firstSheetView: SheetView?, firstTextI: Int?, firstTextRect: Rect?
    private let node = Node(lineType: .color(.selected), fillType: .color(.subSelected))
    let snappedDistance = 3.5
    
    private var beganEvent: DragEvent?
    func select(with event: DragEvent, isUnselect: Bool) {
        if event.phase == .began {
            beganEvent = event
        }
        if let beganEvent {
            guard event.screenPoint.distance(beganEvent.screenPoint) >= 20
                    || event.time - beganEvent.time >= 0.2 else {
                if event.phase == .ended {
                    rootAction.inputKey(with: .init(screenPoint: event.screenPoint,
                                                    time: event.time,
                                                    pressure: event.pressure,
                                                    phase: .began, isRepeat: false,
                                                    inputKeyType: .click))
                    Sleep.start()
                    rootAction.inputKey(with: .init(screenPoint: event.screenPoint,
                                                    time: event.time,
                                                    pressure: event.pressure,
                                                    phase: .ended, isRepeat: false,
                                                    inputKeyType: .click))
                }
                return
            }
            aSelect(with: beganEvent, isUnselect: isUnselect)
            self.beganEvent = nil
        }
        aSelect(with: event, isUnselect: isUnselect)
    }
    func aSelect(with event: DragEvent, isUnselect: Bool) {
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            if let sheetView = rootView.sheetView(at: p),
               sheetView.animationView.containsTimeline(sheetView.animationView.timelineNode.convertFromWorld(p),
                                                        scale: rootView.screenToWorldScale) {
                
                selectKeyframeAction = .init(rootAction)
                selectKeyframeAction?.select(with: event, isUnselect: isUnselect)
                return
            }
            
            rootView.cursor = .arrow
            rootAction.closeLookingUpAndStop(at: p)
            
            firstP = p
            beganTime = event.time
            
            if !isEditingSheet {
                beganWorldSelection = rootView.world.selection
            } else if let sheetView = rootView.sheetView(at: p) {
                captureSelections[sheetView] = sheetView.model.selection
                
                if let ti = sheetView.textIndex(at: sheetView.convertFromWorld(p),
                                                scale: rootView.screenToWorldScale),
                let rect = sheetView.textsView.elementViews[ti].transformedBounds {
                    firstSheetView = sheetView
                    firstTextI = ti
                    firstTextRect = sheetView.convertToWorld(rect.outset(by: 10))
                    node.isHidden = true
                }
            }
            
            node.lineType = .color(!isUnselect ? .selected : .diselected)
            node.fillType = .color(!isUnselect ? .subSelected : .subDiselected)
            node.lineWidth = rootView.worldLineWidth
            node.path = .init(.init(p, distance: 0))
            rootView.node.append(child: node)
        case .changed:
            if let selectKeyframeAction {
                selectKeyframeAction.select(with: event, isUnselect: isUnselect)
                return
            }
            
            let rect = AABB(firstP, p).rect
            node.path = .init(rect, cornerRadius: min(rect.width / 2, rect.height / 2,
                                                      2 * rootView.screenToWorldScale))
            
            if rootView.isEditingSheet, let sheetView = firstSheetView,
                let ti = firstTextI, ti < sheetView.model.texts.count,
                let selection = captureSelections[sheetView],
               let firstTextRect, firstTextRect.contains(p) {
                
                node.isHidden = true
                let textView = sheetView.textsView.elementViews[ti]
                let oRanges = selection.textSelections[ti]?.ranges ?? []
                let nRect = textView.convertFromWorld(rect)
                var nRanges = oRanges.map { textView.model.string.range(fromInt: $0) }
                guard textView.intersectsHalf(nRect),
                      let fi = textView.characterIndexWithOutOfBounds(for: textView.convertFromWorld(firstP)),
                      let li = textView.characterIndexWithOutOfBounds(for: textView.convertFromWorld(p)) else {
                    let str = textView.model.string
                    var nSelection = selection
                    let nnRanges = nRanges.map { str.intRange(from: $0) }
                    if nnRanges.isEmpty {
                        nSelection.textSelections[ti] = nil
                    } else {
                        nSelection.textSelections[ti] = .init(ranges: nnRanges)
                    }
                    sheetView.selection = selection
                    return
                }
                let range = fi < li ? fi ..< li : li ..< fi
                
                if isUnselect {
                    Range.subtracting(range, in: &nRanges)
                } else {
                    Range.union(range, in: &nRanges)
                }
                let str = textView.model.string
                var nSelection = selection
                let nnRanges = nRanges.map { str.intRange(from: $0) }
                if nnRanges.isEmpty {
                    nSelection.textSelections[ti] = nil
                } else {
                    nSelection.textSelections[ti] = .init(ranges: nnRanges)
                }
                if sheetView.model.selection != nSelection {
                    sheetView.selection = nSelection
                }
            } else if rootView.isEditingSheet {
                node.isHidden = false
                
                for v in rootView.sheetViewValues {
                    guard let sheetView = v.value.sheetView else { continue }
                    guard rootView.sheetFrame(with: v.key).intersects(rect) else {
                        if let selection = captureSelections[sheetView],
                           sheetView.model.selection != selection {
                            sheetView.selection = selection
                        }
                        continue
                    }
                    
                    let selection: SheetSelection
                    if let aSelection = captureSelections[sheetView] {
                        selection = aSelection
                    } else {
                        let aSelection = sheetView.model.selection
                        captureSelections[sheetView] = aSelection
                        selection = aSelection
                    }
                    
                    var nSelection = selection
                    
                    let sheetRect = sheetView.convertFromWorld(rect)
                    
                    let scoreView = sheetView.scoreView
                    if scoreView.model.enabled {
                        let score = sheetView.scoreView.model
                        let scoreP = scoreView.convertFromWorld(firstP)
                        let scoreRect = scoreView.convertFromWorld(rect)
                        
                        let nNotePitSprolIs: [Int : [Int : Set<Int>]]
                        if let noteI = scoreView.noteIInTone(at: scoreP,
                                                             scale: rootView.screenToWorldScale),
                           scoreView.isEditTone(from: score.notes[noteI]) {
                            let note = score.notes[noteI]
                            let toneFrames = scoreView.toneFrames(from: note)
                            let pitSprolIs: [Int : Set<Int>] = toneFrames.reduce(into: .init()) { (v, tf) in
                                tf.pitIs.forEach { pitI in
                                    let pit = note.pits[pitI]
                                    for sprolI in pit.tone.spectlope.sprols.count.range {
                                        if scoreRect.contains(scoreView.sprolPosition(atSprol: sprolI, atPit: pitI, at: noteI, atY: tf.frame.minY)) {
                                            if v[pitI] != nil {
                                                v[pitI]?.insert(sprolI)
                                            } else {
                                                v[pitI] = [sprolI]
                                            }
                                        }
                                    }
                                }
                            }
                            if !pitSprolIs.isEmpty {
                                nNotePitSprolIs = [noteI: pitSprolIs]
                            } else {
                                nNotePitSprolIs = [:]
                            }
                        } else {
                            let noteIs = (0 ..< scoreView.model.notes.count).filter {
                                scoreView.intersectsNote(scoreRect, at: $0)
                            }
                            nNotePitSprolIs = noteIs.reduce(into: .init()) {
                                let note = score.notes[$1]
                                $0[$1] = note.pits.count == 1 ?
                                [0: []] :
                                note.pits.count.range.filter {
                                    scoreRect.contains(scoreView.pitPosition(atPit: $0, from: note))
                                }.reduce(into: .init()) { $0[$1] = [] }
                            }
                        }
                        
                        let oNotePitSprolIs = selection.notePitSprolIs
                        if isUnselect {
                            for (noteI, pitSprols) in nNotePitSprolIs {
                                if pitSprols.isEmpty {
                                    nSelection.noteSelections[noteI] = nil
                                } else {
                                    for (pitI, sprolIs) in pitSprols {
                                        if sprolIs.isEmpty {
                                            nSelection.noteSelections[noteI]?.pitSelections[pitI] = nil
                                            if nSelection.noteSelections[noteI]?.pitSelections.isEmpty ?? false {
                                                
                                                nSelection.noteSelections[noteI] = nil
                                            }
                                        } else {
                                            nSelection.noteSelections[noteI]?
                                                .pitSelections[pitI]?.sprolIs
                                            = oNotePitSprolIs[noteI]?[pitI]?.subtracting(sprolIs) ?? []
                                            if nSelection.noteSelections[noteI]?
                                                .pitSelections[pitI]?.sprolIs.isEmpty ?? false {
                                                nSelection.noteSelections[noteI]?
                                                    .pitSelections[pitI] = nil
                                                if nSelection.noteSelections[noteI]?.pitSelections.isEmpty ?? false {
                                                    nSelection.noteSelections[noteI] = nil
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            nSelection.notePitSprolIs
                            = oNotePitSprolIs.merging(nNotePitSprolIs) { v0, v1 in
                                v1.values.isEmpty ? v1 : v0.merging(v1) { w0, w1 in w0.union(w1) }
                            }
                        }
                    }
                    
                    let ki = sheetView.model.animation.index
                    let oSelectedLineIs = selection.keyframeSelections[ki]?.lineIs ?? []
                    let nSelectedLineIs = sheetView.linesView.elementViews.enumerated().compactMap {
                        $0.element.intersects(sheetRect) ? $0.offset : nil
                    }
                    let selectedLineIs
                    = isUnselect ? oSelectedLineIs.subtracting(nSelectedLineIs) :
                        oSelectedLineIs.union(nSelectedLineIs)
                    
                    let sheetRectPath = Path(sheetRect)
                    let oSelectedPlaneIs = selection.keyframeSelections[ki]?.planeIs ?? []
                    let nSelectedPlaneIs = sheetView.planesView.elementViews.enumerated().compactMap {
                        sheetRectPath.contains($0.element.node.path) ? $0.offset : nil
                    }
                    let selectedPlaneIs = isUnselect ? oSelectedPlaneIs.subtracting(nSelectedPlaneIs) :
                        oSelectedPlaneIs.union(nSelectedPlaneIs)
                    
                    let isSelectedKeyframe = !selectedLineIs.isEmpty || !selectedPlaneIs.isEmpty
                    if isSelectedKeyframe {
                        nSelection.keyframeSelections[ki] = .init(lineIs: selectedLineIs,
                                                                  planeIs: selectedPlaneIs)
                    } else if selection.keyframeSelections[ki] != nil {
                        nSelection.keyframeSelections[ki] = .init()
                    } else {
                        nSelection.keyframeSelections[ki] = nil
                    }
                    
                    let oSelectedContentIs = selection.contentIs
                    let nSelectedContentIs = sheetView.contentsView.elementViews.enumerated().compactMap { (ci, contentView) in
                        if let b = contentView.transformedBounds,
                           sheetRectPath.intersects(b) { ci } else { nil }
                    }
                    nSelection.contentIs = isUnselect ? oSelectedContentIs.subtracting(nSelectedContentIs) :
                        oSelectedContentIs.union(nSelectedContentIs)
                    
                    for (ti, textView) in sheetView.textsView.elementViews.enumerated() {
                        let oRanges = selection.textSelections[ti]?.ranges ?? []
                        let nRect = textView.convertFromWorld(rect)
                        var nRanges = oRanges.map { textView.model.string.range(fromInt: $0) }
                        guard textView.intersectsHalf(nRect),
                              let fi = textView.characterIndexWithOutOfBounds(for: textView.convertFromWorld(firstP)),
                              let li = textView.characterIndexWithOutOfBounds(for: textView.convertFromWorld(p)) else {
                            let str = textView.model.string
                            let nnRanges = nRanges.map { str.intRange(from: $0) }
                            if nnRanges.isEmpty {
                                nSelection.textSelections[ti] = nil
                            } else {
                                nSelection.textSelections[ti] = .init(ranges: nnRanges)
                            }
                            continue
                        }
                        let range = fi < li ? fi ..< li : li ..< fi
                        
                        if isUnselect {
                            Range.subtracting(range, in: &nRanges)
                        } else {
                            Range.union(range, in: &nRanges)
                        }
                        let str = textView.model.string
                        let nnRanges = nRanges.map { str.intRange(from: $0) }
                        if nnRanges.isEmpty {
                            nSelection.textSelections[ti] = nil
                        } else {
                            nSelection.textSelections[ti] = .init(ranges: nnRanges)
                        }
                    }
                    
                    nSelection.lastPosition = sheetView.convertFromWorld(p)
                    
                    if sheetView.model.selection != nSelection {
                        sheetView.selection = nSelection
                    }
                }
            } else if let beganWorldSelection {
                let oSIDs = Set(beganWorldSelection.sheetIDs)
                let nSIDs = rootView.world.sheetIDs.filter {
                    rect.intersects(rootView.sheetFrame(with: $0.key))
                }.map { $0.value }
                rootView.world.selection.sheetIDs
                = (isUnselect ? oSIDs.subtracting(nSIDs) : oSIDs.union(nSIDs)).sorted()
                rootView.world.selection.lastPosition = p
                rootView.updateSelected()
            }
            
        case .ended:
            if let selectKeyframeAction {
                selectKeyframeAction.select(with: event, isUnselect: isUnselect)
                return
            }
            
            node.removeFromParent()
            
            if let beganWorldSelection, beganWorldSelection != rootView.world.selection {
                rootView.newUndoGroup()
                rootView.capture(old: beganWorldSelection)
            }
            for (sheetView, oldSelection) in captureSelections {
                if oldSelection != sheetView.model.selection {
                    sheetView.newUndoGroup()
                    sheetView.capture(old: oldSelection)
                }
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}
final class SelectKeyframeAction: Action {
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
                beganSelectedRootBeat = Rational(0), firstSelection = SheetSelection()
    private var lastRootBeats = [(sec: Double, rootBeat: Rational)](capacity: 128)
    private var minLastSec = 1 / 12.0
    
    private let progressWidth = {
        let text = Text(string: "00.00", size: Font.defaultSize)
        return text.frame?.width ?? 40
    } ()
    
    private func updateSelected(fromRootBeeat nRootBeat: Rational,
                                in animationView: AnimationView, _ sheetView: SheetView,
                                isUnselect: Bool) {
        var nSelection = firstSelection
        let beganRootIndex = animationView.model
            .nearestRootIndex(atRootBeat: beganSelectedRootBeat)
        let ni = animationView.model.rootIndex(atRootBeat: nRootBeat)
        let range = beganRootIndex <= ni ? beganRootIndex ... ni : ni ... beganRootIndex
        for i in range {
            let ki = animationView.model.index(atRoot: i)
            if !isUnselect {
                if nSelection.keyframeSelections[ki] == nil {
                    nSelection.keyframeSelections[ki] = .init()
                }
            } else {
                nSelection.keyframeSelections[ki] = nil
            }
        }
        
        if sheetView.model.selection != nSelection {
            sheetView.selection = nSelection
        }
    }
    
    func select(with event: DragEvent, isUnselect: Bool) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootAction.closeLookingUpAndStop(at: p)
            
            if let sheetView = rootView.sheetView(at: p),
               sheetView.animationView.containsTimeline(sheetView.animationView.timelineNode.convertFromWorld(p),
                                                        scale: rootView.screenToWorldScale) {
                self.sheetView = sheetView
                firstSelection = sheetView.model.selection
                let animationView = sheetView.animationView
                beganRootBeatPosition = sheetView.rootBeatPosition
                
                var rbp = movedBeganRootBeatPosition
                rbp.beat = animationView.beat(atX: sheetView.convertFromWorld(p).x)
                - animationView.model.beatRange.start
                let nRootBeat = animationView.model.rootBeat(at: rbp)
                if animationView.rootBeat != nRootBeat {
                    sheetView.rootBeat = nRootBeat
                    rootAction.updateActionNode()
                    rootView.updateSelectedFrame()
                }
                animationView.shownInterTypeKeyframeIndex = animationView.model.index
                
                movedBeganRootBeatPosition = sheetView.rootBeatPosition
                beganSelectedRootBeat = nRootBeat
                lastRootBeats.append((event.time, beganSelectedRootBeat))
                
                updateSelected(fromRootBeeat: nRootBeat, in: animationView, sheetView,
                               isUnselect: isUnselect)
                
                self.rootView.cursor = self.rootView.cursor(from: sheetView.currentKeyframeString(),
                                                  progress: sheetView.currentTimeProgress(),
                                                  progressWidth: self.progressWidth)
            } else {
                rootView.cursor = rootView.cursor(from: Animation.timeString(fromTime: 0, frameRate: 0))
            }
        case .changed:
            if let sheetView {
                let animationView = sheetView.animationView
                let oldKI = animationView.model.index
                var bp = movedBeganRootBeatPosition
                bp.beat = animationView.beat(atX: sheetView.convertFromWorld(p).x)
                - animationView.model.beatRange.start
                let nRootBeat = animationView.model.rootBeat(at: bp)
                
                if sheetView.rootBeat != nRootBeat {
                    sheetView.rootBeat = nRootBeat
                    rootAction.updateActionNode()
                    rootView.updateSelectedFrame()
                    
                    if oldKI != animationView.model.index {
                        lastRootBeats.append((event.time, nRootBeat))
                        for (i, v) in lastRootBeats.enumerated().reversed() {
                            if event.time - v.sec > minLastSec {
                                if i > 0 {
                                    lastRootBeats.removeFirst(i - 1)
                                }
                                break
                            }
                        }
                        
                        animationView.shownInterTypeKeyframeIndex = animationView.model.index
                        
                        updateSelected(fromRootBeeat: nRootBeat, in: animationView, sheetView,
                                       isUnselect: isUnselect)
                        
                        self.rootView.cursor = self.rootView.cursor(from: sheetView.currentKeyframeString(),
                                                          progress: sheetView.currentTimeProgress(),
                                                          progressWidth: self.progressWidth)
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
                        updateSelected(fromRootBeeat: rootBeat, in: animationView, sheetView,
                                       isUnselect: isUnselect)
                        break
                    }
                }
                
                if firstSelection != sheetView.model.selection {
                    sheetView.newUndoGroup()
                    sheetView.capture(old: firstSelection)
                }
            }
            
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
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootAction.closeLookingUpAndStop(at: p)
            
            var isChanged = false
            if let sheetView = rootView.sheetViewWithSelectedLineOrPlane(at: p) {
                let lis = sheetView.keyframeView.selectedLineIs
                let pis = sheetView.keyframeView.selectedPlaneIs
                if !lis.isEmpty || !pis.isEmpty {
                    sheetView.newUndoGroup()
                    sheetView.unselect()
                    if !lis.isEmpty {
                        let lines = sheetView.model.picture.lines[lis]
                        sheetView.removeLines(at: lis)
                        let li = sheetView.model.draftPicture.lines.count
                        sheetView.insertDraft(lines.enumerated().map {
                            IndexValue(value: $0.element, index: li + $0.offset)
                        })
                    }
                    if !pis.isEmpty {
                        let planes = sheetView.model.picture.planes[pis]
                        sheetView.removePlanes(at: pis)
                        let pi = sheetView.model.draftPicture.planes.count
                        sheetView.insertDraft(planes.enumerated().map {
                            IndexValue(value: $0.element, index: pi + $0.offset)
                        })
                    }
                    rootView.updateSelectedFrame()
                    isChanged = true
                }
            } else if let sheetView = rootView.sheetViewWithSelectedKeyframe(at: p) {
                let kis = sheetView.animationView.selectedIs.sorted()
                
                let insertKLs = kis.compactMap {
                    let lines = sheetView.model.animation.keyframes[$0].picture.lines
                    let oldLines = sheetView.model.animation.keyframes[$0].draftPicture.lines
                    let li = oldLines.count
                    let value = lines.enumerated().map {
                        IndexValue(value: $0.element,
                                   index: li + $0.offset)
                    }
                    return lines.isEmpty ?
                        nil :
                        IndexValue(value: value, index: $0)
                }
                let insertKPs = kis.compactMap {
                    let planes = sheetView.model.animation.keyframes[$0].picture.planes
                    let oldPlanes = sheetView.model.animation.keyframes[$0].draftPicture.planes
                    let pi = oldPlanes.count
                    let value = planes.enumerated().map {
                        IndexValue(value: $0.element,
                                   index: pi + $0.offset)
                    }
                    return planes.isEmpty ?
                        nil :
                        IndexValue(value: value, index: $0)
                }
                let removeKLs = kis.compactMap {
                    let lines = sheetView.model.animation.keyframes[$0].picture.lines
                    return lines.isEmpty ?
                        nil :
                    IndexValue(value: Array(0 ..< lines.count), index: $0)
                }
                let removeKPs = kis.compactMap {
                    let planes = sheetView.model.animation.keyframes[$0].picture.planes
                    return planes.isEmpty ?
                        nil :
                    IndexValue(value: Array(0 ..< planes.count), index: $0)
                }
                if !insertKLs.isEmpty || !insertKPs.isEmpty
                    || !removeKLs.isEmpty || !removeKPs.isEmpty {
                    
                    sheetView.newUndoGroup()
                    sheetView.unselect()
                    if !insertKLs.isEmpty {
                        sheetView.insertDraftKeyLines(insertKLs)
                    }
                    if !insertKPs.isEmpty {
                        sheetView.insertDraftKeyPlanes(insertKPs)
                    }
                    if !removeKLs.isEmpty {
                        sheetView.removeKeyLines(removeKLs)
                    }
                    if !removeKPs.isEmpty {
                        sheetView.removeKeyPlanes(removeKPs)
                    }
                }
            } else if let sheetView = rootView.sheetViewWithSelectedNote(at: p) {
                let nis = sheetView.scoreView.selectedNotePitSprolIs.map { $0.key }.sorted()
                if !nis.isEmpty {
                    sheetView.newUndoGroup()
                    sheetView.unselect()
                    let notes = sheetView.model.score.notes[nis]
                    sheetView.removeNote(at: nis)
                    let ni = sheetView.model.score.draftNotes.count
                    sheetView.insertDraft(notes.enumerated().map {
                        IndexValue(value: $0.element, index: ni + $0.offset)
                    })
                    rootView.updateSelectedFrame()
                    isChanged = true
                }
            } else {
                if let sheetView = rootView.sheetView(at: p) {
                    if sheetView.model.score.enabled {
                        let nis = (0 ..< sheetView.model.score.notes.count).map { $0 }
                        if !nis.isEmpty {
                            sheetView.newUndoGroup()
                            sheetView.unselect()
                            let notes = sheetView.model.score.notes[nis]
                            sheetView.removeNote(at: nis)
                            let ni = sheetView.model.score.draftNotes.count
                            sheetView.insertDraft(notes.enumerated().map {
                                IndexValue(value: $0.element, index: ni + $0.offset)
                            })
                            isChanged = true
                        }
                    } else {
                        if !sheetView.model.picture.isEmpty {
                            if sheetView.model.draftPicture.isEmpty {
                                sheetView.newUndoGroup()
                                sheetView.unselect()
                                sheetView.changeToDraft()
                            } else {
                                sheetView.newUndoGroup()
                                sheetView.unselect()
                                if !sheetView.model.picture.lines.isEmpty {
                                    let li = sheetView.model.draftPicture.lines.count
                                    sheetView.insertDraft(sheetView.model.picture.lines.enumerated().map {
                                        IndexValue(value: $0.element, index: li + $0.offset)
                                    })
                                }
                                if !sheetView.model.picture.planes.isEmpty {
                                    let pi = sheetView.model.draftPicture.planes.count
                                    sheetView.insertDraft(sheetView.model.picture.planes.enumerated().map {
                                        IndexValue(value: $0.element, index: pi + $0.offset)
                                    })
                                }
                                sheetView.set(Picture())
                            }
                            isChanged = true
                        }
                    }
                    rootView.updateSelectedFrame()
                }
            }
            if !isChanged {
                if let sheetView = rootView.sheetView(at: p) {
                    sheetView.unselectAndNewUndoGroupIfNeeded()
                }
                rootView.cursor = .arrowWith(string: "Empty".localized)
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
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootAction.closeLookingUpAndStop(at: p)
            
            var isChanged = false
            if let sheetView = rootView.sheetViewWithSelectedKeyframe(at: p) {
                let kis = sheetView.animationView.selectedIs.sorted()
                
                let kls = kis.compactMap {
                    let lines = sheetView.model.animation.keyframes[$0].draftPicture.lines
                    return lines.isEmpty ?
                    nil :
                    IndexValue(value: Array(0 ..< lines.count), index: $0)
                }
                let kps = kis.compactMap {
                    let planes = sheetView.model.animation.keyframes[$0].draftPicture.planes
                    return planes.isEmpty ?
                        nil :
                    IndexValue(value: Array(0 ..< planes.count), index: $0)
                }
                if !kls.isEmpty || !kps.isEmpty {
                    sheetView.newUndoGroup()
                    if !kls.isEmpty {
                        sheetView.removeDraftKeyLines(kls)
                    }
                    if !kps.isEmpty {
                        sheetView.removeDraftKeyPlanes(kps)
                    }
                    isChanged = true
                }
            } else if let sheetView = rootView.sheetView(at: p) {
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
                        
                        Pasteboard.shared.copiedObjects = [.notesValue(.init(notes: notes,
                                                                             deltaPitch: pitch,
                                                                             isSelected: false))]//
                        
                        isChanged = true
                    }
                } else {
                    let draftPicture = sheetView.model.draftPicture
                    if !draftPicture.isEmpty {
                        sheetView.newUndoGroup()
                        sheetView.removeDraft()
                        Pasteboard.shared.copiedObjects = [.picture(draftPicture)]
                        
                        isChanged = true
                    }
                }
            }
            if !isChanged {
                rootView.cursor = .arrowWith(string: "Empty".localized)
            }
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class FillAllAction: InputKeyEventAction {
    let action: FillAction
    
    init(_ rootAction: RootAction) {
        action = FillAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.fillAll(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class CutColorsAllAction: InputKeyEventAction {
    let action: FillAction
    
    init(_ rootAction: RootAction) {
        action = FillAction(rootAction)
    }
    
    func flow(with event: InputKeyEvent) {
        action.cutColorsAll(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class FillAction: Action {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    func updateNode() {
        node.lineWidth = rootView.screenToWorldScale
    }
    let node = Node(lineWidth: 1, lineType: .color(.selected))
    
    func fillAll(with event: InputKeyEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootAction.closeLookingUpAndStop(at: p)
            
            var isChanged = false
            if let sheetView = rootView.sheetViewWithSelectedSheetValue(at: p),
               let rect = sheetView.selectedFrame(scale: rootView.screenToWorldScale) {
                
                isChanged = sheetView.fillAll(withClipping: rect,
                                                selectedKeyframeIs: [], isOutClip: true)
                rootView.updateSelectedFrame()
            } else if let sheetView = rootView.sheetViewWithSelectedKeyframe(at: p) {
                let kis = sheetView.animationView.selectedIs.sorted()
                isChanged = sheetView.fillAll(withClipping: sheetView.model.mainFrame,
                                                selectedKeyframeIs: kis, isOutClip: false)
                rootView.updateSelectedFrame()
            } else if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled {
                let score = sheetView.scoreView.model
                let scoreP = sheetView.scoreView.convertFromWorld(p)
                let ois = sheetView.scoreView.noteIs(at: scoreP, scale: rootView.screenToWorldScale)
                let nis = ois.isEmpty ? Array(score.notes.count.range) : ois
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
                                    let tone = Tone(spectlope: .random())
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
            } else {
                let (_, sheetView, frame, isAll) = rootView.sheetViewAndFrame(at: p)
                if !isAll {
                    if let pathline = Rect(p, distance: 0).minLine(frame) {
                        node.path = .init([pathline])
                        node.lineWidth = rootView.screenToWorldScale
                        rootView.node.append(child: node)
                    }
                }
                if let sheetView {
                    if isAll {
                        isChanged = sheetView.fillAll(withClipping: nil,
                                                        selectedKeyframeIs: [], isOutClip: false)
                    } else {
                        let f = sheetView.convertFromWorld(frame)
                        isChanged = sheetView.fillAll(withClipping: f,
                                                        selectedKeyframeIs: [], isOutClip: false)
                    }
                    rootView.updateSelectedFrame()
                } else if let sheetView = rootView.madeSheetView(at: p) {
                    isChanged = sheetView.fillAllFromKeyframeIndex(withClipping: nil,
                                                                     isOutClip: false,
                                                                     isNewUndoGroup: true)
                }
            }
            if !isChanged {
                rootView.cursor = .arrowWith(string: "No Update".localized)
                Sleep.start(atTime: 0.2)
            }
        case .changed:
            break
        case .ended:
            node.removeFromParent()
            rootView.cursor = rootView.defaultCursor
        }
    }
    func cutColorsAll(with event: InputKeyEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootAction.closeLookingUpAndStop(at: p)
            
            var isChanged = false
            if let sheetView = rootView.sheetViewWithSelectedPlane(at: p) {
                sheetView.newUndoGroup()
                let planes = sheetView.keyframeView.selectedPlaneIs
                    .map { sheetView.model.picture.planes[$0] }
                let t = Transform(translation: -sheetView.convertFromWorld(p))
                sheetView.unselect()
                sheetView.removePlanes(at: sheetView.keyframeView.selectedPlaneIs)
                let value = SheetValue(lines: [], planes: planes, texts: [], isSelected: true) * t
                Pasteboard.shared.copiedObjects = [.sheetValue(value)]
                rootView.updateSelectedFrame()
                
                isChanged = true
            } else if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled {
                let score = sheetView.scoreView.model
                let scoreP = sheetView.scoreView.convertFromWorld(p)
                let ois = sheetView.scoreView.noteIs(at: scoreP, scale: rootView.screenToWorldScale)
                let nis = ois.isEmpty ? Array(score.notes.count.range) : ois
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
                    sheetView.unselect()
                    sheetView.replace(nivs)
                    rootView.updateSelectedFrame()
                    
                    isChanged = true
                }
            } else if let sheetView = rootView.sheetViewWithSelectedKeyframe(at: p) {
                let vs = sheetView.animationView.selectedIs.sorted().compactMap {
                    let planes = sheetView.model.animation.keyframes[$0].picture.planes
                    return planes.isEmpty ?
                        nil :
                    IndexValue(value: Array(0 ..< planes.count), index: $0)
                }
                if !vs.isEmpty {
                    sheetView.newUndoGroup()
                    sheetView.unselect()
                    sheetView.removeKeyPlanes(vs)
                    rootView.updateSelectedFrame()
                    
                    isChanged = true
                }
            } else if let sheetView = rootView.sheetView(at: p) {
                isChanged = sheetView.cutColorsAll(with: nil)
                rootView.updateSelectedFrame()
            }
            
            if !isChanged {
                if let sheetView = rootView.sheetView(at: p) {
                    sheetView.unselectAndNewUndoGroupIfNeeded()
                }
                rootView.cursor = .arrowWith(string: "Empty".localized)
            }
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class AddTimeAction: InputKeyEventAction {
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
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootAction.closeLookingUpAndStop(at: p)
            
            if let sheetView = rootView.madeSheetView(at: p) {
                let sheetP = sheetView.convertFromWorld(p)
                
                if let ci = sheetView.contentIndex(at: sheetP,
                                                   scale: rootView.screenToWorldScale) {
                   let contentView = sheetView.contentsView.elementViews[ci]
                   if contentView.model.timeOption == nil {
                       var content = contentView.model
                       let startBeat: Rational = sheetView.animationView.beat(atX: content.origin.x)
                       let tempo = sheetView.nearestTempo(at: sheetP) ?? rootView.nearestAroundTempo(at: p)
                       content.timeOption = .init(beatRange: startBeat ..< (4 + startBeat),
                                                  tempo: tempo)
                       
                       sheetView.newUndoGroup()
                       sheetView.unselect()
                       sheetView.replace(IndexValue(value: content, index: ci))
                       
                       sheetView.updatePlaying()
                   } else {
                       rootView.cursor = .arrowWith(string: "Added".localized)
                   }
               } else if let ti = sheetView.textIndex(at: sheetP,
                                                      scale: rootView.screenToWorldScale) {
                   let textView = sheetView.textsView.elementViews[ti]
                   if textView.model.timeOption == nil {
                       var text = textView.model
                       let startBeat: Rational = sheetView.animationView.beat(atX: text.origin.x)
                       let tempo = sheetView.nearestTempo(at: sheetP) ?? rootView.nearestAroundTempo(at: p)
                       text.timeOption = .init(beatRange: startBeat ..< (4 + startBeat),
                                               tempo: tempo)
                       
                       sheetView.newUndoGroup()
                       sheetView.unselect()
                       sheetView.replace([IndexValue(value: text, index: ti)])
                       
                       sheetView.updatePlaying()
                   } else {
                       sheetView.unselectAndNewUndoGroupIfNeeded()
                       rootView.cursor = .arrowWith(string: "Added".localized)
                   }
               } else if !sheetView.model.enabledAnimation {
                   if sheetView.model.score.enabled {
                       sheetView.unselectAndNewUndoGroupIfNeeded()
                       rootView.cursor = .arrowWith(string: "Conflict with Score".localized)
                   } else {
                       sheetView.newUndoGroup(enabledKeyframeIndex: false)
                       sheetView.unselect()
                       sheetView.set(beat: 0, at: 0)
                       var option = sheetView.model.animation.option
                       option.tempo = sheetView.nearestTempo(at: sheetP) ?? rootView.nearestAroundTempo(at: p)
                       option.timelineY = sheetP.y.clipped(min: Sheet.timelineY,
                                                           max: Sheet.height - Sheet.timelineY)
                       option.enabled = true
                       sheetView.set(option)
                       
                       rootAction.updateActionNode()
                   }
               } else {
                   sheetView.unselectAndNewUndoGroupIfNeeded()
                   rootView.cursor = .arrowWith(string: "Added".localized)
               }
            } else {
                rootView.cursor = .ban(string: "Error".localized)
                Feedback.beep()
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
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootAction.closeLookingUpAndStop(at: p)
            
            if let sheetView = rootView.madeSheetView(at: p) {
                if !sheetView.model.score.enabled {
                    if sheetView.model.animation.enabled {
                        sheetView.unselectAndNewUndoGroupIfNeeded()
                        rootView.cursor = .arrowWith(string: "Conflict with Timeline".localized)
                    } else {
                        let sheetP = sheetView.convertFromWorld(p)
                        let tempo = sheetView.nearestTempo(at: sheetP) ?? rootView.nearestAroundTempo(at: p)
                        let option = ScoreOption(tempo: tempo, timelineY: Sheet.timelineY, enabled: true)
                        
                        sheetView.newUndoGroup()
                        sheetView.unselect()
                        sheetView.set(option)
                        
                        rootAction.updateActionNode()
                    }
                } else {
                    sheetView.unselectAndNewUndoGroupIfNeeded()
                    rootView.cursor = .arrowWith(string: "Added".localized)
                }
            } else {
                rootView.cursor = .ban(string: "Error".localized)
                Feedback.beep()
            }
        case .changed:
            break
        case .ended:
            rootView.cursor = rootView.defaultCursor
        }
    }
}

