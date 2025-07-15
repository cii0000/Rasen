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
import struct Foundation.URL
import struct Foundation.Data
import Dispatch

final class GoPreviousAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private var sheetView: SheetView?, contentIndex: Int?
    private var contentView: SheetContentView? {
        guard let sheetView, let contentIndex,
              contentIndex < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentIndex]
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
            sheetView = rootView.sheetView(at: p)
            if let sheetView {
                if let contentIndex = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                             scale: rootView.screenToWorldScale),
                   sheetView.contentsView.elementViews[contentIndex].model.type == .movie {
                    self.contentIndex = contentIndex
                    contentView?.movePreviousInterKeyframe()
                }
                
                if contentIndex == nil {
                    move(from: sheetView, at: p)
                    sheetView.showOtherTimeNodeFromMainBeat()
                    sheetView.animationView.shownInterTypeKeyframeIndex = sheetView.animationView.model.index
                }
            }
            
            rootView.cursor = rootView.cursor(from: contentView?.currentTimeString(isInter: true)
                                              ?? sheetView?.currentKeyframeString()
                                              ?? Animation.timeString(fromTime: 0, frameRate: 0))
        case .changed:
            if event.isRepeat, let sheetView {
                if let contentView {
                    contentView.movePreviousInterKeyframe()
                    sheetView.showOtherTimeNodeFromMainBeat()
                    
                    rootView.cursor = .circle(string: contentView.currentTimeString(isInter: true))
                } else {
                    move(from: sheetView, at: p)
                    sheetView.showOtherTimeNodeFromMainBeat()
                    sheetView.animationView.shownInterTypeKeyframeIndex = sheetView.animationView.model.index
                    
                    rootView.cursor = .circle(string: sheetView.currentKeyframeString())
                }
            }
        case .ended:
            if let sheetView {
                sheetView.hideOtherTimeNode()
                sheetView.animationView.shownInterTypeKeyframeIndex = nil
            }
            sheetView?.hideOtherTimeNode()
            
            rootView.cursor = rootView.defaultCursor
        }
    }
    
    func move(from sheetView: SheetView?, at sp: Point) {
        sheetView?.movePreviousInterKeyframe()
        rootAction.updateActionNode()
        rootView.updateSelects()
    }
}

final class GoNextAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private var sheetView: SheetView?, contentIndex: Int?
    private var contentView: SheetContentView? {
        guard let sheetView, let contentIndex,
              contentIndex < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentIndex]
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
            sheetView = rootView.sheetView(at: p)
        
            if let sheetView {
                if let contentIndex = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                             scale: rootView.screenToWorldScale),
                   sheetView.contentsView.elementViews[contentIndex].model.type == .movie {
                    self.contentIndex = contentIndex
                    contentView?.moveNextInterKeyframe()
                }
                
                if contentIndex == nil {
                    move(from: sheetView, at: p)
                    sheetView.showOtherTimeNodeFromMainBeat()
                    sheetView.animationView.shownInterTypeKeyframeIndex = sheetView.animationView.model.index
                }
            }
            
            rootView.cursor = rootView.cursor(from: contentView?.currentTimeString(isInter: true)
                                              ?? sheetView?.currentKeyframeString()
                                              ?? Animation.timeString(fromTime: 0, frameRate: 0))
        case .changed:
            if event.isRepeat, let sheetView {
                if let contentView {
                    contentView.moveNextInterKeyframe()
                    sheetView.showOtherTimeNodeFromMainBeat()
                    
                    rootView.cursor = .circle(string: contentView.currentTimeString(isInter: true))
                } else {
                    move(from: sheetView, at: p)
                    sheetView.showOtherTimeNodeFromMainBeat()
                    sheetView.animationView.shownInterTypeKeyframeIndex = sheetView.animationView.model.index
                    
                    rootView.cursor = rootView.cursor(from: sheetView.currentKeyframeString())
                }
            }
        case .ended:
            if let sheetView {
                sheetView.hideOtherTimeNode()
                sheetView.animationView.shownInterTypeKeyframeIndex = nil
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
    
    func move(from sheetView: SheetView?, at sp: Point) {
        sheetView?.moveNextInterKeyframe()
        rootAction.updateActionNode()
        rootView.updateSelects()
    }
}

final class GoPreviousFrameAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private var sheetView: SheetView?, contentIndex: Int?
    private var contentView: SheetContentView? {
        guard let sheetView, let contentIndex,
              contentIndex < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentIndex]
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
            sheetView = rootView.sheetView(at: p)
            
            if let sheetView {
                if let contentIndex = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                             scale: rootView.screenToWorldScale),
                   sheetView.contentsView.elementViews[contentIndex].model.type == .movie {
                    self.contentIndex = contentIndex
                    contentView?.movePreviousKeyframe()
                }
                
                if contentIndex == nil {
                    move(from: sheetView, at: p)
                    sheetView.showOtherTimeNodeFromMainBeat()
                    sheetView.animationView.shownInterTypeKeyframeIndex = sheetView.animationView.model.index
                }
            }
            
            rootView.cursor = rootView.cursor(from: contentView?.currentTimeString(isInter: false)
                                              ?? sheetView?.currentKeyframeString()
                                              ?? Animation.timeString(fromTime: 0, frameRate: 0))
        case .changed:
            if event.isRepeat, let sheetView {
                if let contentView {
                    contentView.movePreviousKeyframe()
                    sheetView.showOtherTimeNodeFromMainBeat()
                    
                    rootView.cursor = .circle(string: contentView.currentTimeString(isInter: false))
                } else {
                    move(from: sheetView, at: p)
                    sheetView.showOtherTimeNodeFromMainBeat()
                    sheetView.animationView.shownInterTypeKeyframeIndex = sheetView.animationView.model.index
                    
                    rootView.cursor = rootView.cursor(from: sheetView.currentKeyframeString())
                }
            }
        case .ended:
            if let sheetView {
                sheetView.hideOtherTimeNode()
                sheetView.animationView.shownInterTypeKeyframeIndex = nil
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
    
    func move(from sheetView: SheetView?, at sp: Point) {
        sheetView?.movePreviousKeyframe()
        rootAction.updateActionNode()
        rootView.updateSelects()
    }
}

final class GoNextFrameAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private var sheetView: SheetView?, contentIndex: Int?
    private var contentView: SheetContentView? {
        guard let sheetView, let contentIndex,
              contentIndex < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentIndex]
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
            sheetView = rootView.sheetView(at: p)
            
            if let sheetView {
                if let contentIndex = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                             scale: rootView.screenToWorldScale),
                   sheetView.contentsView.elementViews[contentIndex].model.type == .movie {
                    self.contentIndex = contentIndex
                    contentView?.moveNextKeyframe()
                }
                
                if contentIndex == nil {
                    move(from: sheetView, at: p)
                    sheetView.showOtherTimeNodeFromMainBeat()
                    sheetView.animationView.shownInterTypeKeyframeIndex = sheetView.animationView.model.index
                }
            }
            
            rootView.cursor = rootView.cursor(from: contentView?.currentTimeString(isInter: false)
                                              ?? sheetView?.currentKeyframeString()
                                              ?? Animation.timeString(fromTime: 0, frameRate: 0))
        case .changed:
            if event.isRepeat, let sheetView {
                if let contentView {
                    contentView.moveNextKeyframe()
                    sheetView.showOtherTimeNodeFromMainBeat()
                    
                    rootView.cursor = .circle(string: contentView.currentTimeString(isInter: false))
                } else {
                    move(from: sheetView, at: p)
                    sheetView.showOtherTimeNodeFromMainBeat()
                    sheetView.animationView.shownInterTypeKeyframeIndex = sheetView.animationView.model.index
                    
                    rootView.cursor = rootView.cursor(from: sheetView.currentKeyframeString())
                }
            }
        case .ended:
            if let sheetView {
                sheetView.hideOtherTimeNode()
                sheetView.animationView.shownInterTypeKeyframeIndex = nil
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
    
    func move(from sheetView: SheetView?, at sp: Point) {
        sheetView?.moveNextKeyframe()
        rootAction.updateActionNode()
        rootView.updateSelects()
    }
}

