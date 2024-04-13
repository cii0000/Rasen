// Copyright 2023 Cii
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

final class KeyframePreviousMover: InputKeyEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private var sheetView: SheetView?
    
    func send(_ event: InputKeyEvent) {
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
            sheetView = document.sheetView(at: p)
            move(from: sheetView, at: p)
            
            sheetView?.showOtherTimeNodeFromMainBeat()
            
            document.cursor = document.cursor(from: sheetView?.currentTimeString() ?? SheetView.timeString(time: 0, frameRate: 0))
        case .changed:
            if event.isRepeat, let sheetView {
                move(from: sheetView, at: p)
                sheetView.showOtherTimeNodeFromMainBeat()
                
                document.cursor = .circle(string: sheetView.currentTimeString())
            }
        case .ended:
            sheetView?.hideOtherTimeNode()
            
            document.cursor = Document.defaultCursor
        }
    }
    
    func move(from sheetView: SheetView?, at sp: Point) {
        sheetView?.movePreviousInterKeyframe()
        document.updateEditorNode()
        document.updateSelects()
    }
}

final class KeyframeNextMover: InputKeyEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private var sheetView: SheetView?
    
    func send(_ event: InputKeyEvent) {
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
            sheetView = document.sheetView(at: p)
            move(from: sheetView, at: p)
            
            sheetView?.showOtherTimeNodeFromMainBeat()
            
            document.cursor = document.cursor(from: sheetView?.currentTimeString() ?? SheetView.timeString(time: 0, frameRate: 0))
        case .changed:
            if event.isRepeat, let sheetView {
                move(from: sheetView, at: p)
                sheetView.showOtherTimeNodeFromMainBeat()
                
                document.cursor = document.cursor(from: sheetView.currentTimeString())
            }
        case .ended:
            sheetView?.hideOtherTimeNode()
            
            document.cursor = Document.defaultCursor
        }
    }
    
    func move(from sheetView: SheetView?, at sp: Point) {
        sheetView?.moveNextInterKeyframe()
        document.updateEditorNode()
        document.updateSelects()
    }
}

final class TimePreviousMover: InputKeyEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private var sheetView: SheetView?
    
    func send(_ event: InputKeyEvent) {
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
            sheetView = document.sheetView(at: p)
            move(from: sheetView, at: p)
            
            sheetView?.showOtherTimeNodeFromMainBeat()
            
            document.cursor = document.cursor(from: sheetView?.currentTimeString() ?? SheetView.timeString(time: 0, frameRate: 0))
        case .changed:
            if event.isRepeat, let sheetView {
                move(from: sheetView, at: p)
                sheetView.showOtherTimeNodeFromMainBeat()
                
                document.cursor = document.cursor(from: sheetView.currentTimeString())
            }
        case .ended:
            sheetView?.hideOtherTimeNode()
            
            document.cursor = Document.defaultCursor
        }
    }
    
    func move(from sheetView: SheetView?, at sp: Point) {
        sheetView?.movePreviousTime()
        document.updateEditorNode()
        document.updateSelects()
    }
}

final class TimeNextMover: InputKeyEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private var sheetView: SheetView?
    
    func send(_ event: InputKeyEvent) {
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
            sheetView = document.sheetView(at: p)
            move(from: sheetView, at: p)
            
            sheetView?.showOtherTimeNodeFromMainBeat()
            
            document.cursor = document.cursor(from: sheetView?.currentTimeString() ?? SheetView.timeString(time: 0, frameRate: 0))
        case .changed:
            if event.isRepeat, let sheetView {
                move(from: sheetView, at: p)
                sheetView.showOtherTimeNodeFromMainBeat()
                
                document.cursor = document.cursor(from: sheetView.currentTimeString())
            }
        case .ended:
            sheetView?.hideOtherTimeNode()
            
            document.cursor = Document.defaultCursor
        }
    }
    
    func move(from sheetView: SheetView?, at sp: Point) {
        sheetView?.moveNextTime()
        document.updateEditorNode()
        document.updateSelects()
    }
}

