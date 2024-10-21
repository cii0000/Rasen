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
import struct Foundation.URL
import struct Foundation.Data

final class KeyframePreviousMover: InputKeyEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private var sheetView: SheetView?, contentIndex: Int?
    private var contentView: SheetContentView? {
        guard let sheetView, let contentIndex,
              contentIndex < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentIndex]
    }
    
    func send(_ event: InputKeyEvent) {
        guard isEditingSheet else {
            document.keepOut(with: event)
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
            if let sheetView {
                if let contentIndex = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                             scale: document.screenToWorldScale),
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
            
            document.cursor = document.cursor(from: contentView?.currentTimeString(isInter: true)
                                              ?? sheetView?.currentTimeString()
                                              ?? Animation.timeString(fromTime: 0, frameRate: 0))
        case .changed:
            if event.isRepeat, let sheetView {
                if let contentView {
                    contentView.movePreviousInterKeyframe()
                    sheetView.showOtherTimeNodeFromMainBeat()
                    
                    document.cursor = .circle(string: contentView.currentTimeString(isInter: true))
                } else {
                    move(from: sheetView, at: p)
                    sheetView.showOtherTimeNodeFromMainBeat()
                    sheetView.animationView.shownInterTypeKeyframeIndex = sheetView.animationView.model.index
                    
                    document.cursor = .circle(string: sheetView.currentTimeString())
                }
            }
        case .ended:
            if let sheetView {
                sheetView.hideOtherTimeNode()
                sheetView.animationView.shownInterTypeKeyframeIndex = nil
            }
            sheetView?.hideOtherTimeNode()
            
            document.cursor = document.defaultCursor
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
    
    private var sheetView: SheetView?, contentIndex: Int?
    private var contentView: SheetContentView? {
        guard let sheetView, let contentIndex,
              contentIndex < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentIndex]
    }
    
    func send(_ event: InputKeyEvent) {
        guard isEditingSheet else {
            document.keepOut(with: event)
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
        
            if let sheetView {
                if let contentIndex = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                             scale: document.screenToWorldScale),
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
            
            document.cursor = document.cursor(from: contentView?.currentTimeString(isInter: true)
                                              ?? sheetView?.currentTimeString()
                                              ?? Animation.timeString(fromTime: 0, frameRate: 0))
        case .changed:
            if event.isRepeat, let sheetView {
                if let contentView {
                    contentView.moveNextInterKeyframe()
                    sheetView.showOtherTimeNodeFromMainBeat()
                    
                    document.cursor = .circle(string: contentView.currentTimeString(isInter: true))
                } else {
                    move(from: sheetView, at: p)
                    sheetView.showOtherTimeNodeFromMainBeat()
                    sheetView.animationView.shownInterTypeKeyframeIndex = sheetView.animationView.model.index
                    
                    document.cursor = document.cursor(from: sheetView.currentTimeString())
                }
            }
        case .ended:
            if let sheetView {
                sheetView.hideOtherTimeNode()
                sheetView.animationView.shownInterTypeKeyframeIndex = nil
            }
            
            document.cursor = document.defaultCursor
        }
    }
    
    func move(from sheetView: SheetView?, at sp: Point) {
        sheetView?.moveNextInterKeyframe()
        document.updateEditorNode()
        document.updateSelects()
    }
}

final class FramePreviousMover: InputKeyEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private var sheetView: SheetView?, contentIndex: Int?
    private var contentView: SheetContentView? {
        guard let sheetView, let contentIndex,
              contentIndex < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentIndex]
    }
    
    func send(_ event: InputKeyEvent) {
        guard isEditingSheet else {
            document.keepOut(with: event)
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
            
            if let sheetView {
                if let contentIndex = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                             scale: document.screenToWorldScale),
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
            
            document.cursor = document.cursor(from: contentView?.currentTimeString(isInter: false)
                                              ?? sheetView?.currentTimeString()
                                              ?? Animation.timeString(fromTime: 0, frameRate: 0))
        case .changed:
            if event.isRepeat, let sheetView {
                if let contentView {
                    contentView.movePreviousKeyframe()
                    sheetView.showOtherTimeNodeFromMainBeat()
                    
                    document.cursor = .circle(string: contentView.currentTimeString(isInter: false))
                } else {
                    move(from: sheetView, at: p)
                    sheetView.showOtherTimeNodeFromMainBeat()
                    sheetView.animationView.shownInterTypeKeyframeIndex = sheetView.animationView.model.index
                    
                    document.cursor = document.cursor(from: sheetView.currentTimeString())
                }
            }
        case .ended:
            if let sheetView {
                sheetView.hideOtherTimeNode()
                sheetView.animationView.shownInterTypeKeyframeIndex = nil
            }
            
            document.cursor = document.defaultCursor
        }
    }
    
    func move(from sheetView: SheetView?, at sp: Point) {
        sheetView?.movePreviousKeyframe()
        document.updateEditorNode()
        document.updateSelects()
    }
}

final class FrameNextMover: InputKeyEditor {
    let document: Document
    let isEditingSheet: Bool
    
    init(_ document: Document) {
        self.document = document
        isEditingSheet = document.isEditingSheet
    }
    