final class SelectFrameAction: SwipeEventAction, DragEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private let indexInterval = 5.0, animationIndexInterval = 0.5
    private let correction = 3.5
    
    enum MoveType {
        case frame, time
    }
    
    var type = MoveType.frame
    
    private var cursorTimer: (any DispatchSourceTimer)?
    
    private var sheetView: SheetView?, contentIndex: Int?
    private var contentView: SheetContentView? {
        guard let sheetView, let contentIndex,
              contentIndex < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentIndex]
    }
    private var beganContentBeat: Rational = 0, oldContentBeat: Rational = 0
    private var oldDeltaI: Int?
    private var beganSP = Point(), preSP = Point(),
                beganRootI = 0, beganRootBeat: Rational = 0, beganBeat = Rational(0),
                beganSelectedFrameIndexes = [Int](), beganEventTime = 0.0, preEventTime: Double?
    private var allDX = 0.0, co = 0
    private var snapEventTime: Double?
    private let progressWidth = {
        let text = Text(string: "00.00", size: Font.defaultSize)
        return text.frame?.width ?? 40
    } ()
    
    func flow(with event: DragEvent) {
        if event.phase == .began {
            preSP = event.screenPoint
        }
        flow(with: SwipeEvent(screenPoint: event.screenPoint, time: event.time,
                              scrollDeltaPoint: (event.screenPoint - preSP) / correction, phase: event.phase))
        preSP = event.screenPoint
    }
    func flow(with event: SwipeEvent) {
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
            rootAction.rootView.closeLookingUp()
            
            beganSP = event.screenPoint
            beganEventTime = event.time
            preEventTime = nil
            sheetView = rootView.sheetView(at: p)
            if let sheetView {
                if let contentIndex = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                             scale: rootView.screenToWorldScale),
                   sheetView.contentsView.elementViews[contentIndex].model.type == .movie {
                    self.contentIndex = contentIndex
                    if let contentView {
                        beganContentBeat = contentView.model.beat
                        oldContentBeat = beganContentBeat
                    }
                }
                
                if contentIndex == nil {
                    if sheetView.model.enabledAnimation {
                        let animationView = sheetView.animationView
                        beganRootI = animationView.rootKeyframeIndex
                        beganRootBeat = animationView.rootBeat
                        beganBeat = animationView.model.localBeat
                        beganSelectedFrameIndexes = animationView.selectedFrameIndexes
                        animationView.shownInterTypeKeyframeIndex = animationView.model.index
                    }
                }
            } else {
                rootView.cursor = rootView.cursor(from: Animation.timeString(fromTime: 0, frameRate: 0))
            }
            
            sheetView?.showOtherTimeNodeFromMainBeat()
        case .changed:
            if let sheetView {
                if let contentView {
                    allDX += event.scrollDeltaPoint.x * correction
                    let deltaI = Int((allDX / indexInterval).rounded())
                    if deltaI != oldDeltaI {
                        oldDeltaI = deltaI
                        
                        let frameBeat = contentView.model.frameBeat ?? 1
                        let nBeat = (beganContentBeat + .init(deltaI) * frameBeat)
                            .loop(start: 0, end: contentView.model.timeOption?.beatRange.length ?? 0)
                            .interval(scale: frameBeat)
                        if nBeat != oldContentBeat {
                            oldContentBeat = nBeat
                            
                            contentView.beat = nBeat
                        }
                    }
                } else {
                    allDX += event.scrollDeltaPoint.x * correction
                    if sheetView.model.enabledAnimation {
                        let animationView = sheetView.animationView
                        let animation = animationView.model
                        
                        let oldKI = animationView.model.index
                        var isChangedRootI = false
                        switch type {
                        case .frame:
                            var bws = animation.keyframes.count.range.reduce(into: [Rational: Double]()) {
                                $0[animation.keyframes[$1].beat] =
                                (animation.keyframes[$1].isKey ? 0.25 : 0.125) * 50
                            }
                            
                            if let beatRange = animationView.beatRange {
                                let roundedSBeat = beatRange.start.rounded(.down)
                                let deltaBeat = animationView.isFullEdit ? Rational(1, 128) : Rational(1, 8)
                                var cBeat = roundedSBeat
                                while cBeat < beatRange.end {
                                    if cBeat >= beatRange.start {
                                        if bws[cBeat] == nil {
                                            bws[cBeat] = 0.125 * 50
                                        }
                                    }
                                    cBeat += deltaBeat
                                }
                            }
                            let beatAndWidths = bws.sorted(by: { $0.key < $1.key })
                            if !beatAndWidths.isEmpty {
                                let localbeat = animation.localBeat(atRootBeat: beganRootBeat)
                                var bwI = 0
                                for (i, v) in beatAndWidths.enumerated().reversed() {
                                    if localbeat >= v.key {
                                        bwI = i
                                        break
                                    }
                                }
                                var nRootBeat = animation.loopIndexBeat(atLoop: animation.loopIndex(atRootBeat: beganRootBeat))
                                + beatAndWidths[bwI].key
                                var x = beatAndWidths[bwI].value / 2
                                
                                while true {
                                    x += beatAndWidths[bwI].value
                                    guard abs(x) < abs(allDX) else { break }
                                    
                                    let dBeat = if allDX < 0 {
                                        if bwI - 1 >= 0 {
                                            -(beatAndWidths[bwI].key - beatAndWidths[bwI - 1].key)
                                        } else {
                                            -(beatAndWidths[bwI].key
                                            + animation.beatRange.length - beatAndWidths[.last].key)
                                        }
                                    } else {
                                        if bwI + 1 < beatAndWidths.count {
                                            beatAndWidths[bwI + 1].key - beatAndWidths[bwI].key
                                        } else {
                                            animation.beatRange.length - beatAndWidths[bwI].key
                                            + beatAndWidths[0].key
                                        }
                                    }
                                    nRootBeat = Rational.saftyAdd(nRootBeat, dBeat)
                                    
                                    bwI = (allDX < 0 ? bwI - 1 : bwI + 1)
                                        .loop(start: 0, end: beatAndWidths.count)
                                }
                                
                                let oldRKI = animationView.rootKeyframeIndex
                                if sheetView.isPlaying {
                                    sheetView.stop()
                                }
                                sheetView.rootBeat = nRootBeat
                                if oldRKI != sheetView.rootKeyframeIndex {
                                    sheetView.showOtherTimeNodeFromMainBeat()
                                    isChangedRootI = true
                                }
                            }
                        case .time:
                            let deltaI = Int((allDX / animationIndexInterval).rounded())
                            if deltaI != oldDeltaI {
                                oldDeltaI = deltaI
                                
                                let frameBeat = Sheet.fullEditBeatInterval
                                let nRootBeat = (beganRootBeat + .init(deltaI) * frameBeat)
                                    .interval(scale: frameBeat)
                                
                                let oldRKI = animationView.rootKeyframeIndex
                                if sheetView.isPlaying {
                                    sheetView.stop()
                                }
                                sheetView.rootBeat = nRootBeat
                                if oldRKI != sheetView.rootKeyframeIndex {
                                    sheetView.showOtherTimeNodeFromMainBeat()
                                    isChangedRootI = true
                                }
                            }
                        }
                        
                        if isChangedRootI {
                            if preEventTime == nil || event.time - preEventTime! > 0.1,
                               animationView.currentKeyframe.isKey
                                || animationView.model.index == 0 {
                                
                                Feedback.performAlignment()
                                preEventTime = event.time
                            }
                            
                            rootAction.updateActionNode()
                            rootView.updateSelects()
                            
                            if oldKI != animationView.model.index {
                                animationView.shownInterTypeKeyframeIndex = animationView.model.index
                            }
                            
                            if let lineAction = (rootAction.dragAction as? DrawLineAction)?.action,
                               sheetView.id == lineAction.beganSheetID,
                               let lineColor = lineAction.beganLineColor {
                                
                                let isSelect = animationView.model.index !=
                                animationView.model.index(atRoot: lineAction.beganAnimationRootIndex)
                                lineAction.tempLineNode?.lineType = .color(isSelect ? lineColor.with(opacity: 0.1) : lineColor)
                            }
                        }
                    }
                }
            }
        case .ended:
            if let sheetView {
                let animationView = sheetView.animationView
                animationView.shownInterTypeKeyframeIndex = nil
                
                sheetView.hideOtherTimeNode()
            }
        }
        
        switch event.phase {
        case .began:
            cursorTimer = DispatchSource.scheduledTimer(withTimeInterval: 1 / 30) { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard let self, !(self.cursorTimer?.isCancelled ?? true) else { return }
                    if let contentView = self.contentView {
                        self.rootView.cursor = .circle(progress: contentView.currentTimeProgress(),
                                                       progressWidth: self.progressWidth,
                                                  string: contentView.currentTimeString(isInter: false))
                    } else if let sheetView = self.sheetView {
                        self.rootView.cursor = self.rootView.cursor(from: sheetView.currentKeyframeString(),
                                                          progress: sheetView.currentTimeProgress(),
                                                          progressWidth: self.progressWidth)
                    }
                }
            }
        case .changed: break
        case .ended:
            cursorTimer?.cancel()
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class PlayAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private var sheetView: SheetView?
    private var isEndStop = false
    
    func flow(with event: InputKeyEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        let sp = rootView.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = rootView.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            
            rootAction.rootView.closeLookingUp()
            
            sheetView = rootView.sheetView(at: p)
            let cShp = rootView.sheetPosition(at: p)
            if let cSheetView = rootView.sheetView(at: cShp) {
                for (_, v) in rootView.sheetViewValues {
                    if cSheetView != v.sheetView {
                        v.sheetView?.stop()
                    }
                }
                
                func sheetView(at shp: IntPoint) -> SheetView? {
                    if let aSheetView = rootView.sheetView(at: shp),
                       aSheetView.model.enabledTimeline {
                        
                        aSheetView
                    } else {
                        nil
                    }
                }
                func topAndBottom(at ncShp: IntPoint, in aSheetView: SheetView) {
                    var nncShp = ncShp, npsvs = [WeakElement<SheetView>]()
                    nncShp.y -= 1
                    while let aaSheetView = sheetView(at: nncShp) {
                        npsvs.append(.init(element: aaSheetView))
                        nncShp.y -= 1
                    }
                    aSheetView.bottomSheetViews = npsvs.reversed()
                    nncShp = ncShp
                    npsvs = []
                    nncShp.y += 1
                    while let aaSheetView = sheetView(at: nncShp) {
                        npsvs.append(.init(element: aaSheetView))
                        nncShp.y += 1
                    }
                    aSheetView.topSheetViews = npsvs
                }
                
                let shps = rootView.groupSheetPositions(at: cShp)
                for cShp in shps {
                    guard let cSheetView = sheetView(at: cShp) else { continue }
                    
                    topAndBottom(at: cShp, in: cSheetView)
                    
                    var ncShp = cShp, psvs = [WeakElement<SheetView>]()
                    while let preShp = rootView.maxVerticalSheetPosition(at: ncShp, deltaX: -1) {
                        guard let ncSheetView = sheetView(at: preShp) else { break }
                        psvs.append(.init(element: ncSheetView))
                        ncShp = preShp
                    }
                    cSheetView.previousSheetViews = psvs
                    
                    ncShp = cShp
                    var nsvs = [WeakElement<SheetView>]()
                    while let nextShp = rootView.maxVerticalSheetPosition(at: ncShp, deltaX: 1) {
                        guard let ncSheetView = sheetView(at: nextShp) else { break }
                        nsvs.append(.init(element: ncSheetView))
                        ncShp = nextShp
                    }
                    cSheetView.nextSheetViews = nsvs
                }
                
                let scale = rootView.screenToWorldScale
                let sheetP = cSheetView.convertFromWorld(p)
                if let (_, contentView) = cSheetView.contentIndexAndView(at: sheetP, scale: scale),
                   contentView.model.type == .movie,
                   !contentView.containsTimeline(contentView.convertFromWorld(p), scale: scale) {
                    
                    let sec = contentView.model.sec(fromBeat: contentView.model.beat)
                    cSheetView.play(atSec: sec)
                } else if !(rootAction.containsAllTimelines(with: event)
                    || (!cSheetView.model.enabledAnimation && cSheetView.model.enabledMusic)) {
                    
                    if cSheetView.model.enabledTimeline {
                        cSheetView.play()
                        rootView.cursor = rootView.cursor(from: cSheetView.currentTimeString() + "...",
                                                          isArrow: true)
                    }
                } else {
                    let sheetP = cSheetView.convertFromWorld(p)
                    let scoreView = cSheetView.scoreView
                    let sec: Rational
                    if scoreView.model.enabled,
                       let (noteI, pitI) = scoreView.noteAndPitI(at: scoreView.convertFromWorld(p),
                                                                 scale: scale) {
                        let score = scoreView.model
                        let beat = score.notes[noteI].pits[pitI].beat
                        + score.notes[noteI].beatRange.start + score.beatRange.start
                        sec = score.sec(fromBeat: beat)
                    } else {
                        sec = cSheetView.sec(at: sheetP, scale: scale,
                                             interval: rootView.currentBeatInterval)
                    }
                    cSheetView.play(atSec: sec)
                }
            }
        case .changed:
            break
        case .ended:
            if isEndStop {
                sheetView?.stop()
            }
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class InsertKeyframeAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private var linesNode = Node()
    
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
                
                let animationView = sheetView.animationView
                if animationView.containsTimeline(inP, scale: rootView.screenToWorldScale),
                   let i = animationView.slidableKeyframeIndex(at: inP,
                                                               maxDistance: rootView.worldKnobEditDistance),
                   sheetView.selectedFrameIndexes.contains(i) {
                    
                    let kis = sheetView.selectedFrameIndexes
                    sheetView.selectedFrameIndexes = []
                    
                    let beat = animationView.model.localBeat
                    let count = ((animationView.rootBeat - beat) / animationView.model.localDurBeat).rounded(.towardZero)
                    
                    let oneBeat = Rational(1, animationView.frameRate)
                    
                    var nj = 0, isNewUndoGroup = false
                    let idvs = kis.compactMap {
                        let keyframe = animationView.model.keyframes[$0]
                        let idivs: [IndexValue<InterOption>] = keyframe.picture.lines.enumerated().compactMap {
                            let option = $0.element.interOption
                            return if option.interType == .interpolated {
                                .init(value: option.with(.key), index: $0.offset)
                            } else {
                                nil
                            }
                        }
                        return idivs.isEmpty ? nil : IndexValue(value: idivs, index: $0)
                    }
                    if !idvs.isEmpty {
                        if !isNewUndoGroup {
                            sheetView.newUndoGroup()
                            isNewUndoGroup = true
                        }
                        sheetView.set(idvs)
                    }
                    
                    for j in kis {
                        let durBeat = animationView.model.keyframeDurBeat(at: j + nj)
                        if durBeat >= oneBeat {
                            if !isNewUndoGroup {
                                sheetView.newUndoGroup()
                                isNewUndoGroup = true
                            }
                            
                            let nBeat = animationView.model.keyframes[j + nj].beat
                            let count = Int(durBeat / oneBeat) - 1
                            sheetView.insert((0 ..< count).map { k in
                                IndexValue(value: Keyframe(beat: oneBeat * .init(k + 1) + nBeat),
                                           index: k + j + nj + 1)
                            })
                            nj += count
                        }
                    }
                    
                    sheetView.rootBeat = animationView.model.localDurBeat * count + beat
                    rootAction.updateActionNode()
                    rootView.updateSelects()
                } else if sheetView.animationView.containsTimeline(inP, scale: rootView.screenToWorldScale) {
                    sheetView.selectedFrameIndexes = []
                    
                    let animationView = sheetView.animationView
                    let animation = animationView.model
                    
                    let interval = rootView.currentBeatInterval
                    let oBeat = animationView.beat(atX: inP.x, interval: interval)
                    let beat = (oBeat - animation.beatRange.start)
                        .clipped(min: 0, max: animation.beatRange.length)
                    
                    var rootBP = animation.rootBeatPosition
                    rootBP.beat = beat
                    if beat < animation.keyframes.first?.beat ?? 0 {
                        let keyframe = Keyframe(beat: beat)
                        animationView.selectedFrameIndexes = []
                        sheetView.newUndoGroup(enabledKeyframeIndex: false)
                        sheetView.insert([IndexValue(value: keyframe, index: 0)])
                    } else if let (i, iBeat) = animation.indexAndInternalBeat(atRootBeat: beat) {
                        let i = iBeat != 0 ?
                        i :
                        (animationView.beat(atX: inP.x, interval: Rational(1, 60)) < beat ? i - 1 : i)
                        let iBeat = {
                            if iBeat != 0 {
                                return iBeat
                            } else {
                                let nextBeat = !animation.keyframes[i].isKey ?
                                animation.localBeat(at: animation.index(atInter: animation.interIndex(at: i) + 1)) :
                                animation.localBeat(at: i + 1)
                                let nb = nextBeat - animation.localBeat(at: i)
                                return switch nb {
                                case Rational(1, 4): Rational(1, 12)
                                case Rational(1, 6): Rational(1, 12)
                                default: nb / 2
                                }
                            }
                        } ()
                        if iBeat != 0 && animation.keyframes[i].isKey {
                            let nBeat = animation.keyframes[i].beat + iBeat
                            let keyframe = Keyframe(beat: nBeat)
                            animationView.selectedFrameIndexes = []
                            sheetView.newUndoGroup(enabledKeyframeIndex: false)
                            sheetView.insert([IndexValue(value: keyframe, index: i + 1)])
                        } else if !animation.keyframes[i].isKey {
                            let idivs: [IndexValue<InterOption>] = (0 ..< animation.keyframes[i].picture.lines.count).compactMap {
                                
                                let option = animation.keyframes[i].picture.lines[$0].interOption
                                if option.interType == .interpolated {
                                    let nOption = option.with(.key)
                                    return IndexValue(value: nOption, index: $0)
                                } else {
                                    return nil
                                }
                            }
                            guard !idivs.isEmpty else { return }
                            
                            sheetView.rootKeyframeIndex = i
                            sheetView.newUndoGroup()
                            sheetView.set([IndexValue(value: idivs, index: i)])
                            
                            let ids = idivs.map { $0.value.id }
                            sheetView.interpolation(ids.map { ($0, [$0]) },
                                                    oldRootKeyframeIndex: i,
                                                    newRootKeyframeIndex: i,
                                                    isNewUndoGroup: false)
                            animationView.updateTimeline()
                        }
                    }
                    
                    let progressWidth = {
                        let text = Text(string: "00.00", size: Font.defaultSize)
                        return text.frame?.width ?? 40
                    } ()
                    rootView.cursor = rootView.cursor(from: sheetView.currentKeyframeString(),
                                                      isArrow: true,
                                                      progress: sheetView.currentTimeProgress(),
                                                      progressWidth: progressWidth)
                } else if let ci = sheetView.contentIndex(at: inP, scale: rootView.screenToWorldScale) {
                    let contentView = sheetView.contentsView.elementViews[ci]
                    if contentView.model.timeOption == nil {
                        var content = contentView.model
                        let startBeat: Rational = sheetView.animationView.beat(atX: content.origin.x)
                        content.timeOption = .init(beatRange: startBeat ..< (4 + startBeat),
                                                   tempo: sheetView.nearestTempo(at: inP) ?? Music.defaultTempo)
                        
                        sheetView.newUndoGroup()
                        sheetView.replace(IndexValue(value: content, index: ci))
                        
                        sheetView.updatePlaying()
                    }
                } else if let ti = sheetView.textIndex(at: inP, scale: rootView.screenToWorldScale) {
                    let textView = sheetView.textsView.elementViews[ti]
                    if textView.model.timeOption == nil {
                        var text = textView.model
                        let startBeat: Rational = sheetView.animationView.beat(atX: text.origin.x)
                        text.timeOption = .init(beatRange: startBeat ..< (4 + startBeat),
                                                tempo: sheetView.nearestTempo(at: inP) ?? Music.defaultTempo)
                        
                        sheetView.newUndoGroup()
                        sheetView.replace([IndexValue(value: text, index: ti)])
                        
                        sheetView.updatePlaying()
                    }
                } else if sheetView.model.score.enabled {
                    let scoreView = sheetView.scoreView
                    let scoreP = sheetView.scoreView.convertFromWorld(p)
                    if let noteI = sheetView.scoreView.noteIndex(at: scoreP,
                                                                 scale: rootView.screenToWorldScale,
                                                                 enabledTone: true) {
                        let score = scoreView.model
                        let scoreP = scoreView.convertFromWorld(p)
                        if let (pitI, _) = scoreView.pitIAndSprolI(at: scoreP, at: noteI, scale: rootView.screenToWorldScale) {
                            let (_, sprol) = scoreView.nearestSprol(at: scoreP, at: noteI)
                            let oldTone = score.notes[noteI].pits[pitI].tone
                            var tone = oldTone
                            let i = tone.spectlope.sprols.enumerated().reversed()
                                .first(where: { sprol.pitch > $0.element.pitch })?.offset ?? -1
                            tone.spectlope.sprols.insert(sprol, at: i + 1)
                            tone.id = .init()
                            
                            let nis = score.notes.count.range.filter {
                                score.notes[$0].pits.contains { $0.tone.id == oldTone.id }
                            }
                            let nivs = nis.map {
                                var note = score.notes[$0]
                                note.pits = note.pits.map {
                                    if $0.tone.id == oldTone.id {
                                        var pit = $0
                                        pit.tone = tone
                                        return pit
                                    } else {
                                        return $0
                                    }
                                }
                                return IndexValue(value: note, index: $0)
                            }
                            
                            sheetView.newUndoGroup()
                            sheetView.replace(nivs)
    //                        sheetView.set(ToneValue(tone: tone, noteIndexes: nis),
    //                                      old: ToneValue(tone: oldTone, noteIndexes: nis))
                            
                            sheetView.updatePlaying()
                        } else {
                            var pits = score.notes[noteI].pits
                            let pit = scoreView.splittedPit(at: scoreP, at: noteI,
                                                            beatInterval: rootView.currentBeatInterval,
                                                            pitchInterval: rootView.currentPitchInterval)
                            if pits.allSatisfy({ $0.beat != pit.beat }) {
                                pits.append(pit)
                                pits.sort { $0.beat < $1.beat }
                                var note = score.notes[noteI]
                                note.pits = pits
                                
                                sheetView.newUndoGroup()
                                sheetView.replace(note, at: noteI)
                                
                                sheetView.updatePlaying()
                            }
                        }
                    } else if scoreView.containsTimeline(scoreP, scale: rootView.screenToWorldScale) {
                        let interval = rootView.currentBeatInterval
                        let beat = scoreView.beat(atX: inP.x, interval: interval)
                        var option = scoreView.model.option
                        option.keyBeats.append(beat)
                        option.keyBeats.sort()
                        sheetView.newUndoGroup()
                        sheetView.set(option)
                    }
                } else if !sheetView.model.enabledAnimation {
                    sheetView.newUndoGroup(enabledKeyframeIndex: false)
                    sheetView.set(beat: 0, at: 0)
                    var option = sheetView.model.animation.option
                    option.timelineY = inP.y.clipped(min: Sheet.timelineY,
                                                     max: Sheet.height - Sheet.timelineY)
                    option.enabled = true
                    sheetView.set(option)
                }
                
                rootAction.updateActionNode()
                rootView.updateSelects()
            }
        case .changed:
            break
        case .ended:
            linesNode.removeFromParent()
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class InterpolateAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private var linesNode = Node()
    
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
            
            if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled {
                let nis: [Int]
                if rootView.isSelectNoneCursor(at: p), !rootView.isSelectedText {
                    nis = sheetView.noteIndexes(from: rootView.selections)
                } else {
                    let onis = sheetView.scoreView
                        .nearestNoteIndexes(at: sheetView.scoreView.convertFromWorld(p))
                    if onis.count >= 2 {
                        nis = [onis[0], onis[1]]
                    } else {
                        nis = []
                    }
                }
                if nis.count >= 2 {
                    let noteIAndNotes = nis
                        .map { ($0, sheetView.scoreView.model.notes[$0]) }
                        .sorted { $0.1.beatRange.start < $1.1.beatRange.start }
                    var preBeat = noteIAndNotes.first!.1.beatRange.end, isAppend = false
                    var nNote = noteIAndNotes.first!.1
                    var preLastPit = nNote.pits.last!
                    preLastPit.beat = nNote.beatRange.length
                    preLastPit.lyric = ""
                    for i in 1 ..< noteIAndNotes.count {
                        let (_, note) = noteIAndNotes[i]
                        if preBeat <= note.beatRange.start {
                            nNote.pits.append(preLastPit)
                            nNote.pits += note.pits.map {
                                var pit = $0
                                pit.beat += note.beatRange.start - nNote.beatRange.start
                                pit.pitch += note.pitch - nNote.pitch
                                return pit
                            }
                            preBeat = note.beatRange.end
                            preLastPit = note.pits.last!
                            preLastPit.beat = note.beatRange.end - nNote.beatRange.start
                            preLastPit.pitch += note.pitch - nNote.pitch
                            preLastPit.lyric = ""
                            nNote.beatRange.length = preLastPit.beat
                            isAppend = true
                        }
                    }
                    if isAppend {
                        sheetView.newUndoGroup()
                        sheetView.removeNote(at: noteIAndNotes.map { $0.0 }.sorted())
                        sheetView.append(nNote)
                    }
                }
                return
            }
            
            let cos = Pasteboard.shared.copiedObjects
            for co in cos {
                if case .sheetValue(let v) = co,
                   v.lines.isEmpty,
                    let oUUColor = v.planes.first?.uuColor {
                    
                    let nUUColor = rootView.uuColor(at: p)
                    if let sheetView = rootView.sheetView(at: p),
                       sheetView.id == v.id {
                        
                        let animationView = sheetView.animationView
                        let orki = v.rootKeyframeIndex,
                            nrki = animationView.rootKeyframeIndex
                        let di = abs(nrki - orki)
                        if di > 1 {
                            var filledIs = Set<Int>()
                            var vs = [(ki: Int, pis: [Int], uuColor: UUColor)]()
                            for dri in 1 ..< di {
                                let t = Double(dri) / Double(di)
                                let ri = orki < nrki ?
                                    orki + dri : orki - dri
                                let ki = sheetView.model.animation.index(atRoot: ri)
                                guard !filledIs.contains(ki) else { continue }
                                let color = Color.linear(oUUColor.value, nUUColor.value, t: t)
                                
                                let pis = sheetView.model.animation.keyframes[ki].picture.planes.enumerated().compactMap {
                                    $0.element.uuColor == oUUColor || $0.element.uuColor == nUUColor ? $0.offset : nil
                                }
                                
                                if !pis.isEmpty {
                                    vs.append((ki, pis, .init(color)))
                                    filledIs.insert(ki)
                                }
                            }
                            
                            sheetView.newUndoGroup()
                            
                            let svs = vs.sorted(by: { $0.ki < $1.ki })
                            var nodes = [Node]()
                            let scale = 1 / rootView.worldToScreenScale
                            svs.forEach {
                                let cv = ColorValue(uuColor: $0.uuColor,
                                                    planeIndexes: [], lineIndexes: [],
                                                    isBackground: false,
                                                    planeAnimationIndexes: [.init(value: $0.pis,
                                                                                  index: $0.ki)],
                                                    lineAnimationIndexes: [],
                                                    animationColors: [])
                                let oldUUColor = sheetView.model.animation.keyframes[$0.ki].picture.planes[$0.pis.first!].uuColor
                                let ocv = ColorValue(uuColor: oldUUColor,
                                                     planeIndexes: [], lineIndexes: [],
                                                     isBackground: false,
                                                     planeAnimationIndexes: [.init(value: $0.pis,
                                                                                   index: $0.ki)],
                                                     lineAnimationIndexes: [],
                                                     animationColors: [])
                                sheetView.set(cv, oldColorValue: ocv)
                                
                                let value = sheetView.colorPathValue(with: cv, toColor: nil,
                                                                     color: .selected,
                                                                     subColor: .subSelected)
                                nodes += value.paths.map {
                                    Node(path: $0, lineWidth: Line.defaultLineWidth * 2 * scale,
                                         lineType: value.lineType, fillType: value.fillType)
                                }
                            }
                            
                            linesNode.children = nodes
                            rootView.node.append(child: linesNode)
                        }
                    }
                    return
                }
            }
            guard let o = cos.first else { return }
            
            let sheetID: UUID, ios: [InterOption], oRootKI: Int, oldLines: [Line]
            switch o {
            case .sheetValue(let v):
                sheetID = v.id
                ios = v.lines.map { $0.interOption.with(.key) }
                oRootKI = v.rootKeyframeIndex
                oldLines = v.lines
            case .ids(let v):
                sheetID = v.sheetID
                ios = v.ids.map { $0.with(.key) }
                oRootKI = v.rootKeyframeIndex
                oldLines = []
            default: return
            }
            
            if let sheetView = rootView.sheetView(at: p),
               sheetView.id == sheetID {
                
                let animationView = sheetView.animationView
                var isNewUndoGroup = true
//                if oldRootKeyframeIndex != animationView.rootKeyframeIndex {
//                    let beat = animationView.model.localBeat
//                    let count = ((animationView.rootBeat - beat) / animationView.model.localDurBeat).rounded(.towardZero)
//                    
//                    let oneBeat = Rational(1, animationView.frameRate)
//                    
//                    let ki0 = animationView.model.index(atRoot: oldRootKeyframeIndex)
//                    let ki1 = animationView.model.index(atRoot: animationView.rootKeyframeIndex)
//                    let nki0 = min(ki0, ki1), nki1 = max(ki0, ki1)
//                    let ranges = (oldRootKeyframeIndex < animationView.rootKeyframeIndex ? ki0 < ki1 : ki1 < ki0) ? [nki0 ..< nki1] : [0 ..< nki0, nki1 ..< animationView.model.keyframes.count]
//                    
//                    var nj = 0
//                    for range in ranges {
//                        for j in range {
//                            let durBeat = animationView.model.keyframeDurBeat(at: j + nj)
//                            if durBeat >= oneBeat {
//                                if !isNewUndoGroup {
//                                    sheetView.newUndoGroup()
//                                    isNewUndoGroup = true
//                                }
//                                
//                                let nBeat = animationView.model.keyframes[j + nj].beat
//                                let count = Int(durBeat / oneBeat) - 1
//                                sheetView.insert((0 ..< count).map { k in
//                                    IndexValue(value: Keyframe(beat: oneBeat * .init(k + 1) + nBeat),
//                                               index: k + j + nj + 1)
//                                })
//                                nj += count
//                            }
//                        }
//                    }
//                    sheetView.rootBeat = animationView.model.localDurBeat * count + beat
//                    rootAction.updateActionNode()
//                    rootView.updateSelects()
//                }
                
                let lis: [Int], nKI, nRootKI: Int
                if rootView.isSelectNoneCursor(at: p), !rootView.isSelectedText {
                    lis = sheetView.lineIndexes(from: rootView.selections)
                    nKI = sheetView.model.animation.index
                    nRootKI = sheetView.model.animation.rootIndex
                } else {
                    if let (_, li, nrki) = sheetView
                        .lineTuple(at: sheetView.convertFromWorld(p),
                                   enabledPreviousNext: true,
                                   scale: 1 / rootView.worldToScreenScale) {
                        lis = [li]
                        nKI = sheetView.model.animation.index(atRoot: nrki)
                        nRootKI = nrki
                    } else {
                        lis = []
                        nKI = 0
                        nRootKI = 0
                    }
                }
                
                let maxCount = min(ios.count, lis.count)
                guard maxCount > 0 else { return }
                let idSet = Set(ios.map { $0.id })
                let lineIDSet = Set(animationView.model.keyframes[nKI].picture.lines.map { $0.id })
                let idivs: [IndexValue<InterOption>] = (0 ..< maxCount).compactMap {
                    let line = animationView.model.keyframes[nKI].picture.lines[lis[$0]]
                    var interOption: InterOption
                    if idSet.contains(line.interOption.id) {
                        interOption = line.interOption
                    } else {
                        if !animationView.enabledFirstOrLastInterpolated(atLineI: lis[$0],
                                                                         atRootKI: nRootKI,
                                                                         fromRootKI: oRootKI)
                            || lineIDSet.contains(ios[$0].id) {
                            return nil
                        }
                        interOption = ios[$0]
                    }
                    if interOption.interType == .interpolated {
                        interOption.interType = .key
                    }
                    return IndexValue(value: interOption, index: lis[$0])
                }
                
                var noNodes = [Node]()
                if idivs.isEmpty {
                    for li in lis {
                        let lw = Line.defaultLineWidth
                        let scale = 1 / rootView.worldToScreenScale
                        let blw = max(lw * 1.5, lw * 2.5 * scale, 1 * scale)
                        let line = animationView.model.keyframes[nKI].picture.lines[li]
                        let nLine = sheetView.convertToWorld(line)
                        noNodes.append(Node(path: Path(nLine),
                                       lineWidth: blw,
                                       lineType: .color(.removing)))
                    }
                }
                let nidivs = idivs.filter { idiv in
                    let line = animationView.model.keyframes[nKI].picture.lines[idiv.index]
                    let idLines = animationView.model.keyframes[nKI].picture.lines.filter { $0.id == idiv.value.id }
                    if ((oRootKI == nRootKI
                        || !animationView.isInterpolated(atLineI: idiv.index, atKeyframeI: nKI))
                        && idLines.isEmpty)
                        || idLines.count == 1 && idLines[0] == line {
                        return true
                    } else if idLines.isEmpty
                                && animationView.isInterpolated(atLineI: idiv.index, atKeyframeI: nKI) {
                        let lw = Line.defaultLineWidth
                        let scale = 1 / rootView.worldToScreenScale
                        let blw = max(lw * 1.5, lw * 2.5 * scale, 1 * scale)
                        let nLine = sheetView.convertToWorld(line)
                        noNodes.append(Node(path: Path(nLine),
                                       lineWidth: blw,
                                       lineType: .color(.warning)))
                        return true
                    } else {
                        let lw = Line.defaultLineWidth
                        let scale = 1 / rootView.worldToScreenScale
                        let blw = max(lw * 1.5, lw * 2.5 * scale, 1 * scale)
                        let nLine = sheetView.convertToWorld(line)
                        noNodes.append(Node(path: Path(nLine),
                                       lineWidth: blw,
                                       lineType: .color(.removing)))
                        for line in idLines {
                            let nLine = sheetView.convertToWorld(line)
                            noNodes.append(Node(path: Path(nLine),
                                           lineWidth: blw,
                                           lineType: .color(.removing)))
                        }
                        return false
                    }
                }
                
                func updateUndoGroup() {
                    if isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = false
                    }
                }
                if !nidivs.isEmpty {
                    let scale = 1 / rootView.worldToScreenScale
                    let lw = Line.defaultLineWidth
                    let nodes = lis.map {
                        Node(path: sheetView.animationView.elementViews[nKI].linesView.elementViews[$0].node.path * sheetView.node.localTransform,
                             lineWidth: max(lw * 1.5, lw * 2.5 * scale, 1 * scale),
                             lineType: .color(.selected))
                    }
                    
                    let idivLines = sheetView.model.animation
                        .keyframes[nKI].picture.lines
                    if idivs.contains(where: {
                        idivLines[$0.index].interOption != $0.value
                    }) {
                        updateUndoGroup()
                        
                        var vs = [Int: [IndexValue<InterOption>]]()
                        vs[nKI] = idivs
                        idivs.forEach { idiv in
                            let line = animationView.model.keyframes[nKI].picture.lines[idiv.index]
                            let oldID = line.interOption.id
                            let newID = idiv.value.id
                            
                            func append(atKI: Int) -> Bool {
                                if let li = animationView.model
                                    .keyframes[currentKI].picture.lines
                                    .firstIndex(where: { $0.interOption.id == oldID }) {
                                    
                                    var nIO = animationView.model
                                        .keyframes[currentKI].picture.lines[li].interOption
                                    nIO.id = newID
                                    if vs[atKI] == nil {
                                        vs[atKI] = [.init(value: nIO, index: li)]
                                    } else {
                                        vs[atKI]?.append(.init(value: nIO, index: li))
                                    }
                                    return true
                                } else {
                                    return false
                                }
                            }
                            
                            let kCount = animationView.model.keyframes.count
                            var currentKI = nKI - 1 >= 0 ? nKI - 1 : kCount
                            while currentKI != nKI {
                                if !append(atKI: currentKI) { break }
                                currentKI = currentKI - 1 >= 0 ? currentKI - 1 : kCount
                            }
                            if currentKI != nKI {
                                currentKI = nKI + 1 < kCount ? nKI + 1 : 0
                                while currentKI != nKI {
                                    if !append(atKI: currentKI) { break }
                                    currentKI = currentKI + 1 < kCount ? currentKI + 1 : 0
                                }
                            }
                        }
                        
                        let nnidivs = vs
                            .sorted { $0.key < $1.key }
                            .map { IndexValue(value: $0.value, index: $0.key) }
                        sheetView.set(nnidivs)
                    }
                    
                    let oldLineDic = oldLines.reduce(into: [UUID: Line]()) { $0[$1.id] = $1 }
                    struct UUKey: Hashable {
                        var fromUUColor, toUUColor: UUColor
                    }
                    var colorValuesDic = [UUKey: ColorValue]()
                    for idiv in idivs {
                        let line = animationView.model.keyframes[nKI].picture.lines[idiv.index]
                        if let oldLine = oldLineDic[line.id], oldLine.uuColor != line.uuColor {
                            let uuKey = UUKey(fromUUColor: line.uuColor, toUUColor: oldLine.uuColor)
                            if colorValuesDic[uuKey] != nil {
                                if nKI == animationView.model.index {
                                    colorValuesDic[uuKey]?.lineIndexes.append(idiv.index)
                                } else {
                                    colorValuesDic[uuKey]?.lineAnimationIndexes[nKI].value.append(idiv.index)
                                }
                            } else {
                                if nKI == animationView.model.index {
                                    colorValuesDic[uuKey] = .init(uuColor: oldLine.uuColor,
                                                                  planeIndexes: [],
                                                                  lineIndexes: [idiv.index],
                                                                  isBackground: false,
                                                                  planeAnimationIndexes: [],
                                                                  lineAnimationIndexes: [],
                                                                  animationColors: [])
                                } else {
                                    colorValuesDic[uuKey] = .init(uuColor: oldLine.uuColor,
                                                                  planeIndexes: [],
                                                                  lineIndexes: [],
                                                                  isBackground: false,
                                                                  planeAnimationIndexes: [],
                                                                  lineAnimationIndexes: [.init(value: [idiv.index], index: nKI)],
                                                                  animationColors: [])
                                }
                            }
                        }
                    }
                    for (uuKey, cv) in colorValuesDic {
                        var oldCV = cv
                        oldCV.uuColor = uuKey.fromUUColor
                        updateUndoGroup()
                        sheetView.set(cv, oldColorValue: oldCV)
                    }
                    
                    let oldKeyframe = animationView.model.keyframe(atRoot: oRootKI)
                    for idiv in idivs {
                        guard let li = oldKeyframe.picture.lines.firstIndex(where: { $0.id == idiv.value.id }) else { continue }
                        let upperLineIDs = Set(oldKeyframe.picture.lines[(li + 1)...].map { $0.id })
                        let nli = animationView.model.keyframes[nKI].picture.lines.firstIndex { upperLineIDs.contains($0.id) }
                        if let nli, nli != idiv.index {
                            let line = animationView.model.keyframes[nKI].picture.lines[idiv.index]
                            if nKI == animationView.model.index {
                                sheetView.removeLines(at: [idiv.index])
                                sheetView.insert([.init(value: line, index: nli > idiv.index ? nli - 1 : nli)])
                            } else {
                                sheetView.removeKeyLines([.init(value: [idiv.index], index: nKI)])
                                sheetView.insertKeyLines([.init(value: [.init(value: line, index: nli > idiv.index ? nli - 1 : nli)], index: nKI)])
                            }
                        }
                    }
                    
                    let nids = idivs.map { $0.value.id }
                    sheetView.interpolation(nids.enumerated().map { (i, v) in (v, [v]) },
                                            oldRootKeyframeIndex: oRootKI,
                                            newRootKeyframeIndex: nRootKI,
                                            isNewUndoGroup: isNewUndoGroup)
                    
                    let iNodes = animationView.interpolationNodes(from: nids, scale: scale,
                                                                  oldRootKeyframeIndex: oRootKI,
                                                                  newRootKeyframeIndex: nRootKI)
                    linesNode.children = iNodes + nodes + noNodes
                    
                    sheetView.setRootKeyframeIndex(rootKeyframeIndex: animationView.rootKeyframeIndex)
                    
                    animationView.updateTimeline()
                } else {
                    linesNode.children = noNodes
                }
                
                rootView.node.append(child: linesNode)
            }
        case .changed:
            break
        case .ended:
            linesNode.removeFromParent()
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}
extension SheetView {
    func interpolation(_ ids: [(mainID: UUID, replaceIDs: [UUID])],
                       oldRootKeyframeIndex: Int, newRootKeyframeIndex rki: Int,
                       isNewUndoGroup: Bool) {
        var insertLIVs = [Int: [IndexValue<Line>]]()
        var repLIVs = [Int: [IndexValue<Line>]]()
        
        let kts: [(keyframe: Keyframe, time: Rational)] = model.animation.keyframes.map { ($0, $0.beat) }
        let duration = model.animation.beatRange.length
        let lki = model.animation.index(atRoot: rki)
        
        for (id, repIDs) in ids {
            let repIDSet = Set(repIDs)
            
            var keyAndIs = [(i: Int, key: Interpolation<Line>.Key)]()
            var keyIDic = [Int: Int]()
            for (i, kt) in kts.enumerated() {
                var nLine: Line?
                for line in kt.keyframe.picture.lines {
                    if line.id == id && line.interType != .interpolated {
                        nLine = line
                        break
                    }
                }
                if let nLine {
                    let key = Interpolation.Key(value: nLine, time: Double(kt.time), type: .spline)
                    keyAndIs.append((i, key))
                    keyIDic[i] = keyAndIs.count - 1
                }
            }
            
            guard keyAndIs.count > 1 else {
                if var l = keyAndIs.first?.key.value {
                    l.interType = .interpolated
                    
                    let li = kts[lki].keyframe.picture.lines.firstIndex(where: { $0.id == id })!
                    let upperLineIDs = Set(kts[lki].keyframe.picture.lines[(li + 1)...].map { $0.id })
                    
                    for (i, kt) in kts.enumerated() {
                        guard i != lki else { continue }
                        var isRep = false
                        for (li, line) in kt.keyframe.picture.lines.enumerated() {
                            if line.id == id {
                                if line != l {
                                    let iv = IndexValue(value: l, index: li)
                                    if repLIVs[i] == nil {
                                        repLIVs[i] = [iv]
                                    } else {
                                        repLIVs[i]?.append(iv)
                                    }
                                }
                                isRep = true
                                break
                            }
                        }
                        if !isRep {
                            let ii = kt.keyframe.picture.lines.firstIndex { upperLineIDs.contains($0.id) }
                            ?? kt.keyframe.picture.lines.count
                            
                            if insertLIVs[i] == nil {
                                insertLIVs[i] = [IndexValue(value: l, index: ii)]
                            } else {
                                let count = insertLIVs[i]!.count
                                insertLIVs[i]?.append(.init(value: l, index: ii + count))
                            }
                        }
                    }
                }
                continue
            }
            
            var fki = 0
            for (i, k) in keyAndIs.enumerated().reversed() {
                if lki >= k.i {
                    fki = i
                    break
                }
            }
            
            let loopI: Int, preFKI: Int
            var firstI: Int
            if oldRootKeyframeIndex > rki {
                preFKI = fki + 1 < keyAndIs.count ? fki + 1 : 0
                loopI = keyAndIs[preFKI].i
                firstI = keyAndIs[fki].i
            } else if oldRootKeyframeIndex < rki {
                loopI = keyAndIs[fki].i
                preFKI = fki - 1 >= 0 ? fki - 1 : keyAndIs.count - 1
                firstI = keyAndIs[preFKI].i
            } else {
                preFKI = fki
                loopI = keyAndIs[fki].i
                firstI = keyAndIs[preFKI].i
            }
            var j = firstI - 1 >= 0 ? firstI - 1 : kts.count - 1
            while j != loopI {
                guard let line = kts[j].keyframe.picture.lines.first(where: { $0.id == id }) else { break }
                if line.interType != .interpolated {
                    firstI = j
                }
                j = j - 1 >= 0 ? j - 1 : kts.count - 1
            }
            
            let li = kts[firstI].keyframe.picture.lines.firstIndex(where: { $0.id == id })!
            let upperLineIDs = Set(kts[firstI].keyframe.picture.lines[(li + 1)...].map { $0.id })
            
            var di = 0
            let ranges: [Range<Int>]
            func moveToFirst(count: Int) {
                di += 1
                if keyAndIs.count >= count {
                    var k = keyAndIs[keyAndIs.count - count]
                    k.key.time -= Double(duration)
                    keyAndIs.insert(k, at: 0)
                }
            }
            func moveToLast(count: Int) {
                if keyAndIs.count >= count {
                    var k = keyAndIs[count - 1]
                    k.key.time += Double(duration)
                    keyAndIs.append(k)
                }
            }
            if j == loopI {
                moveToFirst(count: 1)
                moveToFirst(count: 2)
                moveToLast(count: 3)
                moveToLast(count: 4)
                ranges = [0 ..< kts.count]
            } else {
                var lastI = loopI
                var j = loopI + 1 < kts.count ? loopI + 1 : 0
                while j != loopI {
                    guard let line =  kts[j].keyframe.picture.lines.first(where: { $0.id == id }) else { break }
                    if line.interType != .interpolated {
                        lastI = j
                    }
                    j = j + 1 < kts.count ? j + 1 : 0
                }
                let firstKI = keyIDic[firstI]!, lastKI = keyIDic[lastI]!
                if lastI < firstI {
                    var c = 1
                    moveToFirst(count: c)
                    if keyAndIs.count - firstKI > 1 {
                        c += 1
                        moveToFirst(count: c)
                    }
                    c += 1
                    moveToLast(count: c)
                    if lastKI >= 1 {
                        c += 1
                        moveToLast(count: c)
                    }
                    ranges = [0 ..< (lastI + 1),
                              firstI ..< kts.count]
                } else {
                    ranges = [firstI ..< (lastI + 1)]
                }
                for (ki, v) in keyAndIs.enumerated() {
                    if v.i == lastI {
                        keyAndIs[ki].key.type = .step
                    }
                }
            }
            
            for (ki, v) in keyAndIs.enumerated() {
                let nextKI = ki + 1 >= keyAndIs.count ? 0 : ki + 1
                let dki = keyAndIs[nextKI].i - v.i
                if dki > 0 ?
                    dki <= 1 :
                    kts.count - v.i + keyAndIs[nextKI].i <= 1 {
                    keyAndIs[ki].key.type = .step
                }
            }
            
            var line = keyAndIs[.last].key.value
            for (i, key) in keyAndIs.enumerated() {
                let nLine = key.key.value
                let nnLine = nLine.noCrossLine(line)
                keyAndIs[i].key.value = nnLine
                line = nnLine
            }
            
            let interpolation = Interpolation(keys: keyAndIs.map { $0.key },
                                              duration: Double(duration))
            for range in ranges {
                for i in range {
                    let kt = kts[i]
                    
                    if let oki = keyIDic[i] {
                        let ki = oki + di
                        if let li = kt.keyframe.picture.lines
                            .firstIndex(where: { $0.id == id }) {
                            let oLine = kt.keyframe.picture.lines[li]
                            var kLine = keyAndIs[ki].key.value
                            kLine.id = id
                            kLine.interType = .key
                            if oLine != kLine {
                                let iv = IndexValue(value: kLine,
                                                    index: li)
                                if repLIVs[i] == nil {
                                    repLIVs[i] = [iv]
                                } else {
                                    repLIVs[i]?.append(iv)
                                }
                            }
                        }
                        continue
                    }
                    
                    if var line = interpolation.monoValue(withTime: Double(kt.time)) {
                        line.id = id
                        line.interType = .interpolated
                        
                        if let li = kt.keyframe.picture.lines
                            .firstIndex(where: { repIDSet.contains($0.id) }) {
                            if kt.keyframe.picture.lines[li] != line {
                                let iv = IndexValue(value: line,
                                                    index: li)
                                if repLIVs[i] == nil {
                                    repLIVs[i] = [iv]
                                } else {
                                    repLIVs[i]?.append(iv)
                                }
                            }
                        } else {
                            let ii = kt.keyframe.picture.lines.firstIndex { upperLineIDs.contains($0.id) }
                            ?? kt.keyframe.picture.lines.count
                            
                            if insertLIVs[i] == nil {
                                insertLIVs[i] = [IndexValue(value: line, index: ii)]
                            } else {
                                let count = insertLIVs[i]!.count
                                insertLIVs[i]?.append(.init(value: line, index: ii + count))
                            }
                        }
                    }
                }
            }
        }
        let insertValues = insertLIVs.sorted(by: { $0.key < $1.key }).map {
            IndexValue(value: $0.value, index: $0.key)
        }
        
        let repValues = repLIVs.sorted(by: { $0.key < $1.key }).map {
            IndexValue(value: $0.value.sorted(by: { $0.index < $1.index }), index: $0.key)
        }.filter {
            let lines = model.animation.keyframes[$0.index].picture.lines
            return $0.value.contains { lines[$0.index] != $0.value }
        }
        
        if !insertValues.isEmpty || !repValues.isEmpty {
            if isNewUndoGroup {
                newUndoGroup()
            }
            if !repValues.isEmpty {
                replaceKeyLines(repValues)
            }
            if !insertValues.isEmpty {
                if insertValues.allSatisfy({ $0.value.minValue({ $0.index })! >= kts[$0.index].keyframe.picture.lines.count }) {
                    let appendValues = insertValues.map {
                        IndexValue(value: $0.value.map { $0.value }, index: $0.index)
                    }
                    appendKeyLines(appendValues)
                } else {
                    insertKeyLines(insertValues)
                }
            }
        }
    }
}