final class KeyframeSwiper: SwipeEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private let indexInterval = 10.0
    
    private var sheetView: SheetView?
    private var interpolatedNode = Node(), interpolatedRootIndex: Int?
    private var oldDeltaI: Int?
    private var beganSP = Point(),
                beganRootBeat = Rational(0), beganRootInterIndex = 0,
                beganRootIndex = 0, beganSelectedFrameIndexes = [Int](),
                beganEventTime = 0.0
    private var allDp = Point()
    private var snapInterRootIndex: Int?, snapEventT: Double?
    private var lastRootIs = [(sec: Double, rootI: Int)](capacity: 128)
    private var minLastSec = 1 / 12.0
    
    func send(_ event: SwipeEvent) {
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
            beganSP = event.screenPoint
            beganEventTime = event.time
            sheetView = document.sheetView(at: p)
            if let sheetView {
                let animationView = sheetView.animationView
                beganRootBeat = animationView.rootBeat
                beganRootInterIndex = animationView.model.rootInterIndex
                beganRootIndex = animationView.model.rootIndex
                lastRootIs.append((event.time, beganRootIndex))
                beganSelectedFrameIndexes = animationView.selectedFrameIndexes
                animationView.shownInterTypeKeyframeIndex = animationView.model.index
                oldDeltaI = nil
                
                document.cursor = document.cursor(from: sheetView.currentTimeString())
            } else {
                document.cursor = document.cursor(from: SheetView.timeString(time: 0, frameRate: 0))
            }
            
            sheetView?.showOtherTimeNodeFromMainBeat()
        case .changed:
            if let sheetView {
                let animationView = sheetView.animationView
                allDp += event.scrollDeltaPoint * 0.5
                let dp = allDp
                if event.time - beganEventTime < 0.2
                    && abs(dp.x) < indexInterval * 3 { return }
                let deltaI = Int((dp.x / indexInterval).rounded())
                
                let ni = beganRootInterIndex.addingReportingOverflow(deltaI).partialValue
                let nRootI = animationView.model.rootIndex(atRootInter: ni)
                
                let ii = Double(beganRootInterIndex) + (dp.x - indexInterval / 2) / indexInterval
                let iit = ii - ii.rounded(.down)
                let si = nRootI
                let ei = animationView.model.rootIndex(atRootInter: ni + 1)
                let nni = Int.linear(si, ei, t: iit)
                if nni != interpolatedRootIndex {
                    interpolatedRootIndex = nni
                    let nnni = animationView.model.index(atRoot: nni)
                    if !animationView.model.keyframes[nnni].isEmptyNotKey {
                        let node = animationView.elementViews[nnni].linesView.node.clone
                        node.children.forEach { $0.lineType = .color(.subInterpolated) }
                        interpolatedNode.children = [node]
                        if interpolatedNode.parent == nil {
                            sheetView.node.append(child: interpolatedNode)
                        }
                    } else {
                        interpolatedNode.children = []
                    }
                }
                
                if deltaI != oldDeltaI {
                    oldDeltaI = deltaI
                    
                    let oldKI = animationView.model.index
                    
                    if nRootI != animationView.model.rootIndex {
                        if sheetView.isPlaying {
                            sheetView.stop()
                        }
                        sheetView.rootKeyframeIndex = nRootI
                        
                        lastRootIs.append((event.time, nRootI))
                        for (i, v) in lastRootIs.enumerated().reversed() {
                            if event.time - v.sec > minLastSec {
                                if i > 0 {
                                    lastRootIs.removeFirst(i - 1)
                                }
                                break
                            }
                        }
                        
                        sheetView.showOtherTimeNodeFromMainBeat()
                        
                        document.updateEditorNode()
                        document.updateSelects()
                        if oldKI != animationView.model.index {
                            animationView.shownInterTypeKeyframeIndex = animationView.model.index
                        }
                        
                        document.cursor = document.cursor(from: sheetView.currentTimeString())
                    }
                }
            }
        case .ended:
            document.cursor = Document.defaultCursor
            
            interpolatedNode.removeFromParent()
            if let sheetView {
                let animationView = sheetView.animationView
                animationView.shownInterTypeKeyframeIndex = nil
                
                sheetView.hideOtherTimeNode()
                
                for (sec, rootI) in lastRootIs.reversed() {
                    if event.time - sec > minLastSec {
                        sheetView.rootKeyframeIndex = rootI
                        document.updateEditorNode()
                        document.updateSelects()
                        break
                    }
                }
            }
        }
    }
}
final class KeyframeSlider: DragEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private let indexInterval = 10.0
    
    private var sheetView: SheetView?
    private var interpolatedNode = Node(), interpolatedRootIndex: Int?
    private var oldDeltaI: Int?
    private var beganSP = Point(),
                beganRootBeat = Rational(0), beganRootInterIndex = 0,
                beganRootIndex = 0, beganSelectedFrameIndexes = [Int](),
                beganEventTime = 0.0
    private var snapInterRootIndex: Int?, snapEventT: Double?
    private var lastRootIs = [(sec: Double, rootI: Int)](capacity: 128)
    private var minLastSec = 1 / 12.0
    
    func send(_ event: DragEvent) {
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
            
            beganSP = event.screenPoint
            beganEventTime = event.time
            sheetView = document.sheetView(at: p)
            if let sheetView {
                let animationView = sheetView.animationView
                beganRootBeat = animationView.rootBeat
                beganRootInterIndex = animationView.model.rootInterIndex
                beganRootIndex = animationView.model.rootIndex
                lastRootIs.append((event.time, beganRootIndex))
                beganSelectedFrameIndexes = animationView.selectedFrameIndexes
                animationView.shownInterTypeKeyframeIndex = animationView.model.index
                oldDeltaI = nil
                
                document.cursor = document.cursor(from: sheetView.currentTimeString())
            } else {
                document.cursor = document.cursor(from: SheetView.timeString(time: 0, frameRate: 0))
            }
            
            sheetView?.showOtherTimeNodeFromMainBeat()
        case .changed:
            if let sheetView {
                let animationView = sheetView.animationView
                let dp = event.screenPoint - beganSP
                if event.time - beganEventTime < 0.2
                    && abs(dp.x) < indexInterval * 3 { return }
                let deltaI = Int((dp.x / indexInterval).rounded())
                
                let ni = beganRootInterIndex.addingReportingOverflow(deltaI).partialValue
                let nRootI = animationView.model.rootIndex(atRootInter: ni)
                
                let ii = Double(beganRootInterIndex) + (dp.x - indexInterval / 2) / indexInterval
                let iit = ii - ii.rounded(.down)
                let si = nRootI
                let ei = animationView.model.rootIndex(atRootInter: ni + 1)
                let nni = Int.linear(si, ei, t: iit)
                if nni != interpolatedRootIndex {
                    interpolatedRootIndex = nni
                    let nnni = animationView.model.index(atRoot: nni)
                    if !animationView.model.keyframes[nnni].isEmptyNotKey {
                        let node = animationView.elementViews[nnni].linesView.node.clone
                        node.children.forEach { $0.lineType = .color(.subInterpolated) }
                        interpolatedNode.children = [node]
                        if interpolatedNode.parent == nil {
                            sheetView.node.append(child: interpolatedNode)
                        }
                    } else {
                        interpolatedNode.children = []
                    }
                }
                
                if deltaI != oldDeltaI {
                    oldDeltaI = deltaI
                    
                    let oldKI = animationView.model.index
                    
                    if nRootI != animationView.model.rootIndex {
                        if sheetView.isPlaying {
                            sheetView.stop()
                        }
                        sheetView.rootKeyframeIndex = nRootI
                        
                        lastRootIs.append((event.time, nRootI))
                        for (i, v) in lastRootIs.enumerated().reversed() {
                            if event.time - v.sec > minLastSec {
                                if i > 0 {
                                    lastRootIs.removeFirst(i - 1)
                                }
                                break
                            }
                        }
                        
                        sheetView.showOtherTimeNodeFromMainBeat()
                        
                        document.updateEditorNode()
                        document.updateSelects()
                        if oldKI != animationView.model.index {
                            animationView.shownInterTypeKeyframeIndex = animationView.model.index
                        }
                        
                        document.cursor = document.cursor(from: sheetView.currentTimeString())
                    }
                }
            }
        case .ended:
            document.cursor = Document.defaultCursor
            
            interpolatedNode.removeFromParent()
            if let sheetView {
                let animationView = sheetView.animationView
                animationView.shownInterTypeKeyframeIndex = nil
                
                sheetView.hideOtherTimeNode()
                
                for (sec, rootI) in lastRootIs.reversed() {
                    if event.time - sec > minLastSec {
                        sheetView.rootKeyframeIndex = rootI
                        document.updateEditorNode()
                        document.updateSelects()
                        break
                    }
                }
            }
        }
    }
}

final class FrameSelecter: DragEditor {
    let editor: FrameEditor
    
    init(_ document: Document) {
        editor = FrameEditor(document)
    }
    
    func send(_ event: DragEvent) {
        editor.selectFrame(with: event, isMultiple: false)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class MultiFrameSelecter: DragEditor {
    let editor: FrameEditor
    
    init(_ document: Document) {
        editor = FrameEditor(document)
    }
    
    func send(_ event: DragEvent) {
        editor.selectFrame(with: event, isMultiple: true)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class FrameEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private let indexInterval = 2.0
    private let snapDeltaIndex = 4, snapDeltaEventTime = 0.075
    
    private var sheetView: SheetView?, animationIndex: Int?
    private var beganSP = Point(),
                beganRootBeat = Rational(0), beganBeat = Rational(0),
                beganSelectedFrameIndexes = [Int](), beganEventTime = 0.0
    private var preMoveEventTime: Double?
    private var snapRootBeat: Rational?, snapEventTime: Double?
    private var lastRootBeats = [(sec: Double, rootBeat: Rational)](capacity: 128)
    private var minLastSec = 1 / 12.0
    
    func selectFrame(with event: DragEvent, isMultiple: Bool) {
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
            
            beganSP = event.screenPoint
            beganEventTime = event.time
            sheetView = document.sheetView(at: p)
            if let sheetView {
                if sheetView.model.enabledAnimation {
                    let animationView = sheetView.animationView
                    beganRootBeat = animationView.rootBeat
                    lastRootBeats.append((event.time, beganRootBeat))
                    beganBeat = animationView.model.localBeat
                    beganSelectedFrameIndexes = animationView.selectedFrameIndexes
                    animationView.shownInterTypeKeyframeIndex = sheetView.model.animation.index
                }
            }
            document.cursor = document.cursor(from: sheetView?.currentTimeString() ?? SheetView.timeString(time: 0, frameRate: 0))
            
            sheetView?.showOtherTimeNodeFromMainBeat()
        case .changed:
            if let sheetView {
                if sheetView.model.enabledAnimation {
                    let animationView = sheetView.animationView
                    
                    let dp = event.screenPoint - beganSP
                    let i = Int((dp.x / indexInterval).rounded())
                    let deltaTime = Rational(i, animationView.frameRate)
                    let oldKI = animationView.model.index
                    let nRootBeat = Rational.saftyAdd(beganRootBeat, deltaTime)
                    if animationView.rootBeat != nRootBeat {
                        if sheetView.isPlaying {
                            sheetView.stop()
                        }
                        if let preMoveEventTime {
                            if event.time - preMoveEventTime > 0.25 {
                                snapRootBeat = animationView.rootBeat
                                snapEventTime = event.time
                            }
                        }
                        preMoveEventTime = event.time
                        sheetView.rootBeat = nRootBeat
                        document.updateEditorNode()
                        document.updateSelects()
                        
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
                            animationView.shownInterTypeKeyframeIndex = sheetView.model.animation.index
                            if isMultiple {
                                var isSelects = [Bool](repeating: false, count: animationView.model.keyframes.count)
                                let beganRootIndex = animationView.model.rootIndex(atRootBeat: beganRootBeat)
                                let ni = animationView.model.rootIndex(atRootBeat: nRootBeat)
                                let range = beganRootIndex <= ni ? beganRootIndex ... ni : ni ... beganRootIndex
                                for i in range {
                                    let ki = animationView.model.index(atRoot: i)
                                    isSelects[ki] = true
                                }
                                beganSelectedFrameIndexes.forEach { isSelects[$0] = true }
                                let fis = isSelects.enumerated().compactMap { $0.element ? $0.offset : nil }
                                animationView.selectedFrameIndexes = fis
                            }
                        }
                        
                        document.cursor = document.cursor(from: sheetView.currentTimeString())
                        sheetView.showOtherTimeNodeFromMainBeat()
                    }
                }
            }
        case .ended:
            document.cursor = Document.defaultCursor
            
            if let sheetView {
                let animationView = sheetView.animationView
                animationView.shownInterTypeKeyframeIndex = nil
                sheetView.hideOtherTimeNode()
                    
                for (sec, rootBeat) in lastRootBeats.reversed() {
                    if event.time - sec > minLastSec {
                        sheetView.rootBeat = rootBeat
                        document.updateEditorNode()
                        document.updateSelects()
                        break
                    }
                }
            }
        }
    }
}

final class Player: InputKeyEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private var sheetView: SheetView?
    private var isEndStop = false
    
