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

final class MoveAction: DragEventAction {
    let rootAction: RootAction, rootView: RootView
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
    }
    
    enum MoveType {
        case sheets(MoveSheetsAction)
        case animation(MoveAnimationAction)
        case sheet(MoveSheetAction)
        case line(MoveLineAction)
        case score(MoveScoreAction)
        case content(MoveContentAction)
        case text(MoveTextAction)
        case tempo(MoveTempoAction)
        case border(MoveBorderAction)
        case mainFrame(MoveMainFrameAction)
        case none
    }
    private var type = MoveType.none
    
    func updateNode() {
        switch type {
        case .sheets(let action): action.updateNode()
        case .animation(let action): action.updateNode()
        case .sheet(let action): action.updateNode()
        case .line(let action): action.updateNode()
        case .score(let action): action.updateNode()
        case .content(let action): action.updateNode()
        case .text(let action): action.updateNode()
        case .tempo(let action): action.updateNode()
        case .border(let action): action.updateNode()
        case .mainFrame(let action): action.updateNode()
        case .none: break
        }
    }
    
    var oldTime = 0.0
    func flow(with event: DragEvent) {
        switch event.phase {
        case .began:
            let p = rootView.convertScreenToWorld(event.screenPoint)
            
            if !rootView.isEditingSheet {
                type = .sheets(MoveSheetsAction(rootAction))
            } else if let sheetView = rootView.sheetViewsFromSelectedFrame(at: p).first {
                type = sheetView.model.score.enabled ?
                    .score(MoveScoreAction(rootAction)) :
                    .sheet(MoveSheetAction(rootAction))
            } else if let sheetView = rootView.sheetViewWithSelectedSheetValue(at: p),
                      !sheetView.scoreView.containsNote(sheetView.scoreView.convertFromWorld(p),
                                                           scale: rootView.screenToWorldScale,
                                                           enabledTone: true) {
                type = .sheet(MoveSheetAction(rootAction))
            } else if let sheetView = rootView.sheetView(at: p) {
                let sheetP = sheetView.convertFromWorld(p)
                if sheetView.containsTempo(sheetP, scale: rootView.screenToWorldScale) {
                    type = .tempo(MoveTempoAction(rootAction))
                } else if sheetView.animationView.containsTimeline(sheetView.animationView.timelineNode.convertFromWorld(p), scale: rootView.screenToWorldScale) {
                    type = .animation(MoveAnimationAction(rootAction))
                } else if sheetView.lineTuple(at: sheetP,
                                              scale: rootView.screenToWorldScale) != nil {
                    type = .line(MoveLineAction(rootAction))
                } else if sheetView.textIndex(at: sheetP, scale: rootView.screenToWorldScale) != nil {
                    type = .text(MoveTextAction(rootAction))
                } else if sheetView.contentIndex(at: sheetP, scale: rootView.screenToWorldScale) != nil {
                    type = .content(MoveContentAction(rootAction))
                } else if sheetView.scoreView.contains(sheetView.scoreView.convertFromWorld(p),
                                                       scale: rootView.screenToWorldScale) {
                    type = .score(MoveScoreAction(rootAction))
                } else if rootView.mainFrame(at: p) != nil {
                    type = .mainFrame(MoveMainFrameAction(rootAction))
                } else if rootView.border(at: p) != nil {
                    type = .border(MoveBorderAction(rootAction))
                }
            } else if rootView.mainFrame(at: p) != nil {
                type = .mainFrame(MoveMainFrameAction(rootAction))
            }
            
            oldTime = event.time
        case .changed:
            if event.time - oldTime <= 1 / 70 {
                return
            } else {
                oldTime = oldTime + ((event.time - oldTime) / (1 / 70)).rounded(.down) * 1 / 70
            }
        case .ended: break
        }
        
        switch type {
        case .sheets(let action):
            action.flow(with: event)
        case .animation(let action):
            action.flow(with: event)
        case .sheet(let action):
            action.flow(with: event)
        case .line(let action):
            action.flow(with: event)
        case .score(let action):
            action.flow(with: event)
        case .content(let action):
            action.flow(with: event)
        case .text(let action):
            action.flow(with: event)
        case .tempo(let action):
            action.flow(with: event)
        case .border(let action):
            action.flow(with: event)
        case .mainFrame(let action):
            action.flow(with: event)
        case .none:
            switch event.phase {
            case .began:
                rootView.cursor = .arrowWith(string: "Empty".localized)
            case .changed: break
            case .ended:
                rootView.cursor = rootView.defaultCursor
            }
        }
    }
}

final class MoveSheetsAction: DragEventAction {
    let rootAction: RootAction, rootView: RootView
    
    func updateNode() {
        let lw = Line.defaultLineWidth / rootView.worldToScreenScale
        pasteSheetNode.children.forEach {
            $0.lineWidth = lw
        }
    }
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
    }
    
    private var contentView: SheetContentView? {
        guard let sheetView, let contentI,
              contentI < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentI]
    }
    private var beganContentBeat: Rational = 0, oldContentBeat: Rational = 0
    private let indexInterval = 10.0
    private var oldDeltaI: Int?
    
    private var sheetView: SheetView?, contentI: Int?, beganContent: Content?
    private var beganSP = Point(), beganInP = Point(), beganContentEndP = Point()
    
    private var beganIsShownSpectrogram = false
    var pasteSheetNode = Node(), selectingLineNode = Node(), firstScale = 1.0
    var beganScreenP = Point(), beganP = Point()
    var csv = CopiedSheetsValue(), isNewUndoGroup = false, containsSelectedLastLine = false
    func flow(with event: DragEvent) {
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootAction.closeLookingUpAndStop(at: p)
            
            rootView.isHiddenSelected = true
            
            containsSelectedLastLine = rootView.containsSelectedLastLine(p)
            let (isSelected, vs) = rootView.sheetFramePositions(at: p)
            var csv = CopiedSheetsValue()
            for value in vs {
                if let sid = rootView.sheetID(at: value.shp) {
                    csv.sheetIDs[value.shp] = sid
                }
            }
            if !csv.sheetIDs.isEmpty {
                csv.deltaPoint = p
            }
            self.csv = csv
            if !vs.isEmpty {
                let shps = vs.map { $0.shp }
                rootView.cursorPoint = event.screenPoint
                rootView.close(from: shps)
                isNewUndoGroup = true
                rootView.newUndoGroup()
                if !isSelected && !rootView.world.selection.isEmpty {
                    rootView.doSet(WorldSelection.empty)
                }
                rootView.removeSheets(at: shps)
            } else {
                if !isSelected && !rootView.world.selection.isEmpty {
                    isNewUndoGroup = true
                    rootView.newUndoGroup()
                    rootView.doSet(WorldSelection.empty)
                }
                rootView.cursor = .arrowWith(string: "Empty".localized)
            }
            
            firstScale = rootView.worldToScreenScale
            beganScreenP = event.screenPoint
            beganP = p
            selectingLineNode.fillType = .color(.subSelected)
            selectingLineNode.lineType = .color(.selected)
            selectingLineNode.lineWidth = rootView.worldLineWidth
            
            rootView.node.append(child: selectingLineNode)
            
            let lw = Line.defaultLineWidth / rootView.worldToScreenScale
            pasteSheetNode.children = csv.sheetIDs.map {
                let fillType = rootView.readFillType(at: $0.value)
                    ?? .color(.disabled)
                
                let sf = rootView.sheetFrame(with: $0.key)
                return Node(attitude: Attitude(position: sf.origin),
                            path: Path(Rect(size: sf.size)),
                            lineWidth: lw,
                            lineType: .color(.selected), fillType: fillType)
            }
            rootView.node.append(child: pasteSheetNode)
            
            updateWithPasteSheet(at: event.screenPoint, phase: event.phase)
        case .changed:
            updateWithPasteSheet(at: event.screenPoint, phase: event.phase)
        case .ended:
            rootView.isHiddenSelected = false
            
            pasteSheet(at: event.screenPoint)
            selectingLineNode.removeFromParent()
            pasteSheetNode.removeFromParent()
            
            rootView.updateSelected()
            rootView.updateWithFinding()
            
            rootView.cursor = rootView.defaultCursor
        }
    }
    func updateWithPasteSheet(at sp: Point, phase: Phase) {
        zip(csv.sheetIDs, pasteSheetNode.children).forEach { (sheetID, node) in
            let sf = rootView.sheetFrame(with: sheetID.key)
            node.attitude = Attitude(position: sf.origin)
        }
        
        let p = rootView.convertScreenToWorld(sp)
        var children = [Node]()
        for (shp, _) in csv.sheetIDs {
            var sf = rootView.sheetFrame(with: shp)
            sf.origin += p - csv.deltaPoint
            let nshp = rootView.sheetPosition(at: Point(Sheet.width / 2, Sheet.height / 2) + sf.origin)
            let nsf = Rect(origin: rootView.sheetFrame(with: nshp).origin,
                          size: sf.size)
            let lw = Line.defaultLineWidth / rootView.worldToScreenScale
            children.append(Node(attitude: Attitude(position: nsf.origin),
                                 path: Path(Rect(size: nsf.size)),
                                 lineWidth: lw,
                                 lineType: selectingLineNode.lineType,
                                 fillType: selectingLineNode.fillType))
        }
        selectingLineNode.children = children
        
        pasteSheetNode.attitude.position = p - csv.deltaPoint
    }
    func pasteSheet(at sp: Point) {
        rootView.cursorPoint = sp
        let p = rootView.convertScreenToWorld(sp)
        var nIndexes = [IntPoint: UUID]()
        var removeIndexes = [IntPoint]()
        for (shp, sid) in csv.sheetIDs {
            var sf = rootView.sheetFrame(with: shp)
            sf.origin += p - csv.deltaPoint
            let nshp = rootView.sheetPosition(at: Point(Sheet.width / 2, Sheet.height / 2) + sf.origin)
            
            if rootView.sheetID(at: nshp) != nil {
                removeIndexes.append(nshp)
            }
            if rootView.sheetPosition(at: sid) != nil {
                nIndexes[nshp] = rootView.duplicateSheet(from: sid)
            } else {
                nIndexes[nshp] = sid
            }
        }
        if !removeIndexes.isEmpty || !nIndexes.isEmpty {
            if !isNewUndoGroup {
                rootView.newUndoGroup()
            }
            if !removeIndexes.isEmpty {
                rootView.removeSheets(at: removeIndexes)
            }
            if !nIndexes.isEmpty {
                rootView.append(nIndexes)
            }
            rootView.updateNode()
            
            if !rootView.world.selection.isEmpty, rootView.world.selection.lastPosition != nil {
                var selection = rootView.world.selection
                selection.lastPosition = containsSelectedLastLine ?
                selection.lastPosition! + p - beganP : nil
                rootView.doSet(selection)
            }
        }
        
//        if !rootView.world.selection.isEmpty {
//            rootView.newUndoGroup()
//            rootView.doSet(WorldSelection.empty)
//        }
    }
}