    private var sheetView: SheetView?, contentIndex: Int?
    private var contentView: SheetContentView? {
        guard let sheetView, let contentIndex,
              contentIndex < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentIndex]
    }
    
    func send(_ event: InputKeyEvent) {
        guard isEditingSheet else {
            document.keepOut(with: event)
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
            
            if let sheetView {
                if let contentIndex = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                             scale: document.screenToWorldScale),
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
            
            document.cursor = document.cursor(from: contentView?.currentTimeString(isInter: false)
                                              ?? sheetView?.currentTimeString()
                                              ?? Animation.timeString(fromTime: 0, frameRate: 0))
        case .changed:
            if event.isRepeat, let sheetView {
                if let contentView {
                    contentView.moveNextKeyframe()
                    sheetView.showOtherTimeNodeFromMainBeat()
                    
                    document.cursor = .circle(string: contentView.currentTimeString(isInter: false))
                } else {
                    move(from: sheetView, at: p)
                    sheetView.showOtherTimeNodeFromMainBeat()
                    sheetView.animationView.shownInterTypeKeyframeIndex = sheetView.animationView.model.index
                    
                    document.cursor = document.cursor(from: sheetView.currentTimeString())
                }
            }
        case .ended:
            if let sheetView {
                sheetView.hideOtherTimeNode()
                sheetView.animationView.shownInterTypeKeyframeIndex = nil
            }
            
            document.cursor = document.defaultCursor
        }
    }
    
    func move(from sheetView: SheetView?, at sp: Point) {
        sheetView?.moveNextKeyframe()
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
    
    private var sheetView: SheetView?, contentIndex: Int?
    private var contentView: SheetContentView? {
        guard let sheetView, let contentIndex,
              contentIndex < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentIndex]
    }
    private var beganContentBeat: Rational = 0, oldContentBeat: Rational = 0
    private var interpolatedNode = Node(), interpolatedRootIndex: Int?
    private var oldDeltaI: Int?
    private var beganSP = Point(),
                beganRootBeat = Rational(0), beganRootInterIndex = 0,
                beganRootIndex = 0, beganSelectedFrameIndexes = [Int](),
                beganEventTime = 0.0
    private var allDp = Point()
    private var snapInterRootIndex: Int?, snapEventT: Double?
    private var lastRootIs = [(sec: Double, rootI: Int)](capacity: 128)
    private var minLastSec = 1 / 24.0
    
    func send(_ event: SwipeEvent) {
        guard isEditingSheet else {
            document.keepOut(with: event)
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
                if let contentIndex = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                             scale: document.screenToWorldScale),
                   sheetView.contentsView.elementViews[contentIndex].model.type == .movie {
                    self.contentIndex = contentIndex
                    if let contentView {
                        beganContentBeat = contentView.model.beat
                        oldContentBeat = beganContentBeat
                        document.cursor = document.cursor(from: contentView.currentTimeString(isInter: true))
                    }
                }
                
                if contentIndex == nil {
                    let animationView = sheetView.animationView
                    beganRootBeat = animationView.rootBeat
                    beganRootInterIndex = animationView.model.rootInterIndex
                    beganRootIndex = animationView.model.rootIndex
                    lastRootIs.append((event.time, beganRootIndex))
                    beganSelectedFrameIndexes = animationView.selectedFrameIndexes
                    animationView.shownInterTypeKeyframeIndex = animationView.model.index
                    oldDeltaI = nil
                    
                    document.cursor = document.cursor(from: sheetView.currentTimeString())
                }
            } else {
                document.cursor = document.cursor(from: Animation.timeString(fromTime: 0, frameRate: 0))
            }
            
            sheetView?.showOtherTimeNodeFromMainBeat()
        case .changed:
            if let sheetView {
                allDp += event.scrollDeltaPoint * 0.5
                let dp = allDp
                let deltaI = Int((dp.x / indexInterval).rounded())
                
                if let contentView {
                    if deltaI != oldDeltaI {
                        oldDeltaI = deltaI
                        
                        let nBeat = (beganContentBeat + .init(deltaI, 12))
                            .loop(start: 0, end: contentView.model.timeOption?.beatRange.length ?? 0)
                            .interval(scale: .init(1, 12))
                        if nBeat != oldContentBeat {
                            oldContentBeat = nBeat
                            
                            contentView.beat = nBeat
                            
                            document.cursor = .circle(string: contentView.currentTimeString(isInter: true))
                        }
                    }
                    return
                }
                
                let animationView = sheetView.animationView
                
                let ni = beganRootInterIndex.addingReportingOverflow(deltaI).partialValue
                let nRootI = animationView.model.rootIndex(atRootInter: ni)
                
                let ii = Double(beganRootInterIndex) + (dp.x - indexInterval / 2) / indexInterval
                let iit = ii - ii.rounded(.down)
                let si = nRootI
                let ei = animationView.model.rootIndex(atRootInter: ni + 1)
                if abs(ei - si) <= 1 {
                    interpolatedNode.children = []
                } else {
                    let nni = Int.linear(si, ei, t: iit)
                    if nni != interpolatedRootIndex {
                        interpolatedRootIndex = nni
                        let nnni = animationView.model.index(atRoot: nni)
                        if !animationView.model.keyframes[nnni].isKeyWhereAllLines {
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
            document.cursor = document.defaultCursor
            
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
    
    private var sheetView: SheetView?, contentIndex: Int?
    private var contentView: SheetContentView? {
        guard let sheetView, let contentIndex,
              contentIndex < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentIndex]
    }
    private var beganContentBeat: Rational = 0, oldContentBeat: Rational = 0
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
            document.keepOut(with: event)
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
                if let contentIndex = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                             scale: document.screenToWorldScale),
                   sheetView.contentsView.elementViews[contentIndex].model.type == .movie {
                    self.contentIndex = contentIndex
                    if let contentView {
                        beganContentBeat = contentView.model.beat
                        oldContentBeat = beganContentBeat
                        document.cursor = document.cursor(from: contentView.currentTimeString(isInter: true))
                    }
                }
                
                if contentIndex == nil {
                    let animationView = sheetView.animationView
                    beganRootBeat = animationView.rootBeat
                    beganRootInterIndex = animationView.model.rootInterIndex
                    beganRootIndex = animationView.model.rootIndex
                    lastRootIs.append((event.time, beganRootIndex))
                    beganSelectedFrameIndexes = animationView.selectedFrameIndexes
                    animationView.shownInterTypeKeyframeIndex = animationView.model.index
                    oldDeltaI = nil
                    
                    document.cursor = document.cursor(from: sheetView.currentTimeString())
                }
            } else {
                document.cursor = document.cursor(from: Animation.timeString(fromTime: 0, frameRate: 0))
            }
            
            sheetView?.showOtherTimeNodeFromMainBeat()
        case .changed:
            if let sheetView {
                let dp = event.screenPoint - beganSP
                if event.time - beganEventTime < 0.2 && abs(dp.x) < indexInterval * 3 { return }
                let deltaI = Int((dp.x / indexInterval).rounded())
                
                if let contentView {
                    if deltaI != oldDeltaI {
                        oldDeltaI = deltaI
                        
                        let nBeat = (beganContentBeat + .init(deltaI, 12))
                            .loop(start: 0, end: contentView.model.timeOption?.beatRange.length ?? 0)
                            .interval(scale: .init(1, 12))
                        if nBeat != oldContentBeat {
                            oldContentBeat = nBeat
                            
                            contentView.beat = nBeat
                            
                            document.cursor = .circle(string: contentView.currentTimeString(isInter: false))
                        }
                    }
                } else {
                    let animationView = sheetView.animationView
                    let ni = beganRootInterIndex.addingReportingOverflow(deltaI).partialValue
                    let nRootI = animationView.model.rootIndex(atRootInter: ni)
                    
                    let ii = Double(beganRootInterIndex) + (dp.x - indexInterval / 2) / indexInterval
                    let iit = ii - ii.rounded(.down)
                    let si = nRootI
                    let ei = animationView.model.rootIndex(atRootInter: ni + 1)
                    if abs(ei - si) <= 1 {
                        interpolatedNode.children = []
                    } else {
                        let nni = Int.linear(si, ei, t: iit)
                        if nni != interpolatedRootIndex {
                            interpolatedRootIndex = nni
                            let nnni = animationView.model.index(atRoot: nni)
                            if !animationView.model.keyframes[nnni].isKeyWhereAllLines {
                                let node = animationView.elementViews[nnni].linesView.node.clone
                                node.children.forEach { $0.lineType = .color(.subInterpolated) }
                                interpolatedNode.children = [node]
                                if interpolatedNode.parent == nil {
                                    sheetView.node.insert(child: interpolatedNode, at: 0)
                                }
                            } else {
                                interpolatedNode.children = []
                            }
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
            }
        case .ended:
            document.cursor = document.defaultCursor
            
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
    
    private let indexInterval = 5.0
    
    private var sheetView: SheetView?, contentIndex: Int?
    private var contentView: SheetContentView? {
        guard let sheetView, let contentIndex,
              contentIndex < sheetView.contentsView.elementViews.count else { return nil }
        return sheetView.contentsView.elementViews[contentIndex]
    }
    private var beganContentBeat: Rational = 0, oldContentBeat: Rational = 0
    private var beganSP = Point(),
                beganRootI = 0, beganBeat = Rational(0),
                beganSelectedFrameIndexes = [Int](), beganEventTime = 0.0
    private var oldDeltaI: Int?
    private var preMoveEventTime: Double?
    private var snapRootBeat: Rational?, snapEventTime: Double?
    private var lastRootBeats = [(sec: Double, rootI: Int)](capacity: 128)
    private var minLastSec = 1 / 12.0
    
    func selectFrame(with event: DragEvent, isMultiple: Bool) {
        guard isEditingSheet else {
            document.keepOut(with: event)
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
                if let contentIndex = sheetView.contentIndex(at: sheetView.convertFromWorld(p),
                                                             scale: document.screenToWorldScale),
                   sheetView.contentsView.elementViews[contentIndex].model.type == .movie {
                    self.contentIndex = contentIndex
                    if let contentView {
                        beganContentBeat = contentView.model.beat
                        oldContentBeat = beganContentBeat
                        document.cursor = document.cursor(from: contentView.currentTimeString(isInter: true))
                    }
                }
                
                if contentIndex == nil {
                    if sheetView.model.enabledAnimation {
                        let animationView = sheetView.animationView
                        beganRootI = animationView.rootKeyframeIndex
                        lastRootBeats.append((event.time, beganRootI))
                        beganBeat = animationView.model.localBeat
                        beganSelectedFrameIndexes = animationView.selectedFrameIndexes
                        animationView.shownInterTypeKeyframeIndex = animationView.model.index
                    }
                    
                    document.cursor = document.cursor(from: sheetView.currentTimeString())
                }
            } else {
                document.cursor = document.cursor(from: Animation.timeString(fromTime: 0, frameRate: 0))
            }
            
            sheetView?.showOtherTimeNodeFromMainBeat()
        case .changed:
            if let sheetView {
                let dp = event.screenPoint - beganSP
                let deltaI = Int((dp.x / indexInterval).rounded())
                
                if let contentView {
                    if deltaI != oldDeltaI {
                        oldDeltaI = deltaI
                        
                        let frameBeat = contentView.model.frameBeat ?? 1
                        let nBeat = (beganContentBeat + .init(deltaI) * frameBeat)
                            .loop(start: 0, end: contentView.model.timeOption?.beatRange.length ?? 0)
                            .interval(scale: frameBeat)
                        if nBeat != oldContentBeat {
                            oldContentBeat = nBeat
                            
                            contentView.beat = nBeat
                            
                            document.cursor = .circle(string: contentView.currentTimeString(isInter: false))
                        }
                    }
                } else {
                    if sheetView.model.enabledAnimation {
                        let animationView = sheetView.animationView
                        
                        let nRootI = beganRootI.addingReportingOverflow(deltaI).partialValue
                        
                        let oldKI = animationView.model.index
                        if animationView.rootKeyframeIndex != nRootI {
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
                            sheetView.rootKeyframeIndex = nRootI
                            document.updateEditorNode()
                            document.updateSelects()
                            
                            lastRootBeats.append((event.time, nRootI))
                            for (i, v) in lastRootBeats.enumerated().reversed() {
                                if event.time - v.sec > minLastSec {
                                    if i > 0 {
                                        lastRootBeats.removeFirst(i - 1)
                                    }
                                    break
                                }
                            }
                            
                            if oldKI != animationView.model.index {
                                if isMultiple {
                                    var isSelects = [Bool](repeating: false, count: animationView.model.keyframes.count)
                                    let range = beganRootI <= nRootI ? beganRootI ... nRootI : nRootI ... beganRootI
                                    for i in range {
                                        let ki = animationView.model.index(atRoot: i)
                                        isSelects[ki] = true
                                    }
                                    beganSelectedFrameIndexes.forEach { isSelects[$0] = true }
                                    let fis = isSelects.enumerated().compactMap { $0.element ? $0.offset : nil }
                                    animationView.selectedFrameIndexes = fis
                                }
                                
                                animationView.shownInterTypeKeyframeIndex = animationView.model.index
                            }
                            
                            document.cursor = document.cursor(from: sheetView.currentTimeString())
                            sheetView.showOtherTimeNodeFromMainBeat()
                        }
                    }
                }
            }
        case .ended:
            document.cursor = document.defaultCursor
            
            if let sheetView {
                let animationView = sheetView.animationView
                animationView.shownInterTypeKeyframeIndex = nil
                
                sheetView.hideOtherTimeNode()
                    
                for (sec, rootI) in lastRootBeats.reversed() {
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

final class TimeEditor: Editor {
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
            document.keepOut(with: event)
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
                }
            }
            document.cursor = document.cursor(from: sheetView?.currentTimeString() ?? Animation.timeString(fromTime: 0, frameRate: 0))
            
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
            document.cursor = document.defaultCursor
            
            if let sheetView {
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
            document.keepOut(with: event)
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
                
                if !(document.containsAllTimelines(with: event)
                    || (!cSheetView.model.enabledAnimation && cSheetView.model.enabledMusic)) {
                    
                    cSheetView.play()
                } else {
                    let sheetP = cSheetView.convertFromWorld(p)
                    var ids = Set<UUID>()
                    var secRange: Range<Rational>?
                    var sec: Rational = cSheetView.animationView.sec(atX: sheetP.x)
                    let scoreView = cSheetView.scoreView
                    if scoreView.model.enabled, let scoreTrackItem = scoreView.scoreTrackItem {
                        let scoreP = scoreView.convertFromWorld(p)
                        let score = scoreView.model
                        if let (noteI, pitI) = scoreView.noteAndPitI(at: scoreP, scale: document.screenToWorldScale) {
                            let beat = score.notes[noteI].pits[pitI].beat
                            + score.notes[noteI].beatRange.start + score.beatRange.start
                            sec = score.sec(fromBeat: beat)
                            secRange = score.secRange
                            ids.insert(scoreTrackItem.id)
                        } else if let noteI = scoreView.noteIndex(at: scoreP, scale: document.screenToWorldScale) {
                            let beat = score.notes[noteI].beatRange.start + score.beatRange.start
                            sec = score.sec(fromBeat: beat)
                            secRange = score.secRange
                            ids.insert(scoreTrackItem.id)
                        } else if scoreView.containsMainLine(scoreP, scale: document.screenToWorldScale) {
                            ids.insert(scoreTrackItem.id)
                        }
                        if secRange != nil {
                            cSheetView.previousSheetView = nil
                            cSheetView.nextSheetView = nil
                        }
                    } else if let ci = cSheetView.contentIndex(at: sheetP,
                                                               scale: document.screenToWorldScale) {
                        let contentView = cSheetView.contentsView.elementViews[ci]
                        if contentView.model.type == .movie
                            && !contentView.containsTimeline(contentView.convertFromWorld(p),
                                                             scale: document.screenToWorldScale) {
                            sec = contentView.sec(fromBeat: contentView.model.beat)
                        }
                    }
                    cSheetView.play(atSec: sec, inSec: secRange, otherTimelineIDs: ids)
                }
            }
        case .changed:
            break
        case .ended:
            if isEndStop {
                sheetView?.stop()
            }
            document.cursor = document.defaultCursor
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
            document.keepOut(with: event)
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
               sheetView.animationView.containsTimeline(sheetView.convertFromWorld(p), scale: document.screenToWorldScale) {
                
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
            
            document.cursor = document.defaultCursor
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
    private var beganSP = Point(), beganSheetP = Point()
    private var beganTempo: Rational = 1, oldTempo: Rational = 1
    private var beganAnimationOption: AnimationOption?, beganScoreOption: ScoreOption?,
                beganContents = [Int: Content](),
                beganTexts = [Int: Text]()
    
    func send(_ event: DragEvent) {
        guard isEditingSheet else {
            document.keepOut(with: event)
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
                beganSheetP = inP
                if let tempo = sheetView.tempo(at: inP, maxDistance: document.worldKnobEditDistance) {
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
            
            document.cursor = document.defaultCursor
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
        case key, all, startBeat, endBeat, none
    }
    
    private let indexInterval = 10.0
    
    private var node = Node()
    private var sheetView: SheetView?, animationIndex = 0, keyframeIndex = 0
    private var type = SlideType.key
    private var beganSP = Point(), beganSheetP = Point(), beganKeyframeOptions = [Int: KeyframeOption](),
                beganTimelineX = 0.0, beganKeyframeX = 0.0, beganBeatX = 0.0,
                beganKeyframeBeat = Rational(0)
    private var beganAnimationOption: AnimationOption?
    private var minLastSec = 1 / 12.0
    
    func send(_ event: DragEvent) {
        guard isEditingSheet else {
            document.keepOut(with: event)
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
                beganSheetP = inP
                beganTimelineX = sheetView.animationView
                    .x(atBeat: sheetView.animationView.model.beatRange.start)
                if sheetView.animationView.containsTimeline(inP, scale: document.screenToWorldScale) {
                    let animationView = sheetView.animationView
                    
                    if animationView.isEndBeat(at: inP, scale: document.screenToWorldScale) {
                        type = .endBeat
                        
                        beganAnimationOption = sheetView.model.animation.option
                        beganBeatX = animationView.x(atBeat: sheetView.model.animation.beatRange.end)
                    } else if let minI = animationView
                        .slidableKeyframeIndex(at: inP,
                                               maxDistance: document.worldKnobEditDistance,
                                               enabledKeyOnly: true) {
                        type = .key
                        
                        keyframeIndex = minI
                        let keyframe = animationView.model.keyframes[keyframeIndex]
                        beganKeyframeBeat = keyframe.beat
                        beganKeyframeX = animationView.x(atBeat: animationView.model.localBeat(at: minI))
                        
                        if !animationView.selectedFrameIndexes.isEmpty
                            && animationView.selectedFrameIndexes.contains(keyframeIndex) {
                            
                            beganKeyframeOptions = animationView.selectedFrameIndexes.reduce(into: .init()) {
                                $0[$1] = animationView.model.keyframes[$1].option
                            }
                        } else {
                            beganKeyframeOptions = [keyframeIndex: keyframe.option]
                        }
                    } else {
                        beganAnimationOption = sheetView.model.animation.option
                        type = .all
                    }
                }
            }
        case .changed:
            if let sheetView = sheetView {
                let animationView = sheetView.animationView
                let sheetP = sheetView.convertFromWorld(p)
                
                switch type {
                case .all:
                    let nh = ScoreLayout.pitchHeight
                    let np = beganTimelineX + sheetP - beganSheetP
                    let py = ((beganAnimationOption?.timelineY ?? 0) + sheetP.y - beganSheetP.y).interval(scale: nh)
                        .clipped(min: Sheet.timelineY, max: sheetView.bounds.height - Sheet.timelineY)
                    let interval = document.currentBeatInterval
                    let beat = max(min(sheetView.animationView.beat(atX: np.x, interval: interval),
                                   sheetView.animationView.beat(atX: sheetView.animationView.bounds.width - Sheet.textPadding.width, interval: interval)),
                                   sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval) - sheetView.animationView.model.beatRange.length)
                    if py != sheetView.animationView.timelineY
                        || beat != sheetView.model.animation.beatRange.start {
                        
                        sheetView.binder[keyPath: sheetView.keyPath].animation.beatRange.start = beat
                        sheetView.binder[keyPath: sheetView.keyPath].animation.timelineY = py
                        sheetView.animationView.updateTimeline()
                    }
                case .startBeat:
                    let interval = document.currentKeyframeBeatInterval
                    let beat = animationView.beat(atX: sheetP.x,
                                                  interval: interval) + sheetView.model.animation.beatRange.start
                    if beat != sheetView.model.animation.beatRange.start {
                        sheetView.binder[keyPath: sheetView.keyPath]
                            .animation.beatRange.start = beat
                        
                        sheetView.animationView.updateTimeline()
                    }
                case .endBeat:
                    if let beganAnimationOption {
                        let interval = document.currentBeatInterval
                        let nBeat = animationView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                       interval: interval)
                        if nBeat != animationView.beatRange?.end {
                            let dBeat = nBeat - beganAnimationOption.beatRange.end
                            let startBeat = sheetView.animationView.beat(atX: Sheet.textPadding.width, interval: interval)
                            let nkBeat = max(beganAnimationOption.beatRange.end + dBeat, startBeat)
                            
                            animationView.beatRange?.end = nkBeat
                        }
                    }
                case .key:
                    let interval = document.currentKeyframeBeatInterval
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
                case .all, .startBeat, .endBeat:
                    if let beganAnimationOption, sheetView.model.animation.option != beganAnimationOption {
                        updateUndoGroup()
                        sheetView.capture(option: sheetView.model.animation.option,
                                          oldOption: beganAnimationOption)
                    }
                case .key:
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
                case .none: break
                }
            }
            
            document.cursor = document.defaultCursor
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

    enum SlideType {
        case pit, reverbEarlyRSec, reverbEarlyAndLateRSec, reverbDurSec, even, sprol
    }
    private var isLine = false
    private var type = SlideType.pit
    
    private var noteI: Int?, pitI: Int?,
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
    private var beganStartBeat = Rational(0)
    private var beganTone = Tone(), beganOvertone = Overtone(), beganEnvelope = Envelope()
    private var sprolI: Int?, beganSprol = Sprol()
    private var beganNotes = [Int: Note]()
    private var beganNoteSprols = [UUID: (nid: UUID, dic: [Int: (note: Note, pits: [Int: (pit: Pit, sprolIs: Set<Int>)])])]()
    
    private var playerBeatNoteIndexes = [Int](), node = Node()
    
    func send(_ event: DragEvent) {
        guard isEditingSheet else {
            document.keepOut(with: event)
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
                if let notePlayer = sheetView.notePlayer {
                    self.notePlayer = notePlayer
                    notePlayer.notes = vs
                } else {
                    notePlayer = try? NotePlayer(notes: vs)
                    sheetView.notePlayer = notePlayer
                }
                notePlayer?.play()
            }
            
            if let sheetView = document.sheetView(at: p) {
                let sheetP = sheetView.convertFromWorld(p)
                let scoreView = sheetView.scoreView
                let scoreP = scoreView.convertFromWorld(p)
                
                if scoreView.model.enabled,
                   let (noteI, result) = scoreView.hitTestPoint(scoreP, scale: document.screenToWorldScale) {
                    
                    isLine = false
                    self.sheetView = sheetView
                    self.noteI = noteI
                    
                    let score = scoreView.model
                    let note = score.notes[noteI]
                    
                    let interval = document.currentBeatInterval
                    let nsBeat = scoreView.beat(atX: sheetP.x, interval: interval)
                    beganStartBeat = nsBeat
                    beganSheetP = sheetP
                    beganSP = sp
                    beganNote = note
                    self.noteI = noteI
                    
                    
                    switch result {
                    case .pit(let pitI):
                        let pit = note.pits[pitI]
                    
                        self.pitI = pitI
                        beganPit = pit
                        
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
                        
                    case .reverbEarlyRSec:
                        type = .reverbEarlyRSec
                        
                        if document.isSelect(at: p) {
                            let noteIs = sheetView.noteIndexes(from: document.selections)
                            beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                        } else {
                            let id = score.notes[noteI].envelope.id
                            beganNotes = score.notes.enumerated().reduce(into: [Int: Note]()) {
                                if id == $1.element.envelope.id {
                                    $0[$1.offset] = $1.element
                                }
                            }
                        }
                        beganNotes[noteI] = score.notes[noteI]
                        
                        beganEnvelope = score.notes[noteI].envelope
                        
                        document.cursor = .circle(string: String(format: "%.3f s", beganEnvelope.reverb.earlySec))
                    case .reverbEarlyAndLateRSec:
                        type = .reverbEarlyAndLateRSec
                        
                        if document.isSelect(at: p) {
                            let noteIs = sheetView.noteIndexes(from: document.selections)
                            beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                        } else {
                            let id = score.notes[noteI].envelope.id
                            beganNotes = score.notes.enumerated().reduce(into: [Int: Note]()) {
                                if id == $1.element.envelope.id {
                                    $0[$1.offset] = $1.element
                                }
                            }
                        }
                        beganNotes[noteI] = score.notes[noteI]
                        
                        beganEnvelope = score.notes[noteI].envelope
                        
                        document.cursor = .circle(string: String(format: "%.3f s", beganEnvelope.reverb.earlyLateSec))
                    case .reverbDurSec:
                        type = .reverbDurSec
                        
                        if document.isSelect(at: p) {
                            let noteIs = sheetView.noteIndexes(from: document.selections)
                            beganNotes = noteIs.reduce(into: [Int: Note]()) { $0[$1] = score.notes[$1] }
                        } else {
                            let id = score.notes[noteI].envelope.id
                            beganNotes = score.notes.enumerated().reduce(into: [Int: Note]()) {
                                if id == $1.element.envelope.id {
                                    $0[$1.offset] = $1.element
                                }
                            }
                        }
                        beganNotes[noteI] = score.notes[noteI]
                        
                        beganEnvelope = score.notes[noteI].envelope
                        
                        document.cursor = .circle(string: String(format: "%.3f s", beganEnvelope.reverb.durSec))
                    case .even(let pitI):
                        type = .even
                        
                        let pit = note.pits[pitI]
                    
                        self.pitI = pitI
                        beganPit = pit
                        
                        beganBeat = note.beatRange.start + pit.beat
                        oldBeat = beganBeat
                        beganBeatX = scoreView.x(atBeat: note.beatRange.start + pit.beat)
                        
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
                    case .sprol(let pitI, let sprolI):
                        type = .sprol
                        
                        beganTone = score.notes[noteI].pits[pitI].tone
                        self.sprolI = sprolI
                        self.beganSprol = scoreView.nearestSprol(at: scoreP, at: noteI)
                        self.noteI = noteI
                        self.pitI = pitI
                        
                        func updatePitsWithSelection() {
                            var noteAndPitIs: [Int: [Int: Set<Int>]]
                            if document.isSelect(at: p) {
                                noteAndPitIs = sheetView.noteAndPitAndSprolIs(from: document.selections)
                            } else {
                                let id = score.notes[noteI].pits[pitI][.tone]
                                noteAndPitIs = score.notes.enumerated().reduce(into: [Int: [Int: Set<Int>]]()) {
                                    $0[$1.offset] = $1.element.pits.enumerated().reduce(into: [Int: Set<Int>]()) { (v, ip) in
                                        if ip.element[.tone] == id {
                                            v[ip.offset] = sprolI < ip.element.tone.spectlope.count ? [sprolI] : []
                                        }
                                    }
                                }
                            }
                            
                            beganNoteSprols = noteAndPitIs.reduce(into: .init()) {
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
                        
                        let noteIsSet = Set(beganNoteSprols.values.flatMap { $0.dic.keys }).sorted()
                        let vs = score.noteIAndNormarizedPits(atBeat: note.pits[pitI].beat + note.beatRange.start,
                                                              in: noteIsSet)
                        playerBeatNoteIndexes = vs.map { $0.noteI }
                        
                        updatePlayer(from: vs.map { $0.pitResult }, in: sheetView)
                        
                        document.cursor = .circle(string: Pitch(value: .init(beganTone.spectlope.sprols[sprolI].pitch, intervalScale: Sheet.fullEditPitchInterval)).octaveString(hidableDecimal: false))
                    }
                } else if let (lineView, li) = sheetView.lineTuple(at: sheetP,
                                                                   isSmall: false,
                                                                   scale: document.screenToWorldScale),
                          let pi = lineView.model.mainPointSequence.nearestIndex(at: sheetP) {
                    
                    isLine = true
                    self.sheetView = sheetView
                    beganLine = lineView.model
                    lineIndex = li
                    pointIndex = pi
                    beganMainP = beganLine.mainPoint(at: pi)
                    beganSheetP = sheetP
                    let pressure = event.pressure
                        .clipped(min: 0.4, max: 1, newMin: 0, newMax: 1)
                    pressures.append((event.time, pressure))
                    
                    node.children = beganLine.mainPointSequence.flatMap {
                        let p = sheetView.convertToWorld($0)
                        return [Node(path: .init(circleRadius: 0.25 * 1.5 * beganLine.size, position: p),
                                     fillType: .color(.content)),
                                Node(path: .init(circleRadius: 0.25 * beganLine.size, position: p),
                                     fillType: .color(.background))]
                    }
                    document.rootNode.append(child: node)
                }
            }
        case .changed:
            if let sheetView {
                if isLine {
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
                            
                            if isPressure || (!isPressure && (event.time - (pressures.first?.time ?? 0) > 1 && (pressures.allSatisfy { $0.pressure <= 0.5 }))) {
                                isPressure = true
                                
                                let nPressures = pressures
                                    .filter { (0.04 ..< 0.4).contains(event.time - $0.time) }
                                let nPressure = nPressures.mean { $0.pressure } ?? pressures.first!.pressure
                                line.controls[pointIndex].pressure = nPressure
                            }
                            
                            lineView.model = line
                            
                            node.children = line.mainPointSequence.flatMap {
                                let p = sheetView.convertToWorld($0)
                                return [Node(path: .init(circleRadius: 0.25 * 1.5 * line.size, position: p),
                                             fillType: .color(.content)),
                                        Node(path: .init(circleRadius: 0.25 * line.size, position: p),
                                             fillType: .color(.background))]
                            }
                        }
                    }
                } else {
                    let sheetP = sheetView.convertFromWorld(p)
                    let scoreView = sheetView.scoreView
                    let score = scoreView.model
                    let scoreP = scoreView.convertFromWorld(p)
                    switch type {
                    case .pit:
                        if let noteI, noteI < score.notes.count, let pitI {
                            let note = score.notes[noteI]
                            let preBeat = pitI > 0 ? note.pits[pitI - 1].beat + note.beatRange.start : .min
                            let nextBeat = pitI + 1 < note.pits.count ? note.pits[pitI + 1].beat + note.beatRange.start : .max
                            let beatInterval = document.currentBeatInterval
                            let pitchInterval = document.currentPitchInterval
                            let pitch = scoreView.pitch(atY: beganPitchY + sheetP.y - beganSheetP.y,
                                                        interval: pitchInterval)
                            let nsBeat = scoreView.beat(atX: beganBeatX + sheetP.x - beganSheetP.x,
                                                        interval: beatInterval)
                                .clipped(min: preBeat, max: nextBeat)
                            if pitch != oldPitch || nsBeat != oldBeat {
                                let dBeat = nsBeat - beganBeat
                                let dPitch = pitch - beganPitch
                                
                                for (noteI, nv) in beganNotePits {
                                    guard noteI < score.notes.count else { continue }
                                    var note = nv.note
                                    for (pitI, beganPit) in nv.pits {
                                        guard pitI < score.notes[noteI].pits.count else { continue }
                                        note.pits[pitI].beat = dBeat + beganPit.beat
                                        note.pits[pitI].pitch = dPitch + beganPit.pitch
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
                    case .reverbEarlyRSec:
                        let dBeat = scoreView.durBeat(atWidth: sheetP.x - beganSheetP.x)
                        let sec = (beganEnvelope.reverb.earlySec + score.sec(fromBeat: dBeat))
                            .clipped(min: 0, max: 10)
                        
                        let nid = UUID()
                        var eivs = [IndexValue<Envelope>](capacity: beganNotes.count)
                        for noteI in beganNotes.keys {
                            guard noteI < score.notes.count else { continue }
                            var envelope = scoreView.model.notes[noteI].envelope
                            envelope.reverb.earlySec = sec
                            envelope.reverb.seedID = nid
                            envelope.id = nid
                            eivs.append(.init(value: envelope, index: noteI))
                        }
                        scoreView.replace(eivs)
                        
                        document.cursor = .circle(string: String(format: "%.3f s", sec))
                    case .reverbEarlyAndLateRSec:
                        let dBeat = scoreView.durBeat(atWidth: sheetP.x - beganSheetP.x)
                        let sec = (beganEnvelope.reverb.lateSec + score.sec(fromBeat: dBeat))
                            .clipped(min: 0, max: 10)
                        
                        let nid = UUID()
                        var eivs = [IndexValue<Envelope>](capacity: beganNotes.count)
                        for noteI in beganNotes.keys {
                            guard noteI < score.notes.count else { continue }
                            var envelope = scoreView.model.notes[noteI].envelope
                            envelope.reverb.lateSec = sec
                            envelope.reverb.seedID = nid
                            envelope.id = nid
                            eivs.append(.init(value: envelope, index: noteI))
                        }
                        scoreView.replace(eivs)
                        
                        document.cursor = .circle(string: String(format: "%.3f s", beganEnvelope.reverb.earlySec + sec))
                    case .reverbDurSec:
                        let dBeat = scoreView.durBeat(atWidth: sheetP.x - beganSheetP.x)
                        let sec = (beganEnvelope.reverb.releaseSec + score.sec(fromBeat: dBeat))
                            .clipped(min: 0, max: 10)
                        
                        let nid = UUID()
                        var eivs = [IndexValue<Envelope>](capacity: beganNotes.count)
                        for noteI in beganNotes.keys {
                            guard noteI < score.notes.count else { continue }
                            var envelope = scoreView.model.notes[noteI].envelope
                            envelope.reverb.releaseSec = sec
                            envelope.reverb.seedID = nid
                            envelope.id = nid
                            eivs.append(.init(value: envelope, index: noteI))
                        }
                        scoreView.replace(eivs)
                        
                        document.cursor = .circle(string: String(format: "%.3f s", beganEnvelope.reverb.earlyLateSec + sec))
                    case .even:
                        if let noteI, noteI < score.notes.count, let pitI {
                            let note = score.notes[noteI]
                            let preBeat = pitI > 0 ? note.pits[pitI - 1].beat + note.beatRange.start : .min
                            let nextBeat = pitI + 1 < note.pits.count ? note.pits[pitI + 1].beat + note.beatRange.start : .max
                            let beatInterval = document.currentBeatInterval
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
                                
                                document.updateSelects()
                            }
                        }
                    case .sprol:
                        if let noteI, noteI < score.notes.count,
                           let pitI, pitI < score.notes[noteI].pits.count,
                           let sprolI, sprolI < score.notes[noteI].pits[pitI].tone.spectlope.count {
                           
                            let pitch = scoreView.spectlopePitch(at: scoreP, at: noteI)
                            let dPitch = pitch - beganSprol.pitch
                            let nPitch = (beganTone.spectlope.sprols[sprolI].pitch + dPitch)
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
                                scoreView.normarizedPitResult(atBeat: beganStartBeat, at: $0)
                            }
                            
                            document.cursor = .circle(string: Pitch(value: .init(nPitch, intervalScale: Sheet.fullEditPitchInterval)).octaveString(hidableDecimal: false))
                        }
                    }
                }
            }
        case .ended:
            node.removeFromParent()
            if let sheetView {
                if !isLine {
                    notePlayer?.stop()
                    
                    var isNewUndoGroup = false
                    func updateUndoGroup() {
                        if !isNewUndoGroup {
                            sheetView.newUndoGroup()
                            isNewUndoGroup = true
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

            document.cursor = document.defaultCursor
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
    lineIndex = 0, lineView: SheetLineView?, oldSP = Point(),
                isNote = false, noteNode: Node?
    
    func send(_ event: DragEvent) {
        guard isEditingSheet else {
            document.keepOut(with: event)
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
                } else if sheetView.scoreView.model.enabled,
                          let li = sheetView.scoreView.noteIndex(at: sheetView.scoreView.convertFromWorld(p),
                                                                 scale: document.screenToWorldScale) {
                    self.sheetView = sheetView
                    lineIndex = li
                    let noteNode = sheetView.scoreView.notesNode.children[li]
                    self.noteNode = noteNode
                    noteNode.isHidden = true
                    
                    let line = sheetView.scoreView.pointline(from: sheetView.scoreView.model.notes[li])
                    let noteH = sheetView.scoreView.noteH(from: sheetView.scoreView.model.notes[li])
                    if let lb = noteNode.path.bounds?.outset(by: noteH / 2) {
                        let toneFrame = sheetView.scoreView.toneFrame(at: li)
                        crossIndexes = sheetView.scoreView.model.notes.enumerated().compactMap {
                            let nNoteH = sheetView.scoreView.noteH(from: sheetView.scoreView.model.notes[$0.offset])
                            let nLine = sheetView.scoreView.pointline(from: $0.element)
                            return if $0.offset == li {
                                li
                            } else if let nb = sheetView.scoreView.notesNode.children[$0.offset].path.bounds,
                                      nb.outset(by: noteH / 2).intersects(lb) {
                                nLine.minDistanceSquared(line) < (noteH / 2 + nNoteH / 2).squared ?
                                $0.offset : nil
                            } else if let toneFrame,
                                      let otherToneFrame = sheetView.scoreView.toneFrame(at: $0.offset),
                                      toneFrame.intersects(otherToneFrame) {
                                $0.offset
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
                    lineNode = noteNode.clone
                    lineNode.isHidden = false
                    sheetView.scoreView.notesNode.children.insert(lineNode, at: li)
                }
            }
        case .changed:
            if let sheetView = sheetView,
               lineIndex < sheetView.linesView.elementViews.count {
                
                guard !crossIndexes.isEmpty else { return }
                
                let cli = (Int((sp.y - oldSP.y) / 10) + crossLineIndex)
                    .clipped(min: 0, max: crossIndexes.count - 1)
                let li = crossIndexes[cli]
                    .clipped(min: 0, max: sheetView.linesView.elementViews.count)
                lineNode.removeFromParent()
                sheetView.linesView.node.children.insert(lineNode, at: li)
            } else if let sheetView = sheetView, sheetView.scoreView.model.enabled,
                      lineIndex < sheetView.scoreView.model.notes.count {
                
                guard !crossIndexes.isEmpty else { return }
                
                let cli = (Int((sp.y - oldSP.y) / 10) + crossLineIndex)
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
            
            if let sheetView = sheetView,
               lineIndex < sheetView.linesView.elementViews.count {
                
                guard !crossIndexes.isEmpty else { return }
                
                let cli = (Int((sp.y - oldSP.y) / 10) + crossLineIndex)
                    .clipped(min: 0, max: crossIndexes.count - 1)
                let li = crossIndexes[cli]
                    .clipped(min: 0, max: sheetView.linesView.elementViews.count)
                let line = sheetView.linesView.elementViews[lineIndex].model
                if lineIndex != li {
                    sheetView.newUndoGroup()
                    sheetView.removeLines(at: [lineIndex])
                    sheetView.insert([.init(value: line, index: li > lineIndex ? li - 1 : li)])
                }
            } else if let sheetView = sheetView, sheetView.scoreView.model.enabled,
                      lineIndex < sheetView.scoreView.model.notes.count {
                
                guard !crossIndexes.isEmpty else { return }
                
                let cli = (Int((sp.y - oldSP.y) / 10) + crossLineIndex)
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

            document.cursor = document.defaultCursor
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
                } else if let ti = sheetView.textIndex(at: inP, scale: document.screenToWorldScale),
                           sheetView.model.texts[ti].timeOption != nil {
                    type = .text(TextSlider(document))
                } else if sheetView.scoreView.contains(sheetView.scoreView.convertFromWorld(p),
                                                       scale: document.screenToWorldScale) {
                    type = .score(ScoreSlider(document))
                } else if sheetView.animationView.containsTimeline(inP, scale: document.screenToWorldScale) {
                    type = .animation(AnimationSlider(document))
                } else {
                    type = .keyframe(KeyframeSlider(document))
                }
            } else {
                type = .keyframe(KeyframeSlider(document))
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
            document.keepOut(with: event)
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
                
                let animationView = sheetView.animationView
                if animationView.containsTimeline(inP, scale: document.screenToWorldScale),
                   let i = animationView
                       .slidableKeyframeIndex(at: inP,
                                              maxDistance: document.worldKnobEditDistance,
                                              enabledKeyOnly: true),
                   sheetView.selectedFrameIndexes.contains(i) {
                    
                    let kis = sheetView.selectedFrameIndexes
                    sheetView.selectedFrameIndexes = []
                    
                    let beat = animationView.model.localBeat
                    let count = ((animationView.rootBeat - beat) / animationView.model.localDurBeat).rounded(.towardZero)
                    
                    let oneBeat = Rational(1, animationView.frameRate)
                    
                    var nj = 0, isNewUndoGroup = false
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
                    document.updateEditorNode()
                    document.updateSelects()
                } else if sheetView.animationView.containsTimeline(inP, scale: document.screenToWorldScale) {
                    sheetView.selectedFrameIndexes = []
                    
                    let animationView = sheetView.animationView
                    let animation = animationView.model
                    
                    let interval = document.currentBeatInterval
                    let oBeat = animationView.beat(atX: inP.x, interval: interval)
                    let beat = (oBeat - animation.beatRange.start)
                        .clipped(min: 0, max: animation.beatRange.length)
                    + animation.beatRange.start
                    
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
                            let nBeat = animation.keyframes[i].beat + iBeat
                            let keyframe = Keyframe(beat: nBeat)
                            animationView.selectedFrameIndexes = []
                            sheetView.newUndoGroup(enabledKeyframeIndex: false)
                            sheetView.insert([IndexValue(value: keyframe, index: i + 1)])
                        } else if animation.keyframes[i].containsInterpolated {
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
                                                            beatInterval: document.currentBeatInterval,
                                                            pitchInterval: document.currentPitchInterval)
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
                    } else if scoreView.containsTimeline(scoreP, scale: document.screenToWorldScale) {
                        let interval = document.currentBeatInterval
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
                } else if let ti = sheetView.textIndex(at: inP, scale: document.screenToWorldScale) {
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
                    sheetView.set(beat: 0, at: 0)
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
            
            document.cursor = document.defaultCursor
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
            document.keepOut(with: event)
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
            
            if let sheetView = document.sheetView(at: p), sheetView.model.score.enabled {
                if document.isSelectNoneCursor(at: p), !document.isSelectedText {
                    let nis = sheetView.noteIndexes(from: document.selections)
                    if !nis.isEmpty {
                        let noteIAndNotes = nis
                            .map { ($0, sheetView.scoreView.model.notes[$0]) }
                            .sorted { $0.1.beatRange.start < $1.1.beatRange.start }
                        var preBeat = noteIAndNotes.first!.1.beatRange.end, isAppend = false
                        var nNote = noteIAndNotes.first!.1
                        var preLastPit = nNote.pits.last!
                        preLastPit.beat = nNote.beatRange.length
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
                }
                return
            }
            
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
                            let scale = 1 / document.worldToScreenScale
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
                            document.rootNode.append(child: linesNode)
                        }
                    }
                    return
                }
            }
            guard let o = cos.first else { return }
            
            let sheetID: SheetID, ios: [InterOption], oldRootKeyframeIndex: Int, oldLines: [Line]
            switch o {
            case .sheetValue(let v):
                sheetID = v.id
                ios = v.lines.map { $0.interOption.with(.key) }
                oldRootKeyframeIndex = v.rootKeyframeIndex
                oldLines = v.lines
            case .ids(let v):
                sheetID = v.sheetID
                ios = v.ids.map { $0.with(.key) }
                oldRootKeyframeIndex = v.rootKeyframeIndex
                oldLines = []
            default: return
            }
            
            if let sheetView = document.sheetView(at: p),
               sheetView.id == sheetID {
                
                let animationView = sheetView.animationView
                var isNewUndoGroup = false
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
//                    document.updateEditorNode()
//                    document.updateSelects()
//                }
                
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
                if idivs.isEmpty {
                    for li in lis {
                        let lw = Line.defaultLineWidth
                        let scale = 1 / document.worldToScreenScale
                        let blw = max(lw * 1.5, lw * 2.5 * scale, 1 * scale)
                        let line = animationView.currentKeyframe.picture.lines[li]
                        let nLine = sheetView.convertToWorld(line)
                        noNodes.append(Node(path: Path(nLine),
                                       lineWidth: blw,
                                       lineType: .color(.removing)))
                    }
                }
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
                    let scale = 1 / document.worldToScreenScale
                    let lw = Line.defaultLineWidth
                    let nodes = lis.map {
                        Node(path: sheetView.linesView.elementViews[$0].node.path * sheetView.node.localTransform,
                             lineWidth: max(lw * 1.5, lw * 2.5 * scale, 1 * scale),
                             lineType: .color(.selected))
                    }
                    
                    if !isNewUndoGroup {
                        sheetView.newUndoGroup()
                        isNewUndoGroup = true
                    }
                    sheetView.set([IndexValue(value: idivs, index: animationView.model.index)])
                    
                    let oldLineDic = oldLines.reduce(into: [UUID: Line]()) { $0[$1.id] = $1 }
                    struct UUKey: Hashable {
                        var fromUUColor, toUUColor: UUColor
                    }
                    var colorValuesDic = [UUKey: ColorValue]()
                    for idiv in idivs {
                        let line = animationView.currentKeyframe.picture.lines[idiv.index]
                        if let oldLine = oldLineDic[line.id], oldLine.uuColor != line.uuColor {
                            let uuKey = UUKey(fromUUColor: line.uuColor, toUUColor: oldLine.uuColor)
                            if colorValuesDic[uuKey] != nil {
                                colorValuesDic[uuKey]?.lineIndexes.append(idiv.index)
                            } else {
                                colorValuesDic[uuKey] = .init(uuColor: oldLine.uuColor,
                                                              planeIndexes: [],
                                                              lineIndexes: [idiv.index],
                                                              isBackground: false,
                                                              planeAnimationIndexes: [],
                                                              lineAnimationIndexes: [],
                                                              animationColors: [])
                            }
                        }
                    }
                    for (uuKey, cv) in colorValuesDic {
                        var oldCV = cv
                        oldCV.uuColor = uuKey.fromUUColor
                        sheetView.set(cv, oldColorValue: oldCV)
                    }
                    
                    let oldKeyframe = animationView.model.keyframe(atRoot: oldRootKeyframeIndex)
                    for idiv in idivs {
                        let li = oldKeyframe.picture.lines.firstIndex(where: { $0.id == idiv.value.id })!
                        let upperLineIDs = Set(oldKeyframe.picture.lines[(li + 1)...].map { $0.id })
                        let nli = animationView.currentKeyframe.picture.lines.firstIndex { upperLineIDs.contains($0.id) }
                        if let nli, nli != idiv.index {
                            let line = animationView.currentKeyframe.picture.lines[idiv.index]
                            sheetView.removeLines(at: [idiv.index])
                            sheetView.insert([.init(value: line, index: nli > idiv.index ? nli - 1 : nli)])
                        }
                    }
                    
                    let nids = idivs.map { $0.value.id }
                    sheetView.interpolation(nids.enumerated().map { (i, v) in (v, [v]) },
                                            rootKeyframeIndex: oldRootKeyframeIndex,
                                            isNewUndoGroup: false)
                    
                    let iNodes = animationView.interpolationNodes(from: nids, scale: scale)
                    linesNode.children = iNodes + noNodes + nodes
                    
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
            
            document.cursor = document.defaultCursor
        }
    }
}
extension SheetView {
    func interpolation(_ ids: [(mainID: UUID, replaceIDs: [UUID])],
                       rootKeyframeIndex: Int,
                       isNewUndoGroup: Bool) {
        var insertLIVs = [Int: [IndexValue<Line>]]()
        var repLIVs = [Int: [IndexValue<Line>]]()
        
        let kts: [(keyframe: Keyframe, time: Rational)] = model.animation.keyframes.map { ($0, $0.beat) }
        let duration = model.animation.beatRange.length
        let rki = self.rootKeyframeIndex
        let lki = model.animation.index
        
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
            document.keepOut(with: event)
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
            
            document.cursor = document.defaultCursor
        }
    }
}