    func send(_ event: InputKeyEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
            ?? event.screenPoint
        let p = document.convertScreenToWorld(sp)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
            sheetView = document.sheetView(at: p)
            let cip = document.intPosition(at: p)
            let cshp = document.sheetPosition(at: cip)
            if let cSheetView = document.sheetView(at: cshp) {
                for (_, v) in document.sheetViewValues {
                    if cSheetView != v.view {
                        v.view?.stop()
                    }
                }
                
                var filledShps = Set<Sheetpos>()
                func sheetView(at ip: IntPoint) -> SheetView? {
                    let shp = document.sheetPosition(at: ip)
                    if !filledShps.contains(shp),
                       let aSheetView = document.sheetView(at: shp),
                       aSheetView.model.enabledTimeline {
                        
                        filledShps.insert(shp)
                        return aSheetView
                    } else {
                        return nil
                    }
                }
                
                let preX = cshp == document.world.sheetpos(at: .init(cip.x - 1, cip.y))
                ? cip.x - 2 : cip.x - 1
                
                let nextX = cshp == document.world.sheetpos(at: .init(cip.x + 1, cip.y))
                ? cip.x + 2 : cip.x + 1
                
                if let aSheetView = sheetView(at: .init(preX, cip.y)) {
                    cSheetView.previousSheetView = aSheetView
                    
                    if let aaSheetView = sheetView(at: .init(preX, cip.y - 1)) {
                        aSheetView.bottomSheetView = aaSheetView
                    }
                    if let aaSheetView = sheetView(at: .init(preX, cip.y + 1)) {
                        aSheetView.topSheetView = aaSheetView
                    }
                }
                if let aSheetView = sheetView(at: .init(nextX, cip.y)) {
                    cSheetView.nextSheetView = aSheetView
                    
                    if let aaSheetView = sheetView(at: .init(nextX, cip.y - 1)) {
                        aSheetView.bottomSheetView = aaSheetView
                    }
                    if let aaSheetView = sheetView(at: .init(nextX, cip.y + 1)) {
                        aSheetView.topSheetView = aaSheetView
                    }
                }
                if let aSheetView = sheetView(at: .init(cip.x, cip.y - 1)) {
                    cSheetView.bottomSheetView = aSheetView
                }
                if let aSheetView = sheetView(at: .init(cip.x, cip.y + 1)) {
                    cSheetView.topSheetView = aSheetView
                }
                
                if !document.containsAllTimeline(with: event) {
                    cSheetView.play()
                } else {
                    let sheetP = cSheetView.convertFromWorld(p)
                    var ids = Set<UUID>()
                    var secRange: Range<Rational>?
                    var sec: Rational = cSheetView.animationView.sec(atX: sheetP.x)
                    let scoreView = cSheetView.scoreView
                    let scoreP = scoreView.convertFromWorld(p)
                    let score = scoreView.model
                    if let (noteI, pitI) = scoreView.noteAndPitI(at: scoreP, scale: document.screenToWorldScale) {
                        let beat = score.notes[noteI].pits[pitI].beat
                        + score.notes[noteI].beatRange.start + score.beatRange.start
                        sec = score.sec(fromBeat: beat)
                        secRange = score.secRange
                        ids.insert(score.id)
                    } else if let ni = scoreView.noteIndex(at: scoreP,
                                                    scale: document.screenToWorldScale) {
                        let beat = score.notes[ni].beatRange.start + score.beatRange.start
                        sec = score.sec(fromBeat: beat)
                        secRange = score.secRange
                        ids.insert(score.id)
                    } else if scoreView.containsMainLine(scoreP,
                                                         distance: 5 * document.screenToWorldScale) {
                        ids.insert(score.id)
                    }
                    if secRange != nil {
                        cSheetView.previousSheetView = nil
                        cSheetView.nextSheetView = nil
                    }
                    cSheetView.play(atSec: sec, inSec: secRange,
                                    otherTimelineIDs: ids)
                }
            }
        case .changed:
            break
        case .ended:
            if isEndStop {
                sheetView?.stop()
            }
            document.cursor = Document.defaultCursor
        }
    }
}

final class TimeSlider: DragEditor {
    let editor: FrameSlideEditor
    
    init(_ document: Document) {
        editor = FrameSlideEditor(document)
    }
    
    func send(_ event: DragEvent) {
        editor.slideFrame(with: event, isMultiple: false)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class MultiFrameSlider: DragEditor {
    let editor: FrameSlideEditor
    
    init(_ document: Document) {
        editor = FrameSlideEditor(document)
    }
    
    func send(_ event: DragEvent) {
        editor.slideFrame(with: event, isMultiple: true)
    }
    func updateNode() {
        editor.updateNode()
    }
}
final class FrameSlideEditor: Editor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
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
        let range = beganRootIndex <= ni ?
        beganRootIndex ... ni : ni ... beganRootIndex
        for i in range {
            let ki = animationView.model.index(atRoot: i)
            isSelects[ki] = true
        }
        beganSelectedFrameIndexes.forEach { isSelects[$0] = true }
        let fis = isSelects.enumerated()
            .compactMap { $0.element ? $0.offset : nil }
        animationView.selectedFrameIndexes = fis
    }
    
    func slideFrame(with event: DragEvent, isMultiple: Bool) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        if document.isPlaying(with: event) {
            document.stopPlaying(with: event)
        }
        
        let p = document.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            document.cursor = .arrow
            if let sheetView = document.sheetView(at: p),
               sheetView.animationView.containsTimeline(sheetView.convertFromWorld(p)) {
                
                self.sheetView = sheetView
                let animationView = sheetView.animationView
                beganRootBeatPosition = sheetView.rootBeatPosition
                
                var rbp = movedBeganRootBeatPosition
                rbp.beat = animationView.beat(atX: sheetView.convertFromWorld(p).x)
                let nRootBeat = animationView.model.rootBeat(at: rbp)
                if animationView.rootBeat != nRootBeat {
                    sheetView.rootBeat = nRootBeat
                    document.updateEditorNode()
                    document.updateSelects()
                }
                animationView.shownInterTypeKeyframeIndex = animationView.model.index
                
                if isMultiple {
                    movedBeganRootBeatPosition = sheetView.rootBeatPosition
                    beganSelectedFrameIndexes = animationView.selectedFrameIndexes
                    beganSelectedRootBeat = nRootBeat
                    lastRootBeats.append((event.time, beganSelectedRootBeat))
                    var isSelects = [Bool](repeating: false,
                                           count: animationView.model.keyframes.count)
                    let beganRootIndex = animationView.model.nearestRootIndex(atRootBeat: beganSelectedRootBeat)
                    let ni = animationView.model.nearestRootIndex(atRootBeat: nRootBeat)
                    let range = beganRootIndex <= ni ?
                    beganRootIndex ... ni : ni ... beganRootIndex
                    
                    for i in range {
                        let ki = animationView.model.index(atRoot: i)
                        isSelects[ki] = true
                    }
                    beganSelectedFrameIndexes.forEach { isSelects[$0] = true }
                    let fis = isSelects.enumerated()
                        .compactMap { $0.element ? $0.offset : nil }
                    animationView.selectedFrameIndexes = fis
                }
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
                    document.updateEditorNode()
                    document.updateSelects()
                    
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
                        
                        if isMultiple {
                            updateSelected(fromRootBeeat: nRootBeat, in: animationView)
                        }
                    }
                }
            }
        case .ended:
            if let sheetView {
                let animationView = sheetView.animationView
                animationView.shownInterTypeKeyframeIndex = nil
            }
            
            if isMultiple, let sheetView {
                sheetView.rootBeatPosition = beganRootBeatPosition
                
                for (sec, rootBeat) in lastRootBeats.reversed() {
                    if event.time - sec > minLastSec {
                        let animationView = sheetView.animationView
                        updateSelected(fromRootBeeat: rootBeat, in: animationView)
                        break
                    }
                }
            }
            
            document.cursor = Document.defaultCursor
        }
    }
}