final class MoveAnimationAction: DragEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    enum SlideType {
        case key, all, startBeat, endBeat, loopDurBeat, previousNext, none
    }
    
    private let indexInterval = 10.0
    
    private var node = Node()
    private var sheetView: SheetView?, animationIndex = 0, keyframeIndex = 0
    private var type = SlideType.key
    private var beganSP = Point(), beganSheetP = Point(), beganKeyframeOptions = [Int: KeyframeOption](), maxBeat = Rational(0),
                beganTimelineX = 0.0, beganKeyframeX = 0.0, beganBeatX = 0.0,
                beganKeyframeBeat = Rational(0), beganRootBeatIndex = Animation.RootBeatIndex()
    private var oldPnP: Point?, beganKeyframeOption: KeyframeOption?
    private var beganAnimationOption: AnimationOption?
    private var minLastSec = 1 / 12.0
    private var isNewUndoGroup = true
    
    func flow(with event: DragEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootAction.closeLookingUpAndStop(at: p)
            
            if let sheetView = rootView.sheetView(at: p), sheetView.model.enabledAnimation {
                beganSP = event.screenPoint
                self.sheetView = sheetView
                sheetView.hideSelected()
                
                let sheetP = sheetView.convertFromWorld(p)
                beganSheetP = sheetP
                beganTimelineX = sheetView.animationView
                    .x(atBeat: sheetView.animationView.model.beatRange.start)
                beganRootBeatIndex = sheetView.animationView.model.rootBeatIndex
                let timelineP = sheetView.animationView.timelineNode.convertFromWorld(p)
                if sheetView.animationView.containsTimeline(timelineP, scale: rootView.screenToWorldScale) {
                    let animationView = sheetView.animationView
                    
                    func unselect() {
                        if !sheetView.model.selection.isEmpty {
                            sheetView.newUndoGroup()
                            isNewUndoGroup = false
                            sheetView.doSet(SheetSelection.empty)
                        }
                    }
                    
                    let result = animationView.hitTest(timelineP, scale: rootView.screenToWorldScale)
                    switch result {
                    case .key(let minI):
                        type = .key
                        
                        keyframeIndex = minI
                        let keyframe = animationView.model.keyframes[keyframeIndex]
                        beganKeyframeBeat = keyframe.beat
                        beganKeyframeX = animationView.x(atBeat: animationView.model.localBeat(at: minI))
                        
                        if animationView.selectedIs.contains(keyframeIndex) {
                            beganKeyframeOptions = animationView.selectedIs.reduce(into: .init()) {
                                $0[$1] = animationView.model.keyframes[$1].option
                            }
                        } else {
                            unselect()
                            beganKeyframeOptions = [keyframeIndex: keyframe.option]
                        }
                        
                        rootView.cursor = rootView.cursor(from: sheetView.timeString(fromBeat: keyframe.beat + sheetView.model.animation.option.beatRange.start),
                                                          isArrow: true)
                    case .previousNext(_):
                        type = .previousNext
                        
                        unselect()
                        
                        beganAnimationOption = sheetView.model.animation.option
                        
                        rootView.cursor = .arrowWith(string: animationView.previousNext.displayName)
                    case .startBeat:
                        type = .startBeat
                        
                        unselect()
                        
                        beganAnimationOption = sheetView.model.animation.option
                        beganBeatX = animationView.x(atBeat: sheetView.model.animation.beatRange.start)
                        
                        if sheetView.model.animation.keyframes.count >= 2 {
                            beganKeyframeOptions = (1 ..< animationView.model.keyframes.count).reduce(into: .init()) {
                                $0[$1] = animationView.model.keyframes[$1].option
                            }
                            maxBeat = animationView.model.keyframes[1].beat
                            + sheetView.model.animation.beatRange.start
                        } else {
                            maxBeat = sheetView.model.animation.beatRange.end
                        }
                        
                        rootView.cursor = rootView.cursor(from: sheetView.timeString(fromBeat: sheetView.model.animation.beatRange.start),
                                                          isArrow: true)
                    case .endBeat:
                        type = .endBeat
                        
                        unselect()
                        
                        beganAnimationOption = sheetView.model.animation.option
                        beganBeatX = animationView.x(atBeat: sheetView.model.animation.beatRange.end)
                        
                        rootView.cursor = rootView.cursor(from: sheetView.timeString(fromBeat: sheetView.model.animation.beatRange.end),
                                                          isArrow: true)
                    case .loopDurBeat:
                        type = .loopDurBeat
                        
                        unselect()
                        
                        beganAnimationOption = sheetView.model.animation.option
                        beganBeatX = animationView.x(atBeat: sheetView.model.animation.endLoopDurBeat)
                        
                        rootView.cursor = rootView.cursor(from: sheetView.timeString(fromBeat: sheetView.model.animation.endLoopDurBeat) + " " + "Loop".localized,
                                                          isArrow: true)
                    case .all:
                        type = .all
                        
                        unselect()
                        
                        beganAnimationOption = sheetView.model.animation.option
                        
                        rootView.cursor = rootView.cursor(from: sheetView.timeString(fromBeat: sheetView.model.animation.option.beatRange.start),
                                                          isArrow: true)
                    }
                }
            }
        case .changed:
            if let sheetView = sheetView {
                let animationView = sheetView.animationView
                let sheetP = sheetView.convertFromWorld(p)
                
                switch type {
                case .all:
                    let nh = Sheet.pitchHeight
                    let np = beganTimelineX + sheetP - beganSheetP
                    let py = ((beganAnimationOption?.timelineY ?? 0) + sheetP.y - beganSheetP.y).interval(scale: nh)
                        .clipped(min: Sheet.timelineY, max: sheetView.bounds.height - Sheet.timelineY)
                    let interval = rootView.currentBeatInterval
                    let beat = max(min(sheetView.animationView.beat(atX: np.x, interval: interval),
                                   sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval)),
                                   sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval) - sheetView.animationView.model.beatRange.length)
                    let isChangeBeat = beat != sheetView.model.animation.beatRange.start
                    if py != sheetView.animationView.timelineY || isChangeBeat {
                        
                        sheetView.binder[keyPath: sheetView.keyPath].animation.beatRange.start = beat
                        sheetView.binder[keyPath: sheetView.keyPath].animation.timelineY = py
                        sheetView.animationView.updateTimeline()
                        
                        rootView.cursor = rootView.cursor(from: sheetView.timeString(fromBeat: beat),
                                                          isArrow: true)
                    }
                case .startBeat:
                    let interval = rootView.currentKeyframeBeatInterval
                    let beat = min(animationView.beat(atX: sheetP.x,
                                                  interval: interval),
                                   maxBeat)
                    if let beganAnimationOption,
                        beat != sheetView.model.animation.beatRange.start {
                        
                        sheetView.binder[keyPath: sheetView.keyPath]
                            .animation.beatRange = beat ..< beganAnimationOption.beatRange.end
                        sheetView.binder[keyPath: sheetView.keyPath].animation
                            .keyframes[0].beat = 0
                        
                        if sheetView.model.animation.keyframes.count >= 2 {
                            let dBeat = -(beat - beganAnimationOption.beatRange.start)
                            beganKeyframeOptions.forEach {
                                sheetView.binder[keyPath: sheetView.keyPath].animation
                                    .keyframes[$0.key].beat = $0.value.beat + dBeat
                            }
                        }
                        
                        animationView.rootBeatIndex = beganRootBeatIndex
                        
                        sheetView.animationView.updateTimeline()
                        
                        rootView.cursor = rootView.cursor(from: sheetView.timeString(fromBeat: beat),
                                                          isArrow: true)
                    }
                case .endBeat:
                    if let beganAnimationOption {
                        let interval = rootView.currentBeatInterval
                        let nBeat = max(animationView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                       interval: interval),
                                        animationView.model.keyframes.last!.beat + beganAnimationOption.beatRange.start)
                        if nBeat != animationView.beatRange?.end {
                            let dBeat = nBeat - beganAnimationOption.beatRange.end
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval)
                            let nkBeat = max(beganAnimationOption.beatRange.end + dBeat, startBeat)
                            
                            animationView.beatRange?.end = nkBeat
                        }
                        
                        animationView.rootBeatIndex = beganRootBeatIndex
                        
                        rootView.cursor = rootView.cursor(from: sheetView.timeString(fromBeat: sheetView.model.animation.beatRange.end),
                                                          isArrow: true)
                    }
                case .loopDurBeat:
                    if let beganAnimationOption {
                        let interval = rootView.currentBeatInterval
                        let nBeat = animationView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                       interval: interval)
                        if nBeat != animationView.endLoopDurBeat {
                            let dBeat = nBeat - beganAnimationOption.endLoopDurBeat
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval)
                            let nkBeat = max(beganAnimationOption.endLoopDurBeat + dBeat, startBeat)
                            
                            animationView.endLoopDurBeat = nkBeat
                        }
                        
                        rootView.cursor = rootView.cursor(from: sheetView.timeString(fromBeat: sheetView.model.animation.endLoopDurBeat) + " " + "Loop".localized,
                                                          isArrow: true)
                    }
                case .previousNext:
                    animationView.previousNext = animationView.previousNext(at: sheetP)
                    rootView.cursor = .arrowWith(string: animationView.previousNext.displayName)
                case .key:
                    let interval = rootView.currentKeyframeBeatInterval
                    let durBeat = animationView.model.beatRange.length
                    let beat = animationView.beat(atX: beganKeyframeX + sheetP.x - beganSheetP.x, interval: interval)
                        .clipped(min: 0, max: durBeat)
                    let oldBeat = animationView.model.keyframes[keyframeIndex].beat
                    if oldBeat != beat && !beganKeyframeOptions.isEmpty {
                        let rootBeatIndex = animationView.model.rootBeatIndex
                        
                        let dBeat = beat - beganKeyframeBeat
                        let kos = beganKeyframeOptions.sorted { $0.key < $1.key }
                        func clippedDBeat() -> Rational {
                            let keyframes = animationView.model.keyframes
                            var preI = 0, minPreDBeat = Rational.max, minNextDBeat = Rational.max
                            while preI < kos.count {
                                var nextI = preI
                                while nextI + 1 < kos.count {
                                    if nextI + 1 < kos.count && kos[nextI].key + 1 != kos[nextI + 1].key { break }
                                    nextI += 1
                                }
                                let preKI = kos[preI].key, nextKI = kos[nextI].key
                                let preDBeat = kos[preI].value.beat - (preKI - 1 >= 0 ? keyframes[preKI - 1].beat : 0)
                                let nextDBeat = (nextKI + 1 < keyframes.count ? keyframes[nextKI + 1].beat : durBeat) - kos[nextI].value.beat
                                minPreDBeat = min(preDBeat, minPreDBeat)
                                minNextDBeat = min(nextDBeat, minNextDBeat)
                                
                                preI = nextI + 1
                            }
                            return dBeat.clipped(min: -minPreDBeat, max: minNextDBeat)
                        }
                        let nDBeat = clippedDBeat()
                        kos.forEach {
                            sheetView.binder[keyPath: sheetView.keyPath].animation
                                .keyframes[$0.key].beat = $0.value.beat + nDBeat
                        }
                        
                        sheetView.rootBeatIndex = rootBeatIndex
                        sheetView.animationView.updateTimeline()
                        
                        rootView.cursor = rootView.cursor(from: sheetView.timeString(fromBeat: beat + sheetView.model.animation.option.beatRange.start),
                                                          isArrow: true)
                    }
                case .none: break
                }
            }
        case .ended:
            node.removeFromParent()
            
            if let sheetView {
                sheetView.showSelected()
                
                func updateUndoGroup() {
                    if isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = false
                    }
                }
                func updateKeyframe() {
                    let animationView = sheetView.animationView
                    let okos = beganKeyframeOptions
                        .filter { animationView.model.keyframes[$0.key].option != $0.value }
                        .sorted { $0.key < $1.key }
                        .map { IndexValue(value: $0.value, index: $0.key) }
                    if !okos.isEmpty {
                        let kos = okos.map {
                            IndexValue(value: animationView.model.keyframes[$0.index].option, index: $0.index)
                        }
                        updateUndoGroup()
                        sheetView.capture(kos, old: okos)
                    }
                }
                switch type {
                case .all, .startBeat, .endBeat, .loopDurBeat, .previousNext:
                    if let beganAnimationOption, sheetView.model.animation.option != beganAnimationOption {
                        updateUndoGroup()
                        sheetView.capture(option: sheetView.model.animation.option,
                                          oldOption: beganAnimationOption)
                    }
                    if type == .startBeat {
                        updateKeyframe()
                    }
                case .key:
                    updateKeyframe()
                case .none: break
                }
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MoveScoreAction: DragEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    enum SlideType {
        case keyBeats, allBeat, endBeat, loopDurBeat, isShownSpectrogram, scale,
             startNoteBeat, endNoteBeat, note,
             pit, strightPit,
             even, sprol, spectlopeHeight, f0
    }
    
    private let editableInterval = 5.0
    private let editableTempoInterval = 10.0
    
    private var node = Node()
    private var notePlayer: NotePlayer?
    private var sheetView: SheetView?
    private var type: SlideType?
    private var beganScreenP = Point(), beganP = Point(),
                beganTime = Rational(0), beganSheetP = Point()
    private var beganLocalStartPitch = Rational(0), secI = 0, noteI: Int?, pitI: Int?, keyBeatI: Int?,
                beganBeatRange: Range<Rational>?,
                playerBeatNoteIndexes = [Int](),
                beganDeltaNoteBeat = Rational(),
                oldPitch: Rational?, oldBeat: Rational?, octaveNode: Node?,
                minScorePitch = Rational(0), maxScorePitch = Rational(0)
    private var beganStartBeat = Rational(0), beganPitch = Rational(0),  beganBeatX = 0.0, beganPitchY = 0.0, beganF0Pitch = Rational(0)
    private var beganTone = Tone(), beganOvertone = Overtone()
    private var sprolI: Int?, beganSprol = Sprol()
    private var beganScoreOption: ScoreOption?
    private var beganNotes = [Int: Note]()
    private var beganNote: Note?, beganPit: Pit?, beganBeat = Rational(0)
    private var preStrightPitI, nextStrightPitI: Int?
    private var beganNotePits = [Int: (note: Note, pit: Pit, pits: [Int: Pit])]()
    private var beganSprolPitch = 0.0, beganSpectlopeY = 0.0
    private var beganNoteSprols = [UUID: (nid: UUID, dic: [Int: (note: Note, pits: [Int: (pit: Pit, sprolIs: Set<Int>)])])]()
    private var isNewUndoGroup = true, containsSelectedLastLine = false
    
    func flow(with event: DragEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootAction.closeLookingUpAndStop(at: p)
            
            let shp = rootView.sheetPositionFromSelectedFrame(at: p)
            ?? rootView.sheetPosition(at: p)
            if let sheetView = rootView.sheetView(at: shp), sheetView.model.score.enabled {
                let sheetP = sheetView.convertFromWorld(p)
                containsSelectedLastLine = sheetView.containsSelectedLastLine(sheetP, scale: rootView.screenToWorldScale)
                let containsSelectedFrame
                = sheetView.containsSelectedFrame(sheetP, scale: rootView.screenToWorldScale)
                || containsSelectedLastLine
                
                let scoreView = sheetView.scoreView
                let score = scoreView.model
                
                beganScreenP = event.screenPoint
                beganP = p
                beganSheetP = sheetP
                self.sheetView = sheetView
                sheetView.hideSelected()
                
                beganTime = sheetView.animationView.beat(atX: sheetP.x)
                
                func updatePlayer(from vs: [Note.PitResult], in sheetView: SheetView) {
                    if let notePlayer = sheetView.notePlayer {
                        self.notePlayer = notePlayer
                        notePlayer.notes = vs
                    } else {
                        notePlayer = try? NotePlayer(notes: vs)
                        sheetView.notePlayer = notePlayer
                    }
                    notePlayer?.play()
                }
                
                let scoreP = scoreView.convert(sheetP, from: sheetView.node)
                let v = scoreView.hitTestPoint(scoreP, scale: rootView.screenToWorldScale)
                let containsSelectedNote = containsSelectedFrame
                || sheetView.containsSelectedNote(sheetP, scale: rootView.screenToWorldScale)
                if !containsSelectedNote {
                    if !sheetView.model.selection.isEmpty {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = false
                        sheetView.doSet(SheetSelection.empty)
                        rootView.updateSelectedFrame()
                    }
                }
                if !(v?.result.isStartEndBeat ?? false)
                    && containsSelectedNote
                    && (v?.result.isNote ?? true) {
                    
                    let noteIs = scoreView.selectedNoteIs
                    beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                    let interval = rootView.currentBeatInterval
                    let nBeat: Rational = scoreView.beat(atX: sheetP.x)
                    
                    let minBV = beganNotes.min(by: { $0.value.beatRange.start < $1.value.beatRange.start })!
                    let maxBV = beganNotes.max(by: { $0.value.beatRange.end < $1.value.beatRange.end })!
                    let minBeat = minBV.value.beatRange.start
                    let maxBeat = maxBV.value.beatRange.end
                    let noteI = !beganNotes.contains(where: { nBeat >= $0.value.beatRange.start }) ?
                    minBV.key :
                    (!beganNotes.contains(where: { nBeat < $0.value.beatRange.end }) ? maxBV.key : beganNotes.min(by: { $0.value.beatRange.distance(nBeat) < $1.value.beatRange.distance(nBeat) })!.key)
                    let nsBeat = scoreView.beat(atX: sheetP.x, interval: interval)
                    let score = scoreView.model
                    let note = score.notes[noteI]
                    
                    beganStartBeat = nsBeat
                    beganNote = note
                    
                    self.noteI = noteI
                    type = .note
                    beganPitch = note.pitch
                    
                    let isInterval = note.pits.contains(where: { ($0.beat + note.beatRange.start) % EditGrid.beatInterval == 0 })
                    let dBeat = isInterval ? (note.beatRange.start - note.beatRange.start.interval(scale: interval)) : 0
                    beganDeltaNoteBeat = dBeat
                    
                    beganBeatRange = note.beatRange
                    oldPitch = note.pitch
                    beganBeatX = scoreView.x(atBeat: note.beatRange.start)
                    beganPitchY = scoreView.y(fromPitch: note.pitch)
                    
                    beganNotes[noteI] = score.notes[noteI]
                    
                    let playerBeat: Rational = nsBeat.clipped(min: minBeat, max: maxBeat)
                    let vs = score.noteIAndNormarizedPits(atBeat: playerBeat, selectedNoteI: noteI, in: noteIs)
                    playerBeatNoteIndexes = vs.map { $0.noteI }
                    
                    updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
                    
                    let octaveNode = scoreView.octaveNode(noteIs: beganNotes.keys.sorted())
                    octaveNode.attitude.position
                    = sheetView.convertToWorld(scoreView.node.attitude.position)
                    self.octaveNode = octaveNode
                    rootView.node.append(child: octaveNode)
                    
                    let result = note.pitResult(atBeat: Double(nsBeat - note.beatRange.start))
                    let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: EditGrid.fullEditBeatInterval)
                    
                    let dSecStr = scoreView.isFullEdit ?
                    "\n"
                    + Duration.msString(fromSec: Double(scoreView.model.sec(fromBeat: dBeat)))
                     : ""
                    rootView.cursor = .arrowWith(string: Pitch(value: cPitch).displayString() + dSecStr)
                } else if let (noteI, result) = v {
                    self.noteI = noteI
                    
                    let score = scoreView.model
                    let note = score.notes[noteI]
                    let interval = rootView.currentBeatInterval
                    let nsBeat = scoreView.beat(atX: sheetP.x, interval: interval)
                    beganStartBeat = nsBeat
                    beganNote = note
                    
                    let selectedNoteIs = if containsSelectedNote {
                        scoreView.selectedNoteIs
                    } else {
                        [noteI]
                    }
                    
                    switch result {
                    case .pit(let pitI), .lyric(let pitI):
                        type = scoreView.isStraightWithSelection(atPit: pitI, atNote: noteI) ? .strightPit : .pit
                        
                        let pit = note.pits[pitI]
                        self.pitI = pitI
                        beganPit = pit
                        
                        beganPitch = note.pitch + pit.pitch
                        oldPitch = beganPitch
                        beganBeat = note.beatRange.start + pit.beat
                        oldBeat = beganBeat
                        beganBeatX = scoreView.x(atBeat: note.beatRange.start + pit.beat)
                        beganPitchY = scoreView.y(fromPitch: note.pitch + pit.pitch)
                        
                        let playerBeat = beganBeat
                        
                        var noteAndPitIs: [Int: [Int]]
                        if case .lyric = result {
                            let note = score.notes[noteI]
                            noteAndPitIs = [noteI: note.lyricRange(at: pitI)?.map { $0 } ?? [pitI]]
                        } else if type == .strightPit {
                            let note = score.notes[noteI]
                            var pitIs = [pitI]
                            if pitI > 0 && (note.pits[pitI - 1].beat == note.pits[pitI].beat
                                            || note.pits[pitI - 1].pitch == note.pits[pitI].pitch) {
                                pitIs.append(pitI - 1)
                                preStrightPitI = pitI - 1
                            }
                            if pitI + 1 < note.pits.count && (note.pits[pitI + 1].pitch == note.pits[pitI].pitch
                                                              || note.pits[pitI + 1].beat == note.pits[pitI].beat) {
                                pitIs.append(pitI + 1)
                                nextStrightPitI = pitI + 1
                            }
                            noteAndPitIs = [noteI: pitIs]
                        } else if containsSelectedNote {
                            noteAndPitIs = scoreView.selectedNotePitIs
                            if noteAndPitIs[noteI] != nil {
                                if !noteAndPitIs[noteI]!.contains(pitI) {
                                    noteAndPitIs[noteI]?.append(pitI)
                                }
                            } else {
                                noteAndPitIs[noteI] = [pitI]
                            }
                        } else {
                            noteAndPitIs = [noteI: [pitI]]
                        }
                        
                        beganNotePits = noteAndPitIs.reduce(into: .init()) { (nv, nap) in
                            let pitDic = nap.value.reduce(into: [Int: Pit]()) { (v, pitI) in
                                v[pitI] = score.notes[nap.key].pits[pitI]
                            }
                            nv[nap.key] = (score.notes[nap.key], pit, pitDic)
                        }
                        
                        let noteIs = Set(beganNotePits.keys).intersection(selectedNoteIs).sorted()
                        let vs = score.noteIAndNormarizedPits(atBeat: playerBeat, selectedNoteI: noteI, in: noteIs)
                        playerBeatNoteIndexes = vs.map { $0.noteI }
                        
                        updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
                        
                        let octaveNode = scoreView.octaveNode(noteIs: [noteI])
                        octaveNode.attitude.position
                        = sheetView.convertToWorld(scoreView.node.attitude.position)
                        self.octaveNode = octaveNode
                        rootView.node.append(child: octaveNode)
                                                 
                        rootView.cursor = .arrowWith(string: Pitch(value: beganPitch).displayString())
                        
                    case .even(let pitI):
                        type = .even
                        
                        let pit = note.pits[pitI]
                    
                        self.pitI = pitI
                        beganPit = pit
                        
                        beganBeat = note.beatRange.start + pit.beat
                        oldBeat = beganBeat
                        beganBeatX = scoreView.x(atBeat: note.beatRange.start + pit.beat)
                        
                        var noteAndPitIs: [Int: [Int]]
                        if containsSelectedNote {
                            noteAndPitIs = sheetView.scoreView.selectedNotePitIs
                            if noteAndPitIs[noteI] != nil {
                                if !noteAndPitIs[noteI]!.contains(pitI) {
                                    noteAndPitIs[noteI]?.append(pitI)
                                }
                            } else {
                                noteAndPitIs[noteI] = [pitI]
                            }
                        } else {
                            noteAndPitIs = [noteI: [pitI]]
                        }
                        
                        beganNotePits = noteAndPitIs.reduce(into: .init()) { (nv, nap) in
                            let pitDic = nap.value.reduce(into: [Int: Pit]()) { (v, pitI) in
                                v[pitI] = score.notes[nap.key].pits[pitI]
                            }
                            nv[nap.key] = (score.notes[nap.key], pit, pitDic)
                        }
                    case .sprol(let pitI, let sprolI, let spectlopeY):
                        type = .sprol
                        
                        beganTone = score.notes[noteI].pits[pitI].tone
                        self.sprolI = sprolI
                        self.beganSpectlopeY = spectlopeY
                        beganBeat = note.pits[pitI].beat + note.beatRange.start
                        self.beganSprol = beganTone.spectlope.sprols[sprolI]
//                        self.beganSprol = scoreView.nearestSprol(at: scoreP, at: noteI)
                        self.beganSprolPitch = scoreView.spectlopePitch(at: scoreP, at: noteI, y: spectlopeY)
                        self.noteI = noteI
                        self.pitI = pitI
                        
                        func updatePitsWithSelection() {
                            var notePitSprolIs: [Int: [Int: Set<Int>]]
                            if containsSelectedNote {
                                notePitSprolIs = scoreView.selectedNotePitSprolIs
                            } else {
                                let id = score.notes[noteI].pits[pitI][.tone]
                                notePitSprolIs = score.notes.enumerated().reduce(into: [Int: [Int: Set<Int>]]()) {
                                    $0[$1.offset] = $1.element.pits.enumerated().reduce(into: [Int: Set<Int>]()) { (v, ip) in
                                        if ip.element[.tone] == id {
                                            v[ip.offset] = sprolI < ip.element.tone.spectlope.count ? [sprolI] : []
                                        }
                                    }
                                }
                            }
                            
                            beganNoteSprols = notePitSprolIs.reduce(into: .init()) {
                                for (pitI, sprolIs) in $1.value {
                                    let pit = score.notes[$1.key].pits[pitI]
                                    let id = pit[.tone]
                                    if $0[id] != nil {
                                        if $0[id]!.dic[$1.key] != nil {
                                            $0[id]!.dic[$1.key]!.pits[pitI] = (pit, sprolIs)
                                        } else {
                                            $0[id]!.dic[$1.key] = (score.notes[$1.key], [pitI: (pit, sprolIs)])
                                        }
                                    } else {
                                        $0[id] = (UUID(), [$1.key: (score.notes[$1.key], [pitI: (pit, sprolIs)])])
                                    }
                                }
                            }
                        }
                        
                        updatePitsWithSelection()
                        
                        let noteIs = Set(beganNoteSprols.values.flatMap { $0.dic.keys }).intersection(selectedNoteIs).sorted()
                        let vs = score.noteIAndNormarizedPits(atBeat: beganBeat, selectedNoteI: noteI, in: noteIs)
                        playerBeatNoteIndexes = vs.map { $0.noteI }
                        
                        updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
                        
                        rootView.cursor = .arrowWith(string: Pitch(value: .init(beganTone.spectlope.sprols[sprolI].pitch, intervalScale: EditGrid.fullEditPitchInterval)).displayString(hidableDecimal: false))
                    case .allSprol(let sprolI, let sprol, let spectlopeY):
                        type = .sprol
                        
                        beganBeat = scoreView.beat(atX: scoreP.x)
                        beganTone = score.notes[noteI].pitResult(atBeat: Double(beganBeat)).tone
                        self.sprolI = sprolI
                        self.beganSpectlopeY = spectlopeY
                        self.beganSprol = sprol
//                        self.beganSprol = scoreView.nearestSprol(at: scoreP, at: noteI)
                        self.beganSprolPitch = scoreView.spectlopePitch(at: scoreP, at: noteI, y: spectlopeY)
                        self.noteI = noteI
                        
                        func updatePitsWithSelection() {
                            var noteAndPitIs: [Int: [Int: Set<Int>]]
                            if containsSelectedNote {
                                noteAndPitIs = scoreView.selectedNotePitSprolIs
                            } else {
                                if let pitI {
                                    let id = score.notes[noteI].pits[pitI].tone.id
                                    noteAndPitIs = score.notes.enumerated().reduce(into: [Int: [Int: Set<Int>]]()) {
                                        $0[$1.offset] = $1.element.pits.enumerated().reduce(into: [Int: Set<Int>]()) { (v, ip) in
                                            if ip.element.tone.id == id {
                                                v[ip.offset] = sprolI < ip.element.tone.spectlope.count ? [sprolI] : []
                                            }
                                        }
                                    }
                                } else {
                                    noteAndPitIs = [noteI: score.notes[noteI].pits.enumerated().reduce(into: [Int: Set<Int>]()) { (v, ip) in
                                        v[ip.offset] = sprolI < ip.element.tone.spectlope.count ? [sprolI] : []
                                    }]
                                }
                            }
                            
                            beganNoteSprols = noteAndPitIs.reduce(into: .init()) {
                                for (pitI, sprolIs) in $1.value {
                                    let pit = score.notes[$1.key].pits[pitI]
                                    let id = pit.tone.id
                                    if $0[id] != nil {
                                        if $0[id]!.dic[$1.key] != nil {
                                            $0[id]!.dic[$1.key]!.pits[pitI] = (pit, sprolIs)
                                        } else {
                                            $0[id]!.dic[$1.key] = (score.notes[$1.key], [pitI: (pit, sprolIs)])
                                        }
                                    } else {
                                        $0[id] = (UUID(), [$1.key: (score.notes[$1.key], [pitI: (pit, sprolIs)])])
                                    }
                                }
                            }
                        }
                        
                        updatePitsWithSelection()
                        
                        let noteIs = Set(beganNoteSprols.values.flatMap { $0.dic.keys }).intersection(selectedNoteIs).sorted()
                        let vs = score.noteIAndNormarizedPits(atBeat: beganBeat, selectedNoteI: noteI, in: noteIs)
                        playerBeatNoteIndexes = vs.map { $0.noteI }
                        
                        updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
                        
                        rootView.cursor = .arrowWith(string: Pitch(value: .init(sprol.pitch, intervalScale: EditGrid.fullEditPitchInterval)).displayString(hidableDecimal: false))
                    case .spectlopeHeight:
                        type = .spectlopeHeight
                        
                        self.noteI = noteI
                        
                        if containsSelectedNote {
                            let noteIs = scoreView.selectedNoteIs
                            beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                        }
                        beganNotes[noteI] = score.notes[noteI]
                        
                    case .f0:
                        type = .f0
                        
                        self.noteI = noteI
                        
                        beganNotes[noteI] = score.notes[noteI]
                        
                        let pitchInterval = rootView.currentPitchInterval
                        beganPitch = scoreView.pitch(atY: scoreView.convertFromWorld(p).y,
                                                     interval: pitchInterval)
                        
                        beganF0Pitch = note.f0Pitch
                        
                        beganPitchY = scoreView.y(fromPitch: note.pitch)
                        
                        rootView.cursor = .arrowWith(string: "F0: " + Pitch(value: note.f0Pitch).displayString())
                    case .note, .startBeat, .endBeat:
                        self.noteI = noteI
                        
                        type = if case .startBeat = result {
                            .startNoteBeat
                        } else if case .endBeat = result {
                            .endNoteBeat
                        } else {
                            .note
                        }
                        
                        beganPitch = note.pitch
                        let isInterval = note.pits.contains(where: { ($0.beat + note.beatRange.start) % EditGrid.beatInterval == 0 })
                        let dBeat = isInterval ? (note.beatRange.start - note.beatRange.start.interval(scale: interval)) : 0
                        beganDeltaNoteBeat = dBeat
                        beganBeatRange = note.beatRange
                        oldPitch = note.pitch
                        
                        if type == .startNoteBeat || type == .note {
                            beganBeatX = scoreView.x(atBeat: note.beatRange.start)
                        } else {
                            beganBeatX = scoreView.x(atBeat: note.beatRange.end)
                        }
                        beganPitchY = scoreView.y(fromPitch: note.pitch)
                        
                        if containsSelectedNote {
                            let noteIs = scoreView.selectedNoteIs
                            beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                        }
                        beganNotes[noteI] = score.notes[noteI]
                        
                        let playerBeat: Rational = switch type {
                        case .startNoteBeat: note.beatRange.start
                        case .endNoteBeat: note.beatRange.end
                        default: scoreView.beat(atX: scoreP.x)
                        }
                        let noteIs = Set(beganNotes.keys).intersection(selectedNoteIs).sorted()
                        let vs = score.noteIAndNormarizedPits(atBeat: playerBeat, selectedNoteI: noteI, in: noteIs)
                        playerBeatNoteIndexes = vs.map { $0.noteI }
                        
                        updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
                        
                        let octaveNode = scoreView.octaveNode(noteIs: beganNotes.keys.sorted())
                        octaveNode.attitude.position
                        = sheetView.convertToWorld(scoreView.node.attitude.position)
                        self.octaveNode = octaveNode
                        rootView.node.append(child: octaveNode)
                        
                        let result = note.pitResult(atBeat: Double(nsBeat - note.beatRange.start))
                        let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: EditGrid.fullEditBeatInterval)
                        rootView.cursor = .arrowWith(string: Pitch(value: cPitch).displayString())
                    }
                } else if scoreView.containsIsShownSpectrogram(scoreP, scale: rootView.screenToWorldScale) {
                    type = .isShownSpectrogram
                    
                    beganScoreOption = scoreView.model.option
                    
                    rootView.cursor = .arrowWith(string: (scoreView.model.isShownSpectrogram ? "Shown Spectrogram" : "Hidden Spectrogram").localized)
                } else if scoreView.isLoopDurBeat(at: scoreP, scale: rootView.screenToWorldScale) {
                    type = .loopDurBeat
                    
                    beganScoreOption = sheetView.model.score.option
                    beganBeatX = scoreView.x(atBeat: sheetView.model.score.endLoopDurBeat)
                    
                    rootView.cursor = rootView.cursor(from: sheetView.timeString(fromBeat: sheetView.model.score.endLoopDurBeat) + " " + "Loop".localized,
                                                      isArrow: true)
                } else if abs(scoreP.x - scoreView.x(atBeat: score.beatRange.end)) < rootView.worldKnobEditDistance
                            && abs(scoreP.y - scoreView.timelineCenterY) < Sheet.timelineHalfHeight {
                    type = .endBeat
                    
                    beganScoreOption = sheetView.model.score.option
                    beganBeatX = scoreView.x(atBeat: score.beatRange.end)
                    oldBeat = sheetView.model.score.beatRange.end
                } else if let result = scoreView.hitTestOption(scoreP, scale: rootView.screenToWorldScale) {
                    switch result {
                    case .keyBeat(let keyBeatI):
                        type = .keyBeats
                        
                        self.keyBeatI = keyBeatI
                        beganScoreOption = score.option
                        let beat = score.keyBeats[keyBeatI]
                        beganBeatX = scoreView.x(atBeat: beat)
                        oldBeat = beat
                    case .scale(_, let pitch):
                        type = .scale
                        
                        beganScoreOption = score.option
                        beganPitch = pitch
                        beganPitchY = scoreView.y(fromPitch: beganPitch)
                        
                        let octaveNode = scoreView.scaleNode(mainPitch: beganPitch)
                        octaveNode.attitude.position
                        = sheetView.convertToWorld(scoreView.node.attitude.position)
                        self.octaveNode = octaveNode
                        rootView.node.append(child: octaveNode)
                        
                        rootView.cursor = .arrowWith(string: Pitch(value: beganPitch).displayString())
                    }
                } else if scoreView.containsTimeline(scoreP, scale: rootView.screenToWorldScale) {
                    type = .allBeat
                    
                    beganScoreOption = sheetView.model.score.option
                    beganBeatX = scoreView.x(atBeat: score.beatRange.start)
                    beganNotes = score.notes.count.range.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                    oldBeat = sheetView.model.score.beatRange.start
                }
            }
        case .changed:
            if let sheetView, let type {
                let scoreView = sheetView.scoreView
                let score = scoreView.model
                let sheetP = sheetView.convertFromWorld(p)
                let scoreP = scoreView.convertFromWorld(p)
                
                switch type {
                case .startNoteBeat:
                    if let beganBeatRange {
                        let beatInterval = rootView.currentBeatInterval
                        let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                    interval: rootView.currentPitchInterval)
                        let nsBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                    interval: beatInterval)
                        if pitch != oldPitch || nsBeat != oldBeat {
                            let dBeat = nsBeat - beganBeatRange.start
                            let dPitch = pitch - beganPitch
                            
                            let endBeat = sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: beatInterval)
                            
                            var nivs = [IndexValue<Note>](capacity: beganNotes.count)
                            for (noteI, beganNote) in beganNotes {
                                guard noteI < score.notes.count else { continue }
                                
                                var note = beganNote
                                note.pitch = (dPitch + beganNote.pitch)
                                    .interval(scale: rootView.currentPitchInterval)
                                    .clipped(min: Score.pitchRange.start, max: Score.pitchRange.end)
                                
                                let nsBeat = min(beganNote.beatRange.start + dBeat, endBeat)
                                let neBeat = beganNote.beatRange.end
                                let beatRange = nsBeat < neBeat ? nsBeat ..< neBeat : neBeat ..< nsBeat
                                note.beatRange = beatRange
                                
                                
                                nivs.append(.init(value: note, index: noteI))
                            }
                            scoreView.replace(nivs)
                            rootView.updateOtherAround(from: sheetView, isUpdateAlways: true)
                            
                            let isChangedBeat = nsBeat != oldBeat
                            oldBeat = nsBeat
                            
                            octaveNode?.children = scoreView.octaveNode(noteIs: beganNotes.keys.sorted()).children
                            
                            if pitch != oldPitch || isChangedBeat {
                                notePlayer?.notes = playerBeatNoteIndexes.map {
                                    scoreView.rendableNormarizedPitResult(atBeat: nsBeat, at: $0)
                                }
                                oldPitch = pitch
                                
                                if let noteI, noteI < scoreView.model.notes.count {
                                    let note = scoreView[noteI]
                                    let result = note.pitResult(atBeat: Double(nsBeat - note.beatRange.start))
                                    let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: EditGrid.fullEditBeatInterval)
                                    let dSecStr = scoreView.isFullEdit ?
                                    "\n"
                                    + Duration.msString(fromSec: Double(scoreView.model.sec(fromBeat: dBeat)))
                                     : ""
                                    rootView.cursor = .arrowWith(string: Pitch(value: cPitch).displayString(deltaPitch: dPitch) + dSecStr)
                                }
                            }
                        }
                    }
                case .endNoteBeat:
                    if let beganBeatRange {
                        let beatInterval = rootView.currentBeatInterval
                        let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                    interval: rootView.currentPitchInterval)
                        let neBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                    interval: beatInterval)
                        if pitch != oldPitch || neBeat != oldBeat {
                            let dBeat = neBeat - beganBeatRange.end
                            let dPitch = pitch - beganPitch
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: beatInterval)
                            
                            var nivs = [IndexValue<Note>](capacity: beganNotes.count)
                            for (noteI, beganNote) in beganNotes {
                                guard noteI < score.notes.count else { continue }
                                
                                var note = beganNote
                                note.pitch = (dPitch + beganNote.pitch)
                                    .interval(scale: rootView.currentPitchInterval)
                                    .clipped(min: Score.pitchRange.start, max: Score.pitchRange.end)
                                
                                let nsBeat = beganNote.beatRange.start
                                let neBeat = max(beganNote.beatRange.end + dBeat, startBeat)
                                let beatRange = nsBeat < neBeat ? nsBeat ..< neBeat : neBeat ..< nsBeat
                                note.beatRange = beatRange
                                
                                nivs.append(.init(value: note, index: noteI))
                            }
                            scoreView.replace(nivs)
                            rootView.updateOtherAround(from: sheetView, isUpdateAlways: true)
                            
                            let isChangedBeat = neBeat != oldBeat
                            oldBeat = neBeat
                            
                            octaveNode?.children = scoreView.octaveNode(noteIs: beganNotes.keys.sorted()).children
                            
                            if pitch != oldPitch || isChangedBeat {
                                notePlayer?.notes = playerBeatNoteIndexes.map {
                                    scoreView.rendableNormarizedPitResult(atBeat: neBeat, at: $0)
                                }
                                oldPitch = pitch
                                
                                if let noteI, noteI < scoreView.model.notes.count {
                                    let note = scoreView[noteI]
                                    let result = note.pitResult(atBeat: Double(neBeat - note.beatRange.start))
                                    let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: EditGrid.fullEditBeatInterval)
                                    let dSecStr = scoreView.isFullEdit ?
                                    "\n"
                                    + Duration.msString(fromSec: Double(scoreView.model.sec(fromBeat: dBeat)))
                                     : ""
                                    rootView.cursor = .arrowWith(string: Pitch(value: cPitch).displayString(deltaPitch: dPitch) + dSecStr)
                                }
                            }
                        }
                    }
                case .note:
                    if let _ = beganBeatRange {
                        let beatInterval = rootView.currentBeatInterval
                        let y = beganPitchY + sheetP.y - beganSheetP.y
                        let doublePitch = scoreView.pitch(atY: y)
                        let pitch = scoreView.pitch(atY: y, interval: rootView.currentPitchInterval)
                        let nsBeat = scoreView.durBeat(atWidth: sheetP.x - beganSheetP.x,
                                                       interval: beatInterval)
                        if pitch != oldPitch || nsBeat != oldBeat {
                            let dBeat = nsBeat
                            let dPitch = pitch - beganPitch
                            let doubleDPitch = doublePitch - .init(beganPitch)
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: beatInterval)
                            let endBeat = sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: beatInterval)
                           
                            var justFitUnison: Int?
                            var nivs = [IndexValue<Note>](capacity: beganNotes.count)
                            for (aNoteI, beganNote) in beganNotes {
                                guard aNoteI < score.notes.count else { continue }
                                
                                let nBeat = dBeat + beganNote.beatRange.start
                                
                                var note = beganNote
                                if rootView.isFullEdit {
                                    let nPitch = dPitch + beganNote.pitch
                                    let doubleNPitch = doubleDPitch + .init(beganNote.pitch)
                                    var nnPitch = nPitch.interval(scale: rootView.currentPitchInterval)
                                    let rnPitch = nPitch.rounded()
                                    var minD = min(1 / 32.0, doubleNPitch.distance(.init(rnPitch)))
                                    for (ni, note) in score.notes.enumerated() {
                                        if beganNotes[ni] == nil,
                                           note.beatRange.contains(beganNote.beatRange.start),
                                           let oPitch = note.pitchWithStraight(atBeat: beganNote.beatRange.start - note.beatRange.start) {
                                            
                                            let roPitch = oPitch.rounded()
                                            let unison = (rnPitch - roPitch).mod(12)
                                            if unison != 0 {
                                                let jPitch = Chord.approximationJustIntonation(pitch: rnPitch - roPitch) + roPitch
                                                let d = doubleNPitch.distance(.init(jPitch))
                                                if d < minD {
                                                    minD = d
                                                    if noteI == aNoteI {
                                                        justFitUnison = Int(unison)
                                                    }
                                                    nnPitch = jPitch
                                                }
                                            }
                                        }
                                    }
                                    note.pitch = nnPitch.clipped(Score.pitchRange)
                                } else {
                                    note.pitch = (dPitch + beganNote.pitch)
                                        .interval(scale: rootView.currentPitchInterval)
                                        .clipped(Score.pitchRange)
                                }
                                
                                note.beatRange.start = max(min(nBeat, endBeat), startBeat - beganNote.beatRange.length)
                                
                                nivs.append(.init(value: note, index: aNoteI))
                            }
                            scoreView.replace(nivs)
                            rootView.updateOtherAround(from: sheetView, isUpdateAlways: true)
                            
                            let isChangedBeat = nsBeat != oldBeat
                            oldBeat = nsBeat
                            
                            octaveNode?.children = scoreView.octaveNode(noteIs: beganNotes.keys.sorted()).children
                            
                            if pitch != oldPitch || isChangedBeat {
                                let beat: Rational = scoreView.beat(atX: scoreP.x)
                                notePlayer?.notes = playerBeatNoteIndexes.map {
                                    scoreView.rendableNormarizedPitResult(atBeat: beat, at: $0)
                                }
                                oldPitch = pitch
                                
                                if let noteI, noteI < scoreView.model.notes.count {
                                    let note = scoreView[noteI]
                                    let result = note.pitResult(atBeat: Double(beat - note.beatRange.start))
                                    let cPitch = result.notePitch + result.pitch.rationalValue(intervalScale: EditGrid.fullEditBeatInterval)
                                    let dPitch = note.pitch - beganNotes[noteI]!.pitch
                                    let dSecStr = scoreView.isFullEdit && dBeat != 0 ?
                                    "\n"
                                    + Duration.msString(fromSec: Double(scoreView.model.sec(fromBeat: dBeat)))
                                     : ""
                                    let jStr = justFitUnison != nil ? " JI:\(justFitUnison!)" : ""
                                    rootView.cursor = .arrowWith(string: Pitch(value: cPitch).displayString(deltaPitch: dPitch) + jStr + dSecStr)
                                }
                            }
                        }
                    }
                    
                case .keyBeats:
                    if let keyBeatI, keyBeatI < score.keyBeats.count, let beganScoreOption {
                        let interval = rootView.currentBeatInterval
                        let nBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                   interval: interval)
                        if nBeat != oldBeat {
                            let dBeat = nBeat - beganScoreOption.keyBeats[keyBeatI]
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval)
                            let nkBeat = max(beganScoreOption.keyBeats[keyBeatI] + dBeat, startBeat)
                            
                            oldBeat = nkBeat
                            
                            var option = beganScoreOption
                            option.keyBeats[keyBeatI] = nkBeat
                            option.keyBeats.sort()
                            scoreView.option = option
                        }
                    }
                case .scale:
                    if let beganScoreOption {
                        let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                    interval: rootView.currentPitchInterval)
                        if pitch != oldPitch {
                            let dPitch = pitch - beganPitch
                            
                            var option = beganScoreOption
                            option.scales = option.scales.map { ($0 + dPitch).mod(12) }
                            scoreView.option = option
                            rootView.updateSelectedFrame()
                            
                            octaveNode?.children = scoreView.scaleNode(mainPitch: pitch).children
                            
                            rootView.cursor = .arrowWith(string: Pitch(value: pitch).displayString(deltaPitch: dPitch))
                            
                            oldPitch = pitch
                        }
                    }
                case .allBeat:
                    let nh = Sheet.pitchHeight
                    let np = beganBeatX + sheetP - beganSheetP
                    let py = ((beganScoreOption?.timelineY ?? 0) + sheetP.y - beganSheetP.y).interval(scale: nh)
                        .clipped(min: Sheet.timelineY, max: sheetView.bounds.height - Sheet.timelineY)
                    let interval = rootView.currentBeatInterval
                    let beat = max(min(scoreView.beat(atX: np.x, interval: interval),
                                   scoreView.beat(atX: scoreView.bounds.width - Sheet.textPadding.width, interval: interval)),
                                   scoreView.beat(atX: Sheet.textPadding.width, interval: interval) - scoreView.model.beatRange.length)
                    if py != scoreView.timelineY
                        || beat != scoreView.model.beatRange.start {
                        
                        if beat != scoreView.model.beatRange.start {
                            let dBeat = beat - (beganScoreOption?.beatRange.start ?? 0)
                            
                            var nivs = [IndexValue<Note>](capacity: beganNotes.count)
                            for (noteI, beganNote) in beganNotes {
                                guard noteI < score.notes.count else { continue }
                                
                                let nBeat = dBeat + beganNote.beatRange.start
                                var note = beganNote
                                note.beatRange.start = nBeat
                                nivs.append(.init(value: note, index: noteI))
                            }
                            scoreView.replace(nivs)
                            scoreView.option.keyBeats = beganScoreOption?.keyBeats.map { $0 + dBeat } ?? []
                        }
                        var option = scoreView.option
                        option.beatRange.start = beat
                        option.timelineY = py
                        scoreView.option = option
                    }
                case .loopDurBeat:
                    if let beganScoreOption {
                        let interval = rootView.currentBeatInterval
                        let nBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                   interval: interval)
                        if nBeat != scoreView.endLoopDurBeat {
                            let dBeat = nBeat - beganScoreOption.endLoopDurBeat
                            let startBeat = sheetView.scoreView.beat(atX: Sheet.textPadding.width, interval: interval)
                            let nkBeat = max(beganScoreOption.endLoopDurBeat + dBeat, startBeat)
                            
                            scoreView.endLoopDurBeat = nkBeat
                        }
                        
                        rootView.cursor = rootView.cursor(from: sheetView.timeString(fromBeat: sheetView.model.score.endLoopDurBeat) + " " + "Loop".localized,
                                                          isArrow: true)
                    }
                case .endBeat:
                    if let beganScoreOption {
                        let interval = rootView.currentBeatInterval
                        let nBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                   interval: interval)
                        if nBeat != oldBeat {
                            let dBeat = nBeat - beganScoreOption.beatRange.end
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval)
                            let nkBeat = max(beganScoreOption.beatRange.end + dBeat, startBeat)
                            
                            oldBeat = nkBeat
                            scoreView.option.beatRange.end = nkBeat
                        }
                    }
                case .isShownSpectrogram:
                    let scoreP = scoreView.convertFromWorld(p)
                    let isShownSpectrogram = scoreView.isShownSpectrogram(at: scoreP)
                    scoreView.isShownSpectrogram = isShownSpectrogram
                    
                    rootView.cursor = .arrowWith(string: (scoreView.model.isShownSpectrogram ? "Shown Spectrogram" : "Hidden Spectrogram").localized)
                case .f0:
                    let pitchInterval = rootView.currentPitchInterval
                    let pitch = scoreView.pitch(atY: scoreView.convertFromWorld(p).y,
                                                interval: pitchInterval)
                    let dPitch = pitch - beganPitch
                    let nPitch = (beganF0Pitch + dPitch).clipped(min: 39, max: 63)
                    if nPitch != oldPitch {
                        var nivs = [IndexValue<Note>](capacity: beganNotes.count)
                        for (noteI, beganNote) in beganNotes {
                            guard noteI < score.notes.count else { continue }
                            
                            var note = beganNote
                            note.f0Pitch = nPitch
                            
                            nivs.append(.init(value: note, index: noteI))
                        }
                        scoreView.replace(nivs)
                        
                        oldPitch = nPitch
                        
                        rootView.cursor = .arrowWith(string: "F0: " + Pitch(value: beganF0Pitch + dPitch).displayString())
                    }
                case .pit, .strightPit:
                    if let noteI, noteI < score.notes.count {
                        let beatInterval = rootView.currentBeatInterval
                        let pitchInterval = rootView.currentPitchInterval
                        let y = beganPitchY + sheetP.y - beganSheetP.y
                        let doublePitch = scoreView.pitch(atY: y)
                        let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                    interval: pitchInterval)
                        let nsBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                    interval: beatInterval)
                        if pitch != oldPitch || nsBeat != oldBeat {
                            let dBeat = nsBeat - beganBeat
                            let dPitch = pitch - beganPitch
                            let doubleDPitch = doublePitch - .init(beganPitch)
                            
                            var justFitUnison: Int?
                            for (aNoteI, nv) in beganNotePits {
                                guard aNoteI < score.notes.count else { continue }
                                var note = nv.note
                                for (pitI, beganPit) in nv.pits {
                                    guard pitI < score.notes[aNoteI].pits.count else { continue }
                                    
                                    let preI = (0 ..< pitI).reversed().first { nv.pits[$0] == nil }
                                    let preBeat = preI != nil ? note.pits[preI!].beat : .min
                                    let nextI = (pitI ..< note.pits.count).first(where: { nv.pits[$0] == nil })
                                    let nextBeat = nextI != nil ? note.pits[nextI!].beat : .max
                                    
                                    note.pits[pitI].beat = (dBeat + beganPit.beat)
                                        .clipped(min: preBeat, max: nextBeat)
                                    
                                    if rootView.isFullEdit {
                                        let nPitch = dPitch + beganPit.pitch + nv.note.pitch
                                        let doubleNPitch = doubleDPitch + .init(beganPit.pitch + nv.note.pitch)
                                        var nnPitch = nPitch.interval(scale: rootView.currentPitchInterval)
                                        let rnPitch = nPitch.rounded()
                                        var minD = min(1 / 32.0, doubleNPitch.distance(.init(rnPitch)))
                                        for (ni, note) in score.notes.enumerated() {
                                            if beganNotePits[ni] == nil,
                                               note.beatRange.contains(nv.note.beatRange.start + beganPit.beat),
                                               let oPitch = note.pitchWithStraight(atBeat: nv.note.beatRange.start + beganPit.beat - note.beatRange.start) {
                                                
                                                let roPitch = oPitch.rounded()
                                                let unison = (rnPitch - roPitch).mod(12)
                                                if unison != 0 {
                                                    let jPitch = Chord.approximationJustIntonation(pitch: rnPitch - roPitch) + roPitch
                                                    let d = doubleNPitch.distance(.init(jPitch))
                                                    if d < minD {
                                                        minD = d
                                                        if noteI == aNoteI {
                                                            justFitUnison = Int(unison)
                                                        }
                                                        nnPitch = jPitch
                                                    }
                                                }
                                            }
                                        }
                                        note.pits[pitI].pitch = nnPitch - nv.note.pitch
                                    } else {
                                        note.pits[pitI].pitch = (dPitch + beganPit.pitch)
                                            .interval(scale: rootView.currentPitchInterval)
                                    }
                                    
                                    if type == .strightPit && pitI == preStrightPitI,
                                        pitI + 1 < note.pits.count {
                                        if beganNote?.pits[pitI + 1].beat == beganPit.beat {
                                            note.pits[pitI].pitch = beganPit.pitch
                                        } else if beganNote?.pits[pitI + 1].pitch == beganPit.pitch {
                                            note.pits[pitI].beat = beganPit.beat
                                        }
                                    }
                                    if type == .strightPit && pitI == nextStrightPitI, pitI > 0 {
                                        if beganNote?.pits[pitI - 1].pitch == beganPit.pitch {
                                            note.pits[pitI].beat = beganPit.beat
                                        } else if beganNote?.pits[pitI - 1].beat == beganPit.beat {
                                            note.pits[pitI].pitch = beganPit.pitch
                                        }
                                    }
                                }
                                if nv.pits[0] != nil {
                                    let dBeat = note.pits.first!.beat
                                    if nv.note.beatRange.length - dBeat <= 0 {
                                        note.beatRange.start = nv.note.beatRange.end
                                        note.beatRange.length = 0
                                        for i in note.pits.count.range {
                                            note.pits[i].beat -= nv.note.beatRange.length
                                        }
                                    } else {
                                        note.beatRange.start = nv.note.beatRange.start + dBeat
                                        note.beatRange.length = nv.note.beatRange.length - dBeat
                                        for i in note.pits.count.range {
                                            note.pits[i].beat -= dBeat
                                        }
                                    }
                                } else {
                                    if note.pits.last!.beat > note.beatRange.length {
                                        note.beatRange.length = note.pits.last!.beat
                                    } else {
                                        note.beatRange.length = nv.note.beatRange.length
                                    }
                                }
                                
                                scoreView[aNoteI] = note
                                rootView.updateOtherAround(from: sheetView, isUpdateAlways: true)
                            }
                            
                            let isChangedBeat = nsBeat != oldBeat
                            oldBeat = nsBeat
                            
                            octaveNode?.children = scoreView.octaveNode(noteIs: [noteI]).children
                            
                            if pitch != oldPitch || isChangedBeat {
                                notePlayer?.notes = playerBeatNoteIndexes.map {
                                    scoreView.rendableNormarizedPitResult(atBeat: nsBeat, at: $0)
                                }
                                
                                oldPitch = pitch
                                
                                let dSecStr = scoreView.isFullEdit && dBeat != 0 ?
                                "\n"
                                + Duration.msString(fromSec: Double(scoreView.model.sec(fromBeat: dBeat)))
                                 : ""
                                let jStr = justFitUnison != nil ? " JI:\(justFitUnison!)" : ""
                                rootView.cursor = .arrowWith(string: Pitch(value: pitch).displayString(deltaPitch: dPitch) + jStr + dSecStr)
                            }
                        }
                    }
                case .even:
                    if let noteI, noteI < score.notes.count, let pitI {
                        let note = score.notes[noteI]
                        let preBeat = pitI > 0 ? note.pits[pitI - 1].beat + note.beatRange.start : .min
                        let nextBeat = pitI + 1 < note.pits.count ? note.pits[pitI + 1].beat + note.beatRange.start : .max
                        let beatInterval = rootView.currentBeatInterval
                        let nsBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                    interval: beatInterval)
                            .clipped(min: preBeat, max: nextBeat)
                        if nsBeat != oldBeat {
                            let dBeat = nsBeat - beganBeat
                            
                            for (noteI, nv) in beganNotePits {
                                guard noteI < score.notes.count else { continue }
                                var note = nv.note
                                for (pitI, beganPit) in nv.pits {
                                    guard pitI < score.notes[noteI].pits.count else { continue }
                                    note.pits[pitI].beat = dBeat + beganPit.beat
                                }
                                if note.pits.first!.beat < 0 {
                                    let dBeat = note.pits.first!.beat
                                    note.beatRange.start = nv.note.beatRange.start + dBeat
                                    note.beatRange.length = nv.note.beatRange.length - dBeat
                                    for i in note.pits.count.range {
                                        note.pits[i].beat -= dBeat
                                    }
                                } else {
                                    if note.pits.last!.beat > note.beatRange.length {
                                        note.beatRange.length = note.pits.last!.beat
                                    } else {
                                        note.beatRange.length = nv.note.beatRange.length
                                    }
                                }
                                
                                scoreView[noteI] = note
                            }
                            
                            oldBeat = nsBeat
                        }
                    }
                case .sprol:
                    if let noteI, noteI < score.notes.count {
                        let pitch = scoreView.spectlopePitch(at: scoreP, at: noteI, y: beganSpectlopeY)
                        let dPitch = pitch - beganSprolPitch
                        let nPitch = (beganSprol.pitch + dPitch)
                            .clipped(min: Score.doubleMinPitch, max: Score.doubleMaxPitch)
                        var nvs = [Int: Note]()
                        for (_, v) in beganNoteSprols {
                            for (noteI, nv) in v.dic {
                                if nvs[noteI] == nil {
                                    nvs[noteI] = nv.note
                                }
                                nv.pits.forEach { (pitI, beganPit) in
                                    for sprolI in beganPit.sprolIs {
                                        let pitch = (beganPit.pit.tone.spectlope.sprols[sprolI].pitch + dPitch)
                                            .clipped(min: Score.doubleMinPitch, max: Score.doubleMaxPitch)
                                        nvs[noteI]?.pits[pitI].tone.spectlope.sprols[sprolI].pitch = pitch
                                    }
                                    nvs[noteI]?.pits[pitI].tone.id = v.nid
                                }
                            }
                        }
                        let nivs = nvs.map { IndexValue(value: $0.value, index: $0.key) }
                        scoreView.replace(nivs)
                        
                        notePlayer?.notes = playerBeatNoteIndexes.map {
                            scoreView.rendableNormarizedPitResult(atBeat: beganStartBeat, at: $0)
                        }
                        
                        rootView.cursor = .arrowWith(string: Pitch(value: .init(nPitch, intervalScale: EditGrid.fullEditPitchInterval)).displayString(hidableDecimal: false))
                    }
                case .spectlopeHeight:
                    var nivs = [IndexValue<Note>](capacity: beganNotes.count)
                    for (noteI, beganNote) in beganNotes {
                        guard noteI < score.notes.count else { continue }
                        
                        var note = beganNote
                        note.spectlopeHeight = (sheetP.y - beganSheetP.y + note.spectlopeHeight)
                            .clipped(min: Sheet.spectlopeHeight, max: Sheet.maxSpectlopeHeight)
                        
                        nivs.append(.init(value: note, index: noteI))
                    }
                    scoreView.replace(nivs)
                }
            }
        case .ended:
            notePlayer?.stop()
            node.removeFromParent()
            octaveNode?.removeFromParent()
            octaveNode = nil
            
            if let sheetView {
                if type == .keyBeats || type == .scale
                    || type == .loopDurBeat
                    || type == .endBeat || type == .isShownSpectrogram {
                    
                    sheetView.updatePlaying()
                    if let beganScoreOption, sheetView.model.score.option != beganScoreOption {
                        if isNewUndoGroup {
                            sheetView.newUndoGroup()
                        }
                        sheetView.capture(sheetView.model.score.option,
                                          old: beganScoreOption)
                    }
                } else {
                    func updateUndoGroup() {
                        if isNewUndoGroup {
                            sheetView.newUndoGroup()
                            isNewUndoGroup = false
                        }
                    }
                    
                    let scoreView = sheetView.scoreView
                    let score = scoreView.model
                    var noteIVs = [IndexValue<Note>](), oldNoteIVs = [IndexValue<Note>]()
                    for (noteI, beganNote) in beganNotes.sorted(by: { $0.key < $1.key }) {
                        guard noteI < score.notes.count else { continue }
                        let note = score.notes[noteI]
                        if beganNote != note {
                            noteIVs.append(.init(value: note, index: noteI))
                            oldNoteIVs.append(.init(value: beganNote, index: noteI))
                        }
                    }
                    if !noteIVs.isEmpty {
                        updateUndoGroup()
                        sheetView.capture(noteIVs, old: oldNoteIVs)
                    }
                    
                    if let beganScoreOption, sheetView.model.score.option != beganScoreOption {
                        updateUndoGroup()
                        sheetView.capture(sheetView.model.score.option,
                                          old: beganScoreOption)
                    }
                    
                    if !beganNotePits.isEmpty {
                        let scoreView = sheetView.scoreView
                        let score = scoreView.model
                        var noteIVs = [IndexValue<Note>](), oldNoteIVs = [IndexValue<Note>]()
                        
                        let beganNoteIAndNotes = beganNotePits.reduce(into: [Int: Note]()) {
                            $0[$1.key] = $1.value.note
                        }
                        for (noteI, beganNote) in beganNoteIAndNotes {
                            guard noteI < score.notes.count else { continue }
                            let note = scoreView.model.notes[noteI]
                            if beganNote != note {
                                noteIVs.append(.init(value: note, index: noteI))
                                oldNoteIVs.append(.init(value: beganNote, index: noteI))
                            }
                        }
                        if !noteIVs.isEmpty {
                            updateUndoGroup()
                            sheetView.capture(noteIVs, old: oldNoteIVs)
                        }
                    }
                    
                    if !beganNoteSprols.isEmpty {
                        let scoreView = sheetView.scoreView
                        let score = scoreView.model
                        var noteIVs = [IndexValue<Note>](), oldNoteIVs = [IndexValue<Note>]()
                        
                        let beganNoteIAndNotes = beganNoteSprols.reduce(into: [Int: Note]()) {
                            for (noteI, v) in $1.value.dic {
                                $0[noteI] = v.note
                            }
                        }
                        for (noteI, beganNote) in beganNoteIAndNotes {
                            guard noteI < score.notes.count else { continue }
                            let note = scoreView.model.notes[noteI]
                            if beganNote != note {
                                noteIVs.append(.init(value: note, index: noteI))
                                oldNoteIVs.append(.init(value: beganNote, index: noteI))
                            }
                        }
                        if !noteIVs.isEmpty {
                            updateUndoGroup()
                            sheetView.capture(noteIVs, old: oldNoteIVs)
                        }
                    }
                    
                    if !sheetView.selection.isEmpty, sheetView.selection.lastPosition != nil {
                        updateUndoGroup()
                        var selection = sheetView.selection
                        selection.lastPosition = type == .note && containsSelectedLastLine ?
                        selection.lastPosition! + p - beganP : nil
                        sheetView.doSet(selection)
                    }
                }
                
                rootView.updateSelectedFrame()
                sheetView.showSelected()
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MoveContentAction: DragEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    enum SlideType {
        case all, startBeat, endBeat, isShownSpectrogram, position
    }
    
    private var contentView: SheetContentView? {
        guard let sheetView, let contentI,
              contentI < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentI]
    }
    private var beganContentBeat: Rational = 0, oldContentBeat: Rational = 0
    private let indexInterval = 10.0
    private var oldDeltaI: Int?
    
    private var sheetView: SheetView?, contentI: Int?, beganContent: Content?
    private var type = SlideType.all
    private var beganSP = Point(), beganInP = Point(), beganContentEndP = Point()
    private var isNewUndoGroup = true
    
    private var beganIsShownSpectrogram = false
    
    func flow(with event: DragEvent) {
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
                let ci = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                scale: rootView.screenToWorldScale) {
                self.sheetView = sheetView
                
                let sheetP = sheetView.convertFromWorld(p)
                let contentView = sheetView.contentsView.elementViews[ci]
                let content = contentView.model
                let contentP = contentView.convertFromWorld(p)
                
                beganSP = event.screenPoint
                beganInP = sheetP
                
                beganContent = content
                if let timeOption = content.timeOption {
                    beganContentEndP = .init(sheetView.animationView.x(atBeat: timeOption.beatRange.end), content.origin.y)
                }
                contentI = ci
                
                let maxMD = 10 * rootView.screenToWorldScale
                
                if contentView.containsIsShownSpectrogram(contentP, scale: rootView.screenToWorldScale) {
                    type = .isShownSpectrogram
                    beganIsShownSpectrogram = contentView.model.isShownSpectrogram
                    rootView.cursor = .arrowWith(string: (contentView.model.isShownSpectrogram ? "Shown Spectrogram" : "Hidden Spectrogram").localized)
                } else if let timeOption = content.timeOption {
                    if abs(sheetP.x - sheetView.animationView.x(atBeat: timeOption.beatRange.start)) < maxMD {
                        type = .startBeat
                    } else if abs(sheetP.x - sheetView.animationView.x(atBeat: timeOption.beatRange.end)) < maxMD {
                        type = .endBeat
                    } else {
                        type = .all
                    }
                } else {
                    type = .position
                }
            }
        case .changed:
            if let sheetView, let beganContent,
               let contentI, contentI < sheetView.contentsView.elementViews.count {
                
                let sheetP = sheetView.convertFromWorld(p)
                let contentView = sheetView.contentsView.elementViews[contentI]
                let content = contentView.model
                
                switch type {
                case .all:
                    let nh = Sheet.pitchHeight
                    let np = beganContent.origin + sheetP - beganInP
                    let interval = rootView.currentBeatInterval
                    let beat = max(min(sheetView.animationView.beat(atX: np.x, interval: interval),
                                   sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval)),
                                   sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval) - (content.timeOption?.beatRange.length ?? 0))
                    var timeOption = content.timeOption
                    let timelineY = np.y.interval(scale: nh)
                        .clipped(min: Sheet.timelineY, max: sheetView.bounds.height - Sheet.timelineY)
                    let isChangeBeat = beat != timeOption?.beatRange.start
                    if isChangeBeat || timelineY != content.origin.y {
                        timeOption?.beatRange.start = beat
                        
                        contentView.set(timeOption, origin: Point(sheetView.animationView.x(atBeat: beat), timelineY))
                        rootView.updateSelectedFrame()
                    }
                    
                case .startBeat:
                    if var timeOption = content.timeOption {
                        let np = beganContent.origin + sheetP - beganInP
                        let interval = rootView.currentBeatInterval
                        let beat = min(sheetView.animationView.beat(atX: np.x, interval: interval),
                                       sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval),
                                       timeOption.beatRange.end)
                        if beat != timeOption.beatRange.start {
                            let dBeat = timeOption.beatRange.start - beat
                            if content.type.hasDur {
                                timeOption.localStartBeat += dBeat
                            }
                            timeOption.beatRange.start -= dBeat
                            timeOption.beatRange.length += dBeat
                            contentView.set(timeOption, origin: .init(sheetView.animationView
                                .x(atBeat: timeOption.beatRange.start), content.origin.y))
                            rootView.updateSelectedFrame()
                        }
                    }
                case .endBeat:
                    if var timeOption = content.timeOption {
                        let np = beganContentEndP + sheetP - beganInP
                        let interval = rootView.currentBeatInterval
                        let beat = max(sheetView.animationView.beat(atX: np.x, interval: interval),
                                       sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval),
                                       timeOption.beatRange.start)
                        if beat != timeOption.beatRange.end {
                            timeOption.beatRange.end = beat
                            contentView.set(timeOption, origin: .init(sheetView.animationView
                                .x(atBeat: timeOption.beatRange.start), content.origin.y))
                            rootView.updateSelectedFrame()
                        }
                    }
                case .isShownSpectrogram:
                    let contentP = contentView.convertFromWorld(p)
                    let isShownSpectrogram = contentView.isShownSpectrogram(at: contentP)
                    if contentView.isShownSpectrogram != isShownSpectrogram {
                        contentView.isShownSpectrogram = isShownSpectrogram
                        
                        rootView.cursor = .arrowWith(string: (contentView.model.isShownSpectrogram ? "Shown Spectrogram" : "Hidden Spectrogram").localized)
                    }
                case .position:
                    let np = rootView.roundedPoint(from: beganContent.origin + sheetP - beganInP)
                    var nnp = np
                    let contentFrame = Rect(origin: np, size: content.size)
                    let sb = sheetView.bounds.inset(by: Sheet.textPadding)
                    if !sb.intersects(contentFrame) {
                        let nFrame = sb.moveOutline(contentFrame)
                        nnp += nFrame.origin - contentFrame.origin
                    }
                    contentView.origin = nnp
                    rootView.updateSelectedFrame()
                }
            }
        case .ended:
            if let sheetView {
                if let beganContent,
                   let contentI, contentI < sheetView.contentsView.elementViews.count {
                    
                    let contentView = sheetView.contentsView.elementViews[contentI]
                    if contentView.model != beganContent {
                        if isNewUndoGroup {
                            sheetView.newUndoGroup()
                        }
                        sheetView.capture(old: beganContent, at: contentI)
                    }
                    if type == .all || type == .startBeat || type == .endBeat {
                        sheetView.updatePlaying()
                    }
                }
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MoveTextAction: DragEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    enum SlideType {
        case all, startBeat, endBeat, position
    }
    
    private var sheetView: SheetView?, textI: Int?, beganText: Text?
    private var type = SlideType.all
    private var beganSP = Point(), beganInP = Point(), beganTextEndP = Point()
    private var isNewUndoGroup = true
    
    func flow(with event: DragEvent) {
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
               let ci = sheetView.textIndex(at: sheetView.convertFromWorld(p),
                                            scale: rootView.screenToWorldScale) {
                self.sheetView = sheetView
                if !sheetView.model.selection.isEmpty {
                    sheetView.newUndoGroup()
                    isNewUndoGroup = false
                    sheetView.doSet(SheetSelection.empty)
                    rootView.updateSelectedFrame()
                }
                
                let sheetP = sheetView.convertFromWorld(p)
                let textView = sheetView.textsView.elementViews[ci]
                let text = textView.model
                
                beganSP = event.screenPoint
                beganInP = sheetP
                
                beganText = text
                if let timeOption = text.timeOption {
                    beganTextEndP = .init(sheetView.animationView.x(atBeat: timeOption.beatRange.end), text.origin.y)
                }
                textI = ci
                
                let maxMD = 10 * rootView.screenToWorldScale
                
                if let timeOption = text.timeOption {
                    if abs(sheetP.x - sheetView.animationView.x(atBeat: timeOption.beatRange.start)) < maxMD {
                        type = .startBeat
                    } else if abs(sheetP.x - sheetView.animationView.x(atBeat: timeOption.beatRange.end)) < maxMD {
                        type = .endBeat
                    } else {
                        type = .all
                    }
                } else {
                    type = .position
                }
            }
        case .changed:
            if let sheetView, let beganText,
               let textI, textI < sheetView.textsView.elementViews.count {
                
                let sheetP = sheetView.convertFromWorld(p)
                let textView = sheetView.textsView.elementViews[textI]
                let text = textView.model
                
                switch type {
                case .all:
                    let np = beganText.origin + sheetP - beganInP
                    let interval = rootView.currentBeatInterval
                    let tw = beganText.orientation == .vertical ? beganText.typesetter.height : 0
                    let beat = max(min(sheetView.animationView.beat(atX: np.x - tw, interval: interval),
                                   sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval)),
                                   sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval) - (text.timeOption?.beatRange.length ?? 0))
                    var timeOption = text.timeOption
                    timeOption?.beatRange.start = beat
                    textView.set(timeOption, origin: Point(sheetView.animationView.x(atBeat: beat) + tw, np.y))
                    rootView.updateSelectedFrame()
                    
                    rootView.updateFinding(from: sheetView)
                case .startBeat:
                    if var timeOption = text.timeOption {
                        let np = beganText.origin + sheetP - beganInP
                        let interval = rootView.currentBeatInterval
                        let tw = beganText.orientation == .vertical ? beganText.typesetter.height : 0
                        let beat = min(sheetView.animationView.beat(atX: np.x - tw, interval: interval),
                                       sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval),
                                       timeOption.beatRange.end)
                        if beat != timeOption.beatRange.start {
                            let dBeat = timeOption.beatRange.start - beat
                            timeOption.beatRange.start -= dBeat
                            timeOption.beatRange.length += dBeat
                            textView.set(timeOption, origin: .init(sheetView.animationView
                                .x(atBeat: timeOption.beatRange.start) + tw, text.origin.y))
                            rootView.updateSelectedFrame()
                            
                            rootView.updateFinding(from: sheetView)
                        }
                    }
                case .endBeat:
                    if let beganTimeOption = beganText.timeOption {
                        let np = beganTextEndP + sheetP - beganInP
                        let interval = rootView.currentBeatInterval
                        let beat = max(sheetView.animationView.beat(atX: np.x, interval: interval),
                                       sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval),
                                       beganTimeOption.beatRange.start)
                        if beat != text.timeOption?.beatRange.end {
                            var beatRange = beganTimeOption.beatRange
                            beatRange.end = beat
                            textView.timeOption?.beatRange = beatRange
                            rootView.updateSelectedFrame()
                        }
                    }
                case .position:
                    let np = beganText.origin + sheetP - beganInP
                    var text = text
                    text.origin = rootView.roundedPoint(from: np)
                    let sb = sheetView.bounds.inset(by: Sheet.textPadding)
                    if let textFrame = text.frame, !sb.intersects(textFrame) {
                        let nFrame = sb.moveOutline(textFrame)
                        text.origin += nFrame.origin - textFrame.origin
                    }
                    textView.origin = text.origin
                    
                    rootView.updateFinding(from: sheetView)
                    
                    rootView.updateSelectedFrame()
                }
            }
        case .ended:
            if let sheetView {
                if let beganText,
                   let textI, textI < sheetView.textsView.elementViews.count {
                   
                    let textView = sheetView.textsView.elementViews[textI]
                    if textView.model != beganText {
                        if isNewUndoGroup {
                            sheetView.newUndoGroup()
                        }
                        sheetView.capture(old: beganText, at: textI)
                    }
                    sheetView.updatePlaying()
                }
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MoveTempoAction: DragEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private let editableTempoInterval = 20.0
    
    private var node = Node()
    private var sheetView: SheetView?
    private var beganSP = Point(), beganSheetP = Point()
    private var beganTempo: Rational = 1, oldTempo: Rational = 1
    private var beganAnimationOption: AnimationOption?, beganScoreOption: ScoreOption?,
                beganContents = [Int: Content](),
                beganTexts = [Int: Text]()
    private var tempos = [Rational](), beganTempoI = 0
    private var isNewUndoGroup = true
    
    func flow(with event: DragEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootAction.closeLookingUpAndStop(at: p)
            
            if let sheetView = rootView.sheetView(at: p) {
                self.sheetView = sheetView
                if !sheetView.model.selection.isEmpty {
                    sheetView.newUndoGroup()
                    isNewUndoGroup = false
                    sheetView.doSet(SheetSelection.empty)
                    rootView.updateSelectedFrame()
                }
                
                let sheetP = sheetView.convertFromWorld(p)
                beganSP = event.screenPoint
                beganSheetP = sheetP
                if let tempo = sheetView.tempo(at: sheetP, scale: rootView.screenToWorldScale) {
                    beganTempo = tempo
                    oldTempo = beganTempo
                    
                    beganContents = sheetView.contentsView.elementViews.enumerated().reduce(into: .init()) { (dic, v) in
                        if beganTempo == v.element.model.timeOption?.tempo {
                            dic[v.offset] = v.element.model
                        }
                    }
                    beganTexts = sheetView.textsView.elementViews.enumerated().reduce(into: .init()) { (dic, v) in
                        if beganTempo == v.element.model.timeOption?.tempo {
                            dic[v.offset] = v.element.model
                        }
                    }
                    if beganTempo == sheetView.model.animation.tempo {
                        beganAnimationOption = sheetView.model.animation.option
                    }
                    if beganTempo == sheetView.model.score.tempo {
                        beganScoreOption = sheetView.model.score.option
                    }
                    
                    tempos = Set(Sheet.temposFromStandardFrameRate() + (1 ..< 400).map { .init($0) }).sorted()
                    var ni: Int?
                    for (i, tempo) in tempos.enumerated().reversed() {
                        if beganTempo >= tempo {
                            ni = i
                            break
                        }
                    }
                    beganTempoI = ni ?? 0
                    
                    rootView.cursor = .arrowWith(string: Sheet.tempoNameFromStandardFrameRate(withTempo: beganTempo))
                }
            }
        case .changed:
            if let sheetView = sheetView {
                let di = Int((event.screenPoint.x - beganSP.x) / editableTempoInterval)
                let tempo = tempos[(beganTempoI + di).clipped(min: 0, max: tempos.count - 1)]
                if tempo != oldTempo {
                    beganContents.forEach {
                        sheetView.contentsView.elementViews[$0.key].tempo = tempo
                    }
                    beganTexts.forEach {
                        sheetView.textsView.elementViews[$0.key].tempo = tempo
                    }
                    if beganAnimationOption != nil {
                        sheetView.animationView.tempo = tempo
                    }
                    if beganScoreOption != nil {
                        sheetView.scoreView.tempo = tempo
                    }
                    
                    rootView.updateSelectedFrame()
                    
                    rootView.cursor = .arrowWith(string: Sheet.tempoNameFromStandardFrameRate(withTempo: tempo))
                    
                    oldTempo = tempo
                }
            }
        case .ended:
            node.removeFromParent()
            
            if let sheetView {
                func updateUndoGroup() {
                    if isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = false
                    }
                }
                
                if let beganAnimationOption, sheetView.model.animation.option != beganAnimationOption {
                    updateUndoGroup()
                    sheetView.capture(option: sheetView.model.animation.option,
                                      oldOption: beganAnimationOption)
                }
                if let beganScoreOption, sheetView.model.score.option != beganScoreOption {
                    updateUndoGroup()
                    sheetView.capture(sheetView.model.score.option,
                                      old: beganScoreOption)
                }
                if !beganContents.isEmpty || !beganTexts.isEmpty {
                    for (ci, beganContent) in beganContents {
                        guard ci < sheetView.model.contents.count else { continue }
                        let content = sheetView.contentsView.elementViews[ci].model
                        if content != beganContent {
                            updateUndoGroup()
                            sheetView.capture(old: beganContent, at: ci)
                        }
                    }
                    for (ti, beganText) in beganTexts {
                        guard ti < sheetView.model.texts.count else { continue }
                        let text = sheetView.textsView.elementViews[ti].model
                        if text != beganText {
                            updateUndoGroup()
                            sheetView.capture(old: beganText, at: ti)
                        }
                    }
                }
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MoveSheetAction: DragEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool

    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    func updateNode() {
        node.lineWidth = rootView.worldLineWidth
    }

    enum MoveType {
        case move, warp, scale, scaleLeft, scaleRight, scaleTop, scaleBottom, rotate
    }
    
    private var sheetView: SheetView?, type = MoveType.move, oldP = Point(), typeRect = Rect()
    private var lineIs = [Int](), planeIs = [Int](), textIs = [Int](), contentIs = [Int]()
    private var oldLines = [Line](), oldPlanes = [Plane](),
                oldTexts = [Text](), oldContents = [Content](), oldStr: String?
    private var sheetOrigin = Point(), containsSelectedLastLine = false
    private let node = Node()

    func flow(with event: DragEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootAction.closeLookingUpAndStop(at: p)
            
            let shp = rootView.sheetPositionFromSelectedFrame(at: p)
            ?? rootView.sheetPosition(at: p)
            if let sheetView = rootView.sheetView(at: shp) {
                let sheetP = sheetView.convertFromWorld(p)
                containsSelectedLastLine = sheetView.containsSelectedLastLine(sheetP, scale: rootView.screenToWorldScale)
                
                let containsSelectedFrame = sheetView.containsSelectedFrame(sheetP,
                                                                            scale: rootView.screenToWorldScale)
                if containsSelectedFrame
                    || sheetView.containsSelectedSheetValue(sheetP,
                                                            scale: rootView.screenToWorldScale) {
                    lineIs = sheetView.keyframeView.selectedLineIs
                    planeIs = sheetView.keyframeView.selectedPlaneIs
                    textIs = sheetView.selectedTextIs
                    contentIs = sheetView.selectedContentIs
                    oldLines = sheetView.model.picture.lines[lineIs]
                    oldPlanes = sheetView.model.picture.planes[planeIs]
                    oldTexts = sheetView.model.texts[textIs]
                    oldContents = sheetView.model.contents[contentIs]
                    oldP = p
                    sheetOrigin = rootView.sheetFrame(with: shp).origin
                    self.sheetView = sheetView
                    sheetView.hideSelected()
                    
                    if containsSelectedFrame || containsSelectedLastLine,
                        let rect = sheetView.selectedFrame(scale: rootView.screenToWorldScale) {
                        
                        typeRect = sheetView.convertToWorld(rect)
                        let rect = rootView.convertWorldToScreen(typeRect)
                        var minDSq = Double.infinity
                        func update(_ rp: Point, _ type: MoveType) {
                            let dSq = rp.distanceSquared(event.screenPoint)
                            if dSq < minDSq {
                                self.type = type
                                minDSq = dSq
                            }
                        }
                        update(rect.minXMinYPoint, .scale)
                        update(rect.minXMaxYPoint, .scale)
                        update(rect.maxXMinYPoint, .scale)
                        update(rect.maxXMaxYPoint, .scale)
                        update(rect.minXMidYPoint, .scaleLeft)
                        update(rect.midXMinYPoint, .scaleBottom)
                        update(rect.maxXMidYPoint, .scaleRight)
                        update(rect.midXMaxYPoint, .scaleTop)
                        update(rect.minXMinYPoint.mid(rect.midXMinYPoint), .rotate)
                        update(rect.midXMinYPoint.mid(rect.maxXMinYPoint), .rotate)
                        update(rect.maxXMinYPoint.mid(rect.maxXMidYPoint), .rotate)
                        update(rect.maxXMidYPoint.mid(rect.maxXMaxYPoint), .rotate)
                        update(rect.maxXMaxYPoint.mid(rect.midXMaxYPoint), .rotate)
                        update(rect.midXMaxYPoint.mid(rect.minXMaxYPoint), .rotate)
                        update(rect.minXMaxYPoint.mid(rect.minXMidYPoint), .rotate)
                        update(rect.minXMidYPoint.mid(rect.minXMinYPoint), .rotate)
                        
                        if type == .rotate {
                            node.lineType = .color(.selected)
                            node.lineWidth = rootView.worldLineWidth
                            node.path = .init(circleRadius: p.distance(typeRect.centerPoint),
                                              position: typeRect.centerPoint)
                            rootView.node.append(child: node)
                        }
                    }
                }
                
                if type == .move {
                    if let (lineView, _) = sheetView.lineTuple(at: sheetP,
                                                                scale: rootView.screenToWorldScale) {
                        let line = lineView.model
                        let d = line.minDistanceSquared(at: sheetP).squareRoot()
                        if d > 20 * rootView.screenToWorldScale,
                           let rect = sheetView.selectedFrame(scale: rootView.screenToWorldScale) {
                            
                            typeRect = sheetView.convertToWorld(rect)
                            type = .warp
                        }
                    }
                }
            }
        case .changed:
            if let sheetView {
                let dp = p - oldP
                let transform: Transform, v: Double
                switch type {
                case .move, .warp:
                    v = 0
                    transform = .init(translation: dp)
                case .scale:
                    v = typeRect.centerPoint.distance(oldP) == 0 ? 0 :
                    typeRect.centerPoint.distance(p) / typeRect.centerPoint.distance(oldP)
                    transform = .init(translation: -typeRect.centerPoint + sheetOrigin)
                    .scaled(by: v)
                    .translated(by: typeRect.centerPoint - sheetOrigin)
                case .scaleLeft:
                    v = oldP.x - typeRect.maxX == 0 ? 0 :
                    (p.x - typeRect.maxX) / (oldP.x - typeRect.maxX)
                    transform = .init(translation: -typeRect.maxXMidYPoint + sheetOrigin)
                    .scaledBy(x: v, y: 1)
                    .translated(by: typeRect.maxXMidYPoint - sheetOrigin)
                case .scaleRight:
                    v = oldP.x - typeRect.minX == 0 ? 0 :
                    (p.x - typeRect.minX) / (oldP.x - typeRect.minX)
                    transform = .init(translation: -typeRect.minXMidYPoint + sheetOrigin)
                    .scaledBy(x: v, y: 1)
                    .translated(by: typeRect.minXMidYPoint - sheetOrigin)
                case .scaleBottom:
                    v = oldP.y - typeRect.minY == 0 ? 0 :
                    (p.y - typeRect.maxY) / (oldP.y - typeRect.maxY)
                    transform = oldP.y - typeRect.minY == 0 ? .init() :
                    .init(translation: -typeRect.midXMaxYPoint + sheetOrigin)
                    .scaledBy(x: 1, y: v)
                    .translated(by: typeRect.midXMaxYPoint - sheetOrigin)
                case .scaleTop:
                    v = oldP.y - typeRect.maxY == 0 ? 0 :
                    (p.y - typeRect.minY) / (oldP.y - typeRect.minY)
                    transform = .init(translation: -typeRect.midXMinYPoint + sheetOrigin)
                    .scaledBy(x: 1, y: v)
                    .translated(by: typeRect.midXMinYPoint - sheetOrigin)
                case .rotate:
                    v = Point.differenceAngle(oldP, typeRect.centerPoint, p) - .pi
                    transform = .init(translation: -typeRect.centerPoint + sheetOrigin)
                    .rotated(by: v)
                    .translated(by: typeRect.centerPoint - sheetOrigin)
                }
                if type == .warp {
                    for (li, oldLine) in zip(lineIs, oldLines) {
                        sheetView.linesView.elementViews[li].model
                        = oldLine.warpedWith(deltaPoint: dp, at: sheetView.convertFromWorld(oldP),
                                             maxD: max(typeRect.width, typeRect.height))
                    }
                } else {
                    for (li, oldLine) in zip(lineIs, oldLines) {
                        sheetView.linesView.elementViews[li].model = oldLine * transform
                    }
                }
                
                for (pi, oldPlane) in zip(planeIs, oldPlanes) {
                    sheetView.planesView.elementViews[pi].model = oldPlane * transform
                }
                for (ti, oldText) in zip(textIs, oldTexts) {
                    sheetView.textsView.elementViews[ti].model = oldText * transform
                }
                if !textIs.isEmpty {
                    rootView.updateFinding(from: sheetView)
                }
                for (ci, oldContent) in zip(contentIs, oldContents) {
                    sheetView.contentsView.elementViews[ci].model = oldContent * transform
                }
                
                if type == .scale || type == .scaleTop
                    || type == .scaleLeft || type == .scaleBottom || type == .scaleRight {
                    
                    let str = (v).string(digitsCount: 2)
                    if str != oldStr {
                        rootView.cursor = rootView.cursor(from: "x" + str,
                                                          isArrow: true)
                        oldStr = str
                    }
                } else if type == .rotate {
                    let str = ((v + .pi2).loopedRotation * 180 / .pi).string(digitsCount: 2)
                    if str != oldStr {
                        rootView.cursor = rootView.cursor(from: str + "°",
                                                          isArrow: true)
                        oldStr = str
                    }
                }
            }
        case .ended:
            node.removeFromParent()
            
            if let sheetView {
                let lines = sheetView.model.picture.lines[lineIs]
                let planes = sheetView.model.picture.planes[planeIs]
                let texts = sheetView.model.texts[textIs]
                let contents = sheetView.model.contents[contentIs]
                let isLines = lines != oldLines, isPlanes = planes != oldPlanes,
                    isTexts = texts != oldTexts, isContents = contents != oldContents
                if isLines || isPlanes || isTexts || isContents {
                    sheetView.newUndoGroup()
                    if isLines {
                        sheetView.capture(old: zip(oldLines, lineIs).map { .init(value: $0.0, index: $0.1) })
                    }
                    if isPlanes {
                        sheetView.capture(old: zip(oldPlanes, planeIs).map { .init(value: $0.0, index: $0.1) })
                    }
                    if isTexts {
                        sheetView.capture(old: zip(oldTexts, textIs).map { .init(value: $0.0, index: $0.1) })
                    }
                    if isContents {
                        sheetView.capture(old: zip(oldContents, contentIs).map { .init(value: $0.0, index: $0.1) })
                    }
                    if isLines {
                        let lis = lineIs.filter { !sheetView.model.picture.lines[$0].intersects(sheetView.bounds) }
                        if !lis.isEmpty {
                            sheetView.removeLines(at: lis)
                        }
                    }
                    if isPlanes {
                        let pis = planeIs.filter { !sheetView.model.picture.planes[$0].path.intersects(sheetView.bounds) }
                        if !pis.isEmpty {
                            sheetView.removePlanes(at: pis)
                        }
                    }
                    if isTexts {
                        let tis = textIs.filter { !(sheetView.model.texts[$0].frame?.intersects(sheetView.bounds) ?? true) }
                        if !tis.isEmpty {
                            sheetView.removeTexts(at: tis)
                        }
                    }
                    if isContents {
                        let cis = contentIs.filter { !(sheetView.model.contents[$0].imageFrame?.intersects(sheetView.bounds) ?? true) }
                        if !cis.isEmpty {
                            sheetView.removeContents(at: cis)
                        }
                    }
                    
                    if !sheetView.selection.isEmpty, sheetView.selection.lastPosition != nil {
                        var selection = sheetView.selection
                        selection.lastPosition
                        = type == .move && containsSelectedLastLine ?
                        selection.lastPosition! + p - oldP : nil
                        sheetView.doSet(selection)
                    }
                }
                
                rootView.updateSelectedFrame()
                sheetView.showSelected()
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MoveLineAction: DragEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    enum MoveType {
        case point, warp, straight, all
    }
    
    private var sheetView: SheetView?, lineIndex = 0, pointIndex = 0, rootKeyframeIndex = 0
    private var beganLine = Line(), beganMainP = Point(), beganSheetP = Point(),
                isSnappable = true,
                lastSnapTime: Double?, snapP = Point(), snapDP = Point(), isEnabledFeedback = true
    private var lineView: SheetLineView?, lastSnapStraightTime: Double?, nsd = Point()
    private var isSnapStraight = false {
        didSet {
            guard isSnapStraight != oldValue else { return }
            if isSnapStraight && isEnabledFeedback {
                Feedback.performAlignment()
            }
        }
    }
    private var isNewUndoGroup = true
    
    let snappableDistance = 2.0
    private var node = Node()
    private var type = MoveType.point
    
    var isSnapped = false {
        didSet {
            guard isSnapped != oldValue else { return }
            if isSnapped && isEnabledFeedback {
                Feedback.performAlignment()
            }
        }
    }
    
    func flow(with event: DragEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }

        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootAction.closeLookingUpAndStop(at: p)
            
            if let sheetView = rootView.sheetView(at: p) {
                self.sheetView = sheetView
                if !sheetView.model.selection.isEmpty {
                    sheetView.newUndoGroup()
                    isNewUndoGroup = false
                    sheetView.doSet(SheetSelection.empty)
                    rootView.updateSelectedFrame()
                }
                
                let sheetP = sheetView.convertFromWorld(p)
                
                isEnabledFeedback = false
                if let (lineView, li) = sheetView.lineTuple(at: sheetP,
                                                            scale: rootView.screenToWorldScale) {
                    if let pi = lineView.model.mainPointSequence.nearestIndex(at: sheetP) {
                        let line = lineView.model
                        beganLine = line
                        lineIndex = li
                        pointIndex = pi
                        beganMainP = line.mainPoint(at: pi)
                        beganSheetP = sheetP
                        
                        let d = line.minDistanceSquared(at: sheetP).squareRoot()
                        type = if d < line.size + 0.5 * rootView.screenToWorldScale {
                            line.controls.count == 2 ? .straight : .point
                        } else if d < line.size + 20 * rootView.screenToWorldScale {
                            line.controls.count == 2 ? .straight : .warp
                        } else {
                            .all
                        }
                        if type == .straight {
                            let d = min(line.firstPoint.distance(sheetP),
                                        line.lastPoint.distance(sheetP))
                            if d >= line.size + 20 * rootView.screenToWorldScale {
                                type = .all
                            }
                        }
                        
                        switch type {
                        case .point:
                            node.children = line.mainControlSequence.flatMap {
                                let p = sheetView.convertToWorld($0.point)
                                return [Node(path: .init(circleRadius: 0.35 * 1.5 * max(line.size * $0.pressure, 0.5),
                                                         position: p),
                                             fillType: .color(.content)),
                                        Node(path: .init(circleRadius: 0.35 * max(line.size * $0.pressure, 0.5),
                                                         position: p),
                                             fillType: .color(.background))]
                            }
                            rootView.node.append(child: node)
                        case .warp:
                            let niv = line.nearestIndexValue(at: sheetP)
                            
                            let length = line.length()
                            if length > 0 {
                                if line.length(with: .init(startIndexValue: line.firstIndexValue,
                                                                endIndexValue: niv)) / length < 0.25 {
                                    pointIndex = 0
                                } else if line.length(with: .init(startIndexValue: niv,
                                                                       endIndexValue: line.lastIndexValue)) / length < 0.25 {
                                    pointIndex = line.mainPointCount - 1
                                }
                            }
                        case .straight:
                            self.lineView = lineView
                            let fp = sheetView.convertToWorld(pointIndex == 0 ?
                                                              line.lastPoint : line.firstPoint)
                            isSnapStraight = line.firstPoint.x == line.lastPoint.x
                            || line.firstPoint.y == line.lastPoint.y
                            let lw = Line.defaultLineWidth
                            let wb = rootView.worldBoundsInScreen
                            let b0 = Rect(x: fp.x - lw / 2, y: wb.minY, width: lw, height: wb.height)
                            let b1 = Rect(x: wb.minX, y: fp.y - lw / 2, width: wb.width, height: lw)
                            let paths = [Path(b0), Path(b1)]
                            node.children = paths.map {
                                Node(path: $0, fillType: .color(.subSelected))
                            }
                            rootView.node.append(child: node)
                        case .all:
                            let niv = line.nearestIndexValue(at: sheetP)
                            
                            let length = line.length()
                            if length > 0 {
                                if line.length(with: .init(startIndexValue: line.firstIndexValue,
                                                                endIndexValue: niv)) / length < 0.25 {
                                    pointIndex = 0
                                } else if line.length(with: .init(startIndexValue: niv,
                                                                       endIndexValue: line.lastIndexValue)) / length < 0.25 {
                                    pointIndex = line.mainPointCount - 1
                                } else {
                                    isSnappable = false
                                }
                            } else {
                                isSnappable = false
                            }
                            
                            pointIndex = line.firstPoint.distance(sheetP)
                            < line.lastPoint.distance(sheetP) ? 0 : line.controls.count - 1
                        }
                        
                        var lines = sheetView.keyframeView.linesView.model
                        lines.remove(at: lineIndex)
                        
                        let nnp = pointIndex == 0 || pointIndex == beganLine.mainPointCount - 1 ?
                        LineAction.snap(pointIndex == 0 ? .first : .last, beganLine,
                                        isSnapSelf: true,
                                        distanceScale: 2,
                                        screenToWorldScale: rootView.screenToWorldScale,
                                        from: lines)?.point :
                        nil
                        if nnp != nil {
                            lastSnapTime = event.time
                            snapP = nnp!
                        }
                    }
                }
            }
            isEnabledFeedback = true
        case .changed:
            if let sheetView {
                if lineIndex < sheetView.linesView.elementViews.count {
                    let lineView = sheetView.linesView.elementViews[lineIndex]
                    
                    switch type {
                    case .point:
                        var line = lineView.model
                        if pointIndex < line.mainPointCount {
                            let sheetP = sheetView.convertFromWorld(p)
                            let op = sheetP - beganSheetP + beganMainP
                            let np = line.mainPoint(withMainCenterPoint: op,
                                                    at: pointIndex)
                            
                            var lines = sheetView.keyframeView.linesView.model
                            lines.remove(at: lineIndex)
                            
                            var nLine = line
                            nLine.controls[pointIndex].point = np - snapDP
                            nLine.controls[pointIndex].weight = 0.5
                            
                            let nnp = pointIndex == 0 || pointIndex == nLine.mainPointCount - 1 ?
                            LineAction.snap(pointIndex == 0 ? .first : .last, nLine,
                                            isSnapSelf: true,
                                            distanceScale: 2,
                                            screenToWorldScale: rootView.screenToWorldScale,
                                            from: lines)?.point :
                            nil
                            
                            if nnp != nil {
                                if let lastSnapTime = lastSnapTime {
                                    if event.time - lastSnapTime > 1 {
                                        if isSnapped {
                                            snapDP = np - nnp!
                                        }
                                        isSnapped = false
                                    }
                                } else {
                                    if !isSnapped {
                                        lastSnapTime = event.time
                                        snapP = nnp!
                                    }
                                    isSnapped = true
                                }
                            } else {
                                lastSnapTime = nil
                                isSnapped = false
                            }
                            
                            line.controls[pointIndex].point = isSnapped ? snapP : np - snapDP
                            line.controls[pointIndex].weight = 0.5
                            lineView.model = line
                            
                            node.children = line.mainControlSequence.flatMap {
                                let p = sheetView.convertToWorld($0.point)
                                return [Node(path: .init(circleRadius: 0.35 * 1.5 * max(line.size * $0.pressure, 0.5),
                                                         position: p),
                                             fillType: .color(.content)),
                                        Node(path: .init(circleRadius: 0.35 * max(line.size * $0.pressure, 0.5),
                                                         position: p),
                                             fillType: .color(.background))]
                            }
                        }
                    case .warp, .all:
                        var line = beganLine
                        let sheetP = sheetView.convertFromWorld(p)
                        var dp = sheetP - beganSheetP
                        let np = pointIndex == 0 ? line.firstPoint + dp : (pointIndex == line.mainPointCount - 1 ? line.lastPoint + dp : nil)
                        var lines = sheetView.keyframeView.linesView.model
                        lines.remove(at: lineIndex)
                        
                        if isSnappable, let np {
                            let nLine = type == .all ? line * Transform(translation: dp)
                            : line.warpedWith(deltaPoint: dp - snapDP, at: pointIndex)
                            let nnp = pointIndex == 0 || pointIndex == line.mainPointCount - 1 ?
                            LineAction.snap(pointIndex == 0 ? .first : .last, nLine,
                                            isSnapSelf: line.controls.count != 2,
                                            distanceScale: 2,
                                            screenToWorldScale: rootView.screenToWorldScale,
                                            from: lines)?.point :
                            nil
                            
                            if nnp != nil {
                                if let lastSnapTime = lastSnapTime {
                                    if event.time - lastSnapTime > 1 {
                                        if isSnapped {
                                            snapDP = np - nnp!
                                        }
                                        isSnapped = false
                                    }
                                } else {
                                    if !isSnapped {
                                        lastSnapTime = event.time
                                        snapP = nnp!
                                    }
                                    isSnapped = true
                                }
                            } else {
                                lastSnapTime = nil
                                isSnapped = false
                            }
                            
                            let nnnp = isSnapped ? snapP : np - snapDP
                            if pointIndex == 0 {
                                dp = nnnp - line.firstPoint
                            } else {
                                dp = nnnp - line.lastPoint
                            }
                        }
                        
                        line = type == .all ? line * Transform(translation: dp)
                        : line.warpedWith(deltaPoint: dp, at: pointIndex)
                        
                        if line.controls.count == 2 {
                            if !isSnapped && !isSnapStraight {
                                if rootView.isSecondEdit {
                                    line.controls[0].point = line.controls[0].point.interval(scale: 0.25)
                                    line.controls[1].point = line.controls[1].point.interval(scale: 0.25)
                                } else {
                                    line.controls[0].point.round()
                                    line.controls[1].point.round()
                                }
                            }
                            
                            rootView.cursor = .arrowWith(string: "(\(line.controls[0].point.x.string(digitsCount: 2, enabledZeroInteger: false)) \(line.controls[0].point.y.string(digitsCount: 2, enabledZeroInteger: false)))\n(\(line.controls[1].point.x.string(digitsCount: 2, enabledZeroInteger: false)) \(line.controls[1].point.y.string(digitsCount: 2, enabledZeroInteger: false)))")
                        }
                        
                        lineView.model = line
                    case .straight:
                        let fol0: FirstOrLast = pointIndex == 0 ? .last : .first
                        let fol1 = fol0.reversed
                        
                        var lines = sheetView.keyframeView.linesView.model
                        lines.remove(at: lineIndex)
                        
                        let np = beganLine.controls[fol1].point
                        + sheetView.convertFromWorld(p) - beganSheetP
                        
                        var nLine = beganLine
                        nLine.controls[fol1].point = np
                        
                        let nnp = LineAction.snap(fol1, nLine,
                                                  isSnapSelf: false,
                                                  distanceScale: 2,
                                                  screenToWorldScale: rootView.screenToWorldScale,
                                                  from: lines)?.point
                        
                        if nnp != nil {
                            if let lastSnapTime = lastSnapTime {
                                if event.time - lastSnapTime > 1 {
                                    if isSnapped {
                                        snapDP = np - nnp!
                                    }
                                    isSnapped = false
                                }
                            } else {
                                if !isSnapped {
                                    lastSnapTime = event.time
                                    snapP = nnp!
                                }
                                isSnapped = true
                            }
                        } else {
                            lastSnapTime = nil
                            isSnapped = false
                        }
                        
                        nLine.controls[fol1].point = isSnapped ? snapP : np - snapDP
                        
                        let dp = nLine.controls[fol1].point - nLine.controls[fol0].point
                        
                        let sd: Point, isSnapS: Bool
                        if abs(dp.x) < abs(dp.y) {
                            sd = .init(dp.x, 0)
                            isSnapS = abs(dp.x * rootView.worldToScreenScale) < abs(dp.y * rootView.worldToScreenScale)
                                .clipped(min: 5, max: 20, newMin: 0, newMax: snappableDistance)
                        } else {
                            sd = .init(0, dp.y)
                            isSnapS = abs(dp.y * rootView.worldToScreenScale) < abs(dp.x * rootView.worldToScreenScale)
                                .clipped(min: 5, max: 20, newMin: 0, newMax: snappableDistance)
                        }
                        if isSnapS {
                            if let lastSnapStraightTime = lastSnapStraightTime {
                                if event.time - lastSnapStraightTime > 1 {
                                    isSnapStraight = false
                                    nsd = sd
                                }
                            } else {
                                if !isSnapStraight {
                                    lastSnapStraightTime = event.time
                                    nsd = sd
                                }
                                isSnapStraight = true
                            }
                        } else {
                            lastSnapStraightTime = nil
                            isSnapStraight = false
                        }
                        if isSnapStraight {
                            if abs(nsd.x) > 0 {
                                nLine.controls[fol1].point.x = nLine.controls[fol0].point.x
                            } else if abs(nsd.y) > 0 {
                                nLine.controls[fol1].point.y = nLine.controls[fol0].point.y
                            }
                        } else {
                            nLine.controls[fol1].point -= nsd
                        }
                        
                        if !isSnapped && !isSnapStraight {
                            switch rootView.editGrid {
                            case .main:
                                nLine.controls[fol1].point.round()
                            case .second, .full: break
                            }
                        }
                        
                        lineView.model = nLine
                        lineView.node.lineType = isSnapStraight ? .color(.selected) : .color(.content)
                        
                        rootView.cursor = .arrowWith(string: "(\(nLine.controls[fol1].point.x.string(digitsCount: 2, enabledZeroInteger: false)) \(nLine.controls[fol1].point.y.string(digitsCount: 2, enabledZeroInteger: false)))")
                    }
                }
            }
        case .ended:
            node.removeFromParent()
            
            lineView?.updateColor()
            if let sheetView {
                if lineIndex < sheetView.linesView.elementViews.count {
                    let line = sheetView.linesView.elementViews[lineIndex].model
                    if line != beganLine {
                        if isNewUndoGroup {
                            sheetView.newUndoGroup()
                        }
                        sheetView.capture(old: beganLine, at: lineIndex)
                    }
                }
            }

            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MoveBorderAction: DragEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    func updateNode() {
        if snapLineNode.children.isEmpty {
            snapLineNode.lineWidth = rootView.worldLineWidth
        } else {
            let w = rootView.worldLineWidth
            for node in snapLineNode.children {
                node.lineWidth = w
            }
        }
    }
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private var sheetView: SheetView?, borderI: Int?, beganBorder: Border?
    private var beganSP = Point(), beganInP = Point(),
                shp = IntPoint(), snapLineNode = Node()
    
    private var isSnapped = false {
        didSet {
            guard isSnapped != oldValue else { return }
            if isSnapped {
                Feedback.performAlignment()
            }
        }
    }
    
    func flow(with event: DragEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootAction.closeLookingUpAndStop(at: p)
            
            if let (border, i, sheetView, _) = rootView.border(at: p),
            let shp = rootView.sheetPosition(from: sheetView) {
                
                let sheetP = sheetView.convertFromWorld(p)
                beganSP = event.screenPoint
                beganInP = sheetP
                self.sheetView = sheetView
                beganBorder = border
                borderI = i
                
                self.shp = shp
                
                snapLineNode.lineType = .color(.subBorder)
                rootView.node.append(child: snapLineNode)
            }
        case .changed:
            if let sheetView, let borderI, borderI < sheetView.bordersView.elementViews.count,
               let oldBorder = beganBorder {
               
                let lw = rootView.screenToWorldScale < 0.5 ? rootView.screenToWorldScale * 2 : 1
                snapLineNode.lineWidth = lw
                
                let sheetFrame = rootView.sheetFrame(with: shp)
                var paths = [Path]()
                let values = Sheet.snappableBorderLocations(from: oldBorder.orientation,
                                                            with: sheetFrame)
                switch oldBorder.orientation {
                case .horizontal:
                    func append(_ p0: Point, _ p1: Point, lw: Double) {
                        paths.append(Path(Rect(x: p0.x, y: p0.y - lw / 2,
                                               width: p1.x - p0.x, height: lw)))
                    }
                    for value in values {
                        append(Point(sheetFrame.minX, sheetFrame.minY + value),
                               Point(sheetFrame.maxX, sheetFrame.minY + value), lw: lw * 1.5)
                    }
                    append(Point(sheetFrame.minX, sheetFrame.minY + oldBorder.location),
                           Point(sheetFrame.maxX, sheetFrame.minY + oldBorder.location), lw: lw * 0.5)
                case .vertical:
                    func append(_ p0: Point, _ p1: Point, lw: Double) {
                        paths.append(Path(Rect(x: p0.x - lw / 2, y: p0.y,
                                               width: lw, height: p1.y - p0.y)))
                    }
                    for value in values {
                        append(Point(sheetFrame.minX + value, sheetFrame.minY),
                               Point(sheetFrame.minX + value, sheetFrame.maxY), lw: lw * 1.5)
                    }
                    append(Point(sheetFrame.minX + oldBorder.location, sheetFrame.minY),
                           Point(sheetFrame.minX + oldBorder.location, sheetFrame.maxY), lw: lw * 0.5)
                }
                snapLineNode.children = paths.map {
                    Node(path: $0, fillType: .color(.subSelected))
                }
                
                let sheetP = p - sheetFrame.origin
                let bnp = Sheet.borderSnappedPoint(sheetP, with: sheetFrame,
                                                   distance: 3 / rootView.worldToScreenScale,
                                                   oldBorder: oldBorder)
                isSnapped = bnp.isSnapped
                
                let borderView = sheetView.bordersView.elementViews[borderI]
                
                let np = bnp.point + sheetFrame.origin, sb = sheetView.bounds
                var nBorder = oldBorder
                switch oldBorder.orientation {
                case .horizontal:
                    nBorder.location = (np.y - sheetFrame.minY).clipped(min: sb.minY, max: sb.maxY)
                case .vertical:
                    nBorder.location = (np.x - sheetFrame.minX).clipped(min: sb.minX, max: sb.maxX)
                }
                borderView.model = nBorder
                
                let nString0 = nBorder.location.string(digitsCount: 1, enabledZeroInteger: false)
                let nString1 = ((nBorder.orientation == .horizontal ? sheetFrame.width : sheetFrame.height) - nBorder.location).string(digitsCount: 1, enabledZeroInteger: false)
                rootView.cursor = switch nBorder.orientation {
                case .horizontal: rootView.cursor(from: "\(nString0):\(nString1)")
                case .vertical: rootView.cursor(from: "\(nString0):\(nString1)")
                }
            }
        case .ended:
            snapLineNode.removeFromParent()
            
            if let sheetView, let beganBorder,
               let borderI, borderI < sheetView.bordersView.elementViews.count {
               
                let borderView = sheetView.bordersView.elementViews[borderI]
                if borderView.model != beganBorder {
                    sheetView.newUndoGroup()
                    sheetView.capture(borderView.model, old: beganBorder, at: borderI)
                }
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MoveMainFrameAction: DragEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    enum MoveType {
        case corner, top, left, right, bottom
    }
    
    private var sheetView: SheetView?, beganOption = SheetOption(), type = MoveType.corner
    private var beganSP = Point(), beganSheetP = Point()
    private var isNewUndoGroup = true
    
    func flow(with event: DragEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = .arrow
            rootView.closeAllPanels(at: p)
            
            if let sheetView = rootView.madeSheetView(at: p) {
                self.sheetView = sheetView
                sheetView.unselect(isNewUndoGroup: &isNewUndoGroup)
                
                let sheetP = sheetView.convertFromWorld(p)
                beganSP = event.screenPoint
                beganSheetP = sheetP
                beganOption = sheetView.model.option
                
                var minDSq = Double.infinity
                let nb = sheetView.mainFrame != Sheet.defaultBounds ?
                sheetView.mainFrame.intersection(sheetView.bounds)?.outset(by: 2) ?? sheetView.bounds : sheetView.bounds
                let topDSq = nb.topEdge.distanceSquared(from: sheetP)
                if topDSq < minDSq {
                    type = .top
                    minDSq = topDSq
                }
                let rightDSq = nb.rightEdge.distanceSquared(from: sheetP)
                if rightDSq < minDSq {
                    type = .right
                    minDSq =  rightDSq
                }
                let leftDSq = nb.leftEdge.distanceSquared(from: sheetP)
                if leftDSq < minDSq {
                    type = .left
                    minDSq = leftDSq
                }
                let bottomDSq = nb.bottomEdge.distanceSquared(from: sheetP)
                if bottomDSq < minDSq {
                    type = .bottom
                    minDSq = bottomDSq
                }
                let maxDSq = (10 * rootView.screenToWorldScale).squared
                if nb.minXMinYPoint.distanceSquared(sheetP) < maxDSq
                    || nb.minXMaxYPoint.distanceSquared(sheetP) < maxDSq
                    || nb.maxXMinYPoint.distanceSquared(sheetP) < maxDSq
                    || nb.maxXMaxYPoint.distanceSquared(sheetP) < maxDSq {
                    type = .corner
                }
            }
        case .changed:
            if let sheetView {
                let oldFrame = sheetView.mainFrame, db = Sheet.defaultBounds
                let sheetP = sheetView.convertFromWorld(p), cp = sheetView.bounds.centerPoint
                let dp = beganSheetP - beganOption.mainFrame.centerPoint
                let nx = (sheetP.x - beganSheetP.x) * dp.x.signValue + beganOption.mainFrame.width / 2
                let ny = (sheetP.y - beganSheetP.y) * dp.y.signValue + beganOption.mainFrame.height / 2
                let rect = switch type {
                case .corner:
                    Rect(cp,
                         dx: abs(nx).rounded().clipped(min: 1, max: db.width / 2),
                         dy: abs(ny).rounded().clipped(min: 1, max: db.height / 2))
                case .top, .bottom:
                    Rect(cp,
                         dx: oldFrame.width / 2,
                         dy: abs(ny).rounded().clipped(min: 1, max: db.height / 2))
                case .left, .right:
                    Rect(cp,
                         dx: abs(nx).rounded().clipped(min: 1, max: db.width / 2),
                         dy: oldFrame.height / 2)
                }
                sheetView.mainFrame = rect
                
                let width = rect.width, height = rect.height
                rootView.cursor = rootView.cursor(from: "\(LookUpAction.sizeString(from: .init(width: width, height: height)))", isArrow: true)
            }
        case .ended:
            if let sheetView {
                if sheetView.model.option != beganOption {
                    if isNewUndoGroup {
                        sheetView.newUndoGroup()
                    }
                    sheetView.capture(sheetView.model.option, old: beganOption)
                }
            }
            
            rootView.cursor = rootView.defaultCursor
        }
    }
}

final class MoveZAction: DragEventAction {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private var sheetView: SheetView?, lineNode = Node(),
    crossIndexes = [Int](), crossLineIndex = 0,
    lineIndex = 0, lineView: SheetLineView?, oldSP = Point(),
                isNote = false, noteNode: Node?
    
    func flow(with event: DragEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootAction.closeLookingUpAndStop(at: p)
            
            var isChange = false
            if let sheetView = rootView.sheetView(at: p) {
                let sheetP = sheetView.convertFromWorld(p)
                if let (lineView, li) = sheetView.lineTuple(at: sheetP,
                                                            scale: rootView.screenToWorldScale) {
                    
                    self.sheetView = sheetView
                    sheetView.hideSelected()
                    
                    lineIndex = li
                    lineView.node.isHidden = true
                    self.lineView = lineView
                    
                    let line = lineView.model
                    if let lb = lineView.node.path.bounds?.outset(by: line.size / 2) {
                        crossIndexes = sheetView.linesView.elementViews.enumerated().compactMap {
                            let nLine = $0.element.model
                            return if $0.offset == li {
                                li
                            } else if let nb = $0.element.node.path.bounds,
                                      nb.outset(by: nLine.size / 2).intersects(lb) {
                                nLine.minDistanceSquared(line) < (line.size / 2 + nLine.size / 2).squared ?
                                $0.offset : nil
                            } else {
                                nil
                            }
                        }
                        if let lastI = crossIndexes.last {
                            crossIndexes.append(lastI + 1)
                        }
                        crossLineIndex = crossIndexes.firstIndex(of: li)!
                    }
                    
                    oldSP = event.screenPoint
                    lineNode.path = Path(lineView.model)
                    lineNode.lineType = lineView.node.lineType
                    lineNode.lineWidth = lineView.node.lineWidth
                    sheetView.linesView.node.children.insert(lineNode, at: li)
                    
                    isChange = true
                } else if sheetView.scoreView.model.enabled,
                          let li = sheetView.scoreView.noteIndex(at: sheetView.scoreView.convertFromWorld(p),
                                                                 scale: rootView.screenToWorldScale) {
                    self.sheetView = sheetView
                    sheetView.hideSelected()
                    
                    lineIndex = li
                    let noteNode = sheetView.scoreView.notesNode.children[li]
                    self.noteNode = noteNode
                    noteNode.isHidden = true
                    
                    let noteI0 = li, noteNode0 = noteNode
                    let line0 = sheetView.scoreView.pointline(from: sheetView.scoreView.model.notes[noteI0])
                    let noteH0 = sheetView.scoreView.noteH(from: sheetView.scoreView.model.notes[noteI0])
                    if let noteB0 = noteNode0.path.bounds?.outset(by: noteH0 / 2) {
                        let toneFrames0 = sheetView.scoreView.toneFrames(at: noteI0)
                        let maxB0 = toneFrames0.reduce(noteB0) { $0 + $1.frame }
                        crossIndexes = sheetView.scoreView.model.notes.enumerated().compactMap { (noteI1, note1) in
                            if noteI0 == noteI1 {
                                return noteI0
                            }
                            let noteNode1 = sheetView.scoreView.notesNode.children[noteI1]
                            let line1 = sheetView.scoreView.pointline(from: note1)
                            let noteH1 = sheetView.scoreView.noteH(from: note1)
                            guard let noteB1 = noteNode1.path.bounds?.outset(by: noteH1 / 2) else { return nil }
                            let toneFrames1 = sheetView.scoreView.toneFrames(at: noteI1)
                            let maxB1 = toneFrames1.reduce(noteB1) { $0 + $1.frame }
                            guard maxB0.intersects(maxB1) else { return nil }
                            
                            if line0.minDistanceSquared(line1) < (noteH0 / 2 + noteH1 / 2).squared
                                || toneFrames0.contains(where: { line1.minDistanceSquared($0.frame) < (noteH1 / 2).squared })
                                || toneFrames1.contains(where: { line0.minDistanceSquared($0.frame) < (noteH0 / 2).squared })
                                || toneFrames0.contains(where: { v0 in toneFrames1.contains(where: { v1 in v0.frame.intersects(v1.frame) }) }) {
                                return noteI1
                            }
                            return nil
                        }
                        if let lastI = crossIndexes.last {
                            crossIndexes.append(lastI + 1)
                        }
                        crossLineIndex = crossIndexes.firstIndex(of: li)!
                    }
                    
                    oldSP = event.screenPoint
                    lineNode = noteNode.clone
                    lineNode.isHidden = false
                    sheetView.scoreView.notesNode.children.insert(lineNode, at: li)
                    
                    isChange = true
                }
            }
            if !isChange {
                rootView.cursor = .arrowWith(string: "Empty".localized)
            } else {
                rootView.cursor = .arrow
            }
        case .changed:
            if let sheetView = sheetView,
               lineIndex < sheetView.linesView.elementViews.count {
                
                guard !crossIndexes.isEmpty else { return }
                
                let cli = (Int((event.screenPoint.y - oldSP.y) / 10) + crossLineIndex)
                    .clipped(min: 0, max: crossIndexes.count - 1)
                let li = crossIndexes[cli]
                    .clipped(min: 0, max: sheetView.linesView.elementViews.count)
                lineNode.removeFromParent()
                sheetView.linesView.node.children.insert(lineNode, at: li)
            } else if let sheetView = sheetView, sheetView.scoreView.model.enabled,
                      lineIndex < sheetView.scoreView.model.notes.count {
                
                guard !crossIndexes.isEmpty else { return }
                
                let cli = (Int((event.screenPoint.y - oldSP.y) / 10) + crossLineIndex)
                    .clipped(min: 0, max: crossIndexes.count - 1)
                let li = crossIndexes[cli]
                    .clipped(min: 0, max: sheetView.scoreView.model.notes.count)
                lineNode.removeFromParent()
                sheetView.scoreView.notesNode.children.insert(lineNode, at: li)
            }
        case .ended:
            lineNode.removeFromParent()
            lineView?.node.isHidden = false
            noteNode?.isHidden = false
            
            if let sheetView {
                sheetView.showSelected()
                
                if lineIndex < sheetView.linesView.elementViews.count {
                    
                    guard !crossIndexes.isEmpty else { return }
                    
                    let cli = (Int((event.screenPoint.y - oldSP.y) / 10) + crossLineIndex)
                        .clipped(min: 0, max: crossIndexes.count - 1)
                    let li = crossIndexes[cli]
                        .clipped(min: 0, max: sheetView.linesView.elementViews.count)
                    let line = sheetView.linesView.elementViews[lineIndex].model
                    if lineIndex != li {
                        sheetView.newUndoGroup()
                        sheetView.removeLines(at: [lineIndex])
                        sheetView.insert([.init(value: line, index: li > lineIndex ? li - 1 : li)])
                    }
                } else if sheetView.scoreView.model.enabled,
                          lineIndex < sheetView.scoreView.model.notes.count {
                    
                    guard !crossIndexes.isEmpty else { return }
                    
                    let cli = (Int((event.screenPoint.y - oldSP.y) / 10) + crossLineIndex)
                        .clipped(min: 0, max: crossIndexes.count - 1)
                    let li = crossIndexes[cli]
                        .clipped(min: 0, max: sheetView.scoreView.model.notes.count)
                    let line = sheetView.scoreView.model.notes[lineIndex]
                    if lineIndex != li {
                        sheetView.newUndoGroup()
                        sheetView.removeNote(at: lineIndex)
                        sheetView.insert([.init(value: line, index: li > lineIndex ? li - 1 : li)])
                    }
                }
            }

            rootView.cursor = rootView.defaultCursor
        }
    }
}