final class DisconnectAction: InputKeyEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private var linesNode = Node()
    
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
            
            if let sheetView = rootView.sheetView(at: p), sheetView.model.score.enabled {
                let scoreView = sheetView.scoreView
                let scoreP = sheetView.scoreView.convertFromWorld(p)
                if let noteI = sheetView.scoreView.noteIndex(at: scoreP,
                                                             scale: rootView.screenToWorldScale,
                                                             enabledTone: true) {
                    let scoreP = scoreView.convertFromWorld(p)
                    
                    let nis = [noteI]
                    var notes = [Note](), replaceIVs = [IndexValue<Note>]()
                    for noteI in nis {
                        let note = scoreView.model.notes[noteI]
                        let beat = scoreView.beat(atX: scoreP.x,
                                                  interval: rootView.currentBeatInterval) - note.beatRange.start
                        if note.pits.count > 1,
                           beat >= 0 && beat < note.beatRange.length,
                           let pitI = note.pits.enumerated().reversed().first(where: { $0.element.beat <= beat })?.offset,
                           pitI > 0 && pitI + 1 < note.pits.count {
                           
                            let nextPitI = pitI + 1
                            let nPits = note.pits[nextPitI...].map {
                                var nPit = $0
                                nPit.beat -= note.pits[nextPitI].beat
                                return nPit
                            }
                            let nNote0 = Note(beatRange: note.beatRange.start ..< (note.pits[pitI].beat + note.beatRange.start),
                                              pitch: note.pitch,
                                              pits: Array(note.pits[..<pitI]),
                                              spectlopeHeight: note.spectlopeHeight, id: note.id)
                            let nNote1 = Note(beatRange: (note.pits[nextPitI].beat + note.beatRange.start) ..< note.beatRange.end,
                                              pitch: note.pitch,
                                              pits: nPits,
                                              spectlopeHeight: note.spectlopeHeight, id: .init())
                            replaceIVs.append(.init(value: nNote0, index: noteI))
                            notes.append(nNote1)
                        }
                    }
                    if !replaceIVs.isEmpty {
                        sheetView.newUndoGroup()
                        sheetView.replace(replaceIVs)
                        sheetView.append(notes)
                    }
                }
            }
            
            let (_, sheetView, _, _) = rootView.sheetViewAndFrame(at: p)
            if let sheetView = sheetView {
                let inP = sheetView.convertFromWorld(p)
                let lis: [Int], isSelected: Bool
                if rootView.isSelectNoneCursor(at: p), !rootView.isSelectedText {
                    lis = sheetView.lineIndexes(from: rootView.selections)
                    isSelected = true
                } else {
                    if let li = sheetView.lineTuple(at: inP, scale: 1 / rootView.worldToScreenScale)?.lineIndex {
                        lis = [li]
                    } else {
                        lis = []
                    }
                    isSelected = false
                }
                let d = 2 / rootView.worldToScreenScale
                let ids = lis.map { sheetView.model.picture.lines[$0].id }
                if ids.count == 1 && !isSelected {
                    func splitLineIndexValues(with lineView0: SheetLineView, index i0: Int,
                                              lineViews: [SheetLineView]) -> [(iv: LineIndexValue, index: Int)] {
                        var iivs = [(iv: LineIndexValue, index: Int)]()
                        let line0 = lineView0.model
                        iivs += line0.selfIndexValues(extensionLength: Line.defaultLineWidth).compactMap {
                            if line0.length(with: LineRange(startIndexValue: line0.firstIndexValue,
                                                            endIndexValue: $0)) >= d
                                && line0.length(with: LineRange(startIndexValue: $0,
                                                                endIndexValue:line0.lastIndexValue)) >= d {
                                return ($0, i0)
                            } else {
                                return nil
                            }
                        }
                        guard let b0 = lineView0.node.bounds else { return [] }
                        for (i1, lineView1) in lineViews.enumerated() {
                            guard i1 != i0 else { continue }
                            guard let b1 = lineView1.node.bounds, b0.intersects(b1) else { continue }
                            let line1 = lineView1.model
                            let line1e = line1.extensionWith(length: Line.defaultLineWidth)
                            let ivs = line0.indexValues(with: line1e)
                            iivs += ivs.compactMap {
                                if line0.length(with: LineRange(startIndexValue: line0.firstIndexValue,
                                                                endIndexValue: $0.l0)) >= d
                                    && line0.length(with: LineRange(startIndexValue: $0.l0,
                                                                    endIndexValue:line0.lastIndexValue)) >= d {
                                    return ($0.l0, i1)
                                } else {
                                    return nil
                                }
                            }
                        }
                        guard !iivs.isEmpty else { return [] }
                        iivs.sort(by: { $0.iv < $1.iv })
                        return iivs
                    }
                    
                    let id = ids[0], li = lis[0]
                    let lines = sheetView.model.picture.lines
                    let line = lines[li]
                    let iivs = splitLineIndexValues(with: sheetView.linesView.elementViews[li], index: li,
                                                    lineViews: sheetView.linesView.elementViews)
                    let iv = line.nearestIndexValue(at: inP)
                    
                    enum RangeType {
                        case none, first, mid, last
                    }
                    var rangeType = RangeType.none
                    var splitLineIDs = [UUID]()
                    for (i, iiv) in iivs.enumerated() {
                        if iv < iiv.iv {
                            if i == 0 {
                                rangeType = .first
                                let l0 = lines[iiv.index]
                                splitLineIDs = [l0.id]
                                break
                            } else {
                                rangeType = .mid
                                let preIIV = iivs[i - 1]
                                let l0 = lines[preIIV.index]
                                let l1 = lines[iiv.index]
                                splitLineIDs = [l0.id, l1.id]
                                break
                            }
                        }
                    }
                    if splitLineIDs.isEmpty, let iiv = iivs.last {
                        rangeType = .last
                        let l0 = lines[iiv.index]
                        splitLineIDs = [l0.id]
                    }
                    
                    let newLineIDs = splitLineIDs.enumerated().map {
                        $0.offset == 0 ? id : UUID()
                    }
                    var values = [IndexValue<[IndexValue<Line>]>]()
                    var appendValues = [IndexValue<[Line]>]()
                    var removeValues = [IndexValue<[Int]>]()
                    var nodes = [Node]()
                    func append(at ki: Int) -> Bool {
                        let keyframe = keyframes[ki]
                        guard let mli = keyframe.picture.lines.firstIndex(where: { $0.id == id }) else { return false }
                        let mLine = keyframe.picture.lines[mli]
                        let keyframeView = sheetView.animationView.elementViews[ki]
                        let nsivs = splitLineIndexValues(with: keyframeView.linesView.elementViews[mli], index: mli,
                                                         lineViews: keyframeView.linesView.elementViews)
                        let nLines: [Line]
                        switch rangeType {
                        case .none:
                            guard nsivs.isEmpty else { return false }
                            
                            removeValues.append(IndexValue(value: [mli], index: ki))
                            nLines = []
                        case .first:
                            guard !nsivs.isEmpty && splitLineIDs[0] == keyframe.picture.lines[nsivs[0].index].id else { return false }
                            
                            let lr = LineRange(startIndexValue: nsivs[0].iv,
                                               endIndexValue: mLine.lastIndexValue)
                            var nLine = mLine.splited(with: lr)
                            nLine.id = newLineIDs[0]
                            nLine.interType = mLine.interType
                            let value = [IndexValue(value: nLine, index: mli)]
                            values.append(IndexValue(value: value, index: ki))
                            nLines = [nLine]
                        case .mid:
                            var ansiv0, ansiv1: (iv: LineIndexValue, index: Int)?
                            for (i, nsiv0) in nsivs.enumerated() {
                                if splitLineIDs[0] == keyframe.picture.lines[nsiv0.index].id {
                                    ansiv0 = nsiv0
                                    if i + 1 < nsivs.count {
                                        let nsiv1 = nsivs[i + 1]
                                        if splitLineIDs[1] == keyframe.picture.lines[nsiv1.index].id {
                                            ansiv1 = nsiv1
                                        }
                                    }
                                    break
                                }
                            }
                            guard let nnsiv0 = ansiv0, let nnsiv1 = ansiv1 else { return false }
                            
                            let lr0 = LineRange(startIndexValue: mLine.firstIndexValue,
                                                endIndexValue: nnsiv0.iv)
                            let lr1 = LineRange(startIndexValue: nnsiv1.iv,
                                                endIndexValue: mLine.lastIndexValue)
                            var nLine0 = mLine.splited(with: lr0)
                            var nLine1 = mLine.splited(with: lr1)
                            nLine0.id = newLineIDs[0]
                            nLine0.interType = mLine.interType
                            nLine1.id = newLineIDs[1]
                            nLine1.interType = mLine.interType
                            removeValues.append(IndexValue(value: [mli], index: ki))
                            appendValues.append(IndexValue(value: [nLine0, nLine1], index: ki))
                            nLines = [nLine0, nLine1]
                        case .last:
                            guard !nsivs.isEmpty && splitLineIDs[0] == keyframe.picture.lines[nsivs.last!.index].id else { return false }
                            
                            let lr = LineRange(startIndexValue: mLine.firstIndexValue,
                                               endIndexValue: nsivs.last!.iv)
                            var nLine = mLine.splited(with: lr)
                            nLine.id = newLineIDs[0]
                            nLine.interType = mLine.interType
                            let value = IndexValue(value: nLine, index: mli)
                            values.append(IndexValue(value: [value], index: ki))
                            nLines = [nLine]
                        }
                        
                        let line = sheetView.convertToWorld(keyframe.picture.lines[mli])
                        nodes.append(Node(path: Path(line),
                                          lineWidth: 1,
                                          lineType: .color(.removing)))
                        
                        for nLine in nLines {
                            let nnLine = sheetView.convertToWorld(nLine)
                            nodes.append(Node(path: Path(nnLine),
                                              lineWidth: 1,
                                              lineType: .color(.selected)))
                        }
                        
                        return true
                    }
                    
                    let ki = sheetView.model.animation.index
                    let keyframes = sheetView.model.animation.keyframes
                    _ = append(at: ki)
                    var nki = ki + 1 < keyframes.count ? ki + 1 : 0
                    while nki != ki {
                        if !append(at: nki) { break }
                        nki = nki + 1 < keyframes.count ? nki + 1 : 0
                    }
                    if nki != ki {
                        let oki = nki
                        nki = ki - 1 >= 0 ? ki - 1 : keyframes.count - 1
                        while nki != ki && nki != oki {
                            if !append(at: nki) { break }
                            nki = nki - 1 >= 0 ? nki - 1 : keyframes.count - 1
                        }
                    }
                    
                    if !values.isEmpty || !removeValues.isEmpty || !appendValues.isEmpty {
                        sheetView.newUndoGroup()
                        if !values.isEmpty {
                            values.sort(by: { $0.index < $1.index })
                            sheetView.replaceKeyLines(values)
                        }
                        if !removeValues.isEmpty {
                            removeValues.sort(by: { $0.index < $1.index })
                            sheetView.removeKeyLines(removeValues)
                        }
                        if !appendValues.isEmpty {
                            appendValues.sort(by: { $0.index < $1.index })
                            sheetView.appendKeyLines(appendValues)
                        }
                    }
                    
                    linesNode.children = nodes
                    rootView.node.append(child: linesNode)
                    
                    rootAction.updateActionNode()
                    rootView.updateSelects()
                } else if ids.count >= 1 {
                    let keyframes = sheetView.model.animation.keyframes
                    var nodes = [Node]()
                    var livs = [Int: [Int]]()
                    for id in ids {
                        var ranges = [Range<Int>](), fi: Int?
                        for (i, keyframe) in keyframes.enumerated() {
                            if keyframe.picture.lines
                                .contains(where: { $0.id == id }) {
                                if fi == nil {
                                    fi = i
                                }
                            } else if let nfi = fi {
                                ranges.append(nfi ..< i)
                                fi = nil
                            }
                        }
                        if let fi = fi {
                            ranges.append(fi ..< keyframes.count)
                        }
                        
                        let ki = sheetView.model.animation.index
                        for range in ranges {
                            guard range.contains(ki) else { continue }
                            for i in range {
                                let keyframe = keyframes[i]
                                let lis = keyframe.picture.lines.enumerated()
                                    .compactMap { $0.element.id == id ? $0.offset : nil }
                                if !lis.isEmpty {
                                    for i in lis {
                                        let line = sheetView
                                            .convertToWorld(keyframe.picture.lines[i])
                                        nodes.append(Node(path: Path(line),
                                                          lineWidth: 1,
                                                          lineType: .color(.removing)))
                                    }
                                    if livs[i] == nil {
                                        livs[i] = lis
                                    } else {
                                        livs[i]? += lis
                                    }
                                }
                            }
                            break
                        }
                    }
                    
                    for (key, v) in livs {
                        livs[key] = Set(v).sorted()
                    }
                    let values = livs.sorted(by: { $0.key < $1.key }).map {
                        IndexValue(value: $0.value, index: $0.key)
                    }
                    
                    if !values.isEmpty {
                        sheetView.newUndoGroup()
                        sheetView.removeKeyLines(values)
                    }
                    
                    linesNode.children = nodes
                    rootView.node.append(child: linesNode)
                    
                    rootAction.updateActionNode()
                    rootView.updateSelects()
                }
            }
        case .changed:
            break
        case .ended:
            linesNode.removeFromParent()
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}