final class TempoSlider: DragEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private let editableTempoInterval = 10.0
    
    private var node = Node()
    private var sheetView: SheetView?
    private var beganSP = Point(), beganInP = Point()
    private var beganTempo: Rational = 1, oldTempo: Rational = 1
    private var beganAnimationOption: AnimationOption?, beganScoreOption: ScoreOption?,
                beganContents = [Int: Content](),
                beganTexts = [Int: Text]()
    
    func send(_ event: DragEvent) {
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
            
            if let sheetView = document.sheetView(at: p), sheetView.model.enabledTimeline {
                beganSP = sp
                self.sheetView = sheetView
                let inP = sheetView.convertFromWorld(p)
                beganInP = inP
                if sheetView.containsTempo(inP, maxDistance: document.worldKnobEditDistance) {
                    beganTempo = sheetView.model.animation.tempo
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
                    
                    document.cursor = .arrowWith(string: SheetView.tempoString(fromTempo: beganTempo))
                }
            }
        case .changed:
            if let sheetView = sheetView {
                let di = (sp.x - beganSP.x) / editableTempoInterval
                let tempo = Rational(Double(beganTempo) + di, intervalScale: Rational(1, 4))
                    .clipped(Music.tempoRange)
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
                    
                    document.updateSelects()
                    
                    document.cursor = .arrowWith(string: SheetView.tempoString(fromTempo: tempo))
                    
                    oldTempo = tempo
                }
            }
        case .ended:
            node.removeFromParent()
            
            if let sheetView = sheetView {
                var isNewUndoGroup = false
                func updateUndoGroup() {
                    if !isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = true
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
                            sheetView.capture(content, old: beganContent, at: ci)
                        }
                    }
                    for (ti, beganText) in beganTexts {
                        guard ti < sheetView.model.texts.count else { continue }
                        let text = sheetView.textsView.elementViews[ti].model
                        if text != beganText {
                            updateUndoGroup()
                            sheetView.capture(text, old: beganText, at: ti)
                        }
                    }
                }
            }
            
            document.cursor = Document.defaultCursor
        }
    }
}

final class AnimationSlider: DragEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    enum SlideType {
        case key, startBeat, all, none
    }
    
    private let indexInterval = 10.0
    
    private var node = Node()
    private var sheetView: SheetView?, animationIndex = 0, keyframeIndex = 0
    private var type = SlideType.key
    private var beganSP = Point(), beganInP = Point(),
                beganTimelineX = 0.0, beganKeyframeX = 0.0,
                beganKeyframeDurBeat = Rational(0)
    private var beganAnimationOption: AnimationOption?
    private var lastBeats = [(sec: Double, rootBeat: Rational)](capacity: 128)
    private var minLastSec = 1 / 12.0
    
    func send(_ event: DragEvent) {
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
            
            if let sheetView = document.sheetView(at: p), sheetView.model.enabledAnimation {
                beganSP = sp
                self.sheetView = sheetView
                let inP = sheetView.convertFromWorld(p)
                beganInP = inP
                beganTimelineX = sheetView.animationView
                    .x(atBeat: sheetView.animationView.model.beatRange.start)
                if sheetView.animationView.containsTimeline(inP) {
                    let animationView = sheetView.animationView
                    
                    if let minI = sheetView.animationView
                        .slidableKeyframeIndex(at: inP,
                                               maxDistance: document.worldKnobEditDistance,
                                               enabledKeyOnly: true) {
                        
                        type = .key
                        keyframeIndex = minI
                        let keyframe = animationView.model.keyframes[keyframeIndex]
                        beganKeyframeDurBeat = keyframe.durBeat
                        beganKeyframeX = sheetView.animationView.x(atBeat: animationView.model.localBeat(at: minI) + keyframe.durBeat)
                        lastBeats.append((event.time, animationView.model.localBeat(at: minI) + keyframe.durBeat))
                    } else if animationView.isStartBeat(at: inP, scale: document.screenToWorldScale) {
                        
                        type = .all
                        
                        beganAnimationOption = sheetView.model.animation.option
                        lastBeats.append((event.time, beganAnimationOption!.startBeat))
                    } else {
                        type = .none
                    }
                }
            }
        case .changed:
            if let sheetView = sheetView {
                let animationView = sheetView.animationView
                let inP = sheetView.convertFromWorld(p)
                
                switch type {
                case .all:
                    let nh = ScoreLayout.pitchHeight
                    let px = beganTimelineX + inP.x - beganInP.x
                    let py = ((beganAnimationOption?.timelineY ?? 0) + inP.y - beganInP.y)
                        .interval(scale: nh)
                    let interval = document.currentKeyframeBeatInterval
                    let beat = animationView.beat(atX: px,
                                                  interval: interval) + sheetView.model.animation.startBeat
                    if py != sheetView.animationView.timelineY
                        || beat != sheetView.model.animation.startBeat {
                        
                        sheetView.binder[keyPath: sheetView.keyPath]
                            .animation.startBeat = beat
                        sheetView.binder[keyPath: sheetView.keyPath]
                            .animation.timelineY = py
                        sheetView.animationView.updateTimeline()
                        
                        lastBeats.append((event.time, beat))
                        for (i, v) in lastBeats.enumerated().reversed() {
                            if event.time - v.sec > minLastSec {
                                if i > 0 {
                                    lastBeats.removeFirst(i - 1)
                                }
                                break
                            }
                        }
                    }
                case .startBeat:
                    let interval = document.currentKeyframeBeatInterval
                    let beat = animationView.beat(atX: inP.x,
                                                  interval: interval) + sheetView.model.animation.startBeat
                    if beat != sheetView.model.animation.startBeat {
                        sheetView.binder[keyPath: sheetView.keyPath]
                            .animation.startBeat = beat
                        
                        sheetView.animationView.updateTimeline()
                        
                        lastBeats.append((event.time, beat))
                        for (i, v) in lastBeats.enumerated().reversed() {
                            if event.time - v.sec > minLastSec {
                                if i > 0 {
                                    lastBeats.removeFirst(i - 1)
                                }
                                break
                            }
                        }
                    }
                case .key:
//                    let dSec = animationView.durSec(atWidth: dp.x)
                    let interval = document.currentKeyframeBeatInterval
                    let dBeat = animationView.beat(atX: beganKeyframeX + inP.x - beganInP.x,
                                                   interval: interval)
                    let nDur = dBeat - animationView.model.localBeat(at: keyframeIndex)
//
//                    let dBeat = animationView.model.beat(fromSec: dSec,
//                                                         beatRate: animationView.frameRate)
                    let dur = max(nDur, Keyframe.minDurBeat)
                    let oldDur = animationView.model.keyframes[keyframeIndex].durBeat
                    if oldDur != dur {
                        let rootBeatIndex = animationView.model.rootBeatIndex
                        
                        sheetView.binder[keyPath: sheetView.keyPath]
                            .animation.keyframes[keyframeIndex]
                            .durBeat = dur
                        
                        sheetView.rootBeatIndex = rootBeatIndex
                        sheetView.animationView.updateTimeline()
                        
                        let beat = dur
                        lastBeats.append((event.time, beat))
                        for (i, v) in lastBeats.enumerated().reversed() {
                            if event.time - v.sec > minLastSec {
                                if i > 0 {
                                    lastBeats.removeFirst(i - 1)
                                }
                                break
                            }
                        }
                    }
                case .none: break
                }
            }
        case .ended:
            node.removeFromParent()
            
            if let sheetView = sheetView {
                var isNewUndoGroup = false
                func updateUndoGroup() {
                    if !isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = true
                    }
                }
                switch type {
                case .all, .startBeat:
                    for (sec, beat) in lastBeats.reversed() {
                        if event.time - sec > minLastSec {
                            if beat != sheetView.model.animation.startBeat {
                                sheetView.binder[keyPath: sheetView.keyPath]
                                    .animation.startBeat = beat
                                
                                sheetView.animationView.updateTimeline()
                            }
                            break
                        }
                    }
                    
                    if let beganAnimationOption, sheetView.model.animation.option != beganAnimationOption {
                        updateUndoGroup()
                        sheetView.capture(option: sheetView.model.animation.option,
                                          oldOption: beganAnimationOption)
                    }
                case .key:
                    let beat = sheetView.animationView.model.keyframes[keyframeIndex].durBeat
                    for (sec, nBeat) in lastBeats.reversed() {
                        if event.time - sec > minLastSec {
                            if nBeat != beat {
                                sheetView.animationView.model.keyframes[keyframeIndex].durBeat = nBeat
                            }
                            break
                        }
                    }
                    
                    let animationView = sheetView.animationView
                    let keyframe = animationView.model.keyframes[keyframeIndex]
                    if keyframe.durBeat != beganKeyframeDurBeat {
                        updateUndoGroup()
                        sheetView.capture(durBeat: keyframe.durBeat,
                                          oldDurBeat: beganKeyframeDurBeat,
                                          at: keyframeIndex)
                    }
                case .none: break
                }
            }
            
            document.cursor = Document.defaultCursor
        }
    }
}

