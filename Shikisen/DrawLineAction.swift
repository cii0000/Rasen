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

import Dispatch
import struct Foundation.UUID

final class DrawLineAction: DragEventAction {
    let action: LineAction
    
    init(_ rootAction: RootAction) {
        action = LineAction(rootAction)
    }
    
    func flow(with event: DragEvent) {
        action.drawLine(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class DrawStraightLineAction: DragEventAction {
    let action: LineAction
    
    init(_ rootAction: RootAction) {
        action = LineAction(rootAction)
    }
    
    func flow(with event: DragEvent) {
        action.drawStraightLine(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class LassoCutAction: DragEventAction {
    let action: LineAction
    
    init(_ rootAction: RootAction) {
        action = LineAction(rootAction)
    }
    
    func flow(with event: DragEvent) {
        action.lassoCut(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
final class LassoCopyAction: DragEventAction {
    let action: LineAction
    
    init(_ rootAction: RootAction) {
        action = LineAction(rootAction)
    }
    
    func flow(with event: DragEvent) {
        action.lassoCopy(with: event)
    }
    func updateNode() {
        action.updateNode()
    }
}
enum LassoType {
    case cut, copy
}
final class LineAction: Action {
    let rootAction: RootAction, rootView: RootView
    let isEditingSheet: Bool
    
    init(_ rootAction: RootAction) {
        self.rootAction = rootAction
        rootView = rootAction.rootView
        isEditingSheet = rootView.isEditingSheet
    }
    
    private(set) var tempLineNode: Node?
    var tempLineWidth = Line.defaultLineWidth
    var lassoDistance = 5.0
    
    var enabledPressure = true
    
    var straightTime = 0.0
    var isSnapStraight = false {
        didSet {
            guard isSnapStraight != oldValue else { return }
            if isSnapStraight && straightTime > 0.5 {
                Feedback.performAlignment()
            }
            tempLineNode?.lineType = isSnapStraight ? .color(.selected) : .color(.content)
        }
    }
    var lastSnapStraightTime = 0.0
    
    var isUpdatedNewUndoGroupWorld = false
    var isUpdatedNewUndoGroupSheetViews = Set<SheetView>()
    var firstPoint = Point()
    var centerOrigin = Point(), centerBounds = Rect(), clipBounds = Rect()
    var centerSHP = IntPoint(), nearestShps = [IntPoint]()
    var tempLine = Line()
    
    func updateNode() {
        lassoPathNodeLineWidth = 1 * rootView.screenToWorldScale
        selectingNode.children.forEach { $0.lineWidth = lassoPathNodeLineWidth }
        rectNode?.children.forEach { $0.lineWidth = lassoPathNodeLineWidth }
        updateStraightNode()
    }
    func updateStraightNode() {
        if let isStraightNode = isStraightNode {
            let fp = firstPoint + centerOrigin
            let lw = lassoPathNodeLineWidth
            let wb = rootView.worldBoundsInScreen
            let b0 = Rect(x: fp.x - lw / 2, y: wb.minY, width: lw, height: wb.height)
            let b1 = Rect(x: wb.minX, y: fp.y - lw / 2, width: wb.width, height: lw)
            let paths = [Path(b0), Path(b1)]
            isStraightNode.children = paths.map {
                Node(path: $0, fillType: isStraightNode.fillType)
            }
        }
    }
    func updateClipBoundsAndIndexRange(at p: Point) {
        let shp = rootView.sheetPosition(at: p)
        nearestShps = [shp] + rootView.aroundSheetPositions(atCenter: shp)
        
        let nearestB = nearestShps.reduce(into: rootView.sheetFrame(with: shp)) {
            $0.formUnion(rootView.sheetFrame(with: $1))
        }
        
        let cb = rootView.sheetFrame(with: shp)
        centerOrigin = cb.origin
        centerBounds = Rect(origin: Point(), size: cb.size)
        
        clipBounds = nearestB.inset(by: rootView.sheetLineWidth) - cb.origin
        centerSHP = shp
    }
    
    private(set) var outlineLassoNode: Node?
    private(set) var lassoNode: Node?
    private(set) var selectingNode = Node(lineWidth: 1.5,
                                          lineType: .color(.selected),
                                          fillType: .color(.subSelected))
    private(set) var isStraightNode: Node?
    var lassoPathNodeLineWidth = 1.0 {
        didSet {
            outlineLassoNode?.lineWidth = lassoPathNodeLineWidth
        }
    }
    
    private var isDrawNote = false
    private var noteSheetView: SheetView?, oldPitch = Rational(0), firstTone = Tone(),
                firstReverb = Reverb(),
                firstSpectlopeHeight = Sheet.spectlopeHeight,
                beganScore: Score?, beganPitch = Rational(), octaveNode: Node?, oldBeat = Rational(0), noteMaxPressure = 0.0, noteOldVolm: Double?,
                noteI: Int?, noteStartBeat: Rational?, notePlayer: NotePlayer?
    
    private var beganEvent: DragEvent?
    func drawNote(with event: DragEvent, isStraight: Bool = false) {
        if event.phase == .began {
            beganEvent = event
        }
        if let beganEvent {
            guard event.screenPoint.distance(beganEvent.screenPoint) >= 2.5
                    || event.time - beganEvent.time >= 0.33 else {
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
            aDrawNote(with: beganEvent, isStraight: isStraight)
            self.beganEvent = nil
        }
        aDrawNote(with: event, isStraight: isStraight)
    }
    private func aDrawNote(with event: DragEvent, isStraight: Bool = false) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootAction.closeLookingUpAndStop(at: p)
            
            if let sheetView = noteSheetView, sheetView.model.score.enabled {
                rootView.unselectAndNewUndoGroupIfNeeded()
                for sheetValue in rootView.sheetViewValues {
                    guard let sheetView = sheetValue.value.sheetView else { continue }
                    var isNewUndoGroup = true
                    sheetView.unselect(isNewUndoGroup: &isNewUndoGroup)
                    if !isNewUndoGroup {
                        isUpdatedNewUndoGroupSheetViews.insert(sheetView)
                    }
                }
                
                let scoreView = sheetView.scoreView
                let sheetP = sheetView.convertFromWorld(p)
                let scoreP = scoreView.convertFromWorld(p)
                let pitchInterval = rootView.currentPitchInterval
                let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                    .clipped(min: Score.pitchRange.start, max: Score.pitchRange.end)
                let score = scoreView.model
                let count = score.notes.count
                let beatInterval = rootView.currentBeatInterval
                let beat = scoreView.beat(atX: sheetP.x, interval: beatInterval)
                let beatRange = beat ..< beat
                let isMinNoise = pitch == Score.minPitch, isMaxNoise = pitch == Score.maxPitch
                
                noteMaxPressure = event.pressure
                let volm = if noteMaxPressure > 0.25 {
                    0.453125
                } else {
                    0.453125 / 2
                }
                
                firstTone = isMinNoise ?
                Tone.minNoise() :
                (isMaxNoise ? Tone.maxNoise() : (isStraight ? Tone.empty() : Tone()))
                firstReverb = isMinNoise || isMaxNoise ?
                Reverb(earlySec: 0, earlyVolm: 1, lateSec: 0, lateVolm: 1, releaseSec: 0) : Reverb()
                firstSpectlopeHeight = isMinNoise || isMaxNoise ?
                Sheet.spectlopeHeight.mid(Sheet.maxSpectlopeHeight) :
                Sheet.spectlopeHeight
                let note = Note(beatRange: beatRange, pitch: pitch,
                                pits: .init([.init(beat: 0, pitch: 0,
                                                   stereo: .init(volm: volm),
                                                   tone: firstTone)]),
                                spectlopeHeight: firstSpectlopeHeight)
                
                noteI = count
                oldPitch = pitch
                oldBeat = beat
                beganPitch = pitch
                noteStartBeat = beat
                beganScore = score
                
                if let notePlayer = sheetView.notePlayer {
                    self.notePlayer = notePlayer
                    notePlayer.notes = [note.firstPitResult]
                } else {
                    let note = isStraight ? Note(beatRange: beatRange, pitch: pitch) : note
                    notePlayer = try? NotePlayer(notes: [note.firstPitResult])
                    sheetView.notePlayer = notePlayer
                }
                notePlayer?.play()
                
                scoreView.append(note)
                rootView.updateOtherAround(from: sheetView, isUpdateAlways: true)
//                    let noteNode = scoreView.noteNode(from: note)
//                    noteNode.attitude.position
//                        = scoreView.node.attitude.position
//                        + sheetView.node.attitude.position
//                    self.tempLineNode = noteNode
//                    rootView.node.insert(child: noteNode,
//                                             at: rootView.accessoryNodeIndex)
                
                let octaveNode = scoreView.octaveNode(fromPitch: pitch, scoreView.notesNode.children.last!.children[0].clone)
                octaveNode.attitude.position
                = sheetView.convertToWorld(scoreView.node.attitude.position)
                self.octaveNode = octaveNode
                rootView.node.append(child: octaveNode)
                
                rootView.cursor = .circle(string: Pitch(value: pitch).displayString())
            }
        case .changed:
            if let sheetView = noteSheetView,
                let nsBeat = noteStartBeat, let noteI {
                
                noteMaxPressure = max(noteMaxPressure, event.pressure)
                let volm = if noteMaxPressure > 0.25 {
                    0.453125
                } else {
                    0.453125 / 2
                }
                
                let pitchInterval = rootView.currentPitchInterval
                let beatInterval = rootView.currentBeatInterval
                let scoreView = sheetView.scoreView
                let sheetP = sheetView.convertFromWorld(p)
                let scoreP = scoreView.convertFromWorld(p)
                let pitch = scoreView.pitch(atY: scoreP.y, interval: pitchInterval)
                    .clipped(min: Score.pitchRange.start, max: Score.pitchRange.end)
                let beat = scoreView.beat(atX: sheetP.x, interval: beatInterval)
                let beatRange = beat > nsBeat ? nsBeat ..< beat : beat ..< nsBeat
                let note = Note(beatRange: beatRange, pitch: pitch,
                                pits: [.init(beat: 0, pitch: 0,
                                             stereo: .init(volm: volm),
                                             tone: firstTone)],
                                spectlopeHeight: firstSpectlopeHeight)
                let isNote = oldPitch != pitch || volm != noteOldVolm
                noteOldVolm = volm
                if isNote {
                    notePlayer?.notes = [note.firstPitResult]
                    self.oldPitch = pitch
                }
                
//                    tempLineNode?.children
//                        = scoreView.noteNode(from: note).children
                
                if isNote || beat != oldBeat {
                    scoreView[noteI] = note
                    rootView.updateOtherAround(from: sheetView, isUpdateAlways: true)
                    
                    octaveNode?.children = scoreView.octaveNode(fromPitch: pitch,
                                                                scoreView.notesNode.children.last!.children[0].clone).children
                    oldBeat = beat
                }
                
                if isNote {
                    rootView.cursor = .circle(string: Pitch(value: pitch)
                        .displayString(deltaPitch: pitch - beganPitch))
                }
            }
        case .ended:
            tempLineNode?.removeFromParent()
            tempLineNode = nil
            octaveNode?.removeFromParent()
            octaveNode = nil
            
            if let sheetView = noteSheetView, let noteI,
               noteI < sheetView.scoreView.model.notes.count {
                
                let scoreView = sheetView.scoreView
                let beatRange = scoreView.model.notes[noteI].beatRange
                if beatRange.length == 0 {
                    scoreView.remove(at: noteI)
                } else {
                    if !isUpdatedNewUndoGroupSheetViews.contains(sheetView) {
                        sheetView.newUndoGroup()
                    }
                    sheetView.captureAppend(sheetView.model.score.notes.last!)
                }
                
                sheetView.updatePlaying()
            }
            
            rootView.showSelected()
            
            notePlayer?.stop()
            
            rootView.cursor = rootView.defaultCursor
        }
    }
    
    func removeNote(with event: DragEvent) {
        let p = rootView.convertScreenToWorld(event.screenPoint)
        if let sheetView = rootView.sheetView(at: p) {
            let scoreView = sheetView.scoreView
            let scoreP = scoreView.convertFromWorld(p)
            let nLine = tempLine * Transform(translation: -centerBounds.origin - Point(0, scoreView.timelineY))
            let scale = rootView.screenToWorldScale
            let lasso = Lasso(line: nLine)
            let edge = Edge(nLine.firstPoint, nLine.lastPoint)
            let length = edge.length
            let d = nLine.controls.maxValue { edge.distanceSquared(from: $0.point) }?.squareRoot() ?? 0
            if let lb = nLine.bounds, d < 5 * scale && length > 10 * scale {
                let x = lb.midX
                let beatInterval = rootView.currentBeatInterval
                let pitchInterval = rootView.currentPitchInterval
                let beat = scoreView.beat(atX: x, interval: beatInterval)
                let nis = (0 ..< scoreView.model.notes.count).compactMap { i in
                    lasso.intersects(scoreView.pointline(from: scoreView.model.notes[i])) ? i : nil
                }
                var notes = [Note](), replaceIVs = [IndexValue<Note>]()
                for noteI in nis {
                    let note = scoreView.model.notes[noteI]
                    let pit = scoreView.splittedPit(at: .init(x, 0), at: noteI,
                                                    beatInterval: beatInterval,
                                                    pitchInterval: pitchInterval)
                    if pit.beat >= 0 && pit.beat < note.beatRange.length,
                       let pitI = note.pits.enumerated().reversed().first(where: { $0.element.beat + note.beatRange.start <= beat })?.offset {
                        let isLastAppend = pitI == 0 || note.pits[pitI].pitch != pit.pitch
                        let nPits = ([pit] + (pitI + 1 < note.pits.count ? Array(note.pits[(pitI + 1)...]) : [])).map {
                            var nPit = $0
                            nPit.beat -= pit.beat
                            return nPit
                        }
                        let nNote0 = Note(beatRange: note.beatRange.start ..< (pit.beat + note.beatRange.start),
                                          pitch: note.pitch,
                                          pits: Array(note.pits[...pitI]) + (isLastAppend ? [pit] : []),
                                          spectlopeHeight: note.spectlopeHeight, id: note.id)
                        let nNote1 = Note(beatRange: (pit.beat + note.beatRange.start) ..< note.beatRange.end,
                                          pitch: note.pitch,
                                          pits: nPits,
                                          spectlopeHeight: note.spectlopeHeight, id: .init())
                        replaceIVs.append(.init(value: nNote0, index: noteI))
                        notes.append(nNote1)
                    }
                }
                if !replaceIVs.isEmpty {
                    if !isUpdatedNewUndoGroupSheetViews.contains(sheetView) {
                        sheetView.newUndoGroup()
                    }
                    sheetView.replace(replaceIVs)
                    sheetView.append(notes)
                    rootView.updateOtherAround(from: sheetView, isUpdateAlways: true)
                }
                return
            }
            
            let nis = (0 ..< scoreView.model.notes.count).compactMap { i in
                lasso.intersects(scoreView.pointline(from: scoreView.model.notes[i])) ? i : nil
            }
            if !nis.isEmpty {
                let pitch = scoreView.pitch(atY: scoreP.y, interval: rootView.currentPitchInterval)
                let score = scoreView.model
                let beat = scoreView.beat(atX: scoreP.x, interval: rootView.currentBeatInterval)
                let notes: [Note] = nis.map {
                    var note = score.notes[$0]
                    note.pitch -= pitch
                    note.beatRange.start -= beat
                    return note
                }
                
                Pasteboard.shared.copiedObjects = [.notesValue(NotesValue(notes: notes,
                                                                          deltaPitch: pitch,
                                                                          isSelected: true))]
                if !isUpdatedNewUndoGroupSheetViews.contains(sheetView) {
                    sheetView.newUndoGroup()
                }
                sheetView.removeNote(at: nis)
                rootView.updateOtherAround(from: sheetView, isUpdateAlways: true)
            }
        }
    }
    
    var isStopPlaying = false
    
    func drawLine(with event: DragEvent) {
        guard isEditingSheet else {
            if event.phase == .began {
                beganEvent = event
            }
            if let beganEvent {
                guard event.screenPoint.distance(beganEvent.screenPoint) >= 2.5
                        || event.time - beganEvent.time >= 0.33 else {
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
                rootAction.keepOut(with: beganEvent)
                self.beganEvent = nil
            }
            rootAction.keepOut(with: event)
            return
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        if isDrawNote {
            drawNote(with: event)
            return
        } else if event.phase == .began {
            if let sheetView = rootView.sheetView(at: p),
               sheetView.scoreView.containsMainFrame(sheetView.scoreView.convertFromWorld(p),
                                                     scale: rootView.screenToWorldScale) {
                isDrawNote = true
                noteSheetView = sheetView
                drawNote(with: event)
                return
            }
        }
        
        if isStopPlaying || rootAction.isPlaying(with: event) {
            rootAction.stopPlaying(with: event)
            isStopPlaying = true
            return
        }
        rootView.closeAllPanels(at: p)
        
        drawLine(with: event, isStraight: false)
    }
    func drawStraightLine(with event: DragEvent) {
        guard isEditingSheet else {
            rootAction.keepOut(with: event)
            return
        }
        
        let p = rootView.convertScreenToWorld(event.screenPoint)
        if isDrawNote {
            drawNote(with: event, isStraight: true)
            return
        } else if event.phase == .began {
            if let sheetView = rootView.sheetView(at: p),
               sheetView.scoreView.containsMainFrame(sheetView.scoreView.convertFromWorld(p),
                                                     scale: rootView.screenToWorldScale) {
                isDrawNote = true
                noteSheetView = sheetView
                drawNote(with: event, isStraight: true)
                return
            }
        }
        
        if isStopPlaying || rootAction.isPlaying(with: event) {
            rootAction.stopPlaying(with: event)
            isStopPlaying = true
            return
        }
        rootView.closeAllPanels(at: p)
        
        drawLine(with: event, isStraight: true)
    }
    
    nonisolated
    private static func revision(pressure: Double, tiltAngle: Double,
                                 minPressure: Double = 0.5,
                                 targetPressure: Double = 0.325,
                                 revisonMinPressure: Double = 0.1875) -> Double {
        ((pressure / targetPressure) * tiltAngle.clipped(min: .pi * 0.25, max: .pi * 0.3,
                                                         newMin: 1, newMax: 0))
        .clipped(min: minPressure, max: 1, newMin: revisonMinPressure, newMax: 1)
    }
    
    nonisolated
    static func snap(_ fol: FirstOrLast, _ line: Line,
                     isSnapSelf: Bool = true, distanceScale: Double = 1,
                     screenToWorldScale: Double,
                     from lines: [Line]) -> Line.Control? {
        snap(line.controls[fol],
             isSnapSelf && line.length() > line.size * 2 ? line.controls[fol.reversed] : nil,
             size: line.size * line.controls[fol].pressure,
             distanceScale: distanceScale,
             screenToWorldScale: screenToWorldScale, from: lines)
    }
    nonisolated
    static func snap(_ c: Line.Control, _ nc: Line.Control?,
                     size: Double, distanceScale: Double = 1,
                     screenToWorldScale: Double,
                     from lines: [Line]) -> Line.Control? {
        let scale = screenToWorldScale.clipped(min: 0.06, max: 2, newMin: 0.5, newMax: 2)
        * distanceScale
        let dd = size / 2
        var minDSq = Double.infinity, minP: Line.Control?
        func update(_ oc: Line.Control, _ oSize: Double) {
            let ond = (dd + oSize / 2) * scale
            let dSq = c.distanceSquared(oc)
            if dSq < ond * ond && dSq < minDSq {
                minDSq = dSq
                minP = oc
            }
        }
        for oLine in lines {
            guard let fc = oLine.controls.first,
                  let lc = oLine.controls.last else { continue }
            update(fc, oLine.size * fc.pressure)
            update(lc, oLine.size * lc.pressure)
        }
        if let nc {
            update(nc, size)
        }
        return minP
    }
    
    nonisolated
    static func line(from events: [DrawLineEvent],
                     isClip: Bool = true, enabledPressure: Bool,
                     isSnap: Bool = true,
                     firstSnapLines: [Line], lastSnapLines: [Line],
                     clipBounds: Rect, isStraight: Bool) -> (line: Line, isSnapStraight: Bool) {
        isStraight ?
        straightLine(from: events, isClip: isClip, isSnap: isSnap,
                     enabledPressure: enabledPressure,
                     firstSnapLines: firstSnapLines,
                     lastSnapLines: lastSnapLines,
                     clipBounds: clipBounds) :
        (line(from: events, isClip: isClip, isSnap: isSnap,
              enabledPressure: enabledPressure,
             firstSnapLines: firstSnapLines,
             lastSnapLines: lastSnapLines,
             clipBounds: clipBounds), false)
    }
    nonisolated
    static func line(from events: [DrawLineEvent],
                     isClip: Bool = true, isSnap: Bool = true, enabledPressure: Bool,
                     lineWidth: Double = Line.defaultLineWidth,
                     firstSnapLines: [Line], lastSnapLines: [Line],
                     clipBounds: Rect) -> Line {
        var nLine = Line(), nLineTimes = [Double]()
        var tempPs = [Point](), tempJointPs = [Point](), preJointP = Point()
        var oldC = Line.Control(point: .init()), oldTime = 0.0, oldFirstChangedTime: Double?
        var snapDP: Point?, isStopRevisionFirstPressure = false
        var tempPresures = [(time: Double, pressure: Double)]()
        
        for event in events {
            switch event.phase {
            case .began:
                var p = RootView.roundedPoint(from: event.p, scale: event.worldToScreenScale)
                if isClip {
                    p = clipBounds.clipped(p)
                }
                
                let pressure = enabledPressure && event.isTablet ?
                revision(pressure: event.pressure, tiltAngle: event.tiltAngle) : 1
                if isSnap, let nc = snap(.init(point: p, weight: 0.5, pressure: pressure), nil,
                                         size: lineWidth,
                                         screenToWorldScale: event.screenToWorldScale,
                                         from: firstSnapLines) {
                    snapDP = nc.point - p
                    p = nc.point
                }
                
                let fc = Line.Control(point: p, weight: 0.5, pressure: pressure)
                nLine = Line(controls: [fc, fc, fc, fc], size: lineWidth)
                nLineTimes = [event.time, event.time, event.time, event.time]
                oldC = fc
                oldTime = event.time
                tempPs = [fc.point]
                tempJointPs = [fc.point]
                preJointP = fc.point
            case .changed:
                var p = RootView.roundedPoint(from: event.p, scale: event.worldToScreenScale)
                let pressure = enabledPressure && event.isTablet ?
                revision(pressure: event.pressure, tiltAngle: event.tiltAngle) : 1
                
                if isClip {
                    p = clipBounds.clipped(p)
                }
                
                let firstChangedTime: Double
                if let aTime = oldFirstChangedTime {
                    firstChangedTime = aTime
                } else {
                    oldFirstChangedTime = event.time
                    firstChangedTime = event.time
                }
                if let nSnapDP = snapDP, event.time - firstChangedTime < 0.08 {
                    snapDP = nSnapDP * 0.75
                    p = RootView.roundedPoint(from: p + nSnapDP * 0.75,
                                              scale: event.worldToScreenScale)
                }
                
                guard p != oldC.point && event.time > oldTime
                        && nLine.controls.count >= 4 else { break }
                tempPs.append(p)
                tempJointPs.append(p)
                if tempJointPs.count > 8 {
                    tempJointPs.removeFirst()
                }
                
                if enabledPressure {
                    func revisionFirstPressure() {
                        if !isStopRevisionFirstPressure {
                            if nLine.controls[.first].pressure < pressure {
                                for i in nLine.controls.count.range {
                                    nLine.controls[i].pressure = pressure
                                }
                                for i in tempPresures.count.range {
                                    tempPresures[i].pressure = pressure
                                }
                            }
                            if event.time - firstChangedTime > 0.1 {
                                 isStopRevisionFirstPressure = true
                            }
                        }
                    }
                    revisionFirstPressure()
                    
                    tempPresures.append((event.time, pressure))
                    for ti in (1 ..< tempPresures.count).reversed() {
                        if event.time - tempPresures[ti].time > 0.04 {
                            tempPresures.removeFirst(ti - 1)
                            break
                        }
                    }
                }
                
                let lastC = Line.Control(point: p, weight: 0.5,
                                         pressure: enabledPressure ? (tempPresures.first?.pressure ?? pressure) : 1)
                
                func revisionFirstBezier() {
                    if nLine.controls.count == 4, tempPs.count >= 2 {
                        var maxL = 0.0
                        for i in 0 ..< (tempPs.count - 1) {
                            let edge = Edge(tempPs[i], tempPs[i + 1])
                            maxL += edge.length
                        }
                        let d = maxL / 3
                        var l = 0.0, maxP = nLine.firstPoint
                        for i in 0 ..< (tempPs.count - 1) {
                            let edge = Edge(tempPs[i], tempPs[i + 1])
                            let el = edge.length
                            if el > 0 && d >= l && d < l + el {
                                maxP = edge.position(atT: (d - l) / el)
                            }
                            l += el
                        }
                        nLine.controls[1].point = maxP
                    }
                }
                revisionFirstBezier()
                
                let maxDSq = (event.time - firstChangedTime < 0.04 ? 3.0 : 0.75).squared
                
                func jointControl(angle: Double = 0.75 * (.pi / 2)) -> Line.Control? {
                    guard tempJointPs.count >= 6 else { return nil }
                    let p0 = tempJointPs.first!, p2 = tempJointPs.last!
                    var maxDr = 0.0, np1: Point?
                    for i in 1 ..< tempJointPs.count - 1 {
                        let p1 = tempJointPs[i]
                        guard p0 != p1 && p1 != p2 else { continue }
                        let dr = abs(Point.differenceAngle(p0, p1, p2))
                        if dr > maxDr && dr > angle {
                            maxDr = dr
                            np1 = p1
                        }
                    }
                    if let np1 {
                        if np1.distanceSquared(preJointP)
                            < (10 * event.screenToWorldScale).squared {
                           return nil
                        } else {
                            preJointP = np1
                        }
                        return .init(point: np1, pressure: lastC.pressure)
                    } else {
                        return nil
                    }
                }
                
                func isAppend(maxDSq: Double) -> Bool {
                    guard tempPs.count >= 3 else { return false }
                    let nMaxDSq = maxDSq * event.screenToWorldScale.squared
                    let ll = LinearLine(tempPs.first!,tempPs.last!)
                    return tempPs.contains { ll.distanceSquared(from: $0) > nMaxDSq }
                }
                
                if var jointC = jointControl() {
                    jointC.weight = 1
                    nLine.controls[nLine.controls.count - 3].weight = 0.5
                    nLine.controls[nLine.controls.count - 2] = jointC
                    
                    jointC.weight = 0.5
                    nLine.controls[nLine.controls.count - 1] = jointC
                    nLine.controls.append(jointC)
                    nLineTimes.append(event.time)
                    nLine.controls.append(jointC)
                    nLineTimes.append(event.time)
                    
                    tempPs = [p]
                    tempJointPs = [p]
                } else if isAppend(maxDSq: maxDSq) {
                    nLine.controls[nLine.controls.count - 3].weight = 0.5
                    let prp = nLine.controls[nLine.controls.count - 1]
                    nLine.controls[nLine.controls.count - 2] = prp
                    nLine.controls[nLine.controls.count - 2].weight = 1
                    
                    nLine.controls.insert(prp, at: nLine.controls.count - 1)
                    nLineTimes.insert(nLineTimes[nLineTimes.count - 1], at: nLineTimes.count - 1)
                    
                    tempPs = [p]
                }
                
                nLine.controls[nLine.controls.count - 3].weight = 1
                nLine.controls[nLine.controls.count - 2]
                    = nLine.controls[nLine.controls.count - 3].mid(lastC)
                nLine.controls[nLine.controls.count - 2].weight = 0.5
                nLine.controls[.last] = lastC
                nLineTimes[nLineTimes.count - 2] = event.time
                nLineTimes[.last] = event.time
                
                oldC = lastC
                oldTime = event.time
            case .ended:
                guard nLine.controls.count >= 4 else { break }
                
                nLine.controls[nLine.controls.count - 3].weight = 0.5
                nLine.controls[nLine.controls.count - 2] = nLine.controls.last!
                nLine.controls.removeLast()
                nLineTimes.removeLast()
                
                func lastCut() {
                    guard let ji = nLine.controls.lastIndex(where: { $0.weight == 1 }),
                          ji < nLine.controls.count - 1 else { return }
                    let allLength = nLine.pointsLength
                    
                    var length = 0.0
                    for i in ji + 1 ..< nLine.controls.count - 1 {
                        length += nLine.controls[i].point.distance(nLine.controls[i + 1].point)
                    }
                    if event.time - nLineTimes[ji] < 0.2
                        && length * event.worldToScreenScale < 10
                        && length / allLength < 0.1 {
                        
                        let nCount = nLine.controls.count - (ji + 1)
                        nLine.controls.removeLast(nCount)
                        nLineTimes.removeLast(nCount)
                    
                        nLine.controls[.last].weight = 0.5
                        nLine.controls[.last].point = nLine.controls[ji].point
                    }
                }
                lastCut()
                
                if isSnap, let nc = snap(.last, nLine,
                                         screenToWorldScale: event.screenToWorldScale,
                                         from: lastSnapLines) {
                    nLine.controls[.last].point = nc.point
                }
            }
        }
        
        return nLine
    }
    
    nonisolated
    static func straightLine(from events: [DrawLineEvent],
                             isClip: Bool = true, isSnap: Bool = true,
                             lineWidth: Double = Line.defaultLineWidth,
                             enabledPressure: Bool,
                             snappableDistance: Double = 2.5,
                             firstSnapLines: [Line], lastSnapLines: [Line],
                             clipBounds: Rect) -> (line: Line, snapStraight: Bool) {
        var nLine = Line()
        var oldPoint = Point()
        var prs = [(time: Double, pressure: Double)]()
        var isSnapStraight = false, lastSnapStraightTime: Double?, nsd = Point()
        
        func drawLine(for p: Point, sp: Point, pressure: Double, tiltAngle: Double,
                      isTablet: Bool,
                      time: Double,
                      worldToScreenScale: Double,
                      screenToWorldScale: Double,
                      _ phase: Phase) {
            var p = RootView.roundedPoint(from: p, scale: worldToScreenScale)
            let pressure = enabledPressure && isTablet ? revision(pressure: pressure,
                                                                  tiltAngle: tiltAngle) : 1
            
            switch phase {
            case .began:
                if isClip {
                    p = clipBounds.clipped(p)
                }
                if isSnap, let nc = Self.snap(.init(point: p, pressure: pressure),
                                              nil, size: lineWidth,
                                              screenToWorldScale: screenToWorldScale,
                                              from: firstSnapLines) {
                    p = nc.point
                }
                
                let fc = Line.Control(point: p, weight: 0.5, pressure: pressure)
                nLine = Line(controls: [fc, fc], size: lineWidth)
                oldPoint = p
                prs = [(time, pressure)]
            case .changed:
                if isClip {
                    p = clipBounds.clipped(p)
                }
                guard p != oldPoint else { return }
                
                if enabledPressure {
                    prs.append((time, pressure))
                    
                    let nPressure = isTablet ? prs.maxValue { $0.pressure }! : prs.last!.pressure
                    nLine.controls[.first].pressure = nPressure
                    nLine.controls[.last].pressure = nPressure
                }
                
                nLine.controls[.last].point = p
                
                let dp = nLine.lastPoint - nLine.firstPoint
                
                let sd: Point, isSnapS: Bool
                if abs(dp.x) < abs(dp.y) {
                    sd = .init(dp.x, 0)
                    isSnapS = abs(dp.x * worldToScreenScale) < abs(dp.y * worldToScreenScale)
                        .clipped(min: 5, max: 20, newMin: 0, newMax: snappableDistance)
                } else {
                    sd = .init(0, dp.y)
                    isSnapS = abs(dp.y * worldToScreenScale) < abs(dp.x * worldToScreenScale)
                        .clipped(min: 5, max: 20, newMin: 0, newMax: snappableDistance)
                }
                if isSnapS {
                    if let lastSnapStraightTime = lastSnapStraightTime {
                        if time - lastSnapStraightTime > 1 {
                            isSnapStraight = false
                            nsd = sd
                        }
                    } else {
                        if !isSnapStraight {
                            lastSnapStraightTime = time
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
                        nLine.controls[.last].point.x = nLine.controls[.first].point.x
                    } else if abs(nsd.y) > 0 {
                        nLine.controls[.last].point.y = nLine.controls[.first].point.y
                    }
                } else {
                    nLine.controls[.last].point -= nsd
                }
                
                oldPoint = p
            case .ended:
                if enabledPressure {
                    let nPressure = isTablet ? prs.maxValue { $0.pressure }! : prs.last!.pressure
                    nLine.controls[.first].pressure = nPressure
                    nLine.controls[.last].pressure = nPressure
                }
                
                if isSnap, let nc = Self.snap(.last, nLine, isSnapSelf: false,
                                              screenToWorldScale: screenToWorldScale,
                                              from: lastSnapLines) {
                    nLine.controls[.last].point = nc.point
                }
            }
        }
        
        for event in events {
            drawLine(for: event.p, sp: event.sp,
                     pressure: event.pressure, tiltAngle: event.tiltAngle,
                     isTablet: event.isTablet,
                     time: event.time,
                     worldToScreenScale: event.worldToScreenScale,
                     screenToWorldScale: event.screenToWorldScale,
                     event.phase)
        }
        
        return (nLine, isSnapStraight)
    }
    struct DrawLineEvent {
        var p: Point, sp: Point, pressure: Double, tiltAngle: Double, isTablet: Bool,
            time: Double, isClip: Bool = true, isSnap: Bool = true,
            worldToScreenScale: Double, screenToWorldScale: Double,
            phase: Phase
    }
    private var drawLineTimer: (any DispatchSourceTimer)?
    private var  oldDrawLineEventsCount = 0, beganTime = 0.0
    private var drawLineEvents = [DrawLineEvent](), drawLineEventsCount = 0, snapLines = [Line]()
    var textView: SheetTextView?
    private(set) var beganLineColor: Color?, beganSheetID: UUID?, beganAnimationRootIndex = 0
    
    func drawLine(with event: DragEvent, isStraight: Bool) {
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = rootView.defaultCursor
            
            updateClipBoundsAndIndexRange(at: p)
            let tempLineNode = Node(attitude: Attitude(position: centerOrigin),
                                    path: Path(),
                                    lineWidth: rootView.sheetLineWidth,
                                    lineType: .color(Line.defaultUUColor.value))
            self.tempLineNode = tempLineNode
            rootView.node.insert(child: tempLineNode,
                                     at: rootView.accessoryNodeIndex)
            
            let sheetView = rootView.sheetView(at: centerSHP)
            
            rootView.unselectAndNewUndoGroupIfNeeded()
            for sheetValue in rootView.sheetViewValues {
                guard let sheetView = sheetValue.value.sheetView else { continue }
                var isNewUndoGroup = true
                sheetView.unselect(isNewUndoGroup: &isNewUndoGroup)
                if !isNewUndoGroup {
                    isUpdatedNewUndoGroupSheetViews.insert(sheetView)
                }
            }
            
            snapLines = sheetView?.model.picture.lines ?? []
            
            beganTime = event.time
            
            if let sheetView, sheetView.model.enabledAnimation {
                beganSheetID = sheetView.id
                beganAnimationRootIndex = sheetView.model.animation.rootIndex
                beganLineColor = Line.defaultUUColor.value
            }
            
            drawLineEvents.append(.init(p: p - centerOrigin,
                                        sp: event.screenPoint,
                                        pressure: event.pressure,
                                        tiltAngle: event.tiltAngle,
                                        isTablet: event.isTablet,
                                        time: event.time,
                                        worldToScreenScale: rootView.worldToScreenScale,
                                        screenToWorldScale: rootView.screenToWorldScale,
                                        phase: .began))
            
            if isStraight {
                let isStraightNode = Node(fillType: .color(.subSelected))
                self.isStraightNode = isStraightNode
                rootView.node.insert(child: isStraightNode,
                                         at: rootView.accessoryNodeIndex + 1)
                let (tempLine, _) = Self.line(from: drawLineEvents,
                                              enabledPressure: enabledPressure,
                                              firstSnapLines: snapLines,
                                              lastSnapLines: snapLines,
                                              clipBounds: clipBounds,
                                              isStraight: isStraight)
                firstPoint = tempLine.firstPoint
                updateStraightNode()
            }
            
            drawLineTimer = DispatchSource.scheduledTimer(withTimeInterval: 1 / 60) { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard let self, !(self.drawLineTimer?.isCancelled ?? true) else { return }
                    guard self.drawLineEvents.count != self.oldDrawLineEventsCount else { return }
                    let events = self.drawLineEvents
                    self.oldDrawLineEventsCount = events.count
                    let snapLines = self.snapLines, clipBounds = self.clipBounds,
                        enabledPressure = self.enabledPressure
                    
                    DispatchQueue.global().async { [weak self] in
                        let (tempLine, isSnapStraight) = Self.line(from: events,
                                                                   enabledPressure: enabledPressure,
                                                                   firstSnapLines: snapLines,
                                                                   lastSnapLines: snapLines,
                                                                   clipBounds: clipBounds,
                                                                   isStraight: isStraight)
                        let path = Path(tempLine)
                        let (linePathData, linePathBufferVertexCounts) = path.linePointsDataWith(lineWidth: tempLine.size)
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self, !(self.drawLineTimer?.isCancelled ?? true) else { return }
                            guard events.count > self.drawLineEventsCount else { return }
                            self.tempLineNode?.update(path: path,
                                                      withLinePathData: linePathData,
                                                      bufferVertexCounts: linePathBufferVertexCounts)
                            self.straightTime = (events.last?.time ?? 0) - self.beganTime
                            self.isSnapStraight = isSnapStraight
                            self.drawLineEventsCount = events.count
                        }
                    }
                }
            }
            break
        case .changed:
            drawLineEvents.append(.init(p: p - centerOrigin,
                                        sp: event.screenPoint,
                                        pressure: event.pressure,
                                        tiltAngle: event.tiltAngle,
                                        isTablet: event.isTablet,
                                        time: event.time,
                                        worldToScreenScale: rootView.worldToScreenScale,
                                        screenToWorldScale: rootView.screenToWorldScale,
                                        phase: .changed))
        case .ended:
            rootView.cursor = rootView.defaultCursor
            
            drawLineTimer?.cancel()
            
            drawLineEvents.append(.init(p: p - centerOrigin,
                                        sp: event.screenPoint,
                                        pressure: event.pressure,
                                        tiltAngle: event.tiltAngle,
                                        isTablet: event.isTablet,
                                        time: event.time,
                                        worldToScreenScale: rootView.worldToScreenScale,
                                        screenToWorldScale: rootView.screenToWorldScale,
                                        phase: .ended))
            let tempLine = Self.line(from: drawLineEvents,
                                     enabledPressure: enabledPressure,
                                     firstSnapLines: snapLines,
                                     lastSnapLines: snapLines,
                                     clipBounds: clipBounds,
                                     isStraight: isStraight).line
            
            guard !(tempLine.length() * rootView.worldToScreenScale < (event.isTablet ? 0.1 : 2) &&
                  event.time - beganTime < 3),
                  let lb = tempLine.bounds else {
                tempLineNode?.removeFromParent()
                tempLineNode = nil
                if isStraight {
                    isStraightNode?.removeFromParent()
                    isStraightNode = nil
                }
                
                rootAction.inputKey(with: .init(screenPoint: event.screenPoint,
                                                time: event.time, pressure: event.pressure,
                                                phase: .began, isRepeat: false,
                                                inputKeyType: .click))
                Sleep.start()
                rootAction.inputKey(with: .init(screenPoint: event.screenPoint,
                                                time: event.time, pressure: event.pressure,
                                                phase: .ended, isRepeat: false,
                                                inputKeyType: .click))
                return
            }
            
            if centerBounds.contains(lb),
               let sheetView = rootView.madeSheetView(at: centerSHP) {
                
                if sheetView.model.enabledAnimation, sheetView.id == beganSheetID,
                   beganAnimationRootIndex != sheetView.model.animation.rootIndex {
                    
                    let oldRootI = sheetView.model.animation.rootIndex
                    sheetView.rootKeyframeIndex = beganAnimationRootIndex
                    if !isUpdatedNewUndoGroupSheetViews.contains(sheetView) {
                        sheetView.newUndoGroup()
                        sheetView.unselect()
                    }
                    sheetView.append(tempLine)
                    sheetView.rootKeyframeIndex = oldRootI
                } else {
                    if !isUpdatedNewUndoGroupSheetViews.contains(sheetView) {
                        sheetView.newUndoGroup()
                        sheetView.unselect()
                    }
                    sheetView.append(tempLine)
                }
//                if sheetView.isSound {
//                    rootView.updateAudio()
//                }
            } else {
                var isWorldNewUndoGroup = true
                for shp in nearestShps {
                    let b = rootView.sheetFrame(with: shp) - centerOrigin
                    if lb.intersects(b),
                       let sheetView = rootView.madeSheetView(at: shp, isNewUndoGroup: isWorldNewUndoGroup) {
                        isWorldNewUndoGroup = false
                        let nLine = tempLine * Transform(translation: -b.origin)
                        if let b = sheetView.node.bounds {
                            let nLines = Sheet.clipped([nLine], in: b).filter {
                                if let b = $0.bounds {
                                    return max(b.width, b.height)
                                    > rootView.worldLineWidth * 4
                                } else {
                                    return true
                                }
                            }
                            if !nLines.isEmpty {
                                if !isUpdatedNewUndoGroupSheetViews.contains(sheetView) {
                                    sheetView.newUndoGroup()
                                    sheetView.unselect()
                                }
                                sheetView.append(nLines)
                            }
                        }
                    }
                }
            }
            
            tempLineNode?.removeFromParent()
            tempLineNode = nil
            if isStraight {
                isStraightNode?.removeFromParent()
                isStraightNode = nil
            }
        }
    }
    
    func lassoCut(with event: DragEvent) {
        lasso(with: event, .cut)
    }
    func lassoCopy(with event: DragEvent, distance: Double = 4) {
        lasso(with: event, .copy)
    }
    func lasso(with event: DragEvent, _ type: LassoType) {
        let p = rootView.convertScreenToWorld(event.screenPoint)
        switch event.phase {
        case .began:
            rootView.cursor = rootView.defaultCursor
            
            let sheetView = rootView.sheetView(at: p)
            let isScore = sheetView?.model.score.enabled ?? false
            
            if rootAction.isPlaying(with: event) {
                rootAction.stopPlaying(with: event)
                if !isScore { return }
            }
            rootView.closeLookingUp()
            
            if isEditingSheet {
                updateClipBoundsAndIndexRange(at: p)
                
                if let sheetView {
                    if isScore {
                        noteSheetView = sheetView
                    }
                    var isNewUndoGroup = true
                    sheetView.unselect(isNewUndoGroup: &isNewUndoGroup)
                    if !isNewUndoGroup {
                        isUpdatedNewUndoGroupSheetViews.insert(sheetView)
                    }
                }
            } else {
                if !rootView.world.selection.isEmpty {
                    rootView.newUndoGroup()
                    rootView.doSet(WorldSelection.empty)
                    isUpdatedNewUndoGroupWorld = true
                }
            }
            
            let path = tempLine.path(isClosed: true, isPolygon: false)
            lassoPathNodeLineWidth = 1 * rootView.screenToWorldScale
            let lineType = Node.LineType.color(type == .copy ? .selected : .removing)
            let fillType = Node.FillType.color(type == .copy ? .subSelected : .subRemoving)
            
            let outlineLassoNode = Node(attitude: Attitude(position: centerOrigin),
                                        path: path,
                                        lineWidth: lassoPathNodeLineWidth,
                                        lineType: lineType)
            let lassoNode = Node(attitude: Attitude(position: centerOrigin),
                                 path: path, fillType: fillType)
            selectingNode.lineType = lineType
            selectingNode.fillType = fillType
            let i = rootView.accessoryNodeIndex
            rootView.node.insert(child: lassoNode, at: i)
            rootView.node.insert(child: outlineLassoNode, at: i + 1)
            rootView.node.insert(child: selectingNode, at: i + 2)
            self.outlineLassoNode = outlineLassoNode
            self.lassoNode = lassoNode
            
            if !isEditingSheet {
                let rectNode = Node(lineWidth: lassoPathNodeLineWidth,
                                    lineType: lineType, fillType: fillType)
                self.rectNode = rectNode
                rootView.node.insert(child: rectNode, at: i)
            }
            
            drawLineEvents.append(.init(p: p - centerOrigin,
                                        sp: event.screenPoint,
                                        pressure: event.pressure,
                                        tiltAngle: event.tiltAngle,
                                        isTablet: event.isTablet,
                                        time: event.time,
                                        isClip: isEditingSheet,
                                        isSnap: false,
                                        worldToScreenScale: rootView.worldToScreenScale,
                                        screenToWorldScale: rootView.screenToWorldScale,
                                        phase: .began))
            
            snapLines = rootView.sheetView(at: centerSHP)?
                .model.picture.lines ?? []
            
            drawLineTimer = DispatchSource.scheduledTimer(withTimeInterval: 1 / 60) { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard let self, !(self.drawLineTimer?.isCancelled ?? true) else { return }
                    guard self.drawLineEvents.count != self.oldDrawLineEventsCount else { return }
                    let events = self.drawLineEvents
                    self.oldDrawLineEventsCount = events.count
                    let snapLines = self.snapLines, clipBounds = self.clipBounds,
                        enabledPressure = self.enabledPressure
                    DispatchQueue.global().async { [weak self] in
                        let (tempLine, _) = Self.line(from: events,
                                                      isClip: false,
                                                      enabledPressure: enabledPressure,
                                                      isSnap: false,
                                                      firstSnapLines: snapLines,
                                                      lastSnapLines: snapLines,
                                                      clipBounds: clipBounds,
                                                      isStraight: false)
                        let path = tempLine.path(isClosed: true, isPolygon: false)
                        DispatchQueue.main.async { [weak self] in
                            guard let self, !(self.drawLineTimer?.isCancelled ?? true) else { return }
                            guard events.count > self.drawLineEventsCount else { return }
                            
                            self.outlineLassoNode?.path = path
                            self.lassoNode?.path = path
                            
                            if self.isEditingSheet {
                                self.updateSelectingText()
                            } else {
                                self.updateSelectingSheetNodes(with: tempLine)
                            }
                            
                            self.drawLineEventsCount = events.count
                            
                            if !isScore,
                               let sheetView = self.rootView.sheetView(at: tempLine.lastPoint + self.centerOrigin),
                               !isUpdatedNewUndoGroupSheetViews.contains(sheetView) {
                                var isNewUndoGroup = true
                                sheetView.unselect(isNewUndoGroup: &isNewUndoGroup)
                                if !isNewUndoGroup {
                                    self.isUpdatedNewUndoGroupSheetViews.insert(sheetView)
                                }
                            }
                        }
                    }
                }
            }
        case .changed:
            drawLineEvents.append(.init(p: p - centerOrigin,
                                        sp: event.screenPoint,
                                        pressure: event.pressure,
                                        tiltAngle: event.tiltAngle,
                                        isTablet: event.isTablet,
                                        time: event.time,
                                        isClip: isEditingSheet,
                                        isSnap: false,
                                        worldToScreenScale: rootView.worldToScreenScale,
                                        screenToWorldScale: rootView.screenToWorldScale,
                                        phase: .changed))
        case .ended:
            rootView.cursor = rootView.defaultCursor
            
            drawLineTimer?.cancel()
            
            drawLineEvents.append(.init(p: p - centerOrigin,
                                        sp: event.screenPoint,
                                        pressure: event.pressure,
                                        tiltAngle: event.tiltAngle,
                                        isTablet: event.isTablet,
                                        time: event.time,
                                        isClip: isEditingSheet,
                                        isSnap: false,
                                        worldToScreenScale: rootView.worldToScreenScale,
                                        screenToWorldScale: rootView.screenToWorldScale,
                                        phase: .ended))
            
            tempLine = Self.line(from: drawLineEvents,
                                 isClip: false,
                                 enabledPressure: enabledPressure,
                                 isSnap: false,
                                 firstSnapLines: snapLines,
                                 lastSnapLines: snapLines,
                                 clipBounds: clipBounds,
                                 isStraight: false).line
            
            switch type {
            case .cut:
                if isEditingSheet {
                    if noteSheetView != nil {
                        removeNote(with: event)
                    } else {
                        lassoCopy(isRemove: true, distance: lassoDistance,
                                  at: rootView.roundedPoint(from: p))
                    }
                } else {
                    cutSheets(at: p)
                }
            case .copy:
                if isEditingSheet {
                    lassoCopy(isRemove: false, distance: lassoDistance,
                              at: rootView.roundedPoint(from: p))
                } else {
                    copySheets(at: p)
                }
            }
            
            lassoNode?.removeFromParent()
            outlineLassoNode?.removeFromParent()
            selectingNode.removeFromParent()
            outlineLassoNode = nil
            rectNode?.removeFromParent()
            
            isUpdatedNewUndoGroupSheetViews.forEach { rootView.updateFinding(from: $0) }
            rootView.updateFinding(at: p)
            
            rootView.updateSelectedFrame()
            rootView.showSelected()
        }
    }
    
    func updateSelectingText() {
        func selectingTextPaths(with nLine: Line,
                                with sheetView: SheetView) -> [Path] {
            guard let nlb = nLine.bounds else { return [] }
            let nPath = nLine.path(isClosed: true, isPolygon: false)
            var paths = [Path]()
            for textView in sheetView.textsView.elementViews {
                if textView.transformedBounds.intersects(nlb) {
                    let ranges = textView.lassoRanges(at: nPath)
                    for range in ranges {
                        for rect in textView.typesetter.rects(for: range) {
                            let r = textView.convertToWorld(rect)
                            paths.append(Path(r))
                        }
                    }
                }
            }
            return paths
        }
        guard let lb = tempLine.bounds else {
            selectingNode.children = []
            return
        }
        if centerBounds.contains(lb),
           let sheetView = rootView.sheetView(at: centerSHP) {
            
            let nLine = tempLine * Transform(translation: -centerBounds.origin)
            let paths = selectingTextPaths(with: nLine, with: sheetView)
            selectingNode.children = paths.map {
                Node(path: $0,
                     lineWidth: lassoPathNodeLineWidth,
                     lineType: selectingNode.lineType, fillType: selectingNode.fillType)
            }
        } else {
            var paths = [Path]()
            for shp in nearestShps {
                let b = rootView.sheetFrame(with: shp)
                if lb.intersects(b),
                   let sheetView = rootView.sheetView(at: shp) {
                    
                    let nLine = tempLine * Transform(translation: -b.origin)
                    paths += selectingTextPaths(with: nLine, with: sheetView)
                }
            }
            
            selectingNode.children = paths.map {
                Node(path: $0,
                     lineWidth: lassoPathNodeLineWidth,
                     lineType: selectingNode.lineType, fillType: selectingNode.fillType)
            }
        }
    }
    
    func lassoCopy(isRemove: Bool,
                   isEnableLine: Bool = true,
                   isEnablePlane: Bool = true,
                   isEnableText: Bool = true,
                   distance: Double = 0, at p: Point) {
        guard let lb = tempLine.bounds else { return }
        if centerBounds.contains(lb),
           let sheetView = rootView.sheetView(at: centerSHP) {
            
            let nLine = tempLine * Transform(translation: -centerBounds.origin)
            let d = distance  * rootView.screenToWorldScale
            if let value = sheetView.lassoErase(with: Lasso(line: nLine),
                                                isRemove: isRemove,
                                                isEnableLine: isEnableLine,
                                                isEnablePlane: isEnablePlane,
                                                isEnableText: isEnableText,
                                                isUpdatedNewUndoGroup: isUpdatedNewUndoGroupSheetViews.contains(sheetView),
                                                distance: d) {
                let np = sheetView.convertFromWorld(p)
                let t = Transform(translation: -np)
                var nValue = value * t
                nValue.origin = np
                if let s = nValue.string {
                    Pasteboard.shared.copiedObjects = [.sheetValue(nValue), .string(s)]
                } else {
                    Pasteboard.shared.copiedObjects = [.sheetValue(nValue)]
                }
            }
        } else {
            var value = SheetValue(isSelected: true)
            for shp in nearestShps {
                let b = rootView.sheetFrame(with: shp) - centerOrigin
                if lb.intersects(b),
                   let sheetView = rootView.sheetView(at: shp) {
                    
                    let nLine = tempLine * Transform(translation: -b.origin)
                    if let aValue
                        = sheetView.lassoErase(with: Lasso(line: nLine),
                                               isRemove: isRemove,
                                               isEnableLine: isEnableLine,
                                               isEnablePlane: isEnablePlane,
                                               isEnableText: isEnableText,
                                               isUpdatedNewUndoGroup: isUpdatedNewUndoGroupSheetViews.contains(sheetView)) {
                        let t = Transform(translation: -sheetView.convertFromWorld(p))
                        value += aValue * t
                    }
                }
            }
            
            if !value.isEmpty {
                if let s = value.string {
                    Pasteboard.shared.copiedObjects = [.sheetValue(value), .string(s)]
                } else {
                    Pasteboard.shared.copiedObjects = [.sheetValue(value)]
                }
            }
        }
    }
    
    var rectNode: Node?
    
    struct Value {
        var shp: IntPoint, frame: Rect
    }
    func values(with line: Line) -> [Value] {
        guard let rect = line.bounds else { return [] }
        let minXMinYSHP = rootView.sheetPosition(at: rect.minXMinYPoint)
        let maxXMinYSHP = rootView.sheetPosition(at: rect.maxXMinYPoint)
        let minXMaxYSHP = rootView.sheetPosition(at: rect.minXMaxYPoint)
        let lx = minXMinYSHP.x, rx = maxXMinYSHP.x
        let by = minXMinYSHP.y, ty = minXMaxYSHP.y
        
        var vs = [Value]()
        for shp in rootView.world.sheetIDs.keys {
            if shp.x >= lx && shp.x <= rx {
                if shp.y >= by && shp.y <= ty {
                    let frame = rootView.sheetFrame(with: shp)
                    if line.lassoIntersects(frame) {
                        vs.append(Value(shp: shp, frame: frame))
                    }
                }
            }
        }
        return vs
    }
    func updateSelectingSheetNodes(with line: Line) {
        guard let rectNode = rectNode else { return }
        rectNode.children = values(with: line).map {
            Node(path: Path($0.frame),
                 lineWidth: rectNode.lineWidth, lineType: rectNode.lineType,
                 fillType: rectNode.fillType)
        }
    }
    
    func updateWithCopySheet(at dp: Point, from values: [Value]) {
        var csv = CopiedSheetsValue(isSelected: true)
        for value in values {
            if let sid = rootView.sheetID(at: value.shp) {
                csv.sheetIDs[value.shp] = sid
            }
        }
        csv.deltaPoint = dp
        Pasteboard.shared.copiedObjects = [.copiedSheetsValue(csv)]
    }
    func cutSheets(at p: Point) {
        let values = self.values(with: tempLine)
        updateWithCopySheet(at: p, from: values)
        if !values.isEmpty {
            if !isUpdatedNewUndoGroupWorld {
                rootView.newUndoGroup()
            }
            rootView.removeSheets(at: values.map { $0.shp })
        }
    }
    func copySheets(at p: Point) {
        updateWithCopySheet(at: p, from: values(with: tempLine))
    }
}