final class LineSlider: DragEditor {
    let document: Document
    let isEditingSheet: Bool

    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }

    private var isPit = false, noteI: Int?, pitI: Int?,
                beganNote: Note?, beganPit: Pit?, beganSP = Point()
    
    private var sheetView: SheetView?,
                lineIndex = 0, pointIndex = 0
    private var beganLine = Line(), beganMainP = Point(), beganSheetP = Point(),
                isPressure = false
    private var pressures = [(time: Double, pressure: Double)]()
    
    private var notePlayer: NotePlayer?
    private var beganBeatX = 0.0, beganPitchY = 0.0
    private var beganPitch = Rational(0), beganBeat = Rational(0), oldBeat = Rational(0), oldPitch = Rational(0)
    private var beganNotePits = [Int: (note: Note, pit: Pit, pits: [Int: Pit])]()
    private var playerBeatNoteIndexes = [Int]()
    
    func send(_ event: DragEvent) {
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

            func updatePlayer(from vs: [Note.PitResult], in sheetView: SheetView) {
                let stereo = Stereo(volm: sheetView.isPlaying ? 0.1 : 1)
                if let notePlayer = sheetView.notePlayer {
                    self.notePlayer = notePlayer
                    notePlayer.notes = vs
                    notePlayer.stereo = stereo
                } else {
                    notePlayer = try? NotePlayer(notes: vs, stereo: stereo)
                    sheetView.notePlayer = notePlayer
                }
                notePlayer?.play()
            }
            
            if let sheetView = document.sheetView(at: p) {
                let sheetP = sheetView.convertFromWorld(p)
                let scoreView = sheetView.scoreView
                let scoreP = scoreView.convertFromWorld(p)
                if scoreView.model.enabled,
                   let (noteI, pitI) = scoreView.noteAndPitI(at: scoreP,
                                                           scale: document.screenToWorldScale) {
                    
                    isPit = true
                    
                    let score = scoreView.model
                    let note = score.notes[noteI]
                    let pit = note.pits[pitI]
                    self.sheetView = sheetView
                    self.noteI = noteI
                    self.pitI = pitI
                    beganSP = sp
                    beganNote = note
                    beganPit = pit
                    
                    beganSheetP = sheetP
                    
                    beganPitch = note.pitch + pit.pitch
                    oldPitch = beganPitch
                    beganBeat = note.beatRange.start + pit.beat
                    oldBeat = beganBeat
                    beganBeatX = scoreView.x(atBeat: note.beatRange.start + pit.beat)
                    beganPitchY = scoreView.y(fromPitch: note.pitch + pit.pitch)
                    
                    var noteAndPitIs: [Int: [Int]]
                    if document.isSelect(at: p) {
                        noteAndPitIs = sheetView.noteAndPitIndexes(from: document.selections,
                                                                   enabledAll: false)
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
                    
                    let vs = score.noteIAndPits(atBeat: pit.beat + note.beatRange.start,
                                                in: Set(beganNotePits.keys).sorted())
                    playerBeatNoteIndexes = vs.map { $0.noteI }
                    
                    updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
                    
                    document.cursor = .circle(string: Pitch(value: beganPitch).octaveString())
                } else if let (lineView, li) = sheetView.lineTuple(at: sheetP,
                                                                   isSmall: false,
                                                                   scale: document.screenToWorldScale),
                   let pi = lineView.model.mainPointSequence.nearestIndex(at: sheetP) {
                    
                    self.sheetView = sheetView
                    beganLine = lineView.model
                    lineIndex = li
                    pointIndex = pi
                    beganMainP = beganLine.mainPoint(at: pi)
                    beganSheetP = sheetP
                    let pressure = event.pressure
                        .clipped(min: 0.4, max: 1, newMin: 0, newMax: 1)
                    pressures.append((event.time, pressure))
                }
            }
        case .changed:
            if let sheetView {
                if isPit {
                    let scoreView = sheetView.scoreView
                    let score = scoreView.model
                    if let noteI, noteI < score.notes.count, let pitI {
                        let sheetP = sheetView.convertFromWorld(p)
                        
                        let note = score.notes[noteI]
                        let preBeat = (pitI > 0 ? note.pits[pitI - 1].beat : 0) + note.beatRange.start
                        let nextBeat = (pitI + 1 < note.pits.count ? note.pits[pitI + 1].beat : note.beatRange.length) + note.beatRange.start
                        let beatInterval = Sheet.fullEditBeatInterval
                        let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                    interval: Sheet.fullEditPitchInterval)
                        let nsBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                    interval: beatInterval)
                            .clipped(min: preBeat, max: nextBeat)
                        if pitch != oldPitch || nsBeat != oldBeat {
                            let dBeat = nsBeat - beganBeat
                            let dPitch = pitch - beganPitch
                            
                            for (noteI, nv) in beganNotePits {
                                guard noteI < score.notes.count else { continue }
                                var note = scoreView[noteI]
                                for (pitI, beganPit) in nv.pits {
                                    guard pitI < score.notes[noteI].pits.count else { continue }
                                    note.pits[pitI].beat = dBeat + beganPit.beat
                                    note.pits[pitI].pitch = dPitch + beganPit.pitch
                                }
                                scoreView[noteI] = note
                            }
                            
                            oldBeat = nsBeat
                            
                            if pitch != oldPitch {
                                let note = scoreView[noteI]
                                let pBeat = note.pits[pitI].beat + note.beatRange.start
                                notePlayer?.notes = playerBeatNoteIndexes.map {
                                    scoreView.pitResult(atBeat: pBeat, at: $0)
                                }
                                
                                oldPitch = pitch
                                
                                document.cursor = .circle(string: Pitch(value: pitch).octaveString())
                            }
                            document.updateSelects()
                        }
                    }
                } else {
                    if lineIndex < sheetView.linesView.elementViews.count {
                        let lineView = sheetView.linesView.elementViews[lineIndex]
                        
                        var line = lineView.model
                        if pointIndex < line.mainPointCount {
                            let inP = sheetView.convertFromWorld(p)
                            let op = inP - beganSheetP + beganMainP
                            let np = line.mainPoint(withMainCenterPoint: op,
                                                    at: pointIndex)
                            let pressure = event.pressure
                                .clipped(min: 0.4, max: 1, newMin: 0, newMax: 1)
                            pressures.append((event.time, pressure))
                            
                            line.controls[pointIndex].point = np
                            
                            if isPressure || (!isPressure && (event.time - (pressures.first?.time ?? 0) > 1 && !pressures.contains(where: { $0.pressure > 0.5 }))) {
                                isPressure = true
                                
                                let nPressures = pressures
                                    .filter { (0.04 ..< 0.4).contains(event.time - $0.time) }
                                let nPressure = nPressures.mean { $0.pressure } ?? pressures.first!.pressure
                                line.controls[pointIndex].pressure = nPressure
                            }
                            
                            lineView.model = line
                        }
                    }
                }
            }
        case .ended:
            if let sheetView {
                if isPit {
                    notePlayer?.stop()
                    
                    var isNewUndoGroup = false
                    func updateUndoGroup() {
                        if !isNewUndoGroup {
                            sheetView.newUndoGroup()
                            isNewUndoGroup = true
                        }
                    }
                    
                    if !beganNotePits.isEmpty {
                        let scoreView = sheetView.scoreView
                        let score = scoreView.model
                        var noteIVs = [IndexValue<Note>](), oldNoteIVs = [IndexValue<Note>]()
                        
                        let beganNoteIAndNotes = beganNotePits.reduce(into: [Int: Note]()) {
                            $0[$1.key] = $1.value.note
                        }
                        for (ni, beganNote) in beganNoteIAndNotes {
                            guard ni < score.notes.count else { continue }
                            let note = scoreView.model.notes[ni]
                            if beganNote != note {
                                noteIVs.append(.init(value: note, index: ni))
                                oldNoteIVs.append(.init(value: beganNote, index: ni))
                            }
                        }
                        if !noteIVs.isEmpty {
                            updateUndoGroup()
                            sheetView.capture(noteIVs, old: oldNoteIVs)
                        }
                    }
                } else {
                    if lineIndex < sheetView.linesView.elementViews.count {
                        let line = sheetView.linesView.elementViews[lineIndex].model
                        if line != beganLine {
                            sheetView.newUndoGroup()
                            sheetView.captureLine(line, old: beganLine, at: lineIndex)
                        }
                    }
                }
            }

            document.cursor = Document.defaultCursor
        }
    }
}

final class LineZSlider: DragEditor {
    let document: Document
    let isEditingSheet: Bool

    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }

    private var sheetView: SheetView?, lineNode = Node(),
    crossIndexes = [Int](), crossLineIndex = 0,
    lineIndex = 0, lineView: SheetLineView?, oldSP = Point()
    
    func send(_ event: DragEvent) {
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

            if let sheetView = document.sheetView(at: p) {
                let inP = sheetView.convertFromWorld(p)
                if let (lineView, li) = sheetView.lineTuple(at: inP,
                                                            isSmall: false,
                                                            scale: document.screenToWorldScale) {
                    
                    self.sheetView = sheetView
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
                    
                    oldSP = sp
                    lineNode.path = Path(lineView.model)
                    lineNode.lineType = lineView.node.lineType
                    lineNode.lineWidth = lineView.node.lineWidth
                    sheetView.linesView.node.children.insert(lineNode, at: li)
                }
            }
        case .changed:
            if let sheetView = sheetView,
               lineIndex < sheetView.linesView.elementViews.count {
                
                guard !crossIndexes.isEmpty else { return }
                
                let cli = (Int((sp.y - oldSP.y) / 10) + crossLineIndex)
                    .clipped(min: 0, max: crossIndexes.count - 1)
                let li = crossIndexes[cli]
                    .clipped(min: 0,
                             max: sheetView.linesView.elementViews.count)
                lineNode.removeFromParent()
                sheetView.linesView.node.children.insert(lineNode, at: li)
            }
        case .ended:
            lineNode.removeFromParent()
            lineView?.node.isHidden = false
            
            if let sheetView = sheetView,
               lineIndex < sheetView.linesView.elementViews.count {
                
                guard !crossIndexes.isEmpty else { return }
                
                let cli = (Int((sp.y - oldSP.y) / 10) + crossLineIndex)
                    .clipped(min: 0, max: crossIndexes.count - 1)
                let li = crossIndexes[cli]
                    .clipped(min: 0,
                             max: sheetView.linesView.elementViews.count)
                let line = sheetView.linesView.elementViews[lineIndex].model
                if lineIndex != li {
                    sheetView.newUndoGroup()
                    sheetView.removeLines(at: [lineIndex])
                    sheetView.insert([.init(value: line, index: li > lineIndex ? li - 1 : li)])
                }
            }

            document.cursor = Document.defaultCursor
        }
    }
}

final class Slider: DragEditor {
    let document: Document
    
    init(_ document: Document) {
        self.document = document
    }
    
    enum SlideType {
        case keyframe(KeyframeSlider)
        case animation(AnimationSlider)
        case score(ScoreSlider)
        case content(ContentSlider)
        case text(TextSlider)
        case tempo(TempoSlider)
        case none
    }
    private var type = SlideType.none
    
    func updateNode() {
        switch type {
        case .keyframe(let keyframeSlider): keyframeSlider.updateNode()
        case .animation(let keyframeDurationSlider): keyframeDurationSlider.updateNode()
        case .score(let scoreSlider): scoreSlider.updateNode()
        case .content(let contentSlider): contentSlider.updateNode()
        case .text(let textSlider): textSlider.updateNode()
        case .tempo(let tempoSlider): tempoSlider.updateNode()
        case .none: break
        }
    }
    
    func send(_ event: DragEvent) {
        if event.phase == .began {
            let sp = document.lastEditedSheetScreenCenterPositionNoneCursor
                ?? event.screenPoint
            let p = document.convertScreenToWorld(sp)
            
            if let sheetView = document.sheetView(at: p) {
                let inP = sheetView.convertFromWorld(p)
                if sheetView.containsTempo(inP, maxDistance: document.worldKnobEditDistance * 0.5) {
                    type = .tempo(TempoSlider(document))
                } else if let ci = sheetView.contentIndex(at: inP, scale: document.screenToWorldScale),
                          sheetView.model.contents[ci].timeOption != nil {
                    type = .content(ContentSlider(document))
                } else if let ti = sheetView.textIndex(at: inP),
                           sheetView.model.texts[ti].timeOption != nil {
                    type = .text(TextSlider(document))
                } else if sheetView.scoreView.containsTimeline(inP) 
                            || sheetView.scoreView.noteIndex(at: sheetView.scoreView.convertFromWorld(p),
                                                             scale: document.screenToWorldScale,
                                                             enabledRelease: true) != nil {
                    type = .score(ScoreSlider(document))
                } else if sheetView.animationView.containsTimeline(inP) {
                    type = .animation(AnimationSlider(document))
                } else {
                    type = .keyframe(KeyframeSlider(document))
                }
            }
        }
        
        switch type {
        case .keyframe(let keyframeSlider):
            keyframeSlider.send(event)
        case .animation(let keyframeDurationSlider):
            keyframeDurationSlider.send(event)
        case .score(let scoreSlider):
            scoreSlider.send(event)
        case .content(let contentSlider):
            contentSlider.send(event)
        case .text(let textSlider):
            textSlider.send(event)
        case .tempo(let tempoSlider):
            tempoSlider.send(event)
        case .none: break
        }
    }
}

final class KeyframeInserter: InputKeyEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private var linesNode = Node()
    
    func send(_ event: InputKeyEvent) {
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
            
            if let sheetView = document.madeSheetView(at: p) {
                let inP = sheetView.convertFromWorld(p)
                
                sheetView.selectedFrameIndexes = []
                
                if sheetView.animationView.containsTimeline(inP) {
                    let animationView = sheetView.animationView
                    let animation = animationView.model
                    
                    let interval = document.currentNoteBeatInterval
                    let oBeat = animationView.beat(atX: inP.x, interval: interval)
                    let beat = (oBeat - animation.beatRange.start)
                        .clipped(min: 0, max: animation.beatRange.length)
                    + animation.beatRange.start
                    
                    var rootBP = animation.rootBeatPosition
                    rootBP.beat = beat
                    if let (i, iBeat) = animation
                        .indexAndInternalBeat(atRootBeat: beat) {
                        let i = iBeat != 0 ?
                        i :
                        (animationView.beat(atX: inP.x, interval: Rational(1, 60)) < beat ? i - 1 : i)
                        let iBeat = {
                            if iBeat != 0 {
                                return iBeat
                            } else {
                                let nextBeat = animation.keyframes[i].containsInterpolated ?
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
                        if iBeat != 0 && !animation.keyframes[i].containsInterpolated {
                            let nDurBeat = animation.keyframes[i].durBeat - iBeat
                            let keyframe = Keyframe(durBeat: nDurBeat)
                            animationView.selectedFrameIndexes = []
                            sheetView.newUndoGroup(enabledKeyframeIndex: false)
                            sheetView.set(durBeat: iBeat, at: i)
                            sheetView.insert([IndexValue(value: keyframe, index: i + 1)])
                        } else if animation.keyframes[i].containsInterpolated {
                            let idivs: [IndexValue<InterOption>] = (0 ..< animation.keyframes[i].picture.lines.count).compactMap {
                                
                                let option = animation.keyframes[i]
                                    .picture.lines[$0].interOption
                                if option.interType == .interpolated {
                                    let nOption = option.with(.key)
                                    return IndexValue(value: nOption,
                                                      index: $0)
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
                                                    rootKeyframeIndex: i,
                                                    isNewUndoGroup: false)
                            animationView.updateTimeline()
                        }
                    }
                } else if sheetView.model.score.enabled {
                    let scoreView = sheetView.scoreView
                    let scoreP = sheetView.scoreView.convertFromWorld(p)
                    if let noteI = sheetView.scoreView.noteIndex(at: scoreP,
                                                                 scale: document.screenToWorldScale) {
                        let score = scoreView.model
                        let scoreP = scoreView.convertFromWorld(p)
                        if let (pitI, _) = scoreView.pitIAndSprolI(at: scoreP, at: noteI) {
                            let sprol = scoreView.nearestSprol(at: scoreP, at: noteI)
                            let oldTone = score.notes[noteI].pits[pitI].tone
                            var tone = oldTone
                            let i = tone.spectlope.sprols.enumerated().reversed()
                                .first(where: { sprol.pitch > $0.element.pitch })?.offset ?? 0
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
                                                            beatInterval: document.currentNoteBeatInterval,
                                                            pitchInterval: document.currentNotePitchInterval)
                            if !pits.contains(where: { $0.beat == pit.beat }) {
                                pits.append(pit)
                                pits.sort { $0.beat < $1.beat }
                                var note = score.notes[noteI]
                                note.pits = pits
                                
                                sheetView.newUndoGroup()
                                sheetView.replace(note, at: noteI)
                                
                                sheetView.updatePlaying()
                            }
                        }
                    } else if scoreView.containsTimeline(scoreP) {
                        let interval = document.currentNoteBeatInterval
                        let beat = scoreView.beat(atX: inP.x, interval: interval)
                        var option = scoreView.model.option
                        option.keyBeats.append(beat)
                        option.keyBeats.sort()
                        sheetView.newUndoGroup()
                        sheetView.set(option)
                    }
                } else if let ci = sheetView.contentIndex(at: inP, scale: document.screenToWorldScale) {
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
                } else if let ti = sheetView.textIndex(at: inP) {
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
                } else if !sheetView.model.enabledAnimation {
                    sheetView.newUndoGroup(enabledKeyframeIndex: false)
                    sheetView.set(durBeat: Animation.defaultDurBeat,
                                  at: 0)
                    var option = sheetView.model.animation.option
                    option.enabled = true
                    sheetView.set(option)
                }
                
                document.updateEditorNode()
                document.updateSelects()
            }
        case .changed:
            break
        case .ended:
            linesNode.removeFromParent()
            
            document.cursor = Document.defaultCursor
        }
    }
}

final class KeyframeCutter: InputKeyEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private var linesNode = Node()
    
    func send(_ event: InputKeyEvent) {
        guard isEditingSheet else {
            document.stop(with: event)
            return
        }
        if document.isPlaying(with: event) {
            document.stopPlaying(with: event)
        }
        switch event.phase {
        case .began:
            document.cursor = .arrow
            
        case .changed:
            break
        case .ended:
            linesNode.removeFromParent()
            
            document.cursor = Document.defaultCursor
        }
    }
}

final class Interpolater: InputKeyEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private var linesNode = Node()
    
    func send(_ event: InputKeyEvent) {
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
            
            let cos = Pasteboard.shared.copiedObjects
            for co in cos {
                if case .sheetValue(let v) = co,
                   v.lines.isEmpty,
                    let oUUColor = v.planes.first?.uuColor {
                    
                    let nUUColor = document.uuColor(at: p)
                    if let sheetView = document.sheetView(at: p),
                       sheetView.id == v.id {
                        
                        let animationView = sheetView.animationView
                        let orki = v.rootKeyframeIndex,
                            nrki = animationView.rootKeyframeIndex
                        if orki != nrki {
                            var filledIs = Set<Int>()
                            var vs = [(ki: Int, pis: [Int], color: Color)]()
                            let di = abs(nrki - orki)
                            for dri in 0 ... di {
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
                                    vs.append((ki, pis, color))
                                    filledIs.insert(ki)
                                }
                            }
                            
                            let svs = vs.sorted(by: { $0.ki < $1.ki })
                            let cv = ColorValue(
                                uuColor: oUUColor,
                                planeIndexes: [], lineIndexes: [],
                                isBackground: false,
                                planeAnimationIndexes: svs.map { .init(value: $0.pis, index: $0.ki) },
                                lineAnimationIndexes: [],
                                animationColors: svs.map { $0.color }
                            )
                            let ocv = ColorValue(
                                uuColor: oUUColor,
                                planeIndexes: [], lineIndexes: [],
                                isBackground: false,
                                planeAnimationIndexes: svs.map { .init(value: $0.pis, index: $0.ki) },
                                lineAnimationIndexes: [],
                                animationColors: svs.map {
                                    sheetView.model.animation.keyframes[$0.ki].picture.planes[$0.pis.first!].uuColor.value
                                }
                            )
                            sheetView.newUndoGroup()
                            sheetView.set(cv, oldColorValue: ocv)
                        }
                    }
                    return
                }
            }
            guard let o = cos.first else { return }
            
            let sheetID: SheetID, ios: [InterOption], oldRootKeyframeIndex: Int
            switch o {
            case .sheetValue(let v):
                sheetID = v.id
                ios = v.lines.map { $0.interOption.with(.key) }
                oldRootKeyframeIndex = v.rootKeyframeIndex
            case .ids(let v):
                sheetID = v.sheetID
                ios = v.ids.map { $0.with(.key) }
                oldRootKeyframeIndex = v.rootKeyframeIndex
            default: return
            }
            
            if let sheetView = document.sheetView(at: p),
               sheetView.id == sheetID {
                
                let animationView = sheetView.animationView
                var isNewUndoGroup = false
                if oldRootKeyframeIndex != animationView.rootKeyframeIndex {
                    let beat = animationView.model.localBeat
                    let count = ((animationView.rootBeat - beat) / animationView.model.localDurBeat).rounded(.towardZero)
                    
                    let oneT = Rational(1, animationView.frameRate)
                    
                    let ki0 = animationView.model.index(atRoot: oldRootKeyframeIndex)
                    let ki1 = animationView.model.index(atRoot: animationView.rootKeyframeIndex)
                    let nki0 = min(ki0, ki1), nki1 = max(ki0, ki1)
                    let ranges = (oldRootKeyframeIndex < animationView.rootKeyframeIndex ? ki0 < ki1 : ki1 < ki0) ? [nki0 ..< nki1] : [0 ..< nki0, nki1 ..< animationView.model.keyframes.count]
                    
                    var nj = 0
                    for range in ranges {
                        for j in range {
                            let k = animationView.model.keyframes[j + nj]
                            let tl = k.durBeat
                            if tl >= oneT {
                                if !isNewUndoGroup {
                                    sheetView.newUndoGroup()
                                    isNewUndoGroup = true
                                }
                                
                                sheetView.set(durBeat: oneT, at: j + nj)
                                let count = Int(tl / oneT) - 1
                                sheetView.insert((0 ..< count).map { k in
                                    IndexValue(value: Keyframe(durBeat: oneT),
                                               index: k + j + nj + 1)
                                })
                                nj += count
                            }
                        }
                    }
                    sheetView.rootBeat = animationView.model.localDurBeat * count + beat
                    document.updateEditorNode()
                    document.updateSelects()
                }
                
                let lis: [Int]
                if document.isSelectNoneCursor(at: p), !document.isSelectedText {
                    lis = sheetView.lineIndexes(from: document.selections)
                } else {
                    if let li = sheetView.lineTuple(at: sheetView.convertFromWorld(p), scale: 1 / document.worldToScreenScale)?.lineIndex {
                        lis = [li]
                    } else {
                        lis = []
                    }
                }
                
                let maxCount = min(ios.count, lis.count)
                guard maxCount > 0 else { return }
                let idSet = Set(ios.map { $0.id })
                let lineIDSet = Set(animationView.currentKeyframe.picture.lines.map { $0.id })
                let idivs: [IndexValue<InterOption>] = (0 ..< maxCount).compactMap {
                    let line = animationView.currentKeyframe.picture.lines[lis[$0]]
                    var interOption: InterOption
                    if idSet.contains(line.interOption.id) {
                        interOption = line.interOption
                    } else {
                        if lineIDSet.contains(ios[$0].id) {
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
                let nidivs = idivs.filter { idiv in
                    let line = animationView.currentKeyframe.picture.lines[idiv.index]
                    let idLines = animationView.currentKeyframe.picture.lines.filter { $0.id == idiv.value.id }
                    if ((oldRootKeyframeIndex == animationView.model.rootIndex
                        || !animationView.isInterpolated(atLineIndex: idiv.index))
                        && idLines.isEmpty)
                        || idLines.count == 1 && idLines[0] == line {
                        return true
                    } else if idLines.isEmpty
                                && animationView.isInterpolated(atLineIndex: idiv.index) {
                        let lw = Line.defaultLineWidth
                        let scale = 1 / document.worldToScreenScale
                        let blw = max(lw * 1.5, lw * 2.5 * scale, 1 * scale)
                        let nLine = sheetView.convertToWorld(line)
                        noNodes.append(Node(path: Path(nLine),
                                       lineWidth: blw,
                                       lineType: .color(.warning)))
                        return true
                    } else {
                        let lw = Line.defaultLineWidth
                        let scale = 1 / document.worldToScreenScale
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
                
                if !nidivs.isEmpty {
                    if !isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = true
                    }
                    sheetView.set([IndexValue(value: idivs, index: animationView.model.index)])
                    
                    let nids = idivs.map { $0.value.id }
                    sheetView.interpolation(nids.enumerated().map { (i, v) in (v, [v]) },
                                            rootKeyframeIndex: oldRootKeyframeIndex,
                                            isNewUndoGroup: false)
                    
                    let scale = 1 / document.worldToScreenScale
                    let iNodes = animationView.interpolationNodes(from: nids, scale: scale)
                    linesNode.children = iNodes + noNodes
                    
                    sheetView.setRootKeyframeIndex(rootKeyframeIndex: animationView.rootKeyframeIndex)
                    
                    animationView.updateTimeline()
                } else {
                    linesNode.children = noNodes
                }
                
                document.rootNode.append(child: linesNode)
            }
        case .changed:
            break
        case .ended:
            linesNode.removeFromParent()
            
            document.cursor = Document.defaultCursor
        }
    }
}
extension SheetView {
    func interpolation(_ ids: [(mainID: UUID, replaceIDs: [UUID])],
                       rootKeyframeIndex: Int,
                       isNewUndoGroup: Bool) {
        var appLIVs = [Int: [Line]]()
        var repLIVs = [Int: [IndexValue<Line>]]()
        for (id, repIDs) in ids {
            let repIDSet = Set(repIDs)
            
            var time = Rational(0)
            let kts: [(keyframe: Keyframe, time: Rational)]
                = model.animation.keyframes.map {
                    let t = time
                    time += $0.durBeat
                    return ($0, t)
            }
            let duration = time
            
            let rki = self.rootKeyframeIndex
            let lki = model.animation.index
            var keyAndIs = [(i: Int, key: Interpolation<Line>.Key)]()
            var keyIDic = [Int: Int]()
            for (i, kt) in kts.enumerated() {
                var nLine: Line?
                for line in kt.keyframe.picture.lines {
                    if line.id == id
                        && line.interType != .interpolated {
                        nLine = line
                        break
                    }
                }
                if let nLine = nLine {
                    let key = Interpolation.Key(value: nLine,
                                                time: Double(kt.time),
                                                type: .spline)
                    keyAndIs.append((i, key))
                    keyIDic[i] = keyAndIs.count - 1
                }
            }
            
            guard keyAndIs.count > 1 else {
                if var l = keyAndIs.first?.key.value {
                    l.interType = .interpolated
                    for (i, kt) in kts.enumerated() {
                        guard i != lki else { continue }
                        var isRep = false
                        for (li, line) in kt.keyframe.picture.lines.enumerated() {
                            if line.id == id {
                                if line != l {
                                    let iv = IndexValue(value: l,
                                                        index: li)
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
                            if appLIVs[i] == nil {
                                appLIVs[i] = [l]
                            } else {
                                appLIVs[i]?.append(l)
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
            if rootKeyframeIndex > rki {
                preFKI = fki + 1 < keyAndIs.count ? fki + 1 : 0
                loopI = keyAndIs[preFKI].i
                firstI = keyAndIs[fki].i
            } else if rootKeyframeIndex < rki {
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
                guard let line =  kts[j].keyframe.picture.lines.first(where: { $0.id == id }) else {
                    
                    break
                }
                if line.interType != .interpolated {
                    firstI = j
                }
                j = j - 1 >= 0 ? j - 1 : kts.count - 1
            }
            
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
                    guard let line =  kts[j].keyframe.picture.lines.first(where: { $0.id == id }) else {
                        
                        break
                    }
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
                    
                    if var line = interpolation
                        .monoValue(withTime: Double(kt.time)) {
                        
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
                            if appLIVs[i] == nil {
                                appLIVs[i] = [line]
                            } else {
                                appLIVs[i]?.append(line)
                            }
                        }
                    }
                }
            }
        }
        let appendValues = appLIVs.sorted(by: { $0.key < $1.key }).map {
            IndexValue(value: $0.value, index: $0.key)
        }
        let repValues = repLIVs.sorted(by: { $0.key < $1.key }).map {
            IndexValue(value: $0.value.sorted(by: { $0.index < $1.index }),
                       index: $0.key)
        }
        if !appendValues.isEmpty || !repValues.isEmpty {
            if isNewUndoGroup {
                newUndoGroup()
            }
            if !repValues.isEmpty {
                replaceKeyLines(repValues)
            }
            if !appendValues.isEmpty {
                appendKeyLines(appendValues)
            }
        }
    }
}

final class CrossEraser: InputKeyEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private var linesNode = Node()
    
    func send(_ event: InputKeyEvent) {
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
            
            let (_, sheetView, _, _) = document.sheetViewAndFrame(at: p)
            if let sheetView = sheetView {
                let inP = sheetView.convertFromWorld(p)
                let lis: [Int], isSelected: Bool
                if document.isSelectNoneCursor(at: p), !document.isSelectedText {
                    lis = sheetView.lineIndexes(from: document.selections)
                    isSelected = true
                } else {
                    if let li = sheetView.lineTuple(at: inP, scale: 1 / document.worldToScreenScale)?.lineIndex {
                        lis = [li]
                    } else {
                        lis = []
                    }
                    isSelected = false
                }
                let d = 2 / document.worldToScreenScale
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
                    document.rootNode.append(child: linesNode)
                    
                    document.updateEditorNode()
                    document.updateSelects()
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
                    document.rootNode.append(child: linesNode)
                    
                    document.updateEditorNode()
                    document.updateSelects()
                }
            }
        case .changed:
            break
        case .ended:
            linesNode.removeFromParent()
            
            document.cursor = Document.defaultCursor
        }
    }
}
